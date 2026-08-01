import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/data_streams.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/money.dart';
import '../../data/collections/catalog_collections.dart';
import '../../data/collections/sales_collections.dart';
import '../../data/enums/app_enums.dart';
import 'package:isar_community/isar.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/core_providers.dart';
import '../../data/collections/people_collections.dart';
import '../../domain/repositories/sales_repository.dart';
import '../../domain/services/receipt_builder.dart';
import '../../core/services/thermal_printer_service.dart';
import '../../core/services/receipt_formatter.dart';
import '../print/receipt_sheet.dart';
import '../shared/widgets.dart';
import 'widgets/modifier_sheet.dart';
import 'widgets/payment_sheet.dart';

class SalesScreen extends ConsumerStatefulWidget {
  final int orderId;
  const SalesScreen({super.key, required this.orderId});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  int? _selectedCat;

  int get _orderId => widget.orderId;

  // --- islemler ---

  Future<void> _addProduct(Product p) async {
    final repo = ref.read(orderRepositoryProvider);
    if (p.modifierGroups.isNotEmpty) {
      final r = await ModifierSheet.show(context, p);
      if (r == null) return;
      await repo.addLine(_orderId, _input(p, r.qty, r.modifiers, r.note));
    } else {
      await repo.addLine(_orderId, _input(p, 1, const [], ''));
    }
  }

  LineInput _input(
          Product p, double qty, List<SelectedModifier> mods, String note) =>
      LineInput(
        productId: p.id,
        productName: p.name,
        categoryId: p.categoryId,
        unitPriceKurus: p.salePriceKurus,
        costPriceKurus: p.costPriceKurus,
        qty: qty,
        vatRate: p.vatRate,
        modifiers: mods,
        note: note,
      );

  Future<void> _editLine(OrderLine line) async {
    final repo = ref.read(orderRepositoryProvider);
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        var qty = line.qty;
        return StatefulBuilder(
          builder: (ctx, setM) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(line.productName,
                      style: Theme.of(ctx).textTheme.titleLarge),
                  if (line.note.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Not: ${line.note}',
                          style: Theme.of(ctx).textTheme.bodySmall),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Adet',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      QtyStepper(
                        value: qty,
                        onChanged: (v) => setM(() => qty = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Hızlı Miktar Seçim Butonları
                  Wrap(
                    spacing: 8,
                    children: [1, 2, 3, 5, 10].map((q) => ActionChip(
                      label: Text('$q adet'),
                      onPressed: () => setM(() => qty = q.toDouble()),
                    )).toList(),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final emp = ref.read(currentEmployeeProvider);
                            final canVoid = emp == null || emp.role == EmployeeRole.admin || emp.role == EmployeeRole.manager || emp.canVoid;
                            
                            if (canVoid) {
                              // Yetkisi var, direkt sil!
                              await repo.voidLine(line.id, 'Iptal');
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ürün başarıyla iptal edildi.')));
                              }
                            } else {
                              // Yetkisi YOK! İptal işlemi onaya (Patrona) düşer.
                              final isar = ref.read(isarProvider);
                              line.isVoidPending = true;
                              line.voidRequestedById = emp.id;
                              await isar.writeTxn(() async => await isar.orderLines.put(line));
                              
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                  content: Text('İptal talebi Patron / Yönetici onayına gönderildi.'),
                                  backgroundColor: AppColors.warning,
                                ));
                              }
                            }
                          },
                          style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Sil / İptal'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: FilledButton(
                          onPressed: () async {
                            await repo.setLineQty(line.id, qty);
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          child: const Text('Kaydet'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _editDiscount(Order order) async {
    var type = order.discountType;
    final ctrl = TextEditingController(
        text: order.discountType == DiscountType.percent
            ? order.discountValue.toStringAsFixed(0)
            : Money.plain(order.discountValue.round()));
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => AlertDialog(
          title: const Text('Indirim'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<DiscountType>(
                segments: const [
                  ButtonSegment(value: DiscountType.none, label: Text('Yok')),
                  ButtonSegment(
                      value: DiscountType.amount, label: Text('Tutar')),
                  ButtonSegment(
                      value: DiscountType.percent, label: Text('%')),
                ],
                selected: {type},
                onSelectionChanged: (s) => setM(() => type = s.first),
              ),
              if (type != DiscountType.none) ...[
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      suffixText:
                          type == DiscountType.percent ? '%' : 'TL'),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Vazgec')),
            FilledButton(
              onPressed: () async {
                final value = type == DiscountType.none
                    ? 0.0
                    : type == DiscountType.percent
                        ? (double.tryParse(ctrl.text) ?? 0)
                        : Money.parse(ctrl.text).toDouble();
                await ref
                    .read(orderRepositoryProvider)
                    .setDiscount(_orderId, type, value);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Uygula'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pay(Order order) async {
    final emp = ref.read(currentEmployeeProvider);
    final canPay = emp == null || emp.role == EmployeeRole.admin || emp.role == EmployeeRole.manager || emp.canTakePayment;

    if (!canPay) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Ödeme alma ve kasayı açma yetkiniz bulunmuyor.'),
        backgroundColor: AppColors.danger,
      ));
      return;
    }

    if (order.totalKurus <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Adisyon bos.')));
      return;
    }
    final ok = await PaymentSheet.show(context, order);
    if (ok == true && mounted) {
      // Fis: odeme sonrasi cikti secenekleri (termal / PDF). Ayar acik + yazici
      // varsa otomatik termal basar; degilse kullanici secer ya da kapatir.
      await ReceiptSheet.show(context, order.id, autoPrint: true);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Odeme alindi, adisyon kapatildi.')));
      }
    }
  }

  Future<void> _cancel(Order order) async {
    final emp = ref.read(currentEmployeeProvider);
    final canVoid = emp == null || emp.role == EmployeeRole.admin || emp.role == EmployeeRole.manager || emp.canVoid;

    if (!canVoid) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Tüm adisyonu iptal etme yetkiniz yok. Ürünleri tek tek onaya gönderebilirsiniz.'),
        backgroundColor: AppColors.danger,
      ));
      return;
    }

    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adisyonu iptal et?'),
        content: const Text('Bu adisyon iptal edilecek.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hayir')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Evet, iptal et')),
        ],
      ),
    );
    if (yes != true) return;
    await ref.read(orderRepositoryProvider).cancelOrder(_orderId, 'Kullanici');
    if (order.tableId != null) {
      await ref
          .read(tableRepositoryProvider)
          .setStatus(order.tableId!, TableStatus.empty);
    }
    if (mounted) Navigator.of(context).pop();
  }

  // --- yapilar ---

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderStreamProvider(_orderId));
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return orderAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Hata: $e'))),
      data: (order) {
        if (order == null) {
          return const Scaffold(body: Center(child: Text('Siparis yok')));
        }
        final title = order.type == OrderType.package
            ? 'Paket • #${order.receiptNo}'
            : 'Adisyon • #${order.receiptNo}';
        return Scaffold(
          appBar: AppBar(
            title: Text(title),
            leading: IconButton(
              tooltip: 'Vazgeç / Geri Dön',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).pop(), // Siparişi silmeden direkt ekrandan çıkış sağlar
            ),
            actions: [
              IconButton(
                tooltip: 'Mutfaga Gonder',
                icon: const Icon(Icons.soup_kitchen_outlined),
                onPressed: () => _sendToKitchen(),
              ),
              IconButton(
                tooltip: 'Adisyonu İptal Et',
                icon: const Icon(Icons.delete_sweep_outlined),
                onPressed: () => _cancel(order),
              ),
            ],
          ),
          body: wide
              ? Row(
                  children: [
                    Expanded(flex: 3, child: _productsArea()),
                    const VerticalDivider(width: 1),
                    SizedBox(width: 360, child: _cart(order, inline: true)),
                  ],
                )
              : _productsArea(),
          bottomNavigationBar: wide ? null : _bottomBar(order),
        );
      },
    );
  }

  Future<void> _sendToKitchen() async {
    final count = await ref.read(orderRepositoryProvider).sendToKitchen(_orderId);
    
    if (count > 0) {
      try {
        final settingsRepo = ref.read(settingsRepositoryProvider);
        final settings = await settingsRepo.getSettings();
        final mode = settings.kitchenMode;

        if (mode == 'print_only' || mode == 'both') {
          final isar = ref.read(isarProvider);
          final builder = ReceiptBuilder(isar, settingsRepo);
          
          final kitchenReceipts = await builder.buildForKitchen(_orderId);
          
          for (final item in kitchenReceipts) {
            // Eğer ürünün departmanı varsa onun yazıcısına, yoksa (null ise) varsayılan ana mutfak yazıcısına yolla
            final targetMac = item.department?.printerMac ?? settings.kitchenPrinterMac;
            
            if (targetMac != null && targetMac.isNotEmpty) {
              final bytes = await ReceiptFormatter.format(item.receipt);
              await ThermalPrinterService().printBytes(mac: targetMac, bytes: bytes);
            }
          }
        }
      } catch (e) {
        debugPrint('Mutfak yazdırma hatası: $e');
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(count > 0
          ? '$count kalem mutfaga gonderildi'
          : 'Gonderilecek yeni kalem yok'),
    ));
  }

  Widget _bottomBar(Order order) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (_) => FractionallySizedBox(
                    heightFactor: 0.9,
                    child: _cart(order, inline: false),
                  ),
                ),
                icon: const Icon(Icons.receipt_long),
                label: Text('Adisyon  ${Money.format(order.totalKurus)}'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _pay(order),
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Ode'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _productsArea() {
    final catsAsync = ref.watch(categoriesStreamProvider);
    return catsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e')),
      data: (cats) {
        if (cats.isEmpty) {
          return const EmptyState(
              icon: Icons.category_outlined,
              message:
                  'Once kategori ve urun ekleyin.\n(Urunler / Kategoriler)');
        }
        final selected = _selectedCat ?? cats.first.id;
        return Column(
          children: [
            SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                itemCount: cats.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (_, i) {
                  final c = cats[i];
                  final sel = c.id == selected;
                  return ChoiceChip(
                    selected: sel,
                    label: Text(c.name),
                    onSelected: (_) => setState(() => _selectedCat = c.id),
                  );
                },
              ),
            ),
            Expanded(child: _grid(selected)),
          ],
        );
      },
    );
  }

  Widget _grid(int categoryId) {
    final prodsAsync = ref.watch(productsByCategoryProvider(categoryId));
    return prodsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e')),
      data: (products) {
        if (products.isEmpty) {
          return const EmptyState(
              icon: Icons.fastfood_outlined,
              message: 'Bu kategoride urun yok.');
        }
        return LayoutBuilder(builder: (ctx, c) {
          final cols = (c.maxWidth / 180).floor().clamp(2, 6);
          return GridView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              childAspectRatio: 0.85,
            ),
            itemCount: products.length,
            itemBuilder: (_, i) => _productCard(products[i]),
          );
        });
      },
    );
  }

  Widget _productCard(Product p) {
    final lowStock = p.lowStock;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _addProduct(p),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _productImage(p)),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      MoneyText(p.salePriceKurus,
                          style: const TextStyle(
                              color: AppColors.amber,
                              fontWeight: FontWeight.w700)),
                      if (lowStock)
                        const Icon(Icons.warning_amber_rounded,
                            size: 16, color: AppColors.warning),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _productImage(Product p) {
    final placeholder = Container(
      color: Color(p.modifierGroups.isEmpty ? 0xFF2A2D35 : 0xFF33363F),
      alignment: Alignment.center,
      child: Text(
        p.name.isNotEmpty ? p.name.characters.first.toUpperCase() : '?',
        style: const TextStyle(
            fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.amber),
      ),
    );
    if (p.imagePath == null || p.imagePath!.isEmpty) return placeholder;
    return Image.file(
      File(p.imagePath!),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => placeholder,
    );
  }

  // --- adisyon paneli ---

  Widget _cart(Order order, {required bool inline}) {
    final linesAsync = ref.watch(orderLinesStreamProvider(_orderId));
    return Container(
      color: inline ? Theme.of(context).colorScheme.surface : null,
      child: Column(
        children: [
          if (!inline)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Text('Adisyon',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
            ),
          Expanded(
            child: linesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Hata: $e')),
              data: (lines) {
                final active = lines.where((l) => !l.isVoid).toList();
                if (active.isEmpty) {
                  return const EmptyState(
                      icon: Icons.shopping_cart_outlined,
                      message: 'Urun ekleyin');
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm),
                  itemCount: active.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => _lineTile(active[i]),
                );
              },
            ),
          ),
          _totals(order),
        ],
      ),
    );
  }

  Widget _lineTile(OrderLine line) {
    final qtyLabel =
        line.qty == line.qty.roundToDouble() ? '${line.qty.toInt()}' : '${line.qty}';
    final modText = line.modifiers.map((m) => m.optionName).join(', ');
    
    // Eğer ürün iptal onayı bekliyorsa (Garson silmiş ama patron onaylamamış)
    final isPending = line.isVoidPending;

    return ListTile(
      dense: true,
      enabled: !isPending, // Beklemedeki ürüne bir daha tıklanamaz
      onTap: isPending ? null : () => _editLine(line),
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: isPending ? AppColors.dTextDim : AppColors.amber.withValues(alpha: 0.2),
        child: Text('${qtyLabel}x',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(line.productName, 
              maxLines: 1, 
              overflow: TextOverflow.ellipsis,
              style: TextStyle(decoration: isPending ? TextDecoration.lineThrough : null)
            )
          ),
          if (isPending) const Icon(Icons.hourglass_empty_rounded, size: 14, color: AppColors.warning),
        ],
      ),
      subtitle: (modText.isNotEmpty || line.note.isNotEmpty || isPending)
          ? Text(
              isPending ? '⏳ İptal Onayı Bekliyor' : [if (modText.isNotEmpty) modText, if (line.note.isNotEmpty) line.note].join(' • '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: isPending ? AppColors.warning : null))
          : null,
      trailing: MoneyText(line.lineTotalKurus,
          style: TextStyle(fontWeight: FontWeight.w600, decoration: isPending ? TextDecoration.lineThrough : null)),
    );
  }

  Widget _totals(Order order) {
    return Material(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            _totalRow('Ara Toplam', order.subtotalKurus),
            if (order.discountAmountKurus > 0)
              _totalRow('Indirim', -order.discountAmountKurus,
                  color: AppColors.success),
            _totalRow('KDV (dahil)', order.vatTotalKurus, dim: true),
            const SizedBox(height: 4),
            _totalRow('GENEL TOPLAM', order.totalKurus, bold: true),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _editDiscount(order),
                    icon: const Icon(Icons.percent, size: 18),
                    label: const Text('Indirim'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () => _pay(order),
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('Odeme / Bol'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _totalRow(String label, int kurus,
      {bool bold = false, bool dim = false, Color? color}) {
    final style = TextStyle(
      fontSize: bold ? 17 : 13,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      color: color ?? (dim ? AppColors.dTextDim : null),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), MoneyText(kurus, style: style)],
      ),
    );
  }
}
