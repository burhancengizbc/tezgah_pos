import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/core_providers.dart';
import '../../core/providers/data_streams.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/collections/business_collections.dart';
import '../../data/collections/people_collections.dart';
import '../../data/collections/sales_collections.dart';
import '../../data/enums/app_enums.dart';
import '../shared/widgets.dart';
import '../../domain/models/receipt_data.dart';
import '../../core/services/receipt_formatter.dart';
import '../../core/services/thermal_printer_service.dart';

/// Mutfak Ekrani (KDS). Garsonun "Mutfaga Gonder" dedigi satirlar burada
/// ticket olarak gorunur; canli yenilenir. Hazir / Servis aksiyonlari.
class KitchenScreen extends ConsumerStatefulWidget {
  const KitchenScreen({super.key});
  @override
  ConsumerState<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends ConsumerState<KitchenScreen> {
  Timer? _tick;
  final FocusNode _focusNode = FocusNode(); // Fiziksel Tuş Takımı (Bump Bar) için

  @override
  void initState() {
    super.initState();
    // Bekleme suresi gostergesini guncel tutmak icin periyodik yenile.
    _tick = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  Future<Map<int, Order>> _loadOrders(List<int> ids) async {
    if (ids.isEmpty) return {};
    final list = await ref.read(isarProvider).collection<Order>().getAll(ids);
    return {for (final o in list.whereType<Order>()) o.id: o};
  }

  // Odenmis/iptal siparisler mutfak panosunda gosterilmez.
  bool _active(Order? o) =>
      o == null ||
      (o.status != OrderStatus.paid && o.status != OrderStatus.cancelled);

  @override
  Widget build(BuildContext context) {
    final linesAsync = ref.watch(kitchenLinesProvider);
    final tables = ref.watch(tablesStreamProvider).value ?? [];
    final tableMap = {for (final t in tables) t.id: t};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mutfak Ekrani'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: linesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('Hata: $e'),
        data: (lines) {
          if (lines.isEmpty) {
            return const EmptyState(
              icon: Icons.restaurant_rounded,
              message: 'Mutfakta bekleyen siparis yok.',
            );
          }
          // orderId -> satirlar
          final byOrder = <int, List<OrderLine>>{};
          for (final l in lines) {
            byOrder.putIfAbsent(l.orderId, () => []).add(l);
          }
          final orderIds = byOrder.keys.toList();

          return FutureBuilder<Map<int, Order>>(
            future: _loadOrders(orderIds),
            builder: (context, snap) {
              final orders = snap.data ?? {};
              
              // Ekranda aktif görünen siparişleri sıralı bir listeye alıyoruz
              final activeOrderIds = orderIds.where((id) => _active(orders[id])).toList();

              return Focus(
                focusNode: _focusNode,
                autofocus: true,
                onKeyEvent: (node, event) {
                  // Sadece tuşa basılma (aşağı inme) anını yakala
                  if (event is KeyDownEvent) {
                    int? ticketIndex;
                    // Klavyedeki 1-9 arası tuşları veya NumPad'i dinle
                    if (event.logicalKey == LogicalKeyboardKey.digit1 || event.logicalKey == LogicalKeyboardKey.numpad1) ticketIndex = 0;
                    if (event.logicalKey == LogicalKeyboardKey.digit2 || event.logicalKey == LogicalKeyboardKey.numpad2) ticketIndex = 1;
                    if (event.logicalKey == LogicalKeyboardKey.digit3 || event.logicalKey == LogicalKeyboardKey.numpad3) ticketIndex = 2;
                    if (event.logicalKey == LogicalKeyboardKey.digit4 || event.logicalKey == LogicalKeyboardKey.numpad4) ticketIndex = 3;
                    if (event.logicalKey == LogicalKeyboardKey.digit5 || event.logicalKey == LogicalKeyboardKey.numpad5) ticketIndex = 4;

                    if (ticketIndex != null && ticketIndex < activeOrderIds.length) {
                      // Tuşa basılan sıradaki bileti "Tümü Hazır" olarak işaretle
                      final targetOrderId = activeOrderIds[ticketIndex];
                      ref.read(orderRepositoryProvider).setOrderKitchen(targetOrderId, KitchenStatus.ready);
                      return KeyEventResult.handled;
                    }
                  }
                  return KeyEventResult.ignored;
                },
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.md,
                    children: [
                      for (final id in orderIds)
                        if (_active(orders[id]))
                          _Ticket(
                            order: orders[id],
                            lines: byOrder[id]!,
                            tableMap: tableMap,
                            onLineReady: (lineId) => ref
                                .read(orderRepositoryProvider)
                                .setLineKitchen(lineId, KitchenStatus.ready),
                            onAllReady: () => ref
                                .read(orderRepositoryProvider)
                                .setOrderKitchen(id, KitchenStatus.ready),
                            onServed: () => ref
                                .read(orderRepositoryProvider)
                                .setOrderKitchen(id, KitchenStatus.served),
                          ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _Ticket extends ConsumerWidget {
  final Order? order;
  final List<OrderLine> lines;
  final Map<int, DiningTable> tableMap;
  final void Function(int lineId) onLineReady;
  final VoidCallback onAllReady;
  final VoidCallback onServed;

  const _Ticket({
    required this.order,
    required this.lines,
    required this.tableMap,
    required this.onLineReady,
    required this.onAllReady,
    required this.onServed,
  });

  String get _title {
    final o = order;
    if (o == null) return 'Siparis';
    if (o.type == OrderType.package) return 'Paket';
    if (o.tableId != null) {
      return tableMap[o.tableId]?.name ?? 'Masa';
    }
    return 'Adisyon';
  }

  int get _waitMinutes {
    final times = lines.map((l) => l.sentToKitchenAt).whereType<DateTime>();
    if (times.isEmpty) return 0;
    final earliest =
        times.reduce((a, b) => a.isBefore(b) ? a : b);
    return DateTime.now().difference(earliest).inMinutes;
  }

  Color get _ageColor {
    final m = _waitMinutes;
    if (m >= 15) return AppColors.danger;
    if (m >= 8) return AppColors.warning;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allReady = lines.every((l) => l.kitchenStatus == KitchenStatus.ready);
    final width = MediaQuery.sizeOf(context).width < 600 ? double.infinity : 320.0;

    return SizedBox(
      width: width,
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: _ageColor.withValues(alpha: 0.14),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppSpacing.rLg)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 17),
                    ),
                  ),
                  if (order != null)
                    Text('#${order!.receiptNo}',
                        style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(width: 8),
                  // Mutfak Fişi Yazdırma Butonu
                  IconButton(
                    icon: const Icon(Icons.print_rounded, size: 20),
                    tooltip: 'Mutfak Fişi Yazdır',
                    onPressed: () async {
                      try {
                        // Mutfak için fiyat içermeyen özel fiş verisi
                        final receiptData = ReceiptData(
                          businessName: 'MUTFAK BİLETİ',
                          address: _title,
                          phone: order != null ? 'Fiş #${order!.receiptNo}' : '',
                          taxInfo: '',
                          headerNote: 'Bekleme: ${_waitMinutes} dk',
                          footerNote: 'ÖNEMLİ: Lütfen notları kontrol edin!',
                          receiptNo: order?.receiptNo.toString() ?? '',
                          dateTime: DateTime.now(),
                          typeLabel: 'Mutfak Siparişi',
                          operatorName: order?.operatorName ?? 'Garson',
                          lines: lines.map((l) => ReceiptLine(
                            name: l.productName,
                            qty: l.qty,
                            unitPriceKurus: 0, // Mutfakta fiyat görünmez
                            lineTotalKurus: 0,
                            extra: l.note,
                          )).toList(),
                          subtotalKurus: 0,
                          discountKurus: 0,
                          totalKurus: 0,
                          vatKurus: 0,
                          payments: [],
                        );

                        final bytes = await ReceiptFormatter.format(receiptData);
                        
                        // Dinamik Mutfak Yazıcısı MAC Adresi Okuma
                        final settings = await ref.read(settingsRepositoryProvider).getSettings();
                        final targetMac = settings.kitchenPrinterMac ?? '00:11:22:33:44:55';

                        await ThermalPrinterService().printBytes(mac: targetMac, bytes: bytes);
                        
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Mutfak fişi yazdırıldı.')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Yazdırma Hatası: $e')),
                          );
                        }
                      }
                    },
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _ageColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${_waitMinutes} dk',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Column(
                children: [
                  for (final l in lines) _line(context, l),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: allReady ? null : onAllReady,
                      icon: const Icon(Icons.done_all_rounded, size: 18),
                      label: const Text('Tumu Hazir'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onServed,
                      icon: const Icon(Icons.room_service_rounded, size: 18),
                      label: const Text('Servis'),
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.success),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(BuildContext context, OrderLine l) {
    final ready = l.kitchenStatus == KitchenStatus.ready;
    final qty = l.qty % 1 == 0 ? l.qty.toInt().toString() : l.qty.toString();
    return InkWell(
      onTap: ready ? null : () => onLineReady(l.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 2, right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('x$qty',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.productName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      decoration: ready ? TextDecoration.lineThrough : null,
                      color: ready ? AppColors.dTextDim : null,
                    ),
                  ),
                  if (l.note.isNotEmpty)
                    Text(l.note,
                        style: const TextStyle(
                            fontStyle: FontStyle.italic,
                            fontSize: 12,
                            color: AppColors.warning)),
                ],
              ),
            ),
            Icon(
              ready
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: ready ? AppColors.success : AppColors.dTextDim,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}