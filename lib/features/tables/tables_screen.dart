import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/data_streams.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/collections/people_collections.dart';
import '../../data/enums/app_enums.dart';
import '../shared/widgets.dart';
import '../sales/sales_screen.dart';

class TablesScreen extends ConsumerWidget {
  const TablesScreen({super.key});

  Color _statusColor(TableStatus s) => switch (s) {
        TableStatus.empty => AppColors.tableEmpty,
        TableStatus.occupied => AppColors.tableOccupied,
        TableStatus.awaitingPayment => AppColors.tableAwaiting,
      };

  String _statusLabel(TableStatus s) => switch (s) {
        TableStatus.empty => 'Bos',
        TableStatus.occupied => 'Dolu',
        TableStatus.awaitingPayment => 'Hesap',
      };

  Future<void> _open(BuildContext context, WidgetRef ref, DiningTable t) async {
    if (t.status != TableStatus.empty && t.currentOrderId != null) {
      final action = await showDialog<String>(
        context: context,
        builder: (c) => SimpleDialog(
          title: Text('${t.name} Operasyonları'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, 'open'),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.edit_note_rounded, color: AppColors.amber),
                    SizedBox(width: 12),
                    Text('Adisyonu Aç / Sipariş Ekle', style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, 'transfer'),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.swap_horiz_rounded, color: Colors.blueAccent),
                    SizedBox(width: 12),
                    Text('Masayı Taşı (Transfer)', style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, 'merge'),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.call_merge_rounded, color: Colors.orangeAccent),
                    SizedBox(width: 12),
                    Text('Masayı Başka Masayla Birleştir', style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

      if (action == 'transfer') {
        if (context.mounted) await _showTransferDialog(context, ref, t);
        return;
      } else if (action == 'merge') {
        if (context.mounted) await _showMergeDialog(context, ref, t);
        return;
      } else if (action != 'open') {
        return;
      }
    }

    final orderRepo = ref.read(orderRepositoryProvider);
    final tableRepo = ref.read(tableRepositoryProvider);

    int orderId;
    if (t.status == TableStatus.empty || t.currentOrderId == null) {
      final order =
          await orderRepo.openOrder(type: OrderType.table, tableId: t.id);
      await tableRepo.setStatus(t.id, TableStatus.occupied,
          currentOrderId: order.id);
      orderId = order.id;
    } else {
      orderId = t.currentOrderId!;
    }
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SalesScreen(orderId: orderId)),
    );
  }

  Future<void> _showTransferDialog(BuildContext context, WidgetRef ref, DiningTable fromTable) async {
    final allTables = await ref.read(tableRepositoryProvider).getAll();
    final emptyTables = allTables.where((t) => t.status == TableStatus.empty && t.id != fromTable.id).toList();

    if (!context.mounted) return;
    if (emptyTables.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Taşıma yapmak için boş masa bulunmuyor.')),
      );
      return;
    }

    final targetTable = await showDialog<DiningTable>(
      context: context,
      builder: (c) => SimpleDialog(
        title: Text('${fromTable.name} -> Hangi Masaya Taşınsın?'),
        children: [
          for (final t in emptyTables)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, t),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(t.name, style: const TextStyle(fontSize: 16)),
              ),
            ),
        ],
      ),
    );

    if (targetTable != null) {
      await ref.read(orderRepositoryProvider).transferTable(
            fromTableId: fromTable.id,
            toTableId: targetTable.id,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${fromTable.name} başarıyla ${targetTable.name} masasına taşındı.')),
        );
      }
    }
  }

  Future<void> _showMergeDialog(BuildContext context, WidgetRef ref, DiningTable fromTable) async {
    final allTables = await ref.read(tableRepositoryProvider).getAll();
    final occupiedTables = allTables.where((t) => t.status != TableStatus.empty && t.id != fromTable.id).toList();

    if (!context.mounted) return;
    if (occupiedTables.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Birleştirme yapmak için başka dolu masa bulunmuyor.')),
      );
      return;
    }

    final targetTable = await showDialog<DiningTable>(
      context: context,
      builder: (c) => SimpleDialog(
        title: Text('${fromTable.name} -> Hangi Masayla Birleşsin?'),
        children: [
          for (final t in occupiedTables)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, t),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('${t.name} (Dolu)', style: const TextStyle(fontSize: 16)),
              ),
            ),
        ],
      ),
    );

    if (targetTable != null) {
      await ref.read(orderRepositoryProvider).mergeTables(
            fromTableId: fromTable.id,
            targetTableId: targetTable.id,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${fromTable.name} hesabı ${targetTable.name} ile birleştirildi.')),
        );
      }
    }
  }

  Future<void> _addTable(WidgetRef ref) async {
    final repo = ref.read(tableRepositoryProvider);
    final all = await repo.getAll();
    final next = all.length + 1;
    await repo.save(DiningTable()
      ..name = 'Masa $next'
      ..sortOrder = next
      ..colorValue = 0xFF455A64);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tablesAsync = ref.watch(tablesStreamProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Masalar'),
        actions: [
          IconButton(
            onPressed: () => _addTable(ref),
            icon: const Icon(Icons.add),
            tooltip: 'Masa ekle',
          ),
        ],
      ),
      body: tablesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Hata: $e')),
        data: (tables) {
          if (tables.isEmpty) {
            return EmptyState(
              icon: Icons.table_restaurant_outlined,
              message: 'Henuz masa yok.',
              action: FilledButton.icon(
                onPressed: () => _addTable(ref),
                icon: const Icon(Icons.add),
                label: const Text('Masa ekle'),
              ),
            );
          }
          return LayoutBuilder(builder: (ctx, c) {
            final cols = (c.maxWidth / 160).floor().clamp(2, 8);
            return GridView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisSpacing: AppSpacing.md,
                crossAxisSpacing: AppSpacing.md,
                childAspectRatio: 1,
              ),
              itemCount: tables.length,
              itemBuilder: (_, i) {
                final t = tables[i];
                final color = _statusColor(t.status);
                return InkWell(
                  borderRadius: BorderRadius.circular(AppSpacing.rLg),
                  onTap: () => _open(context, ref, t),
                  child: Container(
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(AppSpacing.rLg),
                      border: Border.all(color: color, width: 2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.table_restaurant_rounded,
                            color: color, size: 30),
                        const SizedBox(height: AppSpacing.sm),
                        Text(t.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(_statusLabel(t.status),
                            style: TextStyle(fontSize: 12, color: color)),
                      ],
                    ),
                  ),
                );
              },
            );
          });
        },
      ),
    );
  }
}
