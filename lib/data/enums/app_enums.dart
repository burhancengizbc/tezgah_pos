// Tum uygulama enum'lari. Isar koleksiyonlarinda @Enumerated(EnumType.name) ile
// saklanir; "name" kullanmamizin sebebi siralama degisse bile verinin bozulmamasidir.

/// Urun stok tipi.
enum StockType {
  unlimited, // Sinirsiz stok - adet takibi yok
  numeric, // Sayisal stok - adet dusulur
}

/// Siparis turu.
enum OrderType {
  table, // Masa
  package, // Paket (gel-al / adrese degil; online degil)
}

/// Siparis yasam dongusu.
enum OrderStatus {
  open, // Acik adisyon
  preparing, // Hazirlaniyor (+ mutfak akisi icin)
  paid, // Odendi / kapandi
  cancelled, // Iptal
}

/// Masa durumu.
enum TableStatus {
  empty, // Bos
  occupied, // Dolu
  awaitingPayment, // Hesap bekliyor
}

/// Mutfak (KDS) satir durumu (+ garson -> mutfak akisi).
enum KitchenStatus {
  none, // henuz mutfaga gonderilmedi
  queued, // mutfaga gonderildi, bekliyor/hazirlaniyor
  ready, // hazir
  served, // servis edildi
}

/// Odeme yontemi (+ kismi/bolunmus odeme icin gerekli).
enum PaymentMethod {
  cash, // Nakit
  card, // Kredi/Banka karti
  meal, // Yemek karti (Multinet/Sodexo vb.)
  other, // Diger
}

/// Indirim tipi.
enum DiscountType {
  none,
  amount, // Tutar (kurus)
  percent, // Yuzde
}

/// Kasa hareket tipi.
enum CashMovementType {
  open, // Kasa acilis bakiyesi
  close, // Kasa kapanis
  sale, // Satistan nakit giris
  refund, // Iade
  cashIn, // Kasaya para ekle
  cashOut, // Kasadan para cikar
}

/// Muhasebe kaydi turu.
enum AccountingKind {
  income, // Gelir
  expense, // Gider
}

/// Gider kategorileri.
enum ExpenseCategory {
  personnel, // Personel
  rent, // Kira
  electricity, // Elektrik
  water, // Su
  gas, // Dogalgaz
  internet, // Internet
  tax, // Vergi
  supplies, // Sarf / malzeme
  maintenance, // Bakim
  other, // Diger
}

/// Gelir kategorileri.
enum IncomeCategory {
  sales, // Satis (otomatik kayitlar)
  manual, // Elle eklenen gelir
  other,
}

/// Stok hareketi tipi (stok gecmisi icin).
enum StockMovementType {
  purchaseIn, // Alis girisi
  manualIn, // Elle ekleme
  manualOut, // Elle azaltma
  sale, // Satis dusumu
  saleReturn, // Satis iadesi
  adjust, // Sayim duzeltmesi
  waste, // Fire / zayi (+)
}

/// Denetim kaydi (audit) aksiyonu (+ veri butunlugu izi).
enum AuditAction {
  create,
  update,
  delete,
  restore,
  voidLine,
  payment,
  openCash,
  closeCash,
  backup,
  restoreBackup,
}

// ============================================================================
// + MODULLER (yerel ag uzerinden; bulut DEGIL): Kurye + Platform Siparisleri
// ============================================================================

/// Teslimat (kurye) durumu.
enum DeliveryStatus {
  pending, // Hazir, kuryeye atanmadi
  assigned, // Kuryeye atandi
  onTheWay, // Yola cikti
  delivered, // Teslim edildi
  cancelled, // Iptal
}

/// Online platform siparis durumu (Yemeksepeti/Getir vb. veya elle).
enum PlatformOrderStatus {
  newOrder, // Yeni geldi (onay bekliyor)
  accepted, // Kabul edildi
  preparing, // Hazirlaniyor
  onTheWay, // Yola cikti
  delivered, // Teslim edildi
  rejected, // Reddedildi
  cancelled, // Iptal
}

/// Siparisin geldigi kanal/platform.
enum DeliveryPlatform {
  yemeksepeti,
  getir,
  trendyolGo,
  migrosYemek,
  phone, // Telefon siparisi
  other,
}

// ============================================================================
// + PERSONEL / YETKILENDIRME (RBAC)
// ============================================================================

/// Personel rol ve temel yetki seviyeleri.
enum EmployeeRole {
  owner,
  admin,
  manager,
  waiter,
  cashier,
  kitchen,
}