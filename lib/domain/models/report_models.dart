/// Raporlama icin veri transfer nesneleri (DTO).

/// Genel satis & kar/zarar ozeti.
class SalesSummary {
  final int orderCount;
  final int totalSalesKurus; // ciro (indirim sonrasi)
  final int totalCostKurus; // satilan urun maliyeti (COGS)
  final int grossProfitKurus; // brut kar = satis - maliyet
  final int expensesKurus; // donem giderleri (muhasebe)
  final int netProfitKurus; // net kar = brut - gider
  final int vatTotalKurus;
  final int discountKurus;

  const SalesSummary({
    required this.orderCount,
    required this.totalSalesKurus,
    required this.totalCostKurus,
    required this.grossProfitKurus,
    required this.expensesKurus,
    required this.netProfitKurus,
    required this.vatTotalKurus,
    required this.discountKurus,
  });

  static const empty = SalesSummary(
    orderCount: 0,
    totalSalesKurus: 0,
    totalCostKurus: 0,
    grossProfitKurus: 0,
    expensesKurus: 0,
    netProfitKurus: 0,
    vatTotalKurus: 0,
    discountKurus: 0,
  );
}

/// Urun bazli satis/kar.
class ProductSalesRow {
  final int productId;
  final String productName;
  final double qty;
  final int salesKurus;
  final int costKurus;
  int get profitKurus => salesKurus - costKurus;

  const ProductSalesRow({
    required this.productId,
    required this.productName,
    required this.qty,
    required this.salesKurus,
    required this.costKurus,
  });
}

/// Kategori bazli satis/kar.
class CategorySalesRow {
  final int categoryId;
  final String categoryName;
  final double qty;
  final int salesKurus;
  final int costKurus;
  int get profitKurus => salesKurus - costKurus;

  const CategorySalesRow({
    required this.categoryId,
    required this.categoryName,
    required this.qty,
    required this.salesKurus,
    required this.costKurus,
  });
}

/// Gider kirilimi.
class ExpenseRow {
  final String category;
  final int amountKurus;
  const ExpenseRow(this.category, this.amountKurus);
}
