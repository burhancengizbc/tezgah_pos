import '../../core/utils/money.dart';
import '../../data/collections/sales_collections.dart';
import '../../data/enums/app_enums.dart';

/// Hesaplanmis siparis tutarlari.
class OrderTotals {
  final int subtotalKurus; // indirim oncesi
  final int discountAmountKurus;
  final int totalKurus; // odenecek (indirim sonrasi)
  final int vatTotalKurus; // KDV dahil fiyat icindeki KDV payi

  const OrderTotals({
    required this.subtotalKurus,
    required this.discountAmountKurus,
    required this.totalKurus,
    required this.vatTotalKurus,
  });
}

/// Tum fiyat/KDV/indirim hesaplari tek yerde.
/// Turkiye pratigi: satis fiyatlari KDV DAHIL girilir. KDV payi fis icin
/// fiyatin icinden ayristirilir: kdv = tutar * oran / (100 + oran).
class PricingCalculator {
  PricingCalculator._();

  /// Bir satirin secenek ek ucretleri dahil birim fiyati (kurus).
  static int effectiveUnitPrice(int unitPriceKurus, List<SelectedModifier> mods) {
    var sum = unitPriceKurus;
    for (final m in mods) {
      sum += m.priceKurus;
    }
    return sum;
  }

  /// Satir toplami = (birim + secenekler) * adet.
  static int lineTotal(OrderLine line) {
    if (line.isVoid) return 0;
    final unit = effectiveUnitPrice(line.unitPriceKurus, line.modifiers);
    return (unit * line.qty).round();
  }

  /// Bir satirdaki KDV payi (KDV dahil tutarin icinden).
  static int lineVat(OrderLine line) {
    final total = lineTotal(line);
    if (total == 0 || line.vatRate <= 0) return 0;
    return (total * line.vatRate / (100 + line.vatRate)).round();
  }

  /// Siparis genel toplamlari.
  static OrderTotals computeTotals({
    required List<OrderLine> lines,
    required DiscountType discountType,
    required double discountValue,
  }) {
    var subtotal = 0;
    var vatBeforeDiscount = 0;
    for (final l in lines) {
      if (l.isVoid) continue;
      subtotal += lineTotal(l);
      vatBeforeDiscount += lineVat(l);
    }

    var discount = 0;
    switch (discountType) {
      case DiscountType.none:
        discount = 0;
      case DiscountType.amount:
        discount = discountValue.round().clamp(0, subtotal);
      case DiscountType.percent:
        discount = Money.percentOf(subtotal, discountValue).clamp(0, subtotal);
    }

    final total = subtotal - discount;

    // KDV payini indirim oraninda kucult.
    final vat = subtotal == 0
        ? 0
        : (vatBeforeDiscount * total / subtotal).round();

    return OrderTotals(
      subtotalKurus: subtotal,
      discountAmountKurus: discount,
      totalKurus: total,
      vatTotalKurus: vat,
    );
  }
}
