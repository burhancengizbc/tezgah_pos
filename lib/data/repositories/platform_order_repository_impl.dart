import 'package:isar_community/isar.dart';

import '../../data/collections/delivery_collections.dart';
import '../../data/enums/app_enums.dart';
import '../../domain/repositories/platform_order_repository.dart';

class PlatformOrderRepositoryImpl implements PlatformOrderRepository {
  final Isar isar;
  PlatformOrderRepositoryImpl(this.isar);

  IsarCollection<PlatformOrder> get _p => isar.collection<PlatformOrder>();

  @override
  Stream<List<PlatformOrder>> watchRecent({int limit = 100}) {
    return _p
        .where()
        .sortByCreatedAtDesc()
        .limit(limit)
        .watch(fireImmediately: true);
  }

  @override
  Future<PlatformOrder?> getById(int id) => _p.get(id);

  @override
  Future<int> save(PlatformOrder order) async {
    order.updatedAt = DateTime.now();
    late int id;
    await isar.writeTxn(() async {
      id = await _p.put(order);
    });
    return id;
  }

  @override
  Future<void> setStatus(int id, PlatformOrderStatus status) async {
    await isar.writeTxn(() async {
      final o = await _p.get(id);
      if (o != null) {
        o.status = status;
        o.updatedAt = DateTime.now();
        await _p.put(o);
      }
    });
  }
}
