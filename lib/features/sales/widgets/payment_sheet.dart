import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/service_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/money.dart';
import '../../../data/collections/sales_collections.dart';
import '../../../data/enums/app_enums.dart';
import '../../../domain/repositories/sales_repository.dart';
import '../../shared/widgets.dart';
import '../../../domain/services/receipt_builder.dart';
import '../../../core/services/thermal_printer_service.dart';
import '../../../core/services/receipt_formatter.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/providers/data_streams.dart';



/// Odeme + Hesap Bol ekrani. Birden fazla odeme satiri eklenebilir
/// (orn: 100 nakit + 50 kart) => kismi / bolunmus odeme.
class PaymentSheet extends ConsumerStatefulWidget {
  final Order order;
  const PaymentSheet({super.key, required this.order});

  static Future<bool?> show(BuildContext context, Order order) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => PaymentSheet(order: order),
    );
  }

  @override
  ConsumerState<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<PaymentSheet> {
  final List<PaymentInput> _payments = [];
  bool _busy = false;
  bool _printReceipt = true;
  
  bool _splitMode = false;
  final Set<int> _selectedLines = {};

  int get _total => widget.order.totalKurus;
  int get _paid => _payments.fold(0, (s, p) => s + p.amountKurus);
  int get _remaining => (_total - _paid).clamp(0, _total);
  int get _change => _paid > _total ? _paid - _total : 0;

  String _methodName(PaymentMethod m) => switch (m) {
        PaymentMethod.cash => 'Nakit',
        PaymentMethod.card => 'Kart',
        PaymentMethod.meal => 'Yemek Karti',
        PaymentMethod.other => 'Diger',
      };

  Future<void> _addAmount(PaymentMethod method, {int? suggestedAmount}) async {
    final amount = await _askAmount(suggested: suggestedAmount ?? _remaining);
    if (amount == null || amount <= 0) return;
    setState(() {
      _payments.add(PaymentInput(method, amount));
      _selectedLines.clear(); // Ödeme alındığında seçili ürünleri sıfırla
    });
  }

  Future<int?> _askAmount({required int suggested}) async {
    final ctrl = TextEditingController(text: Money.plain(suggested));
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tutar'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(suffixText: 'TL'),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final banknot in [50, 100, 200, 500, 1000])
                  if (banknot * 100 > suggested)
                    ActionChip(
                      label: Text('$banknot TL'),
                      onPressed: () {
                        ctrl.text = banknot.toString();
                        // İmleci sona al
                        ctrl.selection = TextSelection.fromPosition(
                          TextPosition(offset: ctrl.text.length),
                        );
                      },
                    ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Vazgec')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, Money.parse(ctrl.text)),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirm() async {
    if (_paid < _total) return;
    setState(() => _busy = true);
    final res = await ref
        .read(checkoutServiceProvider)
        .payAndClose(orderId: widget.order.id, payments: _payments);
    if (!mounted) return;
    
    res.when(
      ok: (_) async {
        // Ödeme başarılı! Eğer kullanıcı fiş istediyse yazdır
        if (_printReceipt) {
          try {
            final isar = ref.read(isarProvider);
            final settings = ref.read(settingsRepositoryProvider);
            final builder = ReceiptBuilder(isar, settings);
            
            final receiptData = await builder.forOrder(widget.order.id);
            if (receiptData != null) {
              final bytes = await ReceiptFormatter.format(receiptData);
              await ThermalPrinterService().printBytes(mac: '00:11:22:33:44:55', bytes: bytes);
            }
          } catch (e) {
            debugPrint('Ödeme sonrası otomatik yazdırma hatası: $e');
          }
        }

        if (mounted) Navigator.pop(context, true);
      },
      err: (f) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(f.message)));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final canConfirm = _paid >= _total && _total > 0 && !_busy;
    final linesAsync = ref.watch(orderLinesStreamProvider(widget.order.id));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Odeme  •  Fis #${widget.order.receiptNo}', style: t.titleLarge),
                FilterChip(
                  label: const Text('Alman Usulü'),
                  selected: _splitMode,
                  onSelected: (v) => setState(() {
                    _splitMode = v;
                    _selectedLines.clear();
                  }),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _row('Genel Toplam', _total, bold: true),
            _row('Odenen', _paid),
            if (_remaining > 0)
              _row('Kalan', _remaining, color: AppColors.warning),
            if (_change > 0)
              _row('Para Ustu', _change, color: AppColors.success),
            const Divider(height: AppSpacing.xl),

            if (_splitMode) ...[
              linesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => const SizedBox(),
                data: (lines) {
                  final activeLines = lines.where((l) => !l.isVoid).toList();
                  int selectedSum = activeLines
                      .where((l) => _selectedLines.contains(l.id))
                      .fold(0, (s, l) => s + l.lineTotalKurus);
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Ödenecek Ürünleri Seçin', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.amber)),
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 160),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: activeLines.length,
                          itemBuilder: (ctx, i) {
                            final l = activeLines[i];
                            return CheckboxListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(l.productName, maxLines: 1, overflow: TextOverflow.ellipsis),
                              secondary: MoneyText(l.lineTotalKurus),
                              value: _selectedLines.contains(l.id),
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) _selectedLines.add(l.id);
                                  else _selectedLines.remove(l.id);
                                });
                              },
                            );
                          }
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Seçili Tutar:', style: TextStyle(fontWeight: FontWeight.w700)),
                            MoneyText(selectedSum, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.amber)),
                          ],
                        ),
                      ),
                      const Divider(height: AppSpacing.md),
                    ],
                  );
                },
              ),
            ],

            // Hizli butonlar
            Builder(
              builder: (ctx) {
                int suggested = _remaining;
                if (_splitMode && _selectedLines.isNotEmpty) {
                  final lines = linesAsync.value ?? [];
                  final selectedSum = lines.where((l) => _selectedLines.contains(l.id)).fold(0, (s, l) => s + l.lineTotalKurus);
                  suggested = selectedSum > _remaining ? _remaining : selectedSum;
                }
                
                return Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    if (!_splitMode) ...[
                      _quick('Tam Nakit', () async {
                        setState(() {
                          _payments..clear()..add(PaymentInput(PaymentMethod.cash, _total));
                        });
                        await _confirm();
                      }),
                      _quick('Tam Kart', () async {
                        setState(() {
                          _payments..clear()..add(PaymentInput(PaymentMethod.card, _total));
                        });
                        await _confirm();
                      }),
                    ],
                    _quick('+ Nakit', () => _addAmount(PaymentMethod.cash, suggestedAmount: suggested)),
                    _quick('+ Kart', () => _addAmount(PaymentMethod.card, suggestedAmount: suggested)),
                    _quick('+ Yemek K.', () => _addAmount(PaymentMethod.meal, suggestedAmount: suggested)),
                  ],
                );
              }
            ),

            if (_payments.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              ..._payments.asMap().entries.map((e) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.payments_outlined),
                    title: Text(_methodName(e.value.method)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MoneyText(e.value.amountKurus),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () =>
                              setState(() => _payments.removeAt(e.key)),
                        ),
                      ],
                    ),
                  )),
            ],

            const SizedBox(height: AppSpacing.md),
            CheckboxListTile(
              value: _printReceipt,
              onChanged: _busy ? null : (v) => setState(() => _printReceipt = v ?? true),
              title: const Text('Ödeme Sonrası Fiş Yazdır'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),

            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: canConfirm ? _confirm : null,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check_circle_outline),
              label: const Text('Odemeyi Tamamla'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quick(String label, VoidCallback onTap) =>
      OutlinedButton(onPressed: _busy ? null : onTap, child: Text(label));

  Widget _row(String label, int kurus,
      {bool bold = false, Color? color}) {
    final style = TextStyle(
      fontSize: bold ? 18 : 15,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
      color: color,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), MoneyText(kurus, style: style)],
      ),
    );
  }
}
