import '../../data/collections/delivery_collections.dart';
import '../../data/enums/app_enums.dart';

abstract interface class CourierRepository {
  Stream<List<Courier>> watchActive();
  Future<List<Courier>> getAll({bool includeDeleted = false});
  Future<Courier?> getById(int id);
  Future<Courier?> getByPairCode(String code);
  Future<int> save(Courier courier); // pairCode bossa uretir
  Future<void> softDelete(int id);
  Future<void> incrementDeliveries(int courierId);
}

abstract interface class DeliveryRepository {
  Stream<List<Delivery>> watchActive(); // teslim/iptal disindakiler
  Future<List<Delivery>> activeForCourier(int courierId);
  Future<List<Delivery>> recentForCourier(int courierId, {int limit = 50});
  Future<Delivery?> getById(int id);
  Future<Delivery?> byOrder(int orderId);
  Future<int> create(Delivery delivery);
  Future<void> assign(int deliveryId, int courierId);
  Future<void> setStatus(int deliveryId, DeliveryStatus status);
}
