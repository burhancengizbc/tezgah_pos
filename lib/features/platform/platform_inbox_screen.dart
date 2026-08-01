import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/data_streams.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/providers/service_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/money.dart';
import '../../data/collections/delivery_collections.dart';
import '../../data/enums/app_enums.dart';
import '../shared/widgets.dart';
import '../../domain/models/receipt_data.dart';
import '../../core/services/thermal_printer_service.dart';
import '../../core/services/receipt_formatter.dart';

// ============================================================================
// CONSTANTS & PROVIDERS
// ============================================================================

const platformLabels = <DeliveryPlatform, String>{
  DeliveryPlatform.yemeksepeti: 'Yemeksepeti',
  DeliveryPlatform.getir: 'Getir',
  DeliveryPlatform.trendyolGo: 'Trendyol Go',
  DeliveryPlatform.migrosYemek: 'Migros Yemek',
  DeliveryPlatform.phone: 'Telefon',
  DeliveryPlatform.other: 'Diger',
};

const platformColors = <DeliveryPlatform, Color>{
  DeliveryPlatform.yemeksepeti: Color(0xFFEA004B), // Pembe
  DeliveryPlatform.getir: Color(0xFF5D3EBD), // Mor
  DeliveryPlatform.trendyolGo: Color(0xFFF27A1A), // Turuncu
  DeliveryPlatform.migrosYemek: Color(0xFFFF7A00),
  DeliveryPlatform.phone: Colors.blueGrey,
  DeliveryPlatform.other: Colors.grey,
};

const platformStatusLabels = <PlatformOrderStatus, String>{
  PlatformOrderStatus.newOrder: 'Yeni',
  PlatformOrderStatus.accepted: 'Kabul',
  PlatformOrderStatus.preparing: 'Hazırlanıyor',
  PlatformOrderStatus.onTheWay: 'Yolda',
  PlatformOrderStatus.delivered: 'Teslim',
  PlatformOrderStatus.rejected: 'Reddedildi',
  PlatformOrderStatus.cancelled: 'İptal',
};

const _activeStatuses = {
  PlatformOrderStatus.accepted,
  PlatformOrderStatus.preparing,
  PlatformOrderStatus.onTheWay,
};
const _historyStatuses = {
  PlatformOrderStatus.delivered,
  PlatformOrderStatus.cancelled,
  PlatformOrderStatus.rejected,
};

// Geniş ekranlarda (Windows) seçili siparişi tutmak için
final _selectedOrderIdProvider = StateProvider<int?>((ref) => null);

// ============================================================================
// MAIN SCREEN
// ============================================================================

class PlatformInboxScreen extends ConsumerStatefulWidget {
  const PlatformInboxScreen({super.key});

  @override
  ConsumerState<PlatformInboxScreen> createState() => _PlatformInboxScreenState();
}

class _PlatformInboxScreenState extends ConsumerState<PlatformInboxScreen> {
  bool _autoPilotEnabled = false;
  bool _autoPrintEnabled = false; // EKLENDİ: Otomatik yazdırma ayarı
  int _autoAcceptMinutes = 1;
  int _autoOnTheWayMinutes = 5;
  int _autoDeliverMinutes = 15;
  Timer? _autoPilotTimer;

  @override
  void initState() {
    super.initState();
    _autoPilotTimer = Timer.periodic(const Duration(seconds: 10), (_) => _runAutoPilot());
  }

  @override
  void dispose() {
    _autoPilotTimer?.cancel();
    super.dispose();
  }

  void _runAutoPilot() {
    if (!_autoPilotEnabled) return;
    final svc = ref.read(platformOrderServiceProvider);
    final allOrders = ref.read(platformOrdersProvider).value ?? [];

    for (final po in allOrders) {
      if (po.status == PlatformOrderStatus.newOrder) {
        svc.accept(po);
        if (_autoPrintEnabled) _printOrderAuto(po); // EKLENDİ: Otopilot kabul edince yazdır
      } else if (po.status == PlatformOrderStatus.accepted || po.status == PlatformOrderStatus.preparing) {
        svc.setStatus(po, PlatformOrderStatus.onTheWay);
      } else if (po.status == PlatformOrderStatus.onTheWay) {
        svc.deliver(po);
      }
    }
  }

  // Otopilot'un arka planda sessizce fiş yazdırması için yardımcı metod
  Future<void> _printOrderAuto(PlatformOrder order) async {
    try {
      final receiptData = ReceiptData(
        businessName: platformLabels[order.platform] ?? 'Platform Siparişi',
        address: order.address,
        phone: order.phone,
        taxInfo: '',
        headerNote: 'Müşteri: ${order.customerName}',
        footerNote: order.note,
        receiptNo: order.externalCode ?? order.id.toString(),
        dateTime: DateTime.now(),
        typeLabel: 'Paket Servis',
        operatorName: 'Sistem (Otopilot)',
        lines: order.items.map((i) => ReceiptLine(
          name: i.name,
          qty: i.qty,
          unitPriceKurus: i.unitPriceKurus,
          lineTotalKurus: (i.qty * i.unitPriceKurus).round(),
          extra: i.note,
        )).toList(),
        subtotalKurus: order.totalKurus,
        discountKurus: 0,
        totalKurus: order.totalKurus,
        vatKurus: 0,
        payments: [],
      );
      final bytes = await ReceiptFormatter.format(receiptData);
      await ThermalPrinterService().printBytes(mac: '00:11:22:33:44:55', bytes: bytes);
    } catch (e) {
      debugPrint('Otopilot otomatik yazdırma hatası: $e');
    }
  }

  void _showAutomationSettings() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Otopilot ve Otomasyon Ayarları'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Oto-Pilotu Etkinleştir'),
                subtitle: const Text('Gelen siparişleri zaman kurallarına göre otomatik ilerletir'),
                value: _autoPilotEnabled,
                onChanged: (v) => setDialogState(() {
                  _autoPilotEnabled = v;
                  if (!v) _autoPrintEnabled = false; // Otopilot kapanırsa yazdırma da kapansın
                }),
              ),
              SwitchListTile(
                title: const Text('Otomatik Fiş Yazdır'),
                subtitle: const Text('Otopilot siparişi kabul ettiğinde mutfak fişini otomatik yazdırır'),
                value: _autoPrintEnabled,
                // Sadece Otopilot açıksa bu ayar değiştirilebilir olsun
                onChanged: _autoPilotEnabled ? (v) => setDialogState(() => _autoPrintEnabled = v) : null,
              ),
              const Divider(),
              Text('Otomatik Kabul Süresi: $_autoAcceptMinutes dakika'),
              Slider(
                value: _autoAcceptMinutes.toDouble(),
                min: 1, max: 10, divisions: 9,
                label: '$_autoAcceptMinutes dk',
                onChanged: (v) => setDialogState(() => _autoAcceptMinutes = v.toInt()),
              ),
              Text('Yola Çıkış Süresi: $_autoOnTheWayMinutes dakika'),
              Slider(
                value: _autoOnTheWayMinutes.toDouble(),
                min: 2, max: 30, divisions: 28,
                label: '$_autoOnTheWayMinutes dk',
                onChanged: (v) => setDialogState(() => _autoOnTheWayMinutes = v.toInt()),
              ),
              Text('Otomatik Teslim Süresi: $_autoDeliverMinutes dakika'),
              Slider(
                value: _autoDeliverMinutes.toDouble(),
                min: 5, max: 60, divisions: 11,
                label: '$_autoDeliverMinutes dk',
                onChanged: (v) => setDialogState(() => _autoDeliverMinutes = v.toInt()),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () {
                setState(() {});
                Navigator.pop(ctx);
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addManual(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _ManualOrderSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(settingsStreamProvider).value?.platformOrdersEnabled ?? false;
    
    if (!enabled) {
      return Scaffold(
        appBar: AppBar(title: const Text('Paket & Platform Siparişleri')),
        body: const EmptyState(
          icon: Icons.storefront_rounded,
          message: 'Platform siparişleri kapalı.\nAyarlar > Yerel Ağ & Modüller bölümünden açın.',
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Paket & Platform Siparişleri'),
          actions: [
            IconButton(
              icon: Icon(
                _autoPilotEnabled ? Icons.bolt_rounded : Icons.bolt_outlined,
                color: _autoPilotEnabled ? AppColors.amber : Colors.grey,
              ),
              tooltip: 'Otomasyon Ayarları',
              onPressed: _showAutomationSettings,
            ),
          ],
          bottom: const TabBar(tabs: [
            Tab(text: 'Yeni Siparişler'),
            Tab(text: 'Aktif / Yoldakiler'),
            Tab(text: 'Geçmiş / Arşiv'),
          ]),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _addManual(context, ref),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Manuel Sipariş'),
        ),
        body: Column(
          children: [
            if (_autoPilotEnabled)
              Container(
                width: double.infinity,
                color: AppColors.amber.withValues(alpha: 0.15),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.auto_mode_rounded, size: 16, color: AppColors.amber),
                    const SizedBox(width: 8),
                    Text(
                      'Otopilot Aktif: Kabul(${_autoAcceptMinutes}dk) -> Yola Çıkış(${_autoOnTheWayMinutes}dk) -> Teslim(${_autoDeliverMinutes}dk)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.amber),
                    ),
                  ],
                ),
              ),
            const Expanded(
              child: TabBarView(children: [
                _OrderList(filter: 'new'),
                _OrderList(filter: 'active'),
                _OrderList(filter: 'history'),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// RESPONSIVE LIST (Android vs Windows)
// ============================================================================

class _OrderList extends ConsumerWidget {
  final String filter;
  const _OrderList({required this.filter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(platformOrdersProvider);
    
    return all.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e')),
      data: (list) {
        final filtered = list.where((o) {
          switch (filter) {
            case 'new':
              return o.status == PlatformOrderStatus.newOrder;
            case 'active':
              return _activeStatuses.contains(o.status);
            default:
              return _historyStatuses.contains(o.status);
          }
        }).toList();

        if (filtered.isEmpty) {
          return EmptyState(
              icon: Icons.inbox_rounded,
              message: filter == 'new'
                  ? 'Yeni sipariş yok.'
                  : (filter == 'active' ? 'Aktif sipariş yok.' : 'Kayıt yok.'));
        }

        // Seçili siparişi senkronize et (Silinmiş veya sekme değişmişse)
        final selectedId = ref.watch(_selectedOrderIdProvider);
        PlatformOrder? selectedOrder = filtered.where((o) => o.id == selectedId).firstOrNull;
        
        // Eğer seçili yoksa ilkini seçili yap (Sadece Windows için otomatik seçim)
        selectedOrder ??= filtered.first;

        return LayoutBuilder(
          builder: (context, constraints) {
            // Eğer ekran 800 pikselden dar ise (Android / Mobil) -> Eski tek sütunlu görünüm
            if (constraints.maxWidth < 800) {
              return ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: filtered.length,
                itemBuilder: (_, i) => _MobileOrderCard(order: filtered[i]),
              );
            }

            // Eğer ekran 800 pikselden geniş ise (Windows / Tablet) -> Split View Çift Panel
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // SOL PANEL: Sipariş Listesi
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(right: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1))),
                    ),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final order = filtered[i];
                        final isSelected = order.id == selectedOrder!.id;
                        return _CompactOrderTile(
                          order: order,
                          isSelected: isSelected,
                          onTap: () => ref.read(_selectedOrderIdProvider.notifier).state = order.id,
                        );
                      },
                    ),
                  ),
                ),
                
                // SAĞ PANEL: Sipariş Detayı ve Aksiyonlar
                Expanded(
                  flex: 4,
                  child: Container(
                    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
                    child: selectedOrder != null ? _DesktopOrderDetail(order: selectedOrder) : const Center(child: Text('Sipariş seçilmedi')),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ============================================================================
// WINDOWS / DESKTOP WIDGETS (ÇİFT PANEL GÖRÜNÜMÜ)
// ============================================================================

/// Sol taraftaki ufak sipariş kutucuğu (Menulux'teki sol liste gibi)
class _CompactOrderTile extends StatelessWidget {
  final PlatformOrder order;
  final bool isSelected;
  final VoidCallback onTap;

  const _CompactOrderTile({required this.order, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pColor = platformColors[order.platform] ?? AppColors.amber;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? pColor.withValues(alpha: 0.15) : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? pColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: pColor.withValues(alpha: 0.2),
              foregroundColor: pColor,
              radius: 20,
              child: Text(platformLabels[order.platform]?[0] ?? 'D', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.customerName.isNotEmpty ? order.customerName : 'İsimsiz Müşteri', 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(platformStatusLabels[order.status] ?? '', 
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: pColor)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                MoneyText(order.totalKurus, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                if (order.externalCode != null)
                  Text('#${order.externalCode}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Sağ taraftaki devasa sipariş detay ve yönetim paneli
class _DesktopOrderDetail extends ConsumerWidget {
  final PlatformOrder order;
  const _DesktopOrderDetail({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final svc = ref.read(platformOrderServiceProvider);
    final pColor = platformColors[order.platform] ?? AppColors.amber;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ÜST BİLGİ KARTI
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: pColor.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: pColor, borderRadius: BorderRadius.circular(8)),
                  child: Text(platformLabels[order.platform] ?? 'Platform', 
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order.customerName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.phone, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(order.phone.isNotEmpty ? order.phone : 'Telefon Yok', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                          const SizedBox(width: 16),
                          const Icon(Icons.receipt_long, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(order.externalCode != null ? '#${order.externalCode}' : 'Sipariş Kodu Yok', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                        ],
                      )
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      const Text('DURUM', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                      Text(platformStatusLabels[order.status] ?? '', style: TextStyle(color: pColor, fontSize: 16, fontWeight: FontWeight.w900)),
                    ],
                  ),
                )
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // ADRES VE NOT BÖLÜMÜ
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Teslimat Adresi', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Text(order.address.isNotEmpty ? order.address : 'Adres bilgisi yok.', style: const TextStyle(fontSize: 16)),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Sipariş Notu', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
                      ),
                      child: Text(order.note.isNotEmpty ? order.note : 'Not eklenmemiş.', style: const TextStyle(fontSize: 15, color: AppColors.warning, fontStyle: FontStyle.italic)),
                    )
                  ],
                ),
              )
            ],
          ),

          const SizedBox(height: 24),
          const Text('Sipariş İçeriği', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const Divider(),
          
          // ÜRÜNLER LİSTESİ
          Expanded(
            child: ListView.separated(
              itemCount: order.items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final it = order.items[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Row(
                    children: [
                      Text('${it.qty % 1 == 0 ? it.qty.toInt() : it.qty}x', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: pColor)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(it.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            if (it.note.isNotEmpty)
                              Text(it.note, style: const TextStyle(fontSize: 13, color: Colors.grey, fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ),
                      MoneyText((it.unitPriceKurus * it.qty).toInt(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ],
                  ),
                );
              },
            ),
          ),
          
          const Divider(height: 32, thickness: 2),
          
          // TOPLAM VE AKSİYON BUTONLARI
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('GENEL TOPLAM', style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w800)),
                  MoneyText(order.totalKurus, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: pColor)),
                ],
              ),
              const Spacer(),
              // Ekstra Fiş Yazdır Butonu
              OutlinedButton.icon(
                onPressed: () async {
                  try {
                    // 1. Platform Siparişini doğrudan ReceiptData nesnesine çeviriyoruz
                    final receiptData = ReceiptData(
                      businessName: platformLabels[order.platform] ?? 'Platform Siparişi',
                      address: order.address,
                      phone: order.phone,
                      taxInfo: '',
                      headerNote: 'Müşteri: ${order.customerName}',
                      footerNote: order.note,
                      receiptNo: order.externalCode ?? order.id.toString(),
                      dateTime: DateTime.now(),
                      typeLabel: 'Paket Servis',
                      operatorName: 'Sistem',
                      lines: order.items.map((i) => ReceiptLine(
                        name: i.name,
                        qty: i.qty,
                        unitPriceKurus: i.unitPriceKurus,
                        lineTotalKurus: (i.qty * i.unitPriceKurus).round(),
                        extra: i.note,
                      )).toList(),
                      subtotalKurus: order.totalKurus,
                      discountKurus: 0,
                      totalKurus: order.totalKurus,
                      vatKurus: 0,
                      payments: [],
                    );

                    // 2. Fiş verisini ESC/POS formata (byte dizisine) dönüştür
                    final bytes = await ReceiptFormatter.format(receiptData);

                    // 3. Bluetooth yazıcıya gönder (Gerçek MAC adresi ayarlardan çekilecek, şimdilik test değeri)
                    final printer = ThermalPrinterService();
                    final result = await printer.printBytes(mac: '00:11:22:33:44:55', bytes: bytes);
                    
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Yazdırma Hatası: $e')));
                    }
                  }
                },
                icon: const Icon(Icons.print),
                label: const Text('Fiş Yazdır'),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18)),
              ),
              const SizedBox(width: 12),
              // Duruma Özel Aksiyonlar
              _desktopActions(context, ref, svc, pColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _desktopActions(BuildContext context, WidgetRef ref, svc, Color pColor) {
    final s = order.status;
    if (_historyStatuses.contains(s)) return const SizedBox.shrink();

    final buttons = <Widget>[];
    
    if (s == PlatformOrderStatus.newOrder) {
      buttons.add(OutlinedButton.icon(
        onPressed: () => svc.cancel(order, rejected: true),
        icon: const Icon(Icons.close_rounded, size: 24),
        label: const Text('Reddet', style: TextStyle(fontSize: 16)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        ),
      ));
      buttons.add(const SizedBox(width: 16));
      buttons.add(FilledButton.icon(
        onPressed: () => svc.accept(order),
        icon: const Icon(Icons.check_rounded, size: 24),
        label: const Text('Siparişi Onayla', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        style: FilledButton.styleFrom(backgroundColor: pColor, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18)),
      ));
    } else if (s == PlatformOrderStatus.accepted) {
      buttons.add(FilledButton.icon(
        onPressed: () => svc.setStatus(order, PlatformOrderStatus.preparing),
        icon: const Icon(Icons.soup_kitchen_rounded, size: 24),
        label: const Text('Hazırlanıyor Olarak İşaretle', style: TextStyle(fontSize: 16)),
        style: FilledButton.styleFrom(backgroundColor: Colors.blueAccent, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18)),
      ));
    } else if (s == PlatformOrderStatus.preparing) {
      buttons.add(FilledButton.icon(
        onPressed: () => svc.setStatus(order, PlatformOrderStatus.onTheWay),
        icon: const Icon(Icons.two_wheeler_rounded, size: 24),
        label: const Text('Kuryeye Teslim Et / Yola Çıkar', style: TextStyle(fontSize: 16)),
        style: FilledButton.styleFrom(backgroundColor: AppColors.amber, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18)),
      ));
    } else if (s == PlatformOrderStatus.onTheWay) {
      buttons.add(FilledButton.icon(
        onPressed: () => svc.deliver(order),
        icon: const Icon(Icons.done_all_rounded, size: 24),
        label: const Text('Müşteriye Teslim Edildi', style: TextStyle(fontSize: 16)),
        style: FilledButton.styleFrom(backgroundColor: AppColors.success, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18)),
      ));
    }
    
    return Row(children: buttons);
  }
}


// ============================================================================
// ANDROID / MOBILE WIDGET (TEK SÜTUNLU KART)
// ============================================================================

class _MobileOrderCard extends ConsumerWidget {
  final PlatformOrder order;
  const _MobileOrderCard({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final svc = ref.read(platformOrderServiceProvider);
    final pColor = platformColors[order.platform] ?? AppColors.amber;
    
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: pColor.withValues(alpha: 0.3), width: 1),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 8, color: pColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: pColor.withValues(alpha: 0.15),
                          foregroundColor: pColor,
                          radius: 14,
                          child: Text(platformLabels[order.platform]?[0] ?? 'D', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(platformLabels[order.platform] ?? 'Diger', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: pColor)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
                          child: Text(platformStatusLabels[order.status]!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (order.customerName.isNotEmpty)
                      Text(order.customerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    if (order.address.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(order.address, style: Theme.of(context).textTheme.bodySmall),
                      ),
                    const Divider(height: 16),
                    for (final it in order.items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Text('${it.qty % 1 == 0 ? it.qty.toInt() : it.qty}x ${it.name}${it.note.isNotEmpty ? " (${it.note})" : ""}', style: const TextStyle(fontSize: 13)),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('TOPLAM', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey)),
                        MoneyText(order.totalKurus, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: pColor)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _actions(context, ref, svc, pColor),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actions(BuildContext context, WidgetRef ref, svc, Color pColor) {
    final s = order.status;
    if (_historyStatuses.contains(s)) return const SizedBox.shrink();

    final buttons = <Widget>[];
    if (s == PlatformOrderStatus.newOrder) {
      buttons.add(Expanded(child: OutlinedButton.icon(
        onPressed: () => svc.cancel(order, rejected: true),
        icon: const Icon(Icons.close_rounded, size: 18), label: const Text('Reddet'),
        style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
      )));
      buttons.add(const SizedBox(width: 8));
      buttons.add(Expanded(flex: 2, child: FilledButton.icon(
        onPressed: () => svc.accept(order),
        icon: const Icon(Icons.check_rounded, size: 18), label: const Text('Kabul Et', style: TextStyle(fontWeight: FontWeight.bold)),
        style: FilledButton.styleFrom(backgroundColor: pColor),
      )));
    } else if (s == PlatformOrderStatus.accepted) {
      buttons.add(Expanded(child: FilledButton.icon(
        onPressed: () => svc.setStatus(order, PlatformOrderStatus.preparing),
        icon: const Icon(Icons.soup_kitchen_rounded, size: 18), label: const Text('Hazırlanıyor'),
        style: FilledButton.styleFrom(backgroundColor: Colors.blueAccent),
      )));
    } else if (s == PlatformOrderStatus.preparing) {
      buttons.add(Expanded(child: FilledButton.icon(
        onPressed: () => svc.setStatus(order, PlatformOrderStatus.onTheWay),
        icon: const Icon(Icons.directions_run_rounded, size: 18), label: const Text('Yola Çıkar'),
        style: FilledButton.styleFrom(backgroundColor: AppColors.amber),
      )));
    } else if (s == PlatformOrderStatus.onTheWay) {
      buttons.add(Expanded(child: FilledButton.icon(
        onPressed: () => svc.deliver(order),
        icon: const Icon(Icons.done_all_rounded, size: 18), label: const Text('Teslim Et'),
        style: FilledButton.styleFrom(backgroundColor: AppColors.success),
      )));
    }
    return Row(children: buttons);
  }
}

// ============================================================================
// MANUAL ORDER SHEET (Aynı Bırakıldı)
// ============================================================================

class _ManualOrderSheet extends ConsumerStatefulWidget {
  const _ManualOrderSheet();
  @override
  ConsumerState<_ManualOrderSheet> createState() => _ManualOrderSheetState();
}

class _ManualOrderSheetState extends ConsumerState<_ManualOrderSheet> {
  DeliveryPlatform _platform = DeliveryPlatform.phone;
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _note = TextEditingController();
  final List<PlatformOrderItem> _items = [];

  @override
  void dispose() {
    _name.dispose(); _phone.dispose(); _address.dispose(); _note.dispose();
    super.dispose();
  }

  int get _total => _items.fold(0, (s, i) => s + (i.unitPriceKurus * i.qty).round());

  Future<void> _addItem() async {
    final name = TextEditingController();
    final qty = TextEditingController(text: '1');
    final price = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Ürün Ekle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Ürün adı')),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(child: TextField(controller: qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Adet'))),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: TextField(controller: price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Birim (TL)'))),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Ekle')),
        ],
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      setState(() {
        _items.add(PlatformOrderItem()
          ..name = name.text.trim()
          ..qty = double.tryParse(qty.text.replaceAll(',', '.')) ?? 1
          ..unitPriceKurus = Money.parse(price.text));
      });
    }
  }

  Future<void> _save() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('En az bir ürün ekleyin.')));
      return;
    }
    final po = PlatformOrder()
      ..platform = _platform
      ..customerName = _name.text.trim()
      ..phone = _phone.text.trim()
      ..address = _address.text.trim()
      ..note = _note.text.trim()
      ..items = _items
      ..totalKurus = _total
      ..status = PlatformOrderStatus.newOrder;
    await ref.read(platformOrderRepositoryProvider).save(po);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg, right: AppSpacing.lg, top: AppSpacing.sm,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Manuel Sipariş', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<DeliveryPlatform>(
              value: _platform,
              decoration: const InputDecoration(labelText: 'Platform'),
              items: [for (final p in DeliveryPlatform.values) DropdownMenuItem(value: p, child: Text(platformLabels[p]!))],
              onChanged: (v) => setState(() => _platform = v!),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Müşteri adı')),
            const SizedBox(height: AppSpacing.sm),
            TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Telefon')),
            const SizedBox(height: AppSpacing.sm),
            TextField(controller: _address, maxLines: 2, decoration: const InputDecoration(labelText: 'Adres')),
            const SizedBox(height: AppSpacing.sm),
            TextField(controller: _note, decoration: const InputDecoration(labelText: 'Not')),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Ürünler (${_items.length})', style: const TextStyle(fontWeight: FontWeight.w700)),
                TextButton.icon(onPressed: _addItem, icon: const Icon(Icons.add_rounded), label: const Text('Ürün Ekle')),
              ],
            ),
            for (var i = 0; i < _items.length; i++)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('${_items[i].qty % 1 == 0 ? _items[i].qty.toInt() : _items[i].qty} x ${_items[i].name}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MoneyText((_items[i].unitPriceKurus * _items[i].qty).round()),
                    IconButton(icon: const Icon(Icons.close_rounded, size: 18), onPressed: () => setState(() => _items.removeAt(i))),
                  ],
                ),
              ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Toplam', style: TextStyle(fontWeight: FontWeight.w700)),
                MoneyText(_total, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(onPressed: _save, child: const Text('Siparişi Oluştur')),
          ],
        ),
      ),
    );
  }
}