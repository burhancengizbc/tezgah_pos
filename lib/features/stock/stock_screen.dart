import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/data_streams.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/money.dart';
import '../../data/collections/catalog_collections.dart';
import '../../data/collections/finance_collections.dart';
import '../../data/enums/app_enums.dart';
import '../shared/widgets.dart';

/// Stok yonetimi: seviyeler, kritik stok uyarilari, giris/cikis/sayim/fire.
class StockScreen extends ConsumerStatefulWidget {
  const StockScreen({super.key});

  @override
  ConsumerState<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends ConsumerState<StockScreen> {
  String _query = '';
  bool _onlyCritical = false;

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(allProductsStreamProvider);
    final settings = ref.watch(settingsStreamProvider).value;
    final wasteOn = settings?.wasteModuleEnabled ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Stok')),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('Hata: $e'),
        data: (all) {
          final numeric =
              all.where((p) => p.stockType == StockType.numeric).toList();
          final lowCount = numeric.where((p) => p.lowStock).length;

          var list = numeric;
          if (_query.trim().isNotEmpty) {
            final q = _query.toLowerCase();
            list = list.where((p) => p.name.toLowerCase().contains(q)).toList();
          }
          if (_onlyCritical) list = list.where((p) => p.lowStock).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Urun ara...',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              if (lowCount > 0)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Material(
                    color: AppColors.warning.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(AppSpacing.rMd),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppSpacing.rMd),
                      onTap: () => setState(() => _onlyCritical = !_onlyCritical),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: AppColors.warning),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                '$lowCount urun kritik stok seviyesinde',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            Text(_onlyCritical ? 'Tumunu goster' : 'Filtrele',
                                style: const TextStyle(
                                    color: AppColors.warning,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: list.isEmpty
                    ? const EmptyState(
                        icon: Icons.inventory_2_outlined,
                        message: 'Sayisal stoklu urun yok.\n'
                            '(Urun duzenlemede stok turunu "Sayisal" yapin.)')
                    : ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) => _row(list[i], wasteOn),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(Product p, bool wasteOn) {
    final low = p.lowStock;
    final qtyText = p.stockQty % 1 == 0
        ? p.stockQty.toInt().toString()
        : p.stockQty.toStringAsFixed(2);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(p.name),
      subtitle: Text(low
          ? 'Min: ${p.minStock % 1 == 0 ? p.minStock.toInt() : p.minStock}'
          : 'Maliyet: ${Money.format(p.costPriceKurus)}'),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: (low ? AppColors.warning : AppColors.success)
              .withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(qtyText,
            style: TextStyle(
                fontWeight: FontWeight.w800,
                color: low ? AppColors.warning : AppColors.success)),
      ),
      onTap: () => _actions(p, wasteOn),
    );
  }

  Future<void> _actions(Product p, bool wasteOn) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(p.name,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('Mevcut stok: '
                  '${p.stockQty % 1 == 0 ? p.stockQty.toInt() : p.stockQty}'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.add_circle_outline_rounded,
                  color: AppColors.success),
              title: const Text('Stok girisi'),
              onTap: () {
                Navigator.pop(c);
                _qtyOp(p, StockMovementType.manualIn, 'Stok girisi');
              },
            ),
            ListTile(
              leading: const Icon(Icons.remove_circle_outline_rounded),
              title: const Text('Stok cikisi'),
              onTap: () {
                Navigator.pop(c);
                _qtyOp(p, StockMovementType.manualOut, 'Stok cikisi');
              },
            ),
            ListTile(
              leading: const Icon(Icons.fact_check_outlined),
              title: const Text('Sayim (gercek miktari gir)'),
              onTap: () {
                Navigator.pop(c);
                _countOp(p);
              },
            ),
            if (wasteOn)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.danger),
                title: const Text('Fire / zayi'),
                onTap: () {
                  Navigator.pop(c);
                  _qtyOp(p, StockMovementType.waste, 'Fire');
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _qtyOp(
      Product p, StockMovementType type, String title) async {
    final qty = await _askQty(title, p);
    if (qty == null || qty <= 0) return;
    await ref.read(stockRepositoryProvider).adjust(
          productId: p.id,
          type: type,
          qty: qty,
          note: title,
        );
    // Fire ve gidere yansitma
    if (type == StockMovementType.waste) {
      final settings = ref.read(settingsStreamProvider).value;
      if ((settings?.wasteAsExpense ?? true) && p.costPriceKurus > 0) {
        final entry = AccountingEntry()
          ..kind = AccountingKind.expense
          ..expenseCategory = ExpenseCategory.supplies
          ..amountKurus = (p.costPriceKurus * qty).round()
          ..title = 'Fire: ${p.name}'
          ..note = '${qty % 1 == 0 ? qty.toInt() : qty} adet zayi';
        await ref.read(accountingRepositoryProvider).addEntry(entry);
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$title islendi')));
    }
  }

  Future<void> _countOp(Product p) async {
    final target = await _askQty('Sayim - gercek miktar', p, initial: p.stockQty);
    if (target == null) return;
    final delta = target - p.stockQty;
    if (delta == 0) return;
    await ref.read(stockRepositoryProvider).adjust(
          productId: p.id,
          type: StockMovementType.adjust,
          qty: delta,
          note: 'Sayim duzeltmesi',
        );
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Sayim guncellendi')));
    }
  }

  Future<double?> _askQty(String title, Product p, {double? initial}) async {
    final ctrl = TextEditingController(
        text: initial != null
            ? (initial % 1 == 0 ? initial.toInt().toString() : '$initial')
            : '');
    return showDialog<double>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Miktar',
            suffixText: p.sellByWeight ? 'kg' : 'adet',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Vazgec')),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text.replaceAll(',', '.'));
              Navigator.pop(c, v);
            },
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }
}
