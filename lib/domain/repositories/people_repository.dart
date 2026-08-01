import '../../data/collections/people_collections.dart';
import '../../data/enums/app_enums.dart';

abstract interface class CustomerRepository {
  Future<List<Customer>> page({int offset = 0, int limit = 50, String? search});
  Future<Customer?> getById(int id);

  /// Caller ID: normalize edilmis telefona gore musteri bul.
  Future<Customer?> findByPhone(String phone);

  Future<int> save(Customer customer);
  Future<void> softDelete(int id);

  /// Siparis kapaninca cagrilir (denormalize ozet guncelle).
  Future<void> registerOrder(int customerId, int totalKurus, DateTime at);

  /// Telefonu sadece rakamlara indirger.
  static String normalizePhone(String raw) =>
      raw.replaceAll(RegExp(r'[^0-9]'), '');
}

abstract interface class TableRepository {
  Stream<List<DiningTable>> watchActive();
  Future<List<DiningTable>> getAll({bool includeDeleted = false});
  Future<DiningTable?> getById(int id);
  Future<int> save(DiningTable table);
  Future<void> reorder(List<int> orderedIds);
  Future<void> softDelete(int id);
  Future<void> setStatus(int id, TableStatus status, {int? currentOrderId});
  Future<void> transferTableOrder(int fromTableId, int toTableId, int orderId);
}

abstract interface class EmployeeRepository {
  Stream<List<Employee>> watchActive();
  Future<List<Employee>> getAll({bool includeDeleted = false});
  Future<Employee?> getById(int id);
  Future<int> save(Employee employee, {String? plainPin});
  Future<bool> verifyPin(int employeeId, String plainPin);
  Future<void> softDelete(int id);
}
