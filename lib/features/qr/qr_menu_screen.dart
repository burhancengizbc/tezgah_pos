import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/collections/business_collections.dart';

class QrMenuManagementScreen extends ConsumerStatefulWidget {
  const QrMenuManagementScreen({super.key});

  @override
  ConsumerState<QrMenuManagementScreen> createState() => _QrMenuManagementScreenState();
}

class _QrMenuManagementScreenState extends ConsumerState<QrMenuManagementScreen> {
  bool _qrEnabled = true;

  @override
  Widget build(BuildContext context) {
    final isar = ref.watch(isarProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Karekod Menü ve Garson Çağırma'),
        actions: [
          Switch(
            value: _qrEnabled,
            onChanged: (val) => setState(() => _qrEnabled = val),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.rMd),
                border: Border.all(color: AppColors.primary),
              ),
              child: const Row(
                children: [
                  Icon(Icons.qr_code_2_rounded, size: 40, color: AppColors.primary),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Masalara özel QR kodlar oluşturarak müşterilerin dijital menüyü görmesini ve masadan garson/hesap çağırabilmesini sağlayın.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const Text('Aktif Masa QR Talepleri', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: AppSpacing.md),

            Expanded(
              child: StreamBuilder<List<QrMenuSession>>(
                stream: isar.qrMenuSessions
                    .filter()
                    .sortByCreatedAtDesc()
                    .watch(fireImmediately: true),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final sessions = snapshot.data ?? [];
                  if (sessions.isEmpty) {
                    return const Center(
                      child: Text('Şu anda masalardan gelen aktif QR talebi bulunmuyor.', 
                          style: TextStyle(color: AppColors.dTextDim)),
                    );
                  }

                  return ListView.separated(
                    itemCount: sessions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final s = sessions[index];
                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.amber,
                          child: Icon(Icons.notifications_active_rounded, color: Colors.black),
                        ),
                        title: Text(s.tableName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Talep: ${s.isAccountRequested ? "Hesap İstendi" : "Garson Çağrıldı"}'),
                        trailing: FilledButton(
                          onPressed: () async {
                            await isar.writeTxn(() async {
                              await isar.qrMenuSessions.delete(s.id);
                            });
                            setState(() {});
                          },
                          child: const Text('Tamamla / Kapat'),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}