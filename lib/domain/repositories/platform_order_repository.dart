import '../../data/collections/delivery_collections.dart';
import '../../data/enums/app_enums.dart';

abstract interface class PlatformOrderRepository {
  Stream<List<PlatformOrder>> watchRecent({int limit = 100});
  Future<PlatformOrder?> getById(int id);
  Future<int> save(PlatformOrder order); // insert/update
  Future<void> setStatus(int id, PlatformOrderStatus status);
}
