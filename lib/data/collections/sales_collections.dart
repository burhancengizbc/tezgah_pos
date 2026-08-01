import 'package:isar_community/isar.dart';
import '../enums/app_enums.dart';

part 'sales_collections.g.dart';

/// Siparis basligi (adisyon).
/// Tutarlar kurus (int) olarak saklanir -> floating-point hatasi olmaz.
@collection
class Order {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: false)
  int receiptNo = 0; // 2026000001 ...

  @Enumerated(EnumType.name)
  @Index()
  OrderType type = OrderType.table;

  @Enumerated(EnumType.name)
  @Index()
  OrderStatus status = OrderStatus.open;

  @Index()
  int? tableId;

  @Index()
  int? customerId;

  @Index()
  int? cashSessionId; // hangi kasa vardiyasinda kapandi

  // Tutarlar (kurus)
  int subtotalKurus = 0; // urunler toplami (indirim oncesi)
  int vatTotalKurus = 0; // KDV toplami
  int discountAmountKurus = 0; // uygulanan indirim (hesaplanmis)
  int totalKurus = 0; // odenecek genel toplam

  @Enumerated(EnumType.name)
  DiscountType discountType = DiscountType.none;
  double discountValue = 0; // tutar(kurus) ya da yuzde

  // Odeme (+ kismi/bolunmus odeme Payment koleksiyonunda)
  int paidKurus = 0;
  bool get isFullyPaid => paidKurus >= totalKurus && totalKurus > 0;

  String note = '';
  String? operatorName; // Opsiyonel metin olarak kalabilir
  
  @Index()
  int? operatorId; // EKLENDİ: Siparişi başlatan/yöneten personelin ID'si (Kendi raporunu görebilmesi için)

  @Index()
  DateTime createdAt = DateTime.now();
  @Index()
  DateTime? closedAt;
  DateTime updatedAt = DateTime.now();
}

/// Siparise eklenen secenek snapshot'i.
@embedded
class SelectedModifier {
  String groupName = '';
  String optionName = '';
  int priceKurus = 0;
}

/// Siparis satiri. Ayri koleksiyon -> "en cok satan", urun bazli kar gibi
/// raporlar 100.000+ sipariste hizli calissin diye indexli tutuldu.
@collection
class OrderLine {
  Id id = Isar.autoIncrement;

  @Index()
  int orderId = 0;

  @Index()
  int productId = 0;

  @Index()
  int categoryId = 0;

  // Snapshot (urun sonradan degisse de gecmis bozulmasin)
  String productName = '';
  int unitPriceKurus = 0;
  int costPriceKurus = 0;
  double qty = 1;
  double vatRate = 10.0;
  int lineTotalKurus = 0; // (unit + modifiers) * qty

  List<SelectedModifier> modifiers = [];
  String note = ''; // "acili olmasin" vb. (+)

  bool isVoid = false; // Gerçekten iptal edildi mi?
  String? voidReason; // "Müşteri vazgeçti", "Yanlış girildi" vb.
  
  // --- İptal Onay Akışı (Void Tracking) ---
  bool isVoidPending = false; // Patron onayı bekliyor mu? (Garson silince bu true olur, isVoid false kalır)
  int? voidRequestedById; // İptali isteyen garson
  int? voidApprovedById; // İptali onaylayan/reddeden yetkili/patron

  // --- Mutfak (KDS) akisi (+) ---
  @Enumerated(EnumType.name)
  @Index()
  KitchenStatus kitchenStatus = KitchenStatus.none;
  DateTime? sentToKitchenAt;
  DateTime? kitchenReadyAt;

  // Denormalize (raporlar 100.000+ sipariste hizli olsun diye satirda tutulur):
  @Index()
  bool isPaid = false; // siparis kapaninca true
  @Index()
  DateTime? soldAt; // siparis kapanis zamani
  int? cashSessionId;

  @Index()
  DateTime createdAt = DateTime.now();
}

/// Odeme kaydi (+ kismi ve bolunmus hesap destegi).
@collection
class Payment {
  Id id = Isar.autoIncrement;

  @Index()
  int orderId = 0;

  @Enumerated(EnumType.name)
  PaymentMethod method = PaymentMethod.cash;

  int amountKurus = 0;
  String note = '';

  @Index()
  DateTime createdAt = DateTime.now();
}