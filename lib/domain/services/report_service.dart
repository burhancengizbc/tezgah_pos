import 'package:isar_community/isar.dart';

import '../../data/collections/catalog_collections.dart';
import '../../data/collections/sales_collections.dart';
import '../../data/enums/app_enums.dart';
import '../repositories/finance_repository.dart';
import '../models/report_models.dart';

/// Kar/zarar ve satis raporlari. Hiz icin OrderLine'daki denormalize
/// alanlar (isPaid + soldAt) uzerinden sorgular.
class ReportService {
  final Isar isar;
  final AccountingRepository accounting;
  ReportService(this.isar, this.accounting);

  IsarCollection<Order> get _o => isar.collection<Order>();
  IsarCollection<OrderLine> get _l => isar.collection<OrderLine>();

  Future<List<Order>> _paidOrders(DateTime s, DateTime e) {
    return _o
        .filter()
        .statusEqualTo(OrderStatus.paid)
        .closedAtBetween(s, e)
        .findAll();
  }

  Future<List<OrderLine>> _paidLines(DateTime s, DateTime e) {
    return _l.filter().isPaidEqualTo(true).soldAtBetween(s, e).findAll();
  }

  /// Genel kar/zarar ozeti.
  Future<SalesSummary> summary(DateTime start, DateTime end) async {
    final orders = await _paidOrders(start, end);
    final lines = await _paidLines(start, end);

    var sales = 0, discount = 0, vat = 0;
    for (final o in orders) {
      sales += o.totalKurus;
      discount += o.discountAmountKurus;
      vat += o.vatTotalKurus;
    }

    var cost = 0;
    for (final l in lines) {
      cost += (l.costPriceKurus * l.qty).round();
    }

    final expenses =
        await accounting.totalKurus(start, end, AccountingKind.expense);

    final gross = sales - cost;
    return SalesSummary(
      orderCount: orders.length,
      totalSalesKurus: sales,
      totalCostKurus: cost,
      grossProfitKurus: gross,
      expensesKurus: expenses,
      netProfitKurus: gross - expenses,
      vatTotalKurus: vat,
      discountKurus: discount,
    );
  }

  /// Urun bazli satis. ascending=true -> en az satanlar.
  Future<List<ProductSalesRow>> productSales(
    DateTime start,
    DateTime end, {
    int limit = 20,
    bool ascending = false,
  }) async {
    final lines = await _paidLines(start, end);
    final map = <int, ProductSalesRow>{};
    for (final l in lines) {
      final cur = map[l.productId];
      final addQty = l.qty;
      final addSales = l.lineTotalKurus;
      final addCost = (l.costPriceKurus * l.qty).round();
      if (cur == null) {
        map[l.productId] = ProductSalesRow(
          productId: l.productId,
          productName: l.productName,
          qty: addQty,
          salesKurus: addSales,
          costKurus: addCost,
        );
      } else {
        map[l.productId] = ProductSalesRow(
          productId: l.productId,
          productName: cur.productName,
          qty: cur.qty + addQty,
          salesKurus: cur.salesKurus + addSales,
          costKurus: cur.costKurus + addCost,
        );
      }
    }
    final rows = map.values.toList()
      ..sort((a, b) =>
          ascending ? a.qty.compareTo(b.qty) : b.qty.compareTo(a.qty));
    return rows.take(limit).toList();
  }

  /// Kategori bazli satis/kar.
  Future<List<CategorySalesRow>> categorySales(
      DateTime start, DateTime end) async {
    final lines = await _paidLines(start, end);
    final cats = await isar.collection<Category>().where().findAll();
    final names = {for (final c in cats) c.id: c.name};

    final map = <int, CategorySalesRow>{};
    for (final l in lines) {
      final cur = map[l.categoryId];
      final addCost = (l.costPriceKurus * l.qty).round();
      if (cur == null) {
        map[l.categoryId] = CategorySalesRow(
          categoryId: l.categoryId,
          categoryName: names[l.categoryId] ?? 'Diger',
          qty: l.qty,
          salesKurus: l.lineTotalKurus,
          costKurus: addCost,
        );
      } else {
        map[l.categoryId] = CategorySalesRow(
          categoryId: l.categoryId,
          categoryName: cur.categoryName,
          qty: cur.qty + l.qty,
          salesKurus: cur.salesKurus + l.lineTotalKurus,
          costKurus: cur.costKurus + addCost,
        );
      }
    }
    final rows = map.values.toList()
      ..sort((a, b) => b.salesKurus.compareTo(a.salesKurus));
    return rows;
  }

  /// Gider kirilimi (kategoriye gore).
  Future<List<ExpenseRow>> expensesByCategory(
      DateTime start, DateTime end) async {
    final entries = await accounting.inRange(start, end,
        kind: AccountingKind.expense);
    final map = <String, int>{};
    for (final e in entries) {
      final key = e.expenseCategory?.name ?? 'other';
      map[key] = (map[key] ?? 0) + e.amountKurus;
    }
    final rows = map.entries.map((e) => ExpenseRow(e.key, e.value)).toList()
      ..sort((a, b) => b.amountKurus.compareTo(a.amountKurus));
    return rows;
  }
}
