import 'package:isar_community/isar.dart';

import '../../data/collections/people_collections.dart';
import '../../data/collections/sales_collections.dart';
import '../../data/enums/app_enums.dart';
import '../../domain/repositories/sales_repository.dart';
import '../../domain/services/pricing_calculator.dart';
import '../../domain/services/receipt_counter_service.dart';
import '../../core/services/audit_service.dart';

class OrderRepositoryImpl implements OrderRepository {
  final Isar isar;
  final ReceiptCounterService counter;
  final AuditService audit;
  OrderRepositoryImpl(this.isar, this.counter, this.audit);

  IsarCollection<Order> get _o => isar.collection<Order>();
  IsarCollection<OrderLine> get _l => isar.collection<OrderLine>();
  IsarCollection<Payment> get _pay => isar.collection<Payment>();

  @override
  Future<Order> openOrder({
    required OrderType type,
    int? tableId,
    int? customerId,
    String? operatorName,
  }) async {
    // Fis no acilista rezerve edilir (tekrarlanmaz).
    final receiptNo = await counter.next();
    final order = Order()
      ..receiptNo = receiptNo
      ..type = type
      ..status = OrderStatus.open
      ..tableId = tableId
      ..customerId = customerId
      ..operatorName = operatorName;
    await isar.writeTxn(() async {
      await _o.put(order);
    });
    await audit.log(AuditAction.create, 'Order', order.id, '#$receiptNo');
    return order;
  }

  @override
  Future<Order?> getById(int id) => _o.get(id);

  @override
  Future<Order?> getOpenByTable(int tableId) {
    return _o
        .filter()
        .tableIdEqualTo(tableId)
        .statusEqualTo(OrderStatus.open)
        .findFirst();
  }

  @override
  Stream<List<Order>> watchOpen() {
    return _o
        .filter()
        .statusEqualTo(OrderStatus.open)
        .sortByCreatedAt()
        .watch(fireImmediately: true);
  }

  @override
  Future<List<OrderLine>> linesOf(int orderId) {
    return _l.filter().orderIdEqualTo(orderId).sortByCreatedAt().findAll();
  }

  @override
  Future<void> addLine(int orderId, LineInput input) async {
    await isar.writeTxn(() async {
      final line = OrderLine()
        ..orderId = orderId
        ..productId = input.productId
        ..categoryId = input.categoryId
        ..productName = input.productName
        ..unitPriceKurus = input.unitPriceKurus
        ..costPriceKurus = input.costPriceKurus
        ..qty = input.qty
        ..vatRate = input.vatRate
        ..modifiers = input.modifiers
        ..note = input.note
        ..lineTotalKurus = 0;
      line.lineTotalKurus = PricingCalculator.lineTotal(line);
      await _l.put(line);
    });
    await recalc(orderId);
  }

  @override
  Future<void> setLineQty(int lineId, double qty) async {
    await isar.writeTxn(() async {
      final line = await _l.get(lineId);
      if (line == null) return;
      line.qty = qty <= 0 ? 0 : qty;
      line.lineTotalKurus = PricingCalculator.lineTotal(line);
      await _l.put(line);
    });
    final line = await _l.get(lineId);
    if (line != null) await recalc(line.orderId);
  }

  @override
  Future<void> voidLine(int lineId, String reason) async {
    int? orderId;
    await isar.writeTxn(() async {
      final line = await _l.get(lineId);
      if (line == null) return;
      line.isVoid = true;
      line.voidReason = reason;
      line.lineTotalKurus = 0;
      orderId = line.orderId;
      await _l.put(line);
    });
    if (orderId != null) {
      await audit.log(AuditAction.voidLine, 'OrderLine', lineId, reason);
      await recalc(orderId!);
    }
  }

  @override
  Future<void> setDiscount(int orderId, DiscountType type, double value) async {
    await isar.writeTxn(() async {
      final o = await _o.get(orderId);
      if (o == null) return;
      o.discountType = type;
      o.discountValue = value;
      await _o.put(o);
    });
    await recalc(orderId);
  }

  @override
  Future<void> setNote(int orderId, String note) async {
    await isar.writeTxn(() async {
      final o = await _o.get(orderId);
      if (o == null) return;
      o.note = note;
      await _o.put(o);
    });
  }

  @override
  Future<int> sendToKitchen(int orderId) async {
    var count = 0;
    await isar.writeTxn(() async {
      final lines = await _l.filter().orderIdEqualTo(orderId).findAll();
      final now = DateTime.now();
      for (final l in lines) {
        if (l.isVoid) continue;
        if (l.kitchenStatus == KitchenStatus.none) {
          l.kitchenStatus = KitchenStatus.queued;
          l.sentToKitchenAt = now;
          await _l.put(l);
          count++;
        }
      }
      if (count > 0) {
        final o = await _o.get(orderId);
        if (o != null && o.status == OrderStatus.open) {
          o.status = OrderStatus.preparing;
          o.updatedAt = now;
          await _o.put(o);
        }
      }
    });
    return count;
  }

  @override
  Future<void> setLineKitchen(int lineId, KitchenStatus status) async {
    await isar.writeTxn(() async {
      final l = await _l.get(lineId);
      if (l == null) return;
      l.kitchenStatus = status;
      if (status == KitchenStatus.ready) l.kitchenReadyAt = DateTime.now();
      await _l.put(l);
    });
  }

  @override
  Future<void> setOrderKitchen(int orderId, KitchenStatus status) async {
    await isar.writeTxn(() async {
      final lines = await _l.filter().orderIdEqualTo(orderId).findAll();
      final now = DateTime.now();
      for (final l in lines) {
        if (l.isVoid) continue;
        if (l.kitchenStatus == KitchenStatus.none ||
            l.kitchenStatus == KitchenStatus.served) {
          continue;
        }
        l.kitchenStatus = status;
        if (status == KitchenStatus.ready) l.kitchenReadyAt = now;
        await _l.put(l);
      }
    });
  }

  @override
  Stream<List<OrderLine>> watchKitchen() {
    return _l
        .filter()
        .isVoidEqualTo(false)
        .group((q) => q
            .kitchenStatusEqualTo(KitchenStatus.queued)
            .or()
            .kitchenStatusEqualTo(KitchenStatus.ready))
        .sortBySentToKitchenAt()
        .watch(fireImmediately: true);
  }

  @override
  Future<Order> recalc(int orderId) async {
    late Order order;
    await isar.writeTxn(() async {
      final o = await _o.get(orderId);
      if (o == null) return;
      final lines =
          await _l.filter().orderIdEqualTo(orderId).findAll();
      final totals = PricingCalculator.computeTotals(
        lines: lines,
        discountType: o.discountType,
        discountValue: o.discountValue,
      );
      o
        ..subtotalKurus = totals.subtotalKurus
        ..discountAmountKurus = totals.discountAmountKurus
        ..totalKurus = totals.totalKurus
        ..vatTotalKurus = totals.vatTotalKurus
        ..updatedAt = DateTime.now();
      await _o.put(o);
      order = o;
    });
    return order;
  }

  @override
  Future<List<Payment>> paymentsOf(int orderId) {
    return _pay.filter().orderIdEqualTo(orderId).sortByCreatedAt().findAll();
  }

  @override
  Future<void> cancelOrder(int orderId, String reason) async {
    await isar.writeTxn(() async {
      final o = await _o.get(orderId);
      if (o == null) return;
      o.status = OrderStatus.cancelled;
      o.closedAt = DateTime.now();
      o.note = (o.note.isEmpty ? '' : '${o.note} | ') + 'IPTAL: $reason';
      await _o.put(o);
    });
    await audit.log(AuditAction.update, 'Order', orderId, 'IPTAL: $reason');
  }

  @override
  Future<void> transferTable({required int fromTableId, required int toTableId}) async {
    int? transferredOrderId;
    await isar.writeTxn(() async {
      final order = await getOpenByTable(fromTableId);
      if (order == null) return;

      order.tableId = toTableId;
      order.updatedAt = DateTime.now();
      await _o.put(order);
      transferredOrderId = order.id;

      final tables = isar.collection<DiningTable>();
      final fromT = await tables.get(fromTableId);
      final toT = await tables.get(toTableId);
      final now = DateTime.now();

      if (fromT != null) {
        fromT.status = TableStatus.empty;
        fromT.currentOrderId = null;
        fromT.updatedAt = now;
        await tables.put(fromT);
      }
      if (toT != null) {
        toT.status = TableStatus.occupied;
        toT.currentOrderId = order.id;
        toT.updatedAt = now;
        await tables.put(toT);
      }
    });

    if (transferredOrderId != null) {
      await audit.log(AuditAction.update, 'Order', transferredOrderId,
          'Masa transferi: $fromTableId -> $toTableId');
    }
  }

  @override
  Future<void> mergeTables({required int fromTableId, required int targetTableId}) async {
    int? targetOrderId;
    await isar.writeTxn(() async {
      final fromOrder = await getOpenByTable(fromTableId);
      final targetOrder = await getOpenByTable(targetTableId);
      if (fromOrder == null || targetOrder == null) return;

      targetOrderId = targetOrder.id;
      final fromLines = await _l.filter().orderIdEqualTo(fromOrder.id).findAll();

      for (final line in fromLines) {
        line.orderId = targetOrder.id;
        await _l.put(line);
      }

      fromOrder.status = OrderStatus.cancelled;
      fromOrder.closedAt = DateTime.now();
      fromOrder.note = (fromOrder.note.isEmpty ? '' : '${fromOrder.note} | ') +
          'BİRLEŞTİRİLDİ -> Masa ID: $targetTableId';
      await _o.put(fromOrder);

      final tables = isar.collection<DiningTable>();
      final fromT = await tables.get(fromTableId);
      if (fromT != null) {
        fromT.status = TableStatus.empty;
        fromT.currentOrderId = null;
        fromT.updatedAt = DateTime.now();
        await tables.put(fromT);
      }
    });

    if (targetOrderId != null) {
      await recalc(targetOrderId!);
      await audit.log(AuditAction.update, 'Order', targetOrderId,
          'Masa birleştirildi: $fromTableId -> $targetTableId');
    }
  }
}
