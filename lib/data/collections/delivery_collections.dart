import 'package:isar_community/isar.dart';
import '../enums/app_enums.dart';

part 'delivery_collections.g.dart';

/// Kurye. (Hesap/giris sistemi DEGIL; sadece tanim + yerel ag eslesmesi.)
@collection
class Courier {
  Id id = Isar.autoIncrement;

  String name = '';
  String phone = '';

  /// Kurye uygulamasinin yerel agda eslesmesi icin kisa kod.
  @Index(unique: true, replace: true)
  String pairCode = '';

  bool isActive = true;

  @Index()
  bool isDeleted = false;

  // Ozet (denormalize)
  int totalDeliveries = 0;

  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();
}

/// Bir paket siparisin kurye teslimat kaydi. Siparis (Order) ile iliskili.
@collection
class Delivery {
  Id id = Isar.autoIncrement;

  @Index()
  int orderId = 0;

  @Index()
  int? courierId;

  // Teslimat anindaki snapshot (musteri sonra degisse de bozulmasin)
  String customerName = '';
  String phone = '';
  String address = '';
  String note = '';
  int totalKurus = 0;

  @Enumerated(EnumType.name)
  @Index()
  DeliveryStatus status = DeliveryStatus.pending;

  DateTime createdAt = DateTime.now();
  DateTime? assignedAt;
  DateTime? onTheWayAt;
  DateTime? deliveredAt;
}

/// Online platformdan (Yemeksepeti/Getir vb.) veya elle eklenen siparis kalemi.
@embedded
class PlatformOrderItem {
  String name = '';
  double qty = 1;
  int unitPriceKurus = 0;
  String note = '';
}

/// Online platform siparisi. Yerel ag uzerinden POST /platform/order ile
/// alinabilir ya da elle eklenebilir. Kabul/iptal/yola cikar/teslim akisi.
@collection
class PlatformOrder {
  Id id = Isar.autoIncrement;

  @Enumerated(EnumType.name)
  @Index()
  DeliveryPlatform platform = DeliveryPlatform.other;

  /// Platformun kendi siparis kodu (varsa).
  @Index(type: IndexType.value, caseSensitive: false)
  String? externalCode;

  String customerName = '';
  String phone = '';
  String address = '';
  String note = '';

  List<PlatformOrderItem> items = [];

  int totalKurus = 0;

  @Enumerated(EnumType.name)
  @Index()
  PlatformOrderStatus status = PlatformOrderStatus.newOrder;

  /// Kabul edilince acilan dahili Order id (kasa/muhasebe entegrasyonu icin).
  int? linkedOrderId;

  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();
}
