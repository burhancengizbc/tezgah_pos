import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/catalog_repository_impl.dart';
import '../../data/repositories/delivery_repository_impl.dart';
import '../../data/repositories/finance_repository_impl.dart';
import '../../data/repositories/people_repository_impl.dart';
import '../../data/repositories/platform_order_repository_impl.dart';
import '../../data/repositories/sales_repository_impl.dart';
import '../../data/repositories/settings_repository_impl.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../../domain/repositories/delivery_repository.dart';
import '../../domain/repositories/finance_repository.dart';
import '../../domain/repositories/people_repository.dart';
import '../../domain/repositories/platform_order_repository.dart';
import '../../domain/repositories/sales_repository.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/services/receipt_counter_service.dart';
import '../services/audit_service.dart';
import 'core_providers.dart';

/// Tek paylasilan AuditService.
final auditServiceProvider = Provider<AuditService>(
  (ref) => AuditService(ref.watch(isarProvider)),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepositoryImpl(ref.watch(isarProvider)),
);

final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => CategoryRepositoryImpl(
      ref.watch(isarProvider), ref.watch(auditServiceProvider)),
);

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => ProductRepositoryImpl(
      ref.watch(isarProvider), ref.watch(auditServiceProvider)),
);

final stockRepositoryProvider = Provider<StockRepository>(
  (ref) => StockRepositoryImpl(ref.watch(isarProvider)),
);

final customerRepositoryProvider = Provider<CustomerRepository>(
  (ref) => CustomerRepositoryImpl(
      ref.watch(isarProvider), ref.watch(auditServiceProvider)),
);

final tableRepositoryProvider = Provider<TableRepository>(
  (ref) => TableRepositoryImpl(
      ref.watch(isarProvider), ref.watch(auditServiceProvider)),
);

final orderRepositoryProvider = Provider<OrderRepository>(
  (ref) => OrderRepositoryImpl(
    ref.watch(isarProvider),
    ReceiptCounterService(ref.watch(isarProvider)),
    ref.watch(auditServiceProvider),
  ),
);

final cashRepositoryProvider = Provider<CashRepository>(
  (ref) => CashRepositoryImpl(
      ref.watch(isarProvider), ref.watch(auditServiceProvider)),
);

final accountingRepositoryProvider = Provider<AccountingRepository>(
  (ref) => AccountingRepositoryImpl(ref.watch(isarProvider)),
);

final courierRepositoryProvider = Provider<CourierRepository>(
  (ref) => CourierRepositoryImpl(
      ref.watch(isarProvider), ref.watch(auditServiceProvider)),
);

final deliveryRepositoryProvider = Provider<DeliveryRepository>(
  (ref) => DeliveryRepositoryImpl(
      ref.watch(isarProvider), ref.watch(courierRepositoryProvider)),
);

final platformOrderRepositoryProvider = Provider<PlatformOrderRepository>(
  (ref) => PlatformOrderRepositoryImpl(ref.watch(isarProvider)),
);

final employeeRepositoryProvider = Provider<EmployeeRepository>(
  (ref) => EmployeeRepositoryImpl(
      ref.watch(isarProvider), ref.watch(auditServiceProvider)),
);

