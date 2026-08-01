import 'package:isar_community/isar.dart';
import '../enums/app_enums.dart';

part 'business_collections.g.dart';

/// Isletme profili. Tek kayit tutulur (id = 1 onerilir).
@collection
class BusinessProfile {
  Id id = Isar.autoIncrement;

  String name = '';
  String phone = '';
  String address = '';
  String taxOffice = ''; // Vergi Dairesi
  String taxNumber = ''; // Vergi No
  String? logoPath; // Cihaz ici dosya yolu
  String receiptFooter = 'Bizi tercih ettiginiz icin tesekkurler.';

  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();
}

/// Uygulama ayarlari + guvenlik. Tek kayit.
@collection
class AppSettings {
  Id id = Isar.autoIncrement;

  // --- Guvenlik ---
  // Uygulamaya giris sifresi (ISTEGE BAGLI - varsayilan kapali)
  bool appLockEnabled = false;
  String? appPinHash; // SHA-256(pin + salt)
  String? appPinSalt;

  // Yonetici sifresi (korumali islemler: silme, fiyat degisimi, gun sonu...)
  String? adminPinHash;
  String? adminPinSalt;

  // Bosta kalinca otomatik kilit
  bool autoLockEnabled = true;
  int autoLockMinutes = 5;

  // --- Yazici / Fis ---
  String? printerMac; // Kasa (Ana) yazıcı
  String? printerName; 
  
  String? kitchenPrinterMac; // Mutfak yazıcısı (Sıcak/Yemek)
  String? kitchenPrinterName;
  
  String? barPrinterMac; // Bar/İçecek yazıcısı (Soğuk/Çay)
  String? barPrinterName;

  int paperSizeMm = 80; // 58 veya 80
  bool printAfterPayment = false; // odeme sonrasi otomatik fis bas
  String receiptHeader = ''; // fis ust notu (bos ise isletme adi)
  String receiptFooter = 'Bizi tercih ettiginiz icin tesekkurler';

  // --- Gelen Arama (Caller ID) ---
  bool callerIdEnabled = false; // yalnizca Android'de etkilidir

  // --- Bildirimler (Ses ve Titreşim) ---
  bool enableNotifications = true; // Genel bildirim sistemi açık mı?
  bool enableSound = true; // Ziller ve uyarı sesleri çalsın mı?
  bool enableVibration = true; // Cihaz titresin mi?

  // --- + Moduller & Yerel Ag (LAN) ---
  // Tezgah, yerel agda bir sunucu acar; esli telefon (Cagri) ve kurye uygulamalari
  // buna baglanir. Bulut DEGIL - yalnizca ayni WiFi/yerel ag.
  bool lanServerEnabled = false; // yerel ag sunucusu acik mi
  int lanServerPort = 8787;
  String lanPairToken = ''; // basit eslesme anahtari (yerel ag guvenligi)
  bool courierModuleEnabled = false; // kurye modulu
  bool platformOrdersEnabled = false; // online platform siparisleri gelen kutusu
  bool lanCallerIdEnabled = false; // telefondan yerel ag ile gelen arama aktarimi

  // ============================================================================
  // + YENI NESIL MODÜLER ESNAF TERCİHLERİ (Onboarding Seçimleri)
  // ============================================================================
  
  // 1. İşletme Tipi: true = Masalı Restoran/Kafe, false = Hızlı Satış / Dönerci / Büfe (Masasız)
  bool isTableServiceEnabled = true;
  
  // 2. Mutfak (KDS) Ekranı / Fiş Yazdırma Akışı aktif mi?
  bool isKitchenDisplayEnabled = true;
  
  // Mutfak Çalışma Senaryosu: 'print_only' (Sadece Fiş), 'screen_only' (Sadece Ekran), 'both' (Hem Fiş Hem Ekran)
  String kitchenMode = 'both'; 
  
  // 3. Veresiye / Borç (Cari) Defteri modülü aktif mi?
  bool ledgerModuleEnabled = true;
  
  // 4. Akıllı Ürün Reçetesi ve Otomatik Stok Düşümü aktif mi?
  bool recipeStockEnabled = false;
  
  // 5. Gider / Masraf Takibi modülü aktif mi?
  bool expenseTrackerEnabled = true;
  
  // 6. Düşük Stok / Kritik Seviye Alarmları aktif mi?
  bool lowStockAlertEnabled = true;
  
  // 7. Personel Ön Ödemeli Cüzdan & Sadakat (Puan) sistemi aktif mi?
  bool loyaltyWalletEnabled = false;

  // Gorunum
  bool darkMode = true; // Varsayilan: koyu tema
  String currencySymbol = '\u20BA'; // TL

  // --- + Ayarlanabilir arayuz (kullanici tercihleri) ---
  double uiScale = 1.0; // yazi + ikon boyut carpani (0.8 - 1.6)
  String uiAccent = 'amber'; // aksan tema: amber/teal/indigo/crimson/green
  String uiDensity = 'auto'; // auto/compact/comfortable (masaustu=compact onerilir)

  // Ozellestirilebilir panel (dashboard) duzeni. JSON:
  // [{"key":"sales","span":2}, {"key":"tables","span":1}, ...]
  // Bos ise varsayilan duzen kullanilir.
  String dashboardLayout = '';

  // --- + Stok / Fire modulu ---
  bool wasteModuleEnabled = false; // fire (zayi) kaydi acik mi
  bool wasteAsExpense = true; // fire'i maliyet uzerinden gidere yansit

  // KDV varsayilani
  double defaultVatRate = 10.0;

  // Yedekleme
  DateTime? lastBackupAt;

  // Kurulum tamamlandi mi?
  bool onboardingDone = false;

  // ==========================================
  // + LİSANS VE ABONELİK (SaaS) ALANLARI
  // ==========================================
  bool isLicensed = false; // Parası ödenmiş lisans aktif mi?
  bool isLifetime = false; // Ömür boyu (tek seferlik) lisans aktif mi?
  DateTime? trialStartDate; // 15 günlük ücretsiz denemenin başladığı tarih
  DateTime? licenseExpireDate; // Ücretli lisansın bittiği tarih (isLifetime true ise dikkate alınmaz)
  int maxCouriers = 2; // Paketin izin verdiği maksimum kurye sayısı
  String contactPhone = '+90 537 516 66 64'; // Lisans yenileme veya teknik destek için ulaşacakları numara

  // ============================================================================
  // + YENİ NESİL İLERİ DÜZEY MODÜL ANAHTARLARI (Patron Kontrol Paneli)
  // ============================================================================
  bool semiFinishedGoodsEnabled = false;   // 1. Yarı Mamul / Ara Ürün (Örn: Pizza Hamuru, Özel Sos)
  bool multiStationKdsEnabled = false;    // 2. İstasyon Bazlı Mutfak/Bar Yönlendirme
  bool smartCampaignsEnabled = false;     // 3. Happy Hour / Akıllı İndirim ve Kampanya Motoru
  bool whatsappPdfLedgerEnabled = false;  // 4. PDF Cari Ekstresi ve WhatsApp Paylaşımı
  bool mobileHandTerminalEnabled = false; // 5. Garson Cep/El Terminali Hızlı Satış Modu

  DateTime updatedAt = DateTime.now();
}

/// Fis numarasi sayaci. Yil basina tekil sira. Ornek: 2026000001
@collection
class ReceiptCounter {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  int year = DateTime.now().year;

  int lastSeq = 0;
}

/// Denetim (audit) kaydi. (+ veri butunlugu / izlenebilirlik)
@collection
class AuditLog {
  Id id = Isar.autoIncrement;

  @Enumerated(EnumType.name)
  AuditAction action = AuditAction.create;

  String entity = ''; // 'Product', 'Order' ...
  int? entityId;
  String detail = '';

  @Index()
  DateTime createdAt = DateTime.now();
}

/// Gider / Masraf takibi kaydı (+)
@collection
class Expense {
  Id id = Isar.autoIncrement;
  
  String title = ''; // Masraf adı (Örn: Pazar manav alışverişi, Su faturası, Avans)
  int amountKurus = 0; // Tutar (kuruş)
  String category = 'Genel'; // Gıda, Fatura, Personel, Diğer
  
  int? employeeId; // Kasadan parayı alan veya harcamayı yapan personel
  String note = '';
  
  @Index()
  DateTime createdAt = DateTime.now();
}

/// Masa Rezervasyon Modeli
@collection
class Reservation {
  Id id = Isar.autoIncrement;

  String customerName = '';
  String customerPhone = '';
  int guestCount = 2; // Kaç kişilik
  int? tableId; // Rezerve edilen masa ID'si (opsiyonel)
  String tableName = ''; // Kolay okuma için masa adı

  @Index()
  DateTime reservationTime = DateTime.now(); // Rezervasyon saati

  String note = ''; // "Pencere kenarı olsun", "Doğum günü" vb.

  @Enumerated(EnumType.name)
  ReservationStatus status = ReservationStatus.active; // active, completed, cancelled, noShow

  @Index()
  DateTime createdAt = DateTime.now();
}

enum ReservationStatus {
  active,    // Bekliyor / Aktif
  completed, // Müşteri geldi, masaya oturdu
  cancelled, // İptal edildi
  noShow,    // Gelmedi
}

/// Kurye Atama ve Paket Takip Modeli
@collection
class CourierDispatch {
  Id id = Isar.autoIncrement;

  int orderId = 0; // Hangi sipariş / adisyon?
  int courierEmployeeId = 0; // Hangi kurye?
  String courierName = '';
  
  String customerName = '';
  String deliveryAddress = '';
  int totalKurus = 0;

  @Enumerated(EnumType.name)
  CourierDispatchStatus status = CourierDispatchStatus.assigned; // assigned, onTheWay, delivered

  @Index()
  DateTime dispatchedAt = DateTime.now();
  DateTime? deliveredAt;
}

enum CourierDispatchStatus {
  assigned,   // Kuryeye verildi, yola çıkıyor
  onTheWay,   // Yolda / Dağıtımda
  delivered,  // Teslim edildi ve tahsilat yapıldı
}

/// Fire / Zayi Takip Modeli
@collection
class WasteLog {
  Id id = Isar.autoIncrement;
  
  String itemName = ''; // Hammadde veya Ürün adı (Örn: Bozulan Domates, Yanık Adana)
  int costKurus = 0;    // Maliyet tutarı (kuruş)
  double qty = 0;       // Miktar
  String unit = 'g';    // Birim
  String reason = '';   // Bozulma, Yanma, Pişirme Hatası, Düşme vb.
  
  @Index()
  DateTime createdAt = DateTime.now();
}

/// Personel Mesai ve Vardiya Takip Modeli
@collection
class StaffShift {
  Id id = Isar.autoIncrement;

  @Index()
  int employeeId = 0; // Hangi personel?
  String employeeName = '';

  DateTime clockIn = DateTime.now(); // İşe giriş saati
  DateTime? clockOut; // İlden çıkış saati

  String note = ''; // Not / Mazeret
  
  @Index()
  bool isCompleted = false; // Vardiya bitti mi?
}

/// Tedarikçi Satın Alma Siparişi ve Stok Kabul Modülü
@collection
class PurchaseOrder {
  Id id = Isar.autoIncrement;

  int supplierId = 0;
  String supplierName = '';
  
  int totalCostKurus = 0; // Toplam fatura tutarı (kuruş)
  bool isReceived = false; // Malzemeler depoya teslim alındı mı? (Stoklar güncellendi mi?)

  List<PurchaseOrderItem> items = [];

  @Index()
  DateTime createdAt = DateTime.now();
  DateTime? receivedAt;
}

@embedded
class PurchaseOrderItem {
  int rawMaterialId = 0;
  String materialName = '';
  double qty = 0;         // Alınan miktar
  int unitPriceKurus = 0; // Birim alış fiyatı (kuruş)
  String unit = 'g';      // kg, lt, adet vb.
}

/// Bahşiş Takip Modeli
@collection
class TipRecord {
  Id id = Isar.autoIncrement;

  int orderId = 0; // Hangi adisyondan geldi?
  int amountKurus = 0; // Bahşiş tutarı (kuruş)
  
  int? employeeId; // Hangi garsona ait / kim aldı?
  String employeeName = '';
  
  String paymentMethod = 'Nakit'; // Nakit veya Kredi Kartı
  
  @Index()
  DateTime createdAt = DateTime.now();
}

/// QR Menü ve Masa Oturum Modeli
@collection
class QrMenuSession {
  Id id = Isar.autoIncrement;

  int tableId = 0;
  String tableName = '';
  String token = ''; // Güvenli oturum anahtarı (UUID veya hash)
  
  bool isCallerRequested = false; // Müşteri garson çağırdı mı?
  bool isAccountRequested = false; // Müşteri hesap istendi mi?

  @Index()
  DateTime createdAt = DateTime.now();
  DateTime expiresAt = DateTime.now().add(const Duration(hours: 12));
}

/// GİB e-Fatura ve e-Arşiv Kayıt Modeli
@collection
class EInvoiceRecord {
  Id id = Isar.autoIncrement;

  int orderId = 0; // İlgili adisyon / satış ID'si
  String receiptNo = ''; // Fiş / Belge numarası
  
  String targetVatOrId = ''; // Alıcının Vergi No veya TCKN'si
  String targetTitle = ''; // Alıcı Unvanı veya Ad Soyad
  String targetEmail = ''; // E-posta adresi
  
  int totalKurus = 0; // Fatura toplamı (kuruş)
  String gibUuid = ''; // GİB tarafından üretilen tekil belge UUID'si
  
  bool isSentToGib = false; // GİB'e başarıyla gönderildi mi?
  
  @Index()
  DateTime createdAt = DateTime.now();
  DateTime? sentAt;
}

/// Müşteri Geri Bildirim ve Şikayet Takip Modeli
@collection
class CustomerFeedback {
  Id id = Isar.autoIncrement;

  String customerName = '';
  String tableName = ''; // Hangi masadan yazıldı
  int rating = 5; // 1 ile 5 arası yıldız puanı
  String category = 'Yemek Kalitesi'; // Yemek Kalitesi, Servis Hızı, Temizlik, Genel
  String comment = ''; // Müşteri yorumu / şikayeti

  @Index()
  DateTime createdAt = DateTime.now();
}

/// Happy Hour ve Akıllı Kampanya Kuralları Modeli
@collection
class CampaignRule {
  Id id = Isar.autoIncrement;

  String title = ''; // Kampanya Adı (Örn: "Mutlu Saatler (Happy Hour)", "Kahve Saati İndirimi")
  double discountPercent = 0.0; // Uygulanacak yüzdelik indirim (Örn: 20.0)
  
  int startHour = 14; // Başlangıç saati (Örn: 14)
  int endHour = 17;   // Bitiş saati (Örn: 17)
  
  bool isActive = true; // Kampanya aktif mi?

  @Index()
  DateTime createdAt = DateTime.now();
}