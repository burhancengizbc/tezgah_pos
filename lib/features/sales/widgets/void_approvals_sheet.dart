import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/money.dart';
import '../../../data/collections/sales_collections.dart';
import '../../../data/collections/people_collections.dart';

class VoidApprovalsSheet extends ConsumerWidget {
  const VoidApprovalsSheet({super.key});

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const FractionallySizedBox(
        heightFactor: 0.75,
        child: VoidApprovalsSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isar = ref.watch(isarProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('İptal Onay Bekleyenler'),
        automaticallyImplyLeading: false,
      ),
      body: FutureBuilder<List<OrderLine>>(
        future: isar.orderLines.filter().isVoidPendingEqualTo(true).findAll(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const Center(
              child: Text('Onay bekleyen iptal talebi yok.',
                  style: TextStyle(color: AppColors.dTextDim)),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final line = items[index];
              return FutureBuilder<Employee?>(
                future: line.voidRequestedById != null
                    ? isar.employees.get(line.voidRequestedById!)
                    : Future.value(null),
                builder: (context, empSnapshot) {
                  final waiterName = empSnapshot.data?.fullName ?? 'Bilinmeyen Garson';

                  return ListTile(
                    title: Text(line.productName,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                        'İsteyen: $waiterName • Adet: ${line.qty} • Tutar: ${Money.format(line.lineTotalKurus)}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // REDDET (İptal talebini düşür, ürünü sepete geri döndür)
                        OutlinedButton(
                          onPressed: () async {
                            await isar.writeTxn(() async {
                              line.isVoidPending = false;
                              line.voidRequestedById = null;
                              await isar.orderLines.put(line);
                            });
                            (context as Element).markNeedsBuild();
                          },
                          style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.danger),
                          child: const Text('Reddet'),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        // ONAYLA (Ürünü tamamen sil/isVoid yap)
                        FilledButton(
                          onPressed: () async {
                            await isar.writeTxn(() async {
                              line.isVoidPending = false;
                              line.isVoid = true; // Gerçekten iptal edildi
                              await isar.orderLines.put(line);
                            });
                            (context as Element).markNeedsBuild();
                          },
                          style: FilledButton.styleFrom(
                              backgroundColor: AppColors.success),
                          child: const Text('Onayla'),
                        ),
                      ],
                    ),
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