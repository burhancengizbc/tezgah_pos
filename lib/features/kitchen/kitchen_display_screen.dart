import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/collections/sales_collections.dart';
import '../../data/enums/app_enums.dart';

class KitchenDisplayScreen extends ConsumerStatefulWidget {
  const KitchenDisplayScreen({super.key});

  @override
  ConsumerState<KitchenDisplayScreen> createState() => _KitchenDisplayScreenState();
}

class _KitchenDisplayScreenState extends ConsumerState<KitchenDisplayScreen> {
  // Hangi departman süzgecinde olduğumuz (null = Tüm Mutfak)
  int? _selectedDepartmentId;

  @override
  Widget build(BuildContext context) {
    final isar = ref.watch(isarProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Canlı Mutfak Ekranı (KDS)'),
        actions: [
          // İsteğe bağlı departman filtreleme butonları eklenebilir
        ],
      ),
      body: StreamBuilder<List<OrderLine>>(
        // Henüz tamamlanmamış veya mutfakta bekleyen aktif satırları dinle
        stream: isar.orderLines
            .filter()
            .isVoidEqualTo(false)
            .kitchenStatusEqualTo(KitchenStatus.pending) // veya cooking
            .watch(fireImmediately: true),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final lines = snapshot.data ?? [];
          if (lines.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.done_all_rounded, size: 64, color: AppColors.success),
                  SizedBox(height: AppSpacing.md),
                  Text('Harika! Mutfakta bekleyen aktif sipariş kalmadı.',
                      style: TextStyle(fontSize: 16, color: AppColors.dTextDim)),
                ],
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final cols = (constraints.maxWidth / 300).floor().clamp(1, 4);
              return GridView.builder(
                padding: const EdgeInsets.all(AppSpacing.md),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: AppSpacing.md,
                  crossAxisSpacing: AppSpacing.md,
                  childAspectRatio: 1.2,
                ),
                itemCount: lines.length,
                itemBuilder: (context, index) {
                  final line = lines[index];
                  return _KitchenOrderCard(
                    line: line,
                    onStatusChanged: (newStatus) async {
                      await isar.writeTxn(() async {
                        line.kitchenStatus = newStatus;
                        if (newStatus == KitchenStatus.ready) {
                          line.kitchenReadyAt = DateTime.now();
                        }
                        await isar.orderLines.put(line);
                      });
                      setState(() {});
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _KitchenOrderCard extends StatelessWidget {
  final OrderLine line;
  final ValueChanged<KitchenStatus> onStatusChanged;

  const _KitchenOrderCard({required this.line, required this.onStatusChanged});

  @override
  Widget build(BuildContext context) {
    final qtyLabel = line.qty == line.qty.roundToDouble() ? '${line.qty.toInt()}' : '${line.qty}';
    
    // Geçen süreyi hesaplama (Sipariş verileli kaç dakika oldu?)
    final duration = DateTime.now().difference(line.createdAt);
    final minutesAgo = duration.inMinutes;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.rLg),
        side: BorderSide(
          color: minutesAgo > 15 ? AppColors.danger : AppColors.outline,
          width: minutesAgo > 15 ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst Bilgi (Süre ve Adet)
            Row(
              mainAxisAlignment: MainAxisAlignment.between,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: minutesAgo > 15 ? AppColors.danger.withValues(alpha: 0.2) : AppColors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('$minutesAgo dk önce',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: minutesAgo > 15 ? AppColors.danger : AppColors.amber,
                        fontSize: 12,
                      )),
                ),
                Text('${qtyLabel}x',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              ],
            ),
            const Spacer(),
            
            // Ürün Adı
            Text(
              line.productName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            
            if (line.note.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Not: ${line.note}',
                  style: const TextStyle(color: AppColors.warning, fontSize: 13, fontWeight: FontWeight.w600)),
            ],

            const Spacer(),
            
            // Aksiyon Butonu (Hazırla / Tamamla)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => onStatusChanged(KitchenStatus.ready),
                style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Hazırlandı'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}