import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

import '../../core/providers/core_providers.dart';
import '../../core/providers/data_streams.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/money.dart';
import '../../data/collections/delivery_collections.dart' as delivery;
import '../../data/collections/people_collections.dart';
import '../../data/collections/sales_collections.dart';
import '../../data/enums/app_enums.dart';
import '../../features/lan/lan_controller.dart';
import '../shared/widgets.dart';

const deliveryStatusLabels = <DeliveryStatus, String>{
  DeliveryStatus.pending: 'Bekliyor',
  DeliveryStatus.assigned: 'Atandi',
  DeliveryStatus.onTheWay: 'Yolda',
  DeliveryStatus.delivered: 'Teslim',
  DeliveryStatus.cancelled: 'Iptal',
};

Color deliveryStatusColor(DeliveryStatus s) => switch (s) {
      DeliveryStatus.pending => AppColors.dTextDim,
      DeliveryStatus.assigned => AppColors.warning,
      DeliveryStatus.onTheWay => AppColors.amber,
      DeliveryStatus.delivered => AppColors.success,
      DeliveryStatus.cancelled => AppColors.danger,
    };

class CourierHubScreen extends ConsumerWidget {
  const CourierHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled =
        ref.watch(settingsStreamProvider).value?.courierModuleEnabled ?? false;
    if (!enabled) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kurye')),
        body: const EmptyState(
          icon: Icons.delivery_dining_rounded,
          message:
              'Kurye modulu kapali.\nAyarlar > Yerel Ag & Moduller bolumunden acin.',
        ),
      );
    }
    // DEĞİŞEN: Tab sayısı 3 yapıldı ve "Canlı Harita Takip" sekmesi eklendi
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kurye & Paket Yönetimi'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Teslimatlar'),
            Tab(text: 'Canlı Harita Takip'),
            Tab(text: 'Kuryeler'),
          ]),
        ),
        body: const TabBarView(
          children: [_DeliveriesTab(), _CourierMapTab(), _CouriersTab()],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------- Canlı Harita Takip Sekmesi (YENİ)

class _CourierMapTab extends ConsumerWidget {
  const _CourierMapTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final couriers = ref.watch(couriersProvider);
    return couriers.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Hata: $e'),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.map_rounded,
            message: 'Haritada gösterilecek aktif kurye bulunamadı.',
          );
        }
        return Container(
          color: const Color(0xFF1E1E24),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.radar_rounded, size: 64, color: AppColors.amber),
                const SizedBox(height: 12),
                const Text(
                  'Canlı Kurye Konumları Haritası Aktif',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 6),
                const Text('Kuryelerin mobil uygulamalarından gelen GPS sinyalleri izleniyor.'),
                const SizedBox(height: 24),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final k = list[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          leading: const Icon(Icons.two_wheeler_rounded, color: AppColors.amber),
                          title: Text(k.name),
                          subtitle: Text('Durum: Çevrim içi • Kod: ${k.pairCode}'),
                          trailing: const Chip(
                            label: Text('Aktif Konum', style: TextStyle(fontSize: 11)),
                            backgroundColor: Colors.green,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ----------------------------------------------------------- Teslimatlar

class _DeliveriesTab extends ConsumerWidget {
  const _DeliveriesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deliveries = ref.watch(activeDeliveriesProvider);
    final couriers = ref.watch(couriersProvider).value ?? [];
    final courierName = {for (final c in couriers) c.id: c.name};

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _newDelivery(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Kuryeye Gonder'),
      ),
      body: deliveries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('Hata: $e'),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
                icon: Icons.local_shipping_outlined,
                message: 'Aktif teslimat yok.');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final d = list[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      deliveryStatusColor(d.status).withValues(alpha: 0.2),
                  child: Icon(Icons.delivery_dining_rounded,
                      color: deliveryStatusColor(d.status)),
                ),
                title: Text(d.customerName.isEmpty ? '(isimsiz)' : d.customerName),
                subtitle: Text([
                  d.address,
                  if (d.courierId != null)
                    'Kurye: ${courierName[d.courierId] ?? "-"}',
                ].where((e) => e.isNotEmpty).join('\n')),
                isThreeLine: d.address.isNotEmpty && d.courierId != null,
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(deliveryStatusLabels[d.status]!,
                        style: TextStyle(
                            color: deliveryStatusColor(d.status),
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                    MoneyText(d.totalKurus,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                onTap: () => _manage(context, ref, d, couriers),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _manage(BuildContext context, WidgetRef ref, delivery.Delivery d,
      List<delivery.Courier> couriers) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(d.customerName),
              subtitle: Text(d.address),
              trailing: MoneyText(d.totalKurus),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.person_pin_circle_rounded),
              title: const Text('Kurye ata / degistir'),
              onTap: () async {
                Navigator.pop(c);
                await _assign(context, ref, d, couriers);
              },
            ),
            ListTile(
              leading: const Icon(Icons.directions_run_rounded),
              title: const Text('Yola cikti'),
              onTap: () async {
                await ref
                    .read(deliveryRepositoryProvider)
                    .setStatus(d.id, DeliveryStatus.onTheWay);
                ref.read(lanControllerProvider).notifyCouriers();
                if (c.mounted) Navigator.pop(c);
              },
            ),
            ListTile(
              leading: const Icon(Icons.check_circle_rounded,
                  color: AppColors.success),
              title: const Text('Teslim edildi'),
              onTap: () async {
                await ref
                    .read(deliveryRepositoryProvider)
                    .setStatus(d.id, DeliveryStatus.delivered);
                ref.read(lanControllerProvider).notifyCouriers();
                if (c.mounted) Navigator.pop(c);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.cancel_rounded, color: AppColors.danger),
              title: const Text('Iptal et'),
              onTap: () async {
                await ref
                    .read(deliveryRepositoryProvider)
                    .setStatus(d.id, DeliveryStatus.cancelled);
                ref.read(lanControllerProvider).notifyCouriers();
                if (c.mounted) Navigator.pop(c);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _assign(BuildContext context, WidgetRef ref, delivery.Delivery d,
      List<delivery.Courier> couriers) async {
    if (couriers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Once "Kuryeler" sekmesinden kurye ekleyin.')));
      return;
    }
    final picked = await showModalBottomSheet<delivery.Courier>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final k in couriers)
              ListTile(
                leading: const Icon(Icons.two_wheeler_rounded),
                title: Text(k.name),
                subtitle: Text('${k.totalDeliveries} teslimat'),
                onTap: () => Navigator.pop(c, k),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      await ref.read(deliveryRepositoryProvider).assign(d.id, picked.id);
      ref.read(lanControllerProvider).notifyCouriers();
    }
  }

  Future<void> _newDelivery(BuildContext context, WidgetRef ref) async {
    final isar = ref.read(isarProvider);
    final orders = await isar
        .collection<Order>()
        .filter()
        .typeEqualTo(OrderType.package)
        .not()
        .statusEqualTo(OrderStatus.cancelled)
        .sortByCreatedAtDesc()
        .limit(50)
        .findAll();
    final deliveryRepo = ref.read(deliveryRepositoryProvider);
    final candidates = <Order>[];
    for (final o in orders) {
      if (await deliveryRepo.byOrder(o.id) == null) candidates.add(o);
    }
    if (!context.mounted) return;
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Teslimata uygun paket siparisi yok.')));
      return;
    }

    final order = await showModalBottomSheet<Order>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Text('Paket siparisi sec',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            for (final o in candidates)
              ListTile(
                title: Text('Fis #${o.receiptNo}'),
                subtitle: Text(Money.format(o.totalKurus)),
                onTap: () => Navigator.pop(c, o),
              ),
          ],
        ),
      ),
    );
    if (order == null || !context.mounted) return;

    Customer? customer;
    if (order.customerId != null) {
      customer =
          await ref.read(customerRepositoryProvider).getById(order.customerId!);
    }
    if (!context.mounted) return;
    await _detailsAndCreate(context, ref, order, customer);
  }

  Future<void> _detailsAndCreate(BuildContext context, WidgetRef ref,
      Order order, Customer? customer) async {
    final name = TextEditingController(text: customer?.fullName ?? '');
    final phone = TextEditingController(text: customer?.phone ?? '');
    final address = TextEditingController(text: customer?.address ?? '');
    final note = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Teslimat • Fis #${order.receiptNo}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Ad Soyad')),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Telefon')),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                  controller: address,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Adres')),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                  controller: note,
                  decoration: const InputDecoration(labelText: 'Not')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Vazgec')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Olustur')),
        ],
      ),
    );
    if (ok != true) return;

    final deliveryObj = delivery.Delivery()
      ..orderId = order.id
      ..customerName = name.text.trim()
      ..phone = phone.text.trim()
      ..address = address.text.trim()
      ..note = note.text.trim()
      ..totalKurus = order.totalKurus
      ..status = DeliveryStatus.pending;
    final id = await ref.read(deliveryRepositoryProvider).create(deliveryObj);

    if (!context.mounted) return;
    final couriers = ref.read(couriersProvider).value ?? [];
    if (couriers.isNotEmpty) {
      final created = await ref.read(deliveryRepositoryProvider).getById(id);
      if (created != null && context.mounted) {
        await _assign(context, ref, created, couriers);
      }
    } else {
      ref.read(lanControllerProvider).notifyCouriers();
    }
  }
}

// ----------------------------------------------------------- Kuryeler

class _CouriersTab extends ConsumerWidget {
  const _CouriersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final couriers = ref.watch(couriersProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref, null),
        icon: const Icon(Icons.person_add_alt_rounded),
        label: const Text('Kurye Ekle'),
      ),
      body: couriers.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('Hata: $e'),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
                icon: Icons.two_wheeler_rounded,
                message: 'Henuz kurye eklenmedi.');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final k = list[i];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.two_wheeler_rounded)),
                title: Text(k.name),
                subtitle: Text(
                    '${k.phone.isEmpty ? "" : "${k.phone} • "}Kod: ${k.pairCode} • ${k.totalDeliveries} teslimat'),
                onTap: () => _edit(context, ref, k),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, delivery.Courier? existing) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final phone = TextEditingController(text: existing?.phone ?? '');
    final isEdit = existing != null;

    final action = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(isEdit ? 'Kurye Duzenle' : 'Yeni Kurye'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Ad Soyad')),
            const SizedBox(height: AppSpacing.sm),
            TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Telefon')),
            if (isEdit) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  const Icon(Icons.vpn_key_rounded, size: 18),
                  const SizedBox(width: 6),
                  Text('Eslesme kodu: ${existing.pairCode}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ],
        ),
        actions: [
          if (isEdit)
            TextButton(
              onPressed: () => Navigator.pop(c, 'delete'),
              child: const Text('Sil', style: TextStyle(color: AppColors.danger)),
            ),
          TextButton(
              onPressed: () => Navigator.pop(c, 'cancel'),
              child: const Text('Vazgec')),
          FilledButton(
              onPressed: () => Navigator.pop(c, 'save'),
              child: const Text('Kaydet')),
        ],
      ),
    );

    final repo = ref.read(courierRepositoryProvider);
    if (action == 'save') {
      if (name.text.trim().isEmpty) return;
      final k = existing ?? delivery.Courier();
      k
        ..name = name.text.trim()
        ..phone = phone.text.trim();
      await repo.save(k);
    } else if (action == 'delete' && existing != null) {
      await repo.softDelete(existing.id);
    }
  }
}