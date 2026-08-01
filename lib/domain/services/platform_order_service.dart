import '../../data/collections/delivery_collections.dart';
import '../../data/enums/app_enums.dart';
import 'package:flutter/foundation.dart';
import '../repositories/platform_order_repository.dart';
import '../repositories/sales_repository.dart';
import '../repositories/settings_repository.dart'; 
import '../../core/database/isar_service.dart'; 
import '../../core/services/thermal_printer_service.dart'; 
import '../../core/services/receipt_formatter.dart'; 
import '../../domain/services/receipt_builder.dart'; 
import 'checkout_service.dart';
import 'package:isar_community/isar.dart';

/// Platform siparislerinin (Yemeksepeti/Getir vb.) yasam dongusu.
/// Kabul edilince dahili bir Order (paket) olusturulur; teslim edilince
/// "Diger" odeme yontemiyle kapatilir -> kasa/muhasebe akisi aynen isler.
/// (Platform odemeyi kendi tahsil eder; bu yuzden nakit kasaya degil, "diger"
///  satis grubuna yazilir.)
class PlatformOrderService {
  final PlatformOrderRepository repo;
  final OrderRepository orders;
  final CheckoutService checkout;
  final Isar isar; // Doğrudan Isar veritabanı örneği
  final SettingsRepository settingsRepo; 
  PlatformOrderService(this.repo, this.orders, this.checkout, this.isar, this.settingsRepo);

  Future<void> accept(PlatformOrder po) async {
    int? createdOrderId;
    if (po.linkedOrderId == null) {
      final order = await orders.openOrder(
        type: OrderType.package,
        operatorName: _platformLabel(po.platform),
      );
      for (final it in po.items) {
        await orders.addLine(
          order.id,
          LineInput(
            productId: 0,
            productName: it.name,
            categoryId: 0,
            unitPriceKurus: it.unitPriceKurus,
            costPriceKurus: 0,
            qty: it.qty <= 0 ? 1 : it.qty,
            vatRate: 10,
            note: it.note,
          ),
        );
      }
      await orders.setNote(
        order.id,
        'Platform: ${_platformLabel(po.platform)}'
        '${po.externalCode != null ? " #${po.externalCode}" : ""}'
        '${po.customerName.isNotEmpty ? " - ${po.customerName}" : ""}',
      );
      po.linkedOrderId = order.id;
      createdOrderId = order.id;
    }
    po.status = PlatformOrderStatus.accepted;
    await repo.save(po);

    // Mutfak Çalışma Senaryosu Kontrolü (Yazdırma)
    try {
      final settings = await settingsRepo.getSettings();
      final mode = settings.kitchenMode; // 'print_only', 'screen_only', 'both'
      
      // Eğer mod 'print_only' veya 'both' ise ve yeni sipariş oluşturulduysa otomatik mutfak fişi bas
      if ((mode == 'print_only' || mode == 'both') && createdOrderId != null) {
        final builder = ReceiptBuilder(isar, settingsRepo);
        final receiptData = await builder.forOrder(createdOrderId);
        if (receiptData != null) {
          final bytes = await ReceiptFormatter.format(receiptData);
          await ThermalPrinterService().printBytes(mac: '00:11:22:33:44:55', bytes: bytes);
        }
      }
    } catch (e) {
      debugPrint('Platform siparişi otomatik mutfak yazdırma hatası: $e');
    }
  }

  Future<void> setStatus(PlatformOrder po, PlatformOrderStatus status) async {
    po.status = status;
    await repo.save(po);
  }

  /// Teslim: bagli siparisi "Diger" ile kapatir (kasa/muhasebe akisi).
  Future<void> deliver(PlatformOrder po) async {
    final orderId = po.linkedOrderId;
    if (orderId != null) {
      final order = await orders.getById(orderId);
      if (order != null && order.status != OrderStatus.paid) {
        await orders.recalc(orderId);
        final fresh = await orders.getById(orderId);
        final total = fresh?.totalKurus ?? 0;
        if (total > 0) {
          await checkout.payAndClose(
            orderId: orderId,
            payments: [PaymentInput(PaymentMethod.other, total)],
          );
        }
      }
    }
    po.status = PlatformOrderStatus.delivered;
    await repo.save(po);
  }

  Future<void> cancel(PlatformOrder po, {bool rejected = false}) async {
    final orderId = po.linkedOrderId;
    if (orderId != null) {
      final order = await orders.getById(orderId);
      if (order != null && order.status != OrderStatus.paid) {
        await orders.cancelOrder(orderId, 'Platform iptal');
      }
    }
    po.status =
        rejected ? PlatformOrderStatus.rejected : PlatformOrderStatus.cancelled;
    await repo.save(po);
  }

  static String _platformLabel(DeliveryPlatform p) => switch (p) {
        DeliveryPlatform.yemeksepeti => 'Yemeksepeti',
        DeliveryPlatform.getir => 'Getir',
        DeliveryPlatform.trendyolGo => 'Trendyol Go',
        DeliveryPlatform.migrosYemek => 'Migros Yemek',
        DeliveryPlatform.phone => 'Telefon',
        DeliveryPlatform.other => 'Diger',
      };
}
