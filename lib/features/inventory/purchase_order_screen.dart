import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/money.dart';
import '../../data/collections/business_collections.dart';
import '../../data/collections/catalog_collections.dart';

class PurchaseOrderScreen extends ConsumerStatefulWidget {
  const PurchaseOrderScreen({super.key});

  @override
  ConsumerState<PurchaseOrderScreen> createState() => _PurchaseOrderScreenState();
}

class _PurchaseOrderScreenState extends ConsumerState<PurchaseOrderScreen> {
  Future<void> _createOrderDialog() async {
    final supplierNameCtrl = TextEditingController();
    final totalCostCtrl = TextEditingController();
    final itemDescCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeni Satın Alma Faturası'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: supplierNameCtrl,
                decoration: const InputDecoration(labelText: 'Tedarikçi Firma Adı (Örn: Metro Market)'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: totalCostCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Toplam Fatura Tutarı (TL)'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: itemDescCtrl,
                decoration: const InputDecoration(labelText: 'Alınan Ürün Özeti (Örn: 50kg Un, 10lt Yağ)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () async {
              final supplier = supplierNameCtrl.text.trim();
              final cost = Money.parse(totalCostCtrl.text);

              if (supplier.isEmpty || cost <= 0) return;

              final isar = ref.read(isarProvider);
              final order = PurchaseOrder()
                ..supplierName = supplier
                ..totalCostKurus = cost
                ..isReceived = false;

              await isar.writeTxn(() async {
                await isar.purchaseOrders.put(order);
              });

              if (ctx.mounted) Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('Siparişi Kaydet'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isar = ref.watch(isarProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tedarikçi Satın Alma & Mal Kabul'),
        actions: [
          IconButton(
            tooltip: 'Yeni Satın Alma',
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: _createOrderDialog,
          ),
        ],
      ),
      body: FutureBuilder<List<PurchaseOrder>>(
        future: isar.purchaseOrders.filter().sortByCreatedAtDesc().findAll(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = snapshot.data ?? [];
          if (orders.isEmpty) {
            return const Center(
              child: Text('Kayıtlı satın alma faturası bulunmuyor.', style: TextStyle(color: AppColors.dTextDim)),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final po = orders[index];

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.between,
                        children: [
                          Text(po.supplierName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          MoneyText(po.totalKurus, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.amber)),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text('Tarih: ${po.createdAt.day}.${po.createdAt.month}.${po.createdAt.year} • Durum: ${po.isReceived ? "Teslim Alındı (Stoka Eklendi)" : "Bekliyor"}'),
                      const SizedBox(height: AppSpacing.md),
                      if (!po.isReceived)
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () async {
                              await isar.writeTxn(() async {
                                po.isReceived = true;
                                po.receivedAt = DateTime.now();
                                await isar.purchaseOrders.put(po);
                              });
                              setState(() {});
                            },
                            style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                            icon: const Icon(Icons.inventory_rounded, size: 18),
                            label: const Text('Mal Kabul Yap ve Stoklara Ekle'),
                          ),
                        )
                      else
                        const Center(
                          child: Text('Depo Stok Girişi Tamamlandı', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
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
        onPressed: _createOrderDialog,
        icon: const Icon(Icons.add),
        label: const Text('Satın Alma Ekle'),
      ),
    );
  }
}