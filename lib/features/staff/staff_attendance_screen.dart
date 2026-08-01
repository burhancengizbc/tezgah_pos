import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/providers/core_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/collections/business_collections.dart';

class StaffAttendanceScreen extends ConsumerStatefulWidget {
  const StaffAttendanceScreen({super.key});

  @override
  ConsumerState<StaffAttendanceScreen> createState() => _StaffAttendanceScreenState();
}

class _StaffAttendanceScreenState extends ConsumerState<StaffAttendanceScreen> {
  Future<void> _clockIn() async {
    final emp = ref.read(currentEmployeeProvider);
    if (emp == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aktif bir kullanıcı oturumu bulunamadı.'), backgroundColor: AppColors.danger),
      );
      return;
    }

    final isar = ref.read(isarProvider);
    
    // Zaten açık bir mesaisi var mı kontrol et
    final activeShift = await isar.staffShifts
        .filter()
        .employeeIdEqualTo(emp.id)
        .isCompletedEqualTo(false)
        .findFirst();

    if (activeShift != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zaten aktif bir mesainiz devam ediyor!'), backgroundColor: AppColors.warning),
        );
      }
      return;
    }

    final shift = StaffShift()
      ..employeeId = emp.id
      ..employeeName = emp.fullName
      ..clockIn = DateTime.now()
      ..isCompleted = false;

    await isar.writeTxn(() async {
      await isar.staffShifts.put(shift);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mesai başarıyla başlatıldı. İyi çalışmalar!'), backgroundColor: AppColors.success),
      );
      setState(() {});
    }
  }

  Future<void> _clockOut(StaffShift shift) async {
    final isar = ref.read(isarProvider);

    await isar.writeTxn(() async {
      shift.clockOut = DateTime.now();
      shift.isCompleted = true;
      await isar.staffShifts.put(shift);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vardiya sonlandırıldı. Dinlenmeler dileriz!'), backgroundColor: AppColors.success),
      );
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isar = ref.watch(isarProvider);
    final currentEmp = ref.watch(currentEmployeeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personel Mesai ve Vardiya Takibi'),
      ),
      body: Column(
        children: [
          // Giriş / Çıkış Hızlı İşlem Kartı
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    Text('Aktif Personel: ${currentEmp?.fullName ?? "Yönetici"}', 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _clockIn,
                        style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                        icon: const Icon(Icons.login_rounded),
                        label: const Text('İşe Giriş Yap (Mesaiyi Başlat)'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(),

          // Aktif ve Geçmiş Vardiyalar Listesi
          Expanded(
            child: FutureBuilder<List<StaffShift>>(
              future: isar.staffShifts.filter().sortByClockInDesc().findAll(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final shifts = snapshot.data ?? [];
                if (shifts.isEmpty) {
                  return const Center(
                    child: Text('Henüz kaydedilmiş mesai hareketi bulunmuyor.', style: TextStyle(color: AppColors.dTextDim)),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: shifts.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final s = shifts[index];
                    final inStr = '${s.clockIn.hour.toString().padLeft(2, '0')}:${s.clockIn.minute.toString().padLeft(2, '0')}';
                    final outStr = s.clockOut != null 
                        ? '${s.clockOut!.hour.toString().padLeft(2, '0')}:${s.clockOut!.minute.toString().padLeft(2, '0')}'
                        : 'Devam Ediyor';

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: s.isCompleted ? Colors.blue.withValues(alpha: 0.2) : AppColors.success.withValues(alpha: 0.2),
                        child: Icon(
                          s.isCompleted ? Icons.history_rounded : Icons.timer_rounded,
                          color: s.isCompleted ? Colors.blue : AppColors.success,
                        ),
                      ),
                      title: Text(s.employeeName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Giriş: $inStr • Çıkış: $outStr • Tarih: ${s.clockIn.day}.${s.clockIn.month}.${s.clockIn.year}'),
                      trailing: !s.isCompleted
                          ? OutlinedButton(
                              onPressed: () => _clockOut(s),
                              style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                              child: const Text('Çıkış Yap'),
                            )
                          : const Chip(label: Text('Tamamlandı', style: TextStyle(fontSize: 11))),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}