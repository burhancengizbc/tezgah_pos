import 'package:isar_community/isar.dart';

part 'license_collection.g.dart';

/// Cihazın yerel lisans verisini tutan tablo
@collection
class AppLicense {
  Id id = Isar.autoIncrement;

  /// Örn: TZGH-2026-ABCD-1234
  @Index(unique: true)
  late String licenseKey;

  /// Lisansın son geçerlilik tarihi
  late DateTime expirationDate;

  /// İşletme veya şube adı (Lisans kimin adına?)
  late String registeredTo;

  /// Lisans aktif mi? (Buluttan iptal edilme durumu için)
  bool isActive = true;

  /// Lisans kontrolünün en son yapıldığı tarih (Offline tolerans süresi için)
  late DateTime lastChecked;
  
  /// Offline çalışmaya ne kadar izin verilecek? (Örn: İnternetsiz 30 gün)
  int offlineToleranceDays = 30;

  bool get isExpired => DateTime.now().isAfter(expirationDate);
}