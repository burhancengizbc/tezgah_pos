import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:isar_community/isar.dart';

import '../../data/collections/people_collections.dart';
import '../../data/enums/app_enums.dart';
import '../../domain/repositories/people_repository.dart';
import '../../core/services/audit_service.dart';

class CustomerRepositoryImpl implements CustomerRepository {
  final Isar isar;
  final AuditService audit;
  CustomerRepositoryImpl(this.isar, this.audit);

  IsarCollection<Customer> get _c => isar.collection<Customer>();

  @override
  Future<List<Customer>> page(
      {int offset = 0, int limit = 50, String? search}) {
    if (search == null || search.trim().isEmpty) {
      return _c
          .filter()
          .isDeletedEqualTo(false)
          .sortByCreatedAtDesc()
          .offset(offset)
          .limit(limit)
          .findAll();
    }
    final s = search.trim();
    final digits = CustomerRepository.normalizePhone(s);
    return _c
        .filter()
        .isDeletedEqualTo(false)
        .group((q) {
          if (digits.isEmpty) {
            return q.firstNameContains(s, caseSensitive: false)
                    .or()
                    .lastNameContains(s, caseSensitive: false);
          }
          return q.firstNameContains(s, caseSensitive: false)
                  .or()
                  .lastNameContains(s, caseSensitive: false)
                  .or()
                  .phoneContains(digits);
        })
        .sortByCreatedAtDesc()
        .offset(offset)
        .limit(limit)
        .findAll();
  }

  @override
  Future<Customer?> getById(int id) => _c.get(id);

  @override
  Future<Customer?> findByPhone(String phone) {
    final digits = CustomerRepository.normalizePhone(phone);
    if (digits.isEmpty) return Future.value(null);
    return _c
        .filter()
        .isDeletedEqualTo(false)
        .phoneEqualTo(digits)
        .findFirst();
  }

  @override
  Future<int> save(Customer customer) async {
    final isNew = customer.id == Isar.autoIncrement;
    customer.phone = CustomerRepository.normalizePhone(customer.phone);
    customer.updatedAt = DateTime.now();
    late int id;
    await isar.writeTxn(() async {
      id = await _c.put(customer);
    });
    await audit.log(isNew ? AuditAction.create : AuditAction.update, 'Customer',
        id, customer.fullName);
    return id;
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
    await audit.log(AuditAction.delete, 'Customer', id, '');
  }

  @override
  Future<void> registerOrder(int customerId, int totalKurus, DateTime at) async {
    await isar.writeTxn(() async {
      final c = await _c.get(customerId);
      if (c != null) {
        c.totalOrders += 1;
        c.totalSpendKurus += totalKurus;
        c.lastOrderAt = at;
        await _c.put(c);
      }
    });
  }
}

class TableRepositoryImpl implements TableRepository {
  final Isar isar;
  final AuditService audit;
  TableRepositoryImpl(this.isar, this.audit);

  IsarCollection<DiningTable> get _t => isar.collection<DiningTable>();

  @override
  Stream<List<DiningTable>> watchActive() {
    return DiningTableQuerySortBy(_t
        .filter()
        .isDeletedEqualTo(false)
        .isActiveEqualTo(true))
        .sortBySortOrder()
        .watch(fireImmediately: true);
  }

  @override
  Future<List<DiningTable>> getAll({bool includeDeleted = false}) {
    final q = _t.filter();
    if (includeDeleted) return q.sortBySortOrder().findAll();
    return DiningTableQuerySortBy(q.isDeletedEqualTo(false)).sortBySortOrder().findAll();
  }

  @override
  Future<DiningTable?> getById(int id) => _t.get(id);

  @override
  Future<int> save(DiningTable table) async {
    final isNew = table.id == Isar.autoIncrement;
    table.updatedAt = DateTime.now();
    late int id;
    await isar.writeTxn(() async {
      id = await _t.put(table);
    });
    await audit.log(isNew ? AuditAction.create : AuditAction.update,
        'DiningTable', id, table.name);
    return id;
  }

  @override
  Future<void> reorder(List<int> orderedIds) async {
    await isar.writeTxn(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        final t = await _t.get(orderedIds[i]);
        if (t != null) {
          t.sortOrder = i;
          await _t.put(t);
        }
      }
    });
  }

  @override
  Future<void> softDelete(int id) async {
    await isar.writeTxn(() async {
      final t = await _t.get(id);
      if (t != null) {
        t.isDeleted = true;
        t.updatedAt = DateTime.now();
        await _t.put(t);
      }
    });
    await audit.log(AuditAction.delete, 'DiningTable', id, '');
  }

  @override
  Future<void> setStatus(int id, TableStatus status, {int? currentOrderId}) async {
    await isar.writeTxn(() async {
      final t = await _t.get(id);
      if (t != null) {
        t.status = status;
        if (status == TableStatus.empty) {
          t.currentOrderId = null;
        } else if (currentOrderId != null) {
          t.currentOrderId = currentOrderId;
        }
        t.updatedAt = DateTime.now();
        await _t.put(t);
      }
    });
  }

  @override
  Future<void> transferTableOrder(int fromTableId, int toTableId, int orderId) async {
    await isar.writeTxn(() async {
      final fromTable = await _t.get(fromTableId);
      final toTable = await _t.get(toTableId);
      final now = DateTime.now();

      if (fromTable != null) {
        fromTable.status = TableStatus.empty;
        fromTable.currentOrderId = null;
        fromTable.updatedAt = now;
        await _t.put(fromTable);
      }

      if (toTable != null) {
        toTable.status = TableStatus.occupied;
        toTable.currentOrderId = orderId;
        toTable.updatedAt = now;
        await _t.put(toTable);
      }
    });
  }
}

extension on QueryBuilder<DiningTable, DiningTable, QFilterCondition> {
  sortBySortOrder() {}
}

class EmployeeRepositoryImpl implements EmployeeRepository {
  final Isar isar;
  final AuditService audit;
  EmployeeRepositoryImpl(this.isar, this.audit);

  IsarCollection<Employee> get _e => isar.collection<Employee>();

  String _newSalt() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    return base64Url.encode(bytes);
  }

  String _hash(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  @override
  Stream<List<Employee>> watchActive() {
    return _e
        .filter()
        .isDeletedEqualTo(false)
        .isActiveEqualTo(true)
        .watch(fireImmediately: true);
  }

  @override
  Future<List<Employee>> getAll({bool includeDeleted = false}) async {
    if (includeDeleted) {
      return await _e.where().findAll();
    }
    return await _e.filter().isDeletedEqualTo(false).findAll();
  }

  @override
  Future<Employee?> getById(int id) => _e.get(id);

  @override
  Future<int> save(Employee employee, {String? plainPin}) async {
    final isNew = employee.id == Isar.autoIncrement;
    employee.updatedAt = DateTime.now();
    if (plainPin != null && plainPin.trim().isNotEmpty) {
      final salt = _newSalt();
      employee.pinSalt = salt;
      employee.pinHash = _hash(plainPin.trim(), salt);
    }
    late int id;
    await isar.writeTxn(() async {
      id = await _e.put(employee);
    });
    await audit.log(isNew ? AuditAction.create : AuditAction.update, 'Employee',
        id, employee.fullName);
    return id;
  }

  @override
  Future<bool> verifyPin(int employeeId, String plainPin) async {
    final emp = await _e.get(employeeId);
    if (emp == null || !emp.isActive || emp.isDeleted) return false;
    if (emp.pinHash == null || emp.pinSalt == null) return true;
    return _hash(plainPin.trim(), emp.pinSalt!) == emp.pinHash;
  }

  @override
  Future<void> softDelete(int id) async {
    await isar.writeTxn(() async {
      final emp = await _e.get(id);
      if (emp != null) {
        emp.isDeleted = true;
        emp.updatedAt = DateTime.now();
        await _e.put(emp);
      }
    });
    await audit.log(AuditAction.delete, 'Employee', id, '');
  }
}