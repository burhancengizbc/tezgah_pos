import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_info_plus/network_info_plus.dart';

import '../../core/providers/core_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/services/lan_server_service.dart';
import '../../data/collections/delivery_collections.dart';
import '../../data/collections/sales_collections.dart';
import '../../data/enums/app_enums.dart';
import '../caller_id/caller_id_controller.dart';

final lanServerServiceProvider =
    Provider<LanServerService>((ref) => LanServerService());

final lanControllerProvider =
    Provider<LanController>((ref) => LanController(ref));

/// Yerel ag sunucusunu uygulama mantigina baglar (ust akil Tezgah).
class LanController {
  final Ref ref;
  LanController(this.ref);

  LanServerService get server => ref.read(lanServerServiceProvider);

  bool get isRunning => server.isRunning;

  Future<String?> wifiIp() async {
    try {
      return await NetworkInfo().getWifiIP();
    } catch (_) {
      return null;
    }
  }

  /// Eslesme tokeni yoksa uretip kaydeder, dondurur.
  Future<String> ensureToken() async {
    final repo = ref.read(settingsRepositoryProvider);
    final s = await repo.getSettings();
    if (s.lanPairToken.trim().isEmpty) {
      const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
      final r = Random.secure();
      s.lanPairToken =
          List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
      await repo.saveSettings(s);
    }
    return s.lanPairToken;
  }

  Future<void> start() async {
    final s = await ref.read(settingsRepositoryProvider).getSettings();
    if (!s.lanServerEnabled) return;
    final token = await ensureToken();
    await server.start(
      port: s.lanServerPort,
      token: token,
      onCallerId: _onCallerId,
      onPlatformOrder: _onPlatformOrder,
      onCourierInfo: _onCourierInfo,
      onCourierJobs: _onCourierJobs,
      onCourierStatus: _onCourierStatus,
    );
  }

  Future<void> stop() => server.stop();

  Future<void> restart() async {
    await stop();
    await start();
  }

  Future<void> _onCallerId(String number) async {
    final s = await ref.read(settingsRepositoryProvider).getSettings();
    if (!s.lanCallerIdEnabled) return;
    await ref.read(callerIdControllerProvider).handleIncomingNumber(number);
  }

  /// Yerel agdan gelen platform siparisini gelen kutusuna ekler.
  Future<Map<String, dynamic>> _onPlatformOrder(
      Map<String, dynamic> body) async {
    final s = await ref.read(settingsRepositoryProvider).getSettings();
    if (!s.platformOrdersEnabled) {
      return {'error': 'platform module disabled'};
    }
    final isar = ref.read(isarProvider);

    final items = <PlatformOrderItem>[
      for (final raw in (body['items'] as List? ?? const []))
        if (raw is Map)
          (PlatformOrderItem()
            ..name = (raw['name'] ?? '').toString()
            ..qty = (raw['qty'] as num?)?.toDouble() ?? 1
            ..unitPriceKurus = (raw['unitPriceKurus'] as num?)?.toInt() ?? 0
            ..note = (raw['note'] ?? '').toString()),
    ];

    var total = (body['totalKurus'] as num?)?.toInt() ?? 0;
    if (total == 0 && items.isNotEmpty) {
      total = items.fold(
          0, (sum, i) => sum + (i.unitPriceKurus * i.qty).round());
    }

    final po = PlatformOrder()
      ..platform = _platform(body['platform'])
      ..externalCode = body['externalCode']?.toString()
      ..customerName = (body['customerName'] ?? '').toString()
      ..phone = (body['phone'] ?? '').toString()
      ..address = (body['address'] ?? '').toString()
      ..note = (body['note'] ?? '').toString()
      ..items = items
      ..totalKurus = total
      ..status = PlatformOrderStatus.newOrder;

    late int id;
    await isar.writeTxn(() async {
      id = await isar.collection<PlatformOrder>().put(po);
    });
    return {'ok': true, 'id': id};
  }

  DeliveryPlatform _platform(dynamic v) {
    final name = (v ?? '').toString();
    for (final p in DeliveryPlatform.values) {
      if (p.name == name) return p;
    }
    return DeliveryPlatform.other;
  }

  // --- Kurye ---

  /// Kurye uygulamalarina "listeni yenile" sinyali yayinlar.
  void notifyCouriers() => server.broadcast({'type': 'refresh'});

  Future<Map<String, dynamic>> _onCourierInfo() async {
    final s = await ref.read(settingsRepositoryProvider).getSettings();
    if (!s.courierModuleEnabled) return {'error': 'courier module disabled'};
    final p = await ref.read(settingsRepositoryProvider).getProfile();
    return {
      'ok': true,
      'business': {'name': p.name, 'address': p.address, 'phone': p.phone},
    };
  }

  Future<Map<String, dynamic>> _onCourierJobs(String code) async {
    final s = await ref.read(settingsRepositoryProvider).getSettings();
    if (!s.courierModuleEnabled) return {'error': 'courier module disabled'};

    final courier = await ref.read(courierRepositoryProvider).getByPairCode(code);
    if (courier == null) return {'ok': false, 'error': 'invalid code'};

    final isar = ref.read(isarProvider);
    final list =
        await ref.read(deliveryRepositoryProvider).activeForCourier(courier.id);
    final jobs = <Map<String, dynamic>>[];
    for (final d in list) {
      final order = await isar.collection<Order>().get(d.orderId);
      jobs.add({
        'id': d.id,
        'receiptNo': order?.receiptNo ?? 0,
        'customerName': d.customerName,
        'phone': d.phone,
        'address': d.address,
        'note': d.note,
        'totalKurus': d.totalKurus,
        'status': d.status.name,
      });
    }
    return {
      'ok': true,
      'courier': {'name': courier.name, 'totalDeliveries': courier.totalDeliveries},
      'jobs': jobs,
    };
  }

  Future<Map<String, dynamic>> _onCourierStatus(
      String code, int deliveryId, String status) async {
    final s = await ref.read(settingsRepositoryProvider).getSettings();
    if (!s.courierModuleEnabled) return {'error': 'courier module disabled'};

    final courier = await ref.read(courierRepositoryProvider).getByPairCode(code);
    if (courier == null) return {'ok': false, 'error': 'invalid code'};

    final delivery = await ref.read(deliveryRepositoryProvider).getById(deliveryId);
    if (delivery == null || delivery.courierId != courier.id) {
      return {'ok': false, 'error': 'not your job'};
    }

    DeliveryStatus? st;
    for (final v in DeliveryStatus.values) {
      if (v.name == status) st = v;
    }
    if (st == null) return {'ok': false, 'error': 'bad status'};

    await ref.read(deliveryRepositoryProvider).setStatus(deliveryId, st);
    notifyCouriers();
    return {'ok': true};
  }
}
