import '../../data/collections/catalog_collections.dart';
import '../../data/collections/inventory_collections.dart';
import '../../data/enums/app_enums.dart';

abstract interface class CategoryRepository {
  Stream<List<Category>> watchActive();
  Future<List<Category>> getAll({bool includeDeleted = false});
  Future<Category?> getById(int id);
  Future<int> save(Category category); // insert/update -> id
  Future<void> reorder(List<int> orderedIds);
  Future<void> softDelete(int id);
}

abstract interface class ProductRepository {
  /// Sayfalama destekli (10.000+ urun icin).
  Future<List<Product>> page({
    int offset = 0,
    int limit = 50,
    int? categoryId,
    String? search,
    bool onlyActive = true,
  });
  Stream<List<Product>> watchByCategory(int categoryId, {bool onlyActive = true});
  Future<Product?> getById(int id);
  Future<Product?> getByBarcode(String barcode);
  Future<int> save(Product product);
  Future<void> softDelete(int id);
  Future<void> setActive(int id, bool active);
  Future<List<Product>> lowStock();
}

abstract interface class StockRepository {
  /// Elle stok girisi/cikisi (hareket loglanir).
  Future<void> adjust({
    required int productId,
    required StockMovementType type,
    required double qty,
    String note = '',
    int? refOrderId,
  });
  Future<List<StockMovement>> history(int productId, {int limit = 100});
}
