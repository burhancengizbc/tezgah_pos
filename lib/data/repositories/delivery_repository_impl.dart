import 'dart:math';

import 'package:isar_community/isar.dart';

import '../../data/collections/delivery_collections.dart';
import '../../data/enums/app_enums.dart';
import '../../domain/repositories/delivery_repository.dart';
import '../../core/services/audit_service.dart';

class CourierRepositoryImpl implements CourierRepository {
  final Isar isar;
  final AuditService audit;
  CourierRepositoryImpl(this.isar, this.audit);

  IsarCollection<Courier> get _c => isar.collection<Courier>();

  @override
  Stream<List<Courier>> watchActive() {
    return CourierQuerySortBy(_c
        .filter()
        .isDeletedEqualTo(false)
        .isActiveEqualTo(true))
        .sortByName()
        .watch(fireImmediately: true);
  }

  @override
  Future<List<Courier>> getAll({bool includeDeleted = false}) {
    final q = _c.filter();
    if (includeDeleted) return q.sortByName().findAll();
    return CourierQuerySortBy(q.isDeletedEqualTo(false)).sortByName().findAll();
  }

  @override
  Future<Courier?> getById(int id) => _c.get(id);

  @override
  Future<Courier?> getByPairCode(String code) {
    final c = code.trim().toUpperCase();
    if (c.isEmpty) return Future.value(null);
    return _c.filter().isDeletedEqualTo(false).pairCodeEqualTo(c).findFirst();
  }

  @override
  Future<int> save(Courier courier) async {
    if (courier.pairCode.trim().isEmpty) {
      courier.pairCode = await _uniqueCode();
    } else {
      courier.pairCode = courier.pairCode.trim().toUpperCase();
    }
    courier.updatedAt = DateTime.now();
    final isNew = courier.id == Isar.autoIncrement;
    late int id;
    await isar.writeTxn(() async {
      id = await _c.put(courier);
    });
    await audit.log(isNew ? AuditAction.create : AuditAction.update, 'Courier',
        id, courier.name);
    return id;
  }

  Future<String> _uniqueCode() async {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    for (var attempt = 0; attempt < 20; attempt++) {
      final code =
          List.generate(4, (_) => chars[r.nextInt(chars.length)]).join();
      final exists = await _c.filter().pairCodeEqualTo(code).findFirst();
      if (exists == null) return code;
    }
    return DateTime.now().millisecondsSinceEpoch.toString().substring(8);
  }

  @override
  Future<void> softDelete(int id) async {
    await isar.writeTxn(() async {
      final c = await _c.get(id);
      if (c != null) {
        c.isDeleted = true;
        c.updatedAt = DateTime.now();
        await _c.put(c);
      }
    });
    await audit.log(AuditAction.delete, 'Courier', id, '');
  }

  @override
  Future<void> incrementDeliveries(int courierId) async {
    await isar.writeTxn(() async {
      final c = await _c.get(courierId);
      if (c != null) {
        c.totalDeliveries += 1;
        await _c.put(c);
      }
    });
  }
}

extension on QueryBuilder<Courier, Courier, QFilterCondition> {
  sortByName() {}
}

class DeliveryRepositoryImpl implements DeliveryRepository {
  final Isar isar;
  final CourierRepository couriers;
  DeliveryRepositoryImpl(this.isar, this.couriers);

  IsarCollection<Delivery> get _d => isar.collection<Delivery>();

  @override
  Stream<List<Delivery>> watchActive() {
    return _d
        .filter()
        .not()
        .group((q) => q
            .statusEqualTo(DeliveryStatus.delivered)
            .or()
            .statusEqualTo(DeliveryStatus.cancelled))
        .sortByCreatedAtDesc()
        .watch(fireImmediately: true);
  }

  @override
  Future<List<Delivery>> activeForCourier(int courierId) {
    return _d
        .filter()
        .courierIdEqualTo(courierId)
        .not()
        .group((q) => q
            .statusEqualTo(DeliveryStatus.delivered)
            .or()
            .statusEqualTo(DeliveryStatus.cancelled))
        .sortByCreatedAt()
        .findAll();
  }

  @override
  Future<List<Delivery>> recentForCourier(int courierId, {int limit = 50}) {
    return _d
        .filter()
        .courierIdEqualTo(courierId)
        .statusEqualTo(DeliveryStatus.delivered)
        .sortByDeliveredAtDesc()
        .limit(limit)
        .findAll();
  }

  @override
  Future<Delivery?> getById(int id) => _d.get(id);

  @override
  Future<Delivery?> byOrder(int orderId) =>
      _d.filter().orderIdEqualTo(orderId).findFirst();

  @override
  Future<int> create(Delivery delivery) async {
    late int id;
    await isar.writeTxn(() async {
      id = await _d.put(delivery);
    });
    return id;
  }

  @override
  Future<void> assign(int deliveryId, int courierId) async {
    await isar.writeTxn(() async {
      final d = await _d.get(deliveryId);
      if (d == null) return;
      d.courierId = courierId;
      d.status = DeliveryStatus.assigned;
      d.assignedAt = DateTime.now();
      await _d.put(d);
    });
  }

  @override
  Future<void> setStatus(int deliveryId, DeliveryStatus status) async {
    int? courierToBump;
    await isar.writeTxn(() async {
      final d = await _d.get(deliveryId);
      if (d == null) return;
      final now = DateTime.now();
      d.status = status;
      if (status == DeliveryStatus.onTheWay) d.onTheWayAt = now;
      if (status == DeliveryStatus.delivered) {
        d.deliveredAt = now;
        courierToBump = d.courierId;
      }
      await _d.put(d);
    });
    if (courierToBump != null) {
      await couriers.incrementDeliveries(courierToBump!);
    }
  }
}
