import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/collections/people_collections.dart';
import '../../data/enums/app_enums.dart'; 

// O an cihaza PIN girerek oturum açmış olan personeli tutar
final currentEmployeeProvider = StateProvider<Employee?>((ref) => null);

// Sadece patron/yönetici yetkisi var mı? (Hızlı kontrol için)
final isAdminProvider = Provider<bool>((ref) {
  final emp = ref.watch(currentEmployeeProvider);
  return emp?.role == EmployeeRole.admin || emp?.role == EmployeeRole.manager;
});