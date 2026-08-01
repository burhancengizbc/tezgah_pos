import 'package:isar_community/isar.dart';
import '../../data/collections/catalog_collections.dart';
import '../../data/collections/sales_collections.dart';

class StockDeductionService {
  final Isar isar;
  StockDeductionService(this.isar);

  /// Bir sipariş onaylandığında veya mutfağa gönderildiğinde reçetedeki hammaddeleri düşer
  Future<void> deductForOrder(int orderId) async {
    // 1. Sipariş satırlarını al
    final lines = await isar.orderLines
        .filter()
        .orderIdEqualTo(orderId)
        .findAll();

    if (lines.isEmpty) return;

    // Tüm ürünleri önceden çekelim (Performans için)
    final productIds = lines.map((l) => l.productId).toSet().toList();
    final products = await isar.products.getAll(productIds);
    final productMap = {for (var p in products) if (p != null) p.id: p};

    await isar.writeTxn(() async {
      for (final line in lines) {
        if (line.isVoid) continue; // İptal edilen ürünler için stok düşülmez

        final product = productMap[line.productId];
        if (product == null || product.recipe.isEmpty) continue;

        // Ürünün her bir reçete kalemi için (Örn: 1 porsiyon için 150g kıyma)
        for (final item in product.recipe) {
          final rawMaterial = await isar.rawMaterials.get(item.rawMaterialId);
          if (rawMaterial != null) {
            // Toplam düşülecek miktar = Reçete Miktarı * Satır Adedi
            final totalDeduction = item.quantity * line.qty;
            
            rawMaterial.stockQty = (rawMaterial.stockQty - totalDeduction).clamp(0.0, 999999.0);
            rawMaterial.updatedAt = DateTime.now();

            await isar.rawMaterials.put(rawMaterial);
          }
        }
      }
    });
  }
}