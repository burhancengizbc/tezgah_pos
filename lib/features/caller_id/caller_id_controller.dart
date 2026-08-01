import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_keys.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/services/caller_id_service.dart';
import '../../data/collections/people_collections.dart';
import '../../data/enums/app_enums.dart';
import '../customers/customers_screen.dart';
import '../sales/sales_screen.dart';
import 'caller_id_overlay.dart';

final callerIdServiceProvider =
    Provider<CallerIdService>((ref) => CallerIdService());

final callerIdControllerProvider =
    Provider<CallerIdController>((ref) => CallerIdController(ref));

/// Gelen arama olayini musteri eslestirme + ekran akisina baglar.
class CallerIdController {
  final Ref ref;
  bool _showing = false;
  CallerIdController(this.ref);

  bool get isSupported => ref.read(callerIdServiceProvider).isSupported;

  Future<bool> enable() async {
    final svc = ref.read(callerIdServiceProvider);
    if (!svc.isSupported) return false;
    final ok = await svc.requestPermission();
    if (!ok) return false;
    await svc.start(handleIncomingNumber);
    return true;
  }

  Future<void> disable() async {
    await ref.read(callerIdServiceProvider).stop();
  }

  /// Gelen numarayi isler: kayitli musteriyi bulur ve bildirim diyalogunu acar.
  /// Hem cihazin kendi aramasi hem de yerel agdaki "Cagri" uygulamasindan
  /// gelen aramalar bu metodu kullanir.
  Future<void> handleIncomingNumber(String number) async {
    if (_showing) return;
    final customer =
        await ref.read(customerRepositoryProvider).findByPhone(number);
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;

    _showing = true;
    await showDialog<void>(
      context: ctx,
      builder: (dctx) => CallerIdDialog(
        number: number,
        customer: customer,
        onClose: () => Navigator.of(dctx).pop(),
        onOpenOrder: () async {
          Navigator.of(dctx).pop();
          final order = await ref.read(orderRepositoryProvider).openOrder(
                type: OrderType.package,
                customerId: customer?.id,
              );
          navigatorKey.currentState?.push(
            MaterialPageRoute(
                builder: (_) => SalesScreen(orderId: order.id)),
          );
        },
        onAddCustomer: () async {
          Navigator.of(dctx).pop();
          // Telefon numarasını önceden doldurup doğrudan gelişmiş kayıt formunu aç
          final c = Customer()..phone = number;
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => CustomerFormScreen(existing: c), // veya initialPhone destekliyorsa o şekilde
            ),
          );
        },
      ),
    );
    _showing = false;
  }
}
