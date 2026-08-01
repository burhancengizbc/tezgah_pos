import '../../data/collections/sales_collections.dart';
import '../../data/enums/app_enums.dart';

/// Bir satira eklenecek girdi.
class LineInput {
  final int productId;
  final String productName;
  final int categoryId;
  final int unitPriceKurus;
  final int costPriceKurus;
  final double qty;
  final double vatRate;
  final List<SelectedModifier> modifiers;
  final String note;

  const LineInput({
    required this.productId,
    required this.productName,
    required this.categoryId,
    required this.unitPriceKurus,
    required this.costPriceKurus,
    this.qty = 1,
    this.vatRate = 10,
    this.modifiers = const [],
    this.note = '',
  });
}

/// Bir odeme girdisi (kismi / bolunmus odeme icin).
class PaymentInput {
  final PaymentMethod method;
  final int amountKurus;
  final String note;
  const PaymentInput(this.method, this.amountKurus, {this.note = ''});
}

abstract interface class OrderRepository {
  /// Yeni adisyon ac (masa/paket). currentOrderId masaya yazilir.
  Future<Order> openOrder({
    required OrderType type,
    int? tableId,
    int? customerId,
    String? operatorName,
  });

  Future<Order?> getById(int id);
  Future<Order?> getOpenByTable(int tableId);
  Stream<List<Order>> watchOpen();

  Future<List<OrderLine>> linesOf(int orderId);

  Future<void> addLine(int orderId, LineInput input);
  Future<void> setLineQty(int lineId, double qty);
  Future<void> voidLine(int lineId, String reason);
  Future<void> setDiscount(int orderId, DiscountType type, double value);
  Future<void> setNote(int orderId, String note);

  /// (+) Garson -> Mutfak: henuz gonderilmemis (none) ve iptal olmayan satirlari
  /// "queued" yapar. Gonderilen satir sayisini dondurur.
  Future<int> sendToKitchen(int orderId);

  /// (+) Bir satirin mutfak durumunu degistir (ready/served...).
  Future<void> setLineKitchen(int lineId, KitchenStatus status);

  /// (+) Bir siparisin tum aktif mutfak satirlarini topluca ayarla.
  Future<void> setOrderKitchen(int orderId, KitchenStatus status);

  /// (+) KDS icin: aktif mutfak satirlari (queued + ready), eskiden yeniye.
  Stream<List<OrderLine>> watchKitchen();

  /// Toplamlari satirlardan yeniden hesapla ve kaydet.
  Future<Order> recalc(int orderId);

  /// Kismi/bolunmus odeme ekle (odeme listesini de dondurur).
  Future<List<Payment>> paymentsOf(int orderId);

  Future<void> cancelOrder(int orderId, String reason);
  Future<void> transferTable({required int fromTableId, required int toTableId});
  Future<void> mergeTables({required int fromTableId, required int targetTableId});
}
