import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/money.dart';
import '../../data/collections/catalog_collections.dart';
import '../../data/collections/people_collections.dart';
import '../../data/collections/sales_collections.dart';

class MobileHandTerminalScreen extends ConsumerStatefulWidget {
  const MobileHandTerminalScreen({super.key});

  @override
  ConsumerState<MobileHandTerminalScreen> createState() => _MobileHandTerminalScreenState();
}

class _MobileHandTerminalScreenState extends ConsumerState<MobileHandTerminalScreen> {
  DiningTable? _selectedTable;
  List<Product> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final isar = ref.read(isarProvider);
    final products = await isar.products.filter().isDeletedEqualTo(false).findAll();
    if (mounted) {
      setState(() {
        _products = products;
        _loading = false;
      });
    }
  }

  Future<void> _quickAddProduct(Product product) async {
    if (_selectedTable == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen önce işlem yapılacak masayı seçin!'), backgroundColor: AppColors.warning),
      );
      return;
    }

    final isar = ref.read(isarProvider);

    await isar.writeTxn(() async {
      // Masanın aktif siparişi var mı kontrol et
      Order? order;
      if (_selectedTable!.currentOrderId != null) {
        order = await isar.orders.get(_selectedTable!.currentOrderId!);
      }

      if (order == null) {
        // Yeni adisyon aç
        order = Order()
          ..tableId = _selectedTable!.id
          ..tableName = _selectedTable!.name
          ..status = OrderStatus.active;
        await isar.orders.put(order);

        _selectedTable!.currentOrderId = order.id;
        _selectedTable!.status = TableStatus.occupied;
        await isar.diningTables.put(_selectedTable!);
      }

      // Sipariş satırı ekle
      final line = OrderLine()
        ..orderId = order.id
        ..productId = product.id
        ..productName = product.name
        ..quantity = 1
        ..unitPriceKurus = product.priceKurus
        ..totalKurus = product.priceKurus;

      await isar.orderLines.put(line);

      // Toplam tutarları güncelle
      order.subtotalKurus += product.priceKurus;
      order.totalKurus += product.priceKurus;
      await isar.orders.put(order);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${product.name} masaya eklendi.'), backgroundColor: AppColors.success, duration: const Duration(milliseconds: 800)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isar = ref.watch(isarProvider);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Garson El Terminali (Mobil POS)'),
      ),
      body: Column(
        children: [
          // 1. Masa Seçim Alanı
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            color: Theme.of(context).colorScheme.surface,
            child: FutureBuilder<List<DiningTable>>(
              future: isar.diningTables.filter().isDeletedEqualTo(false).findAll(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const LinearProgressIndicator();
                final tables = snapshot.data ?? [];

                return DropdownButtonFormField<DiningTable>(
                  value: _selectedTable,
                  decoration: const InputDecoration(labelText: 'İşlem Yapılacak Masa'),
                  items: tables.map((t) => DropdownMenuItem(value: t, child: Text('${t.name} (${t.zoneName})'))).toList(),
                  onChanged: (v) => setState(() => _selectedTable = v),
                );
              },
            ),
          ),
          const Divider(height: 1),

          // 2. Ürün Hızlı Seçim Izgarası
          Expanded(
            child: _selectedTable == null
                ? const Center(
                    child: Text('Lütfen sipariş girmek için önce yukarıdan bir masa seçin.', 
                        style: TextStyle(color: AppColors.dTextDim), textAlign: TextAlign.center),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: AppSpacing.md,
                      crossAxisSpacing: AppSpacing.md,
                      childAspectRatio: 1.4,
                    ),
                    itemCount: _products.length,
                    itemBuilder: (context, index) {
                      final p = _products[index];
                      return InkWell(
                        onTap: () => _quickAddProduct(p),
                        borderRadius: BorderRadius.circular(AppSpacing.rMd),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppSpacing.rMd),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 2, overflow: TextOverflow.ellipsis),
                              MoneyText(p.priceKurus, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.amber)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}