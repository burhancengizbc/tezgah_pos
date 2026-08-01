import 'package:isar_community/isar.dart';

import '../../data/collections/catalog_collections.dart';
import '../../data/collections/finance_collections.dart';
import '../../data/collections/inventory_collections.dart';
import '../../data/collections/people_collections.dart';
import '../../data/collections/sales_collections.dart';
import '../../data/enums/app_enums.dart';
import '../../core/error/failures.dart';
import '../../core/services/audit_service.dart';
import '../../core/utils/result.dart';
import '../repositories/sales_repository.dart';
import 'pricing_calculator.dart';

/// Siparis kapatma (odeme) motoru.
/// Tek bir writeTxn icinde: toplam dogrulama -> odeme kayitlari -> stok dusumu
/// -> masa serbest -> musteri ozeti -> muhasebe geliri -> kasa hareketi.
/// Boylece islem ya tamamen olur ya hic olmaz (veri tutarliligi).
class CheckoutService {
  final Isar isar;
  final AuditService audit;
  CheckoutService(this.isar, this.audit);

  Future<Result<Order>> payAndClose({
    required int orderId,
    required List<PaymentInput> payments,
  }) async {
    final openSession = await isar
        .collection<CashSession>()
        .filter()
        .isOpenEqualTo(true)
        .sortByOpenedAtDesc()
        .findFirst();

    Order? closed;
    Failure? failure;

    await isar.writeTxn(() async {
      final orders = isar.collection<Order>();
      final lines = isar.collection<OrderLine>();

      final order = await orders.get(orderId);
      if (order == null) {
        failure = const NotFoundFailure('Siparis bulunamadi.');
        return;
      }
      if (order.status == OrderStatus.paid) {
        failure = const ValidationFailure('Siparis zaten kapatilmis.');
        return;
      }

      final orderLines =
          await lines.filter().orderIdEqualTo(orderId).findAll();
      final activeLines = orderLines.where((l) => !l.isVoid).toList();
      if (activeLines.isEmpty) {
        failure = const ValidationFailure('Adisyonda urun yok.');
        return;
      }

      final totals = PricingCalculator.computeTotals(
        lines: orderLines,
        discountType: order.discountType,
        discountValue: order.discountValue,
      );

      final paid =
          payments.fold<int>(0, (s, p) => s + p.amountKurus);
      if (paid < totals.totalKurus) {
        failure = const ValidationFailure('Odeme tutari yetersiz.');
        return;
      }

      final now = DateTime.now();

      // 1) Odeme kayitlari
      final payCol = isar.collection<Payment>();
      var cash = 0, card = 0, other = 0;
      for (final p in payments) {
        await payCol.put(Payment()
          ..orderId = orderId
          ..method = p.method
          ..amountKurus = p.amountKurus
          ..note = p.note
          ..createdAt = now);
        switch (p.method) {
          case PaymentMethod.cash:
            cash += p.amountKurus;
          case PaymentMethod.card:
            card += p.amountKurus;
          case PaymentMethod.meal:
          case PaymentMethod.other:
            other += p.amountKurus;
        }
      }

      // 2) Siparisi kapat + satirlari isaretle + stok dusumu
      final products = isar.collection<Product>();
      final stockMoves = isar.collection<StockMovement>();
      for (final l in activeLines) {
        l
          ..isPaid = true
          ..soldAt = now
          ..cashSessionId = openSession?.id;
        await lines.put(l);

        final p = await products.get(l.productId);
        if (p != null) {
          if (p.recipe.isNotEmpty) {
            final materials = isar.collection<RawMaterial>();
for (final rItem in p.recipe) {
  final raw = await materials.get(rItem.rawMaterialId);
  if (raw != null) {
    final totalUsed = rItem.quantity * l.qty;
    raw.stockQty -= totalUsed;
    raw.updatedAt = now;
    await materials.put(raw);
    await stockMoves.put(StockMovement()
      ..productId = raw.id // veya rawMaterialId
      ..type = StockMovementType.sale
      ..qty = totalUsed
      ..balanceAfter = raw.stockQty
      ..note = 'Reçete Düşümü (${p.name}) #${order.receiptNo}'
      ..refOrderId = orderId
      ..createdAt = now);
  }
}
          } else if (p.stockType == StockType.numeric) {
            p.stockQty -= l.qty;
            p.updatedAt = now;
            await products.put(p);
            await stockMoves.put(StockMovement()
              ..productId = p.id
              ..type = StockMovementType.sale
              ..qty = l.qty
              ..balanceAfter = p.stockQty
              ..note = 'Satis #${order.receiptNo}'
              ..refOrderId = orderId
              ..createdAt = now);
          }
        }
      }

      order
        ..status = OrderStatus.paid
        ..closedAt = now
        ..updatedAt = now
        ..paidKurus = paid
        ..subtotalKurus = totals.subtotalKurus
        ..discountAmountKurus = totals.discountAmountKurus
        ..totalKurus = totals.totalKurus
        ..vatTotalKurus = totals.vatTotalKurus
        ..cashSessionId = openSession?.id;
      await orders.put(order);

      // 3) Masa serbest birak
      if (order.tableId != null) {
        final tables = isar.collection<DiningTable>();
        final t = await tables.get(order.tableId!);
        if (t != null) {
          t
            ..status = TableStatus.empty
            ..currentOrderId = null
            ..updatedAt = now;
          await tables.put(t);
        }
      }

      // 4) Musteri ozeti
      if (order.customerId != null) {
        final customers = isar.collection<Customer>();
        final c = await customers.get(order.customerId!);
        if (c != null) {
          c
            ..totalOrders += 1
            ..totalSpendKurus += totals.totalKurus
            ..lastOrderAt = now;
          await customers.put(c);
        }
      }

      // 5) Muhasebe geliri (satis)
      await isar.collection<AccountingEntry>().put(AccountingEntry()
        ..kind = AccountingKind.income
        ..incomeCategory = IncomeCategory.sales
        ..amountKurus = totals.totalKurus
        ..title = 'Satis #${order.receiptNo}'
        ..date = now
        ..refOrderId = orderId
        ..createdAt = now);

      // 6) Kasa guncelle (acik vardiya varsa)
      if (openSession != null) {
        final sessions = isar.collection<CashSession>();
        final s = await sessions.get(openSession.id);
        if (s != null) {
          s
            ..totalSalesKurus += totals.totalKurus
            ..cashSalesKurus += cash
            ..cardSalesKurus += card
            ..otherSalesKurus += other;
          await sessions.put(s);
          if (cash > 0) {
            await isar.collection<CashMovement>().put(CashMovement()
              ..sessionId = s.id
              ..type = CashMovementType.sale
              ..amountKurus = cash
              ..reason = 'Satis #${order.receiptNo}'
              ..refOrderId = orderId
              ..createdAt = now);
          }
        }
      }

      closed = order;
    });

    if (failure != null) return Err(failure!);
    await audit.log(
        AuditAction.payment, 'Order', orderId, '#${closed!.receiptNo}');
    return Ok(closed!);
  }
}
