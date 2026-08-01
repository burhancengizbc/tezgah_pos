import 'package:isar_community/isar.dart';
import '../enums/app_enums.dart';

part 'catalog_collections.g.dart';

/// İsletme ici üretim/hazırlık departmanları (Fırın, Izgara, Bar vb.)
@collection
class Department {
  Id id = Isar.autoIncrement;
  String name = ''; // Orn: "Fırın", "Sıcak Mutfak", "Bar"
  String? printerMac; // Bu departmana ait yazıcı MAC adresi
  String? printerName; 
  
  @Index()
  bool isDeleted = false;
}

/// Kategori.
@collection
class Category {
  Id id = Isar.autoIncrement;

  String name = '';

  @Index()
  int? departmentId;

  @Index()
  int sortOrder = 0;

  bool isActive = true;
  int colorValue = 0xFF2A2A2E; // ARGB
  int iconCodePoint = 0xe56c; // Icons.restaurant_menu varsayilan

  @Index()
  bool isDeleted = false;

  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();
}

/// Urune eklenebilir secenek (porsiyon/ekstra). (+ fast-food/donerci icin sart)
@embedded
class ModifierOption {
  String name = ''; // ornek: "Buyuk", "Ekstra peynir"
  int priceKurus = 0; // ek ucret (kurus)
}

/// Secenek grubu.
@embedded
class ModifierGroup {
  String name = ''; // ornek: "Porsiyon", "Ekstralar"
  bool multiSelect = false; // birden fazla secilebilir mi
  bool required = false; // zorunlu mu
  List<ModifierOption> options = [];
}

/// Urun.
@collection
class Product {
  Id id = Isar.autoIncrement;

  String name = '';

  @Index()
  int categoryId = 0;

  int salePriceKurus = 0; // Satis fiyati (kurus)
  int costPriceKurus = 0; // Alis maliyeti (kurus) -> kar/zarar icin

  @Index(type: IndexType.value, caseSensitive: false)
  String? barcode;

  String description = '';
  String? imagePath;

  bool isActive = true;

  // Stok
  @Enumerated(EnumType.name)
  StockType stockType = StockType.unlimited;
  double stockQty = 0; // double: tartili satis ihtimaline karsi (+)
  double minStock = 0;
  bool sellByWeight = false; // (+) kg ile satis opsiyonu

  double vatRate = 10.0; // KDV %

  @Index()
  int sortOrder = 0;

  // Secenekler (+)
  List<ModifierGroup> modifierGroups = [];

  // Reçete / Hammadde bağlantısı (BOM)
  List<RecipeItem> recipe = [];

  @Index()
  bool isDeleted = false;

  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();

  bool get lowStock =>
      stockType == StockType.numeric && stockQty <= minStock && minStock > 0;
}



/// Hammadde (Kuru çay, süt, un, bardak vb.).
@collection
class Ingredient {
  Id id = Isar.autoIncrement;

  String name = '';
  String unit = 'gr'; // gr, ml, kg, lt, adet
  int costPriceKurus = 0; // Birim maliyeti
  double stockQty = 0;
  double minStock = 0;

  @Index()
  bool isDeleted = false;

  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();

  bool get lowStock => stockQty <= minStock && minStock > 0;
}


// --- 1. HAMMADDE (Depodaki Malzemeler: Kıyma, Domates, Lavaş vb.) ---
@collection
class RawMaterial {
  Id id = Isar.autoIncrement;

  late String name; // Malzeme adı (Örn: Dana Kıyma)
  String unit = 'g'; // Birim: g (gram), ml, adet, kg, paket
  double stockQty = 0; // Mevcut miktar (Örn: 5000.0 gram)
  double criticalQty = 1000.0; // Kritik uyarı seviyesi (Altına düşerse alarm verir)

  bool isDeleted = false;
  DateTime updatedAt = DateTime.now();
}

/// Reçete satırı (ürünün içinde hangi hammaddeden ne kadar var).
@embedded
class RecipeItem {
  int rawMaterialId = 0;
  String rawMaterialName = '';
  double quantity = 0;
  String unit = 'g';
}

/// Periyodik Stok Sayım Oturumu
@collection
class StockTake {
  Id id = Isar.autoIncrement;
  
  String title = ''; // Örn: "Temmuz Ayı Sonu Genel Sayım"
  bool isCompleted = false; // Sayım bitti mi, onaylandı mı?
  
  List<StockTakeItem> items = []; // Sayılan malzemelerin detayları
  
  @Index()
  DateTime createdAt = DateTime.now();
  DateTime? completedAt;
}

@embedded
class StockTakeItem {
  int rawMaterialId = 0;
  String materialName = '';
  double systemQty = 0;    // Sistemin bildirdiği miktar
  double physicalQty = 0;  // Personelin sayıp girdiğimi miktar
  double get variance => physicalQty - systemQty; // Fark (Eksik / Fazla)
  String unit = 'g';
}

/// Yarı Mamul / Ara Ürün Modeli (Örn: Pizza Hamuru, Özel Sos)
@collection
class SemiFinishedProduct {
  Id id = Isar.autoIncrement;

  String name = ''; // Ara ürün adı (Örn: Cheddar Sos, Mayalı Hamur)
  String unit = 'g'; // Örn: g, ml, adet
  double stockQty = 0; // Mevcut stok miktarı
  int costPerUnitKurus = 0; // Birim maliyet (kuruş)

  List<RecipeItem> subRecipe = []; // İçindeki hammaddeler (Reçete)

  bool isDeleted = false;
  DateTime updatedAt = DateTime.now();
}

/// İstasyon Tanım Modeli (Örn: Izgara, Bar, Fırın)
@collection
class KitchenStation {
  Id id = Isar.autoIncrement;

  String name = ''; // İstasyon Adı (Örn: Bar, Sıcak Mutfak, Fırın)
  String printerName = ''; // Bu istasyona özel yazıcı adı
  bool isActive = true;

  DateTime createdAt = DateTime.now();
}