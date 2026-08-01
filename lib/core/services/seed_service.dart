import 'package:isar_community/isar.dart';

import '../../data/collections/catalog_collections.dart';
import '../../data/collections/people_collections.dart';
import '../../data/enums/app_enums.dart';

/// Ilk denemeler icin ornek veri olusturur (kategoriler, urunler, masalar).
class SeedService {
  final Isar isar;
  SeedService(this.isar);

  Future<void> run() async {
    final catCol = isar.collection<Category>();
    final prodCol = isar.collection<Product>();
    final tableCol = isar.collection<DiningTable>();

    final existing = await catCol.count();
    if (existing > 0) return; // zaten veri var

    await isar.writeTxn(() async {
      final icecek = Category()
        ..name = 'Icecekler'
        ..sortOrder = 0
        ..colorValue = 0xFF1565C0
        ..iconCodePoint = 0xe544;
      final yiyecek = Category()
        ..name = 'Yiyecekler'
        ..sortOrder = 1
        ..colorValue = 0xFFEF6C00
        ..iconCodePoint = 0xe56c;
      final tatli = Category()
        ..name = 'Tatlilar'
        ..sortOrder = 2
        ..colorValue = 0xFFAD1457
        ..iconCodePoint = 0xe541;
      final icecekId = await catCol.put(icecek);
      final yiyecekId = await catCol.put(yiyecek);
      final tatliId = await catCol.put(tatli);

      Product p(String name, int catId, int price, int cost,
          {StockType st = StockType.unlimited,
          double qty = 0,
          List<ModifierGroup> mods = const []}) {
        return Product()
          ..name = name
          ..categoryId = catId
          ..salePriceKurus = price
          ..costPriceKurus = cost
          ..vatRate = 10
          ..stockType = st
          ..stockQty = qty
          ..modifierGroups = mods;
      }

      final porsiyon = ModifierGroup()
        ..name = 'Porsiyon'
        ..required = true
        ..options = [
          ModifierOption()
            ..name = 'Normal'
            ..priceKurus = 0,
          ModifierOption()
            ..name = 'Buyuk'
            ..priceKurus = 1500,
        ];

      await prodCol.putAll([
        p('Cay', icecekId, 1500, 300),
        p('Turk Kahvesi', icecekId, 4500, 1200),
        p('Ayran', icecekId, 3000, 1000,
            st: StockType.numeric, qty: 40),
        p('Doner Durum', yiyecekId, 12000, 5000, mods: [porsiyon]),
        p('Lahmacun', yiyecekId, 8000, 3000),
        p('Pide', yiyecekId, 14000, 6000, mods: [porsiyon]),
        p('Sutlac', tatliId, 6000, 2000,
            st: StockType.numeric, qty: 20),
        p('Baklava (porsiyon)', tatliId, 9000, 4000),
      ]);

      for (var i = 1; i <= 8; i++) {
        await tableCol.put(DiningTable()
          ..name = 'Masa $i'
          ..sortOrder = i
          ..colorValue = 0xFF455A64);
      }
    });
  }
}
