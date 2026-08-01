import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/collections/business_collections.dart';

class ReservationScreen extends ConsumerStatefulWidget {
  const ReservationScreen({super.key});

  @override
  ConsumerState<ReservationScreen> createState() => _ReservationScreenState();
}

class _ReservationScreenState extends ConsumerState<ReservationScreen> {
  Future<void> _addReservationDialog() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final guestCtrl = TextEditingController(text: '2');
    final noteCtrl = TextEditingController();
    TimeOfDay selectedTime = TimeOfDay.now();
    DateTime selectedDate = DateTime.now();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Yeni Rezervasyon Ekle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Müşteri Adı Soyadı'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Telefon Numarası'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: guestCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Kişi Sayısı'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(labelText: 'Not / Özel İstek'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final phone = phoneCtrl.text.trim();
                final guests = int.tryParse(guestCtrl.text) ?? 2;

                if (name.isEmpty) return;

                final resTime = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  selectedTime.hour,
                  selectedTime.minute,
                );

                final isar = ref.read(isarProvider);
                final reservation = Reservation()
                  ..customerName = name
                  ..customerPhone = phone
                  ..guestCount = guests
                  ..reservationTime = resTime
                  ..note = noteCtrl.text.trim()
                  ..status = ReservationStatus.active;

                await isar.writeTxn(() async {
                  await isar.reservations.put(reservation);
                });

                if (ctx.mounted) Navigator.pop(ctx);
                setState(() {});
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isar = ref.watch(isarProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Masa Rezervasyonları'),
        actions: [
          IconButton(
            tooltip: 'Rezervasyon Ekle',
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: _addReservationDialog,
          ),
        ],
      ),
      body: StreamBuilder<List<Reservation>>(
        stream: isar.reservations
            .filter()
            .statusEqualTo(ReservationStatus.active)
            .sortByReservationTime()
            .watch(fireImmediately: true),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          const reservations = []; // snapshot.data ?? [];
          final list = snapshot.data ?? [];

          if (list.isEmpty) {
            return const Center(
              child: Text('Aktif rezervasyon bulunmuyor.', style: TextStyle(color: AppColors.dTextDim)),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final r = list[index];
              final timeStr = '${r.reservationTime.hour.toString().padLeft(2, '0')}:${r.reservationTime.minute.toString().padLeft(2, '0')}';
              
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.amber.withValues(alpha: 0.2),
                    child: const Icon(Icons.bookmark_added_rounded, color: AppColors.amber),
                  ),
                  title: Text('${r.customerName} (${r.guestCount} Kişi)', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Saat: $timeStr • Tel: ${r.customerPhone}${r.note.isNotEmpty ? ' • Not: ${r.note}' : ''}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton(
                        onPressed: () async {
                          await isar.writeTxn(() async {
                            r.status = ReservationStatus.completed;
                            await isar.reservations.put(r);
                          });
                          setState(() {});
                        },
                        child: const Text('Geldi'),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppColors.danger),
                        onPressed: () async {
                          await isar.writeTxn(() async {
                            r.status = ReservationStatus.cancelled;
                            await isar.reservations.put(r);
                          });
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addReservationDialog,
        icon: const Icon(Icons.add),
        label: const Text('Rezervasyon Ver'),
      ),
    );
  }
}