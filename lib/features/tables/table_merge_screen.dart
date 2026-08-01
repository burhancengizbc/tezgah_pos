import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/collections/people_collections.dart';
import '../../data/collections/sales_collections.dart';

class TableMergeScreen extends ConsumerStatefulWidget {
  const TableMergeScreen({super.key});

  @override
  ConsumerState<TableMergeScreen> createState() => _TableMergeScreenState();
}

class _TableMergeScreenState extends ConsumerState<TableMergeScreen> {
  DiningTable? _sourceTable;
  DiningTable? _targetTable;

  Future<void> _executeMerge(WidgetRef ref) async {
    if (_sourceTable == null || _targetTable == null) return;
    if (_sourceTable!.id == _targetTable!.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kaynak ve hedef masa aynı olamaz!'), backgroundColor: AppColors.danger),
      );
      return;
    }

    final isar = ref.read(isarProvider);

    await isar.writeTxn(() async {
      // Kaynak masadaki aktif siparişi bul
      if (_sourceTable!.currentOrderId != null) {
        final sourceOrder = await isar.orders.get(_sourceTable!.currentOrderId!);
        
        if (sourceOrder != null) {
          if (_targetTable!.currentOrderId != null) {
            // Hedef masada da sipariş varsa, satırları hedef siparişe taşı ve kaynak siparişi kapat
            final targetOrder = await isar.orders.get(_targetTable!.currentOrderId!);
            if (targetOrder != null) {
              // Satırları güncelle
              final lines = await isar.orderLines.filter().orderId(sourceOrder.id).findAll();
              for (final line in lines) {
                line.orderId = targetOrder.id;
                await isar.orderLines.put(line);
              }
              // Toplam tutarları güncelle
              targetOrder.subtotalKurus += sourceOrder.subtotalKurus;
              targetOrder.totalKurus += sourceOrder.totalKurus;
              await isar.orders.put(targetOrder);

              // Kaynak siparişi iptal/kapalı yap
              sourceOrder.status = OrderStatus.cancelled;
              await isar.orders.put(sourceOrder);
            }
          } else {
            // Hedef masada sipariş yoksa, kaynak siparişi doğrudan hedef masaya ata
            sourceOrder.tableId = _targetTable!.id;
            await isar.orders.put(sourceOrder);
            _targetTable!.currentOrderId = sourceOrder.id;
            _targetTable!.status = TableStatus.occupied;
          }

          // Kaynak masayı boşalt
          _sourceTable!.currentOrderId = null;
          _sourceTable!.status = TableStatus.empty;

          await isar.diningTables.put(_sourceTable!);
          await isar.diningTables.put(_targetTable!);
        }
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masalar başarıyla birleştirildi.'), backgroundColor: AppColors.success),
      );
      setState(() {
        _sourceTable = null;
        _targetTable = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isar = ref.watch(isarProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Masa Birleştirme ve Transfer'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Adisyonu Taşınacak Kaynak Masa:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.sm),
            FutureBuilder<List<DiningTable>>(
              future: isar.diningTables.filter().isDeletedEqualTo(false).findAll(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const LinearProgressIndicator();
                final tables = snapshot.data ?? [];

                return DropdownButtonFormField<DiningTable>(
                  value: _sourceTable,
                  decoration: const InputDecoration(labelText: 'Kaynak Masa Seçin'),
                  items: tables.map((t) => DropdownMenuItem(value: t, child: Text(t.name))).toList(),
                  onChanged: (v) => setState(() => _sourceTable = v),
                );
              },
            ),
            const SizedBox(height: AppSpacing.xl),

            const Text('Aktarılacağı Hedef Masa:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.sm),
            FutureBuilder<List<DiningTable>>(
              future: isar.diningTables.filter().isDeletedEqualTo(false).findAll(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final tables = snapshot.data ?? [];

                return DropdownButtonFormField<DiningTable>(
                  value: _targetTable,
                  decoration: const InputDecoration(labelText: 'Hedef Masa Seçin'),
                  items: tables.map((t) => DropdownMenuItem(value: t, child: Text(t.name))).toList(),
                  onChanged: (v) => setState(() => _targetTable = v),
                );
              },
            ),
            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: (_sourceTable != null && _targetTable != null) ? () => _executeMerge(ref) : null,
                icon: const Icon(Icons.merge_rounded),
                label: const Text('Masaları Birleştir ve Aktar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}