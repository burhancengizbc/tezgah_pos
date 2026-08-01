import 'package:isar_community/isar.dart';
import '../../data/enums/app_enums.dart';

part 'people_collections.g.dart';

@collection
class Customer {
  Id id = Isar.autoIncrement;

  String firstName = '';
  String lastName = '';
  
  String get fullName => '$firstName $lastName'.trim();
  set fullName(String v) {
    final parts = v.trim().split(' ');
    if (parts.isNotEmpty) {
      firstName = parts.first;
      lastName = parts.skip(1).join(' ');
    }
  }

  late String phone;
  String address = '';
  String note = '';
  
  int? customerNumber;
  int totalOrders = 0;
  int totalSpendKurus = 0;

  // --- YENİ: Cüzdan ve Sadakat Puanı ---
  int walletBalanceKurus = 0; // Ön ödemeli cüzdan bakiyesi (kuruş)
  int loyaltyPoints = 0;      // Biriken sadakat puanı

  DateTime? lastOrderAt;
  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();
  
  bool isDeleted = false;
}

@collection
class DiningTable {
  Id id = Isar.autoIncrement;
  late String name;
  int sortOrder = 0;

  String zoneName = 'Ana Salon'; // EKLENDİ: Salon / Kat adı (İç Mekan, Bahçe, Teras vb.)

  int colorValue = 0xFF2E7D32;
  bool isActive = true;

  @Enumerated(EnumType.name)
  TableStatus status = TableStatus.empty;
  int? currentOrderId;

  bool isDeleted = false;

  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();
}

@collection
class Employee {
  Id id = Isar.autoIncrement;
  
  String firstName = '';
  String lastName = '';
  
  String get fullName => '$firstName $lastName'.trim();
  set fullName(String v) {
    final parts = v.trim().split(' ');
    if (parts.isNotEmpty) {
      firstName = parts.first;
      lastName = parts.skip(1).join(' ');
    }
  }

  String phone = '';
  late String pinHash;
  late String pinSalt;

  @Enumerated(EnumType.name)
  EmployeeRole role = EmployeeRole.waiter;
  
  // --- Detaylı Yetkilendirme (LEGO Düğmeleri) ---
  bool canVoid = false; // Direkt iptal yapabilsin mi? (Hayır ise iptal onaya düşer)
  bool canDiscount = false; // İndirim yapabilsin mi?
  bool canTakePayment = false; // Ödeme alıp kasayı kapatabilsin mi?
  bool canAccessSettings = false; // Menü/Yazıcı ayarlarına girebilsin mi?
  bool canViewGeneralReports = false; // Tüm dükkanın cirosunu görebilsin mi? (Hayır ise sadece kendi baktığı masaları görür)
  
  int avatarColorValue = 0xFFFFB300;

  bool isActive = true;
  bool isDeleted = false;
  
  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();
}

@collection
class Supplier {
  Id id = Isar.autoIncrement;
  late String name;
  late String phone;
  bool isDeleted = false;
}

// --- CARİ HAREKETLER (Veresiye / Borç Defteri) ---
@collection
class CustomerTransaction {
  Id id = Isar.autoIncrement;

  @Index()
  int customerId = 0;

  @Enumerated(EnumType.name)
  CustomerTxType type = CustomerTxType.debt; // debt (borçlanma), payment (ödeme/tahsilat)

  int amountKurus = 0;
  String note = ''; // "Adisyon #2026001", "Elden ödeme" vb.

  @Index()
  DateTime createdAt = DateTime.now();
}

enum CustomerTxType {
  debt,     // Borç yazıldı
  payment,  // Ödeme alındı (Tahsilat)
}