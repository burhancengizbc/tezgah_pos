import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/collections/sales_collections.dart';
import '../../../data/collections/people_collections.dart';
import '../../../data/enums/app_enums.dart';

class TableTransferSheet extends ConsumerStatefulWidget {
  final int sourceOrderId;
  final int? currentTableId;

  const TableTransferSheet({
    super.key,
    required this.sourceOrderId,
    required this.currentTableId,
  });

  static Future<void> show(BuildContext context, int orderId, int? tableId) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.7,
        child: TableTransferSheet(sourceOrderId: orderId, currentTableId: tableId),
      ),
    );
  }

  @override
  ConsumerState<TableTransferSheet> createState() => _TableTransferSheetState();
}

class _TableTransferSheetState extends ConsumerState<TableTransferSheet> {
  int? _selectedTargetTableId;

  Future<void> _executeTransfer(List<DiningTable> tables) async {
    if (_selectedTargetTableId == null) return;
    if (_selectedTargetTableId == widget.currentTableId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zaten aynı masadasınız!'), backgroundColor: AppColors.warning),
      );
      return;
    }

    final isar = ref.read(isarProvider);

    await isar.writeTxn(() async {
      // 1. Hedef masayı bul
      final targetTable = await isar.diningTables.get(_selectedTargetTableId!);
      if (targetTable == null) return;

      // 2. Mevcut siparişi güncelle
      final order = await isar.orders.get(widget.sourceOrderId);
      if (order == null) return;

      // Eğer hedef masada zaten açık bir sipariş varsa birleştirme yapılır, yoksa taşınır
      if (targetTable.currentOrderId != null) {
        // İki masanın adisyon satırlarını hedef siparişe aktar
        final sourceLines = await isar.orderLines.filter().orderIdEqualTo(order.id).findAll();
        for (final line in sourceLines) {
          line.orderId = targetTable.currentOrderId!;
          await isar.orderLines.put(line);
        }
        // Eski siparişi iptal/kapalı duruma getir
        order.status = OrderStatus.cancelled;
        await isar.orders.put(order);
      } else {
        // Sadece masayı değiştir
        order.tableId = targetTable.id;
        await isar.orders.put(order);

        // Hedef masayı dolu yap
        targetTable.status = TableStatus.occupied;
        targetTable.currentOrderId = order.id;
        targetTable.updatedAt = DateTime.now();
        await isar.diningTables.put(targetTable);
      }

      // 3. Eski masayı boşalt
      if (widget.currentTableId != null) {
        final oldTable = await isar.diningTables.get(widget.currentTableId!);
        if (oldTable != null) {
          oldTable.status = TableStatus.empty;
          oldTable.currentOrderId = null;
          oldTable.updatedAt = DateTime.now();
          await isar.diningTables.put(oldTable);
        }
      }
    });

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masa başarıyla aktarıldı.'), backgroundColor: AppColors.success),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isar = ref.watch(isarProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Masa Değiştir / Taşı'),
        automaticallyImplyLeading: false,
      ),
      body: FutureBuilder<List<DiningTable>>(
        future: isar.diningTables.filter().isDeletedEqualTo(false).isActiveEqualTo(true).findAll(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final tables = snapshot.data ?? [];
          // Sadece boş masaları veya hedef olabilecek masaları listele
          final availableTables = tables.where((t) => t.id != widget.currentTableId).toList();

          if (availableTables.isEmpty) {
            return const Center(child: Text('Aktarılabilecek başka boş masa yok.'));
          }

          return Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Text('Lütfen siparişi taşımak istediğiniz hedef masayı seçin:',
                    style: TextStyle(color: AppColors.dTextDim)),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: AppSpacing.md,
                    crossAxisSpacing: AppSpacing.md,
                    childAspectRatio: 1.5,
                  ),
                  itemCount: availableTables.length,
                  itemBuilder: (context, index) {
                    final t = availableTables[index];
                    final isSelected = _selectedTargetTableId == t.id;
                    final isOccupied = t.status == TableStatus.occupied;

                    return InkWell(
                      onTap: () => setState(() => _selectedTargetTableId = t.id),
                      borderRadius: BorderRadius.circular(AppSpacing.rMd),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? AppColors.amber.withValues(alpha: 0.3) 
                              : (isOccupied ? Colors.red.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1)),
                          borderRadius: BorderRadius.circular(AppSpacing.rMd),
                          border: Border.all(
                            color: isSelected ? AppColors.amber : (isOccupied ? AppColors.danger : AppColors.success),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(t.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text(isOccupied ? 'Dolu (Birleştir)' : 'Boş',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isOccupied ? AppColors.danger : AppColors.success,
                                )),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _selectedTargetTableId == null ? null : () => _executeTransfer(availableTables),
                    child: const Text('Taşıma İşlemini Tamamla'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}