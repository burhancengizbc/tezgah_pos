import 'package:isar_community/isar.dart';

import '../../data/collections/catalog_collections.dart';
import '../../data/collections/inventory_collections.dart';
import '../../data/enums/app_enums.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../../core/services/audit_service.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  final Isar isar;
  final AuditService audit;
  CategoryRepositoryImpl(this.isar, this.audit);

  IsarCollection<Category> get _c => isar.collection<Category>();

  @override
  Stream<List<Category>> watchActive() {
    return _c
        .where()
        .anyId()
        .filter()
        .isDeletedEqualTo(false)
        .isActiveEqualTo(true)
        .sortBySortOrder()
        .watch(fireImmediately: true);
  }

  @override
  Future<List<Category>> getAll({bool includeDeleted = false}) {
    if (includeDeleted) {
      // Hiçbir filtre yoksa doğrudan anyId üzerinden sıralıyoruz
      return _c.where().anyId().sortBySortOrder().findAll();
    }
    return _c
        .where()
        .anyId()
        .filter()
        .isDeletedEqualTo(false)
        .sortBySortOrder()
        .findAll();
  }

  @override
  Future<Category?> getById(int id) => _c.get(id);

  @override
  Future<int> save(Category category) async {
    final isNew = category.id == Isar.autoIncrement;
    category.updatedAt = DateTime.now();
    late int id;
    await isar.writeTxn(() async {
      id = await _c.put(category);
    });
    await audit.log(
      isNew ? AuditAction.create : AuditAction.update,
      'Category',
      id,
      category.name,
    );
    return id;
  }

  @override
  Future<void> reorder(List<int> orderedIds) async {
    await isar.writeTxn(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        final cat = await _c.get(orderedIds[i]);
        if (cat != null) {
          cat.sortOrder = i;
          await _c.put(cat);
        }
      }
    });
  }

  @override
  Future<void> softDelete(int id) async {
    await isar.writeTxn(() async {
      final cat = await _c.get(id);
      if (cat != null) {
        cat.isDeleted = true;
        cat.updatedAt = DateTime.now();
        await _c.put(cat);
      }
    });
    await audit.log(AuditAction.delete, 'Category', id, '');
  }
}

class ProductRepositoryImpl implements ProductRepository {
  final Isar isar;
  final AuditService audit;
  ProductRepositoryImpl(this.isar, this.audit);

  IsarCollection<Product> get _p => isar.collection<Product>();

  @override
  Future<List<Product>> page({
    int offset = 0,
    int limit = 50,
    int? categoryId,
    String? search,
    bool onlyActive = true,
  }) {
    var q = _p.where().anyId().filter().isDeletedEqualTo(false);
    if (onlyActive) q = q.isActiveEqualTo(true);
    if (categoryId != null) q = q.categoryIdEqualTo(categoryId);
    if (search != null && search.trim().isNotEmpty) {
      q = q.nameContains(search.trim(), caseSensitive: false);
    }
    return q.sortBySortOrder().offset(offset).limit(limit).findAll();
  }

  @override
  Stream<List<Product>> watchByCategory(int categoryId,
      {bool onlyActive = true}) {
    var q = _p
        .where()
        .anyId()
        .filter()
        .isDeletedEqualTo(false)
        .categoryIdEqualTo(categoryId);
    if (onlyActive) q = q.isActiveEqualTo(true);
    return q.sortBySortOrder().watch(fireImmediately: true);
  }

  @override
  Future<Product?> getById(int id) => _p.get(id);

  @override
  Future<Product?> getByBarcode(String barcode) =>
      _p.filter().barcodeEqualTo(barcode, caseSensitive: false).findFirst();

  @override
  Future<int> save(Product product) async {
    final isNew = product.id == Isar.autoIncrement;
    product.updatedAt = DateTime.now();
    late int id;
    await isar.writeTxn(() async {
      id = await _p.put(product);
    });
    await audit.log(
      isNew ? AuditAction.create : AuditAction.update,
      'Product',
      id,
      product.name,
    );
    return id;
  }

  @override
  Future<void> softDelete(int id) async {
    await isar.writeTxn(() async {
      final p = await _p.get(id);
      if (p != null) {
        p.isDeleted = true;
        p.updatedAt = DateTime.now();
        await _p.put(p);
      }
    });
    await audit.log(AuditAction.delete, 'Product', id, '');
  }

  @override
  Future<void> setActive(int id, bool active) async {
    await isar.writeTxn(() async {
      final p = await _p.get(id);
      if (p != null) {
        p.isActive = active;
        p.updatedAt = DateTime.now();
        await _p.put(p);
      }
    });
  }

  @override
  Future<List<Product>> lowStock() async {
    final numeric = await _p
        .filter()
        .isDeletedEqualTo(false)
        .stockTypeEqualTo(StockType.numeric)
        .findAll();
    return numeric.where((p) => p.lowStock).toList();
  }
}

class StockRepositoryImpl implements StockRepository {
  final Isar isar;
  StockRepositoryImpl(this.isar);

  IsarCollection<Product> get _p => isar.collection<Product>();
  IsarCollection<StockMovement> get _m => isar.collection<StockMovement>();

  @override
  Future<void> adjust({
    required int productId,
    required StockMovementType type,
    required double qty,
    String note = '',
    int? refOrderId,
  }) async {
    await isar.writeTxn(() async {
      final p = await _p.get(productId);
      if (p == null || p.stockType != StockType.numeric) return;

      final inflow = type == StockMovementType.purchaseIn ||
          type == StockMovementType.manualIn ||
          type == StockMovementType.saleReturn;

      if (type == StockMovementType.adjust) {
        p.stockQty += qty;
      } else {
        p.stockQty += inflow ? qty : -qty;
      }
      p.updatedAt = DateTime.now();
      await _p.put(p);

      final mv = StockMovement()
        ..productId = productId
        ..type = type
        ..qty = qty
        ..balanceAfter = p.stockQty
        ..note = note
        ..refOrderId = refOrderId;
      await _m.put(mv);
    });
  }

  @override
  Future<List<StockMovement>> history(int productId, {int limit = 100}) {
    return _m
        .filter()
        .productIdEqualTo(productId)
        .sortByCreatedAtDesc()
        .limit(limit)
        .findAll();
  }
}