import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/providers/core_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/money.dart';
import '../../data/collections/sales_collections.dart';

class WaiterReportSheet extends ConsumerWidget {
  const WaiterReportSheet({super.key});

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const FractionallySizedBox(
        heightFactor: 0.85,
        child: WaiterReportSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emp = ref.watch(currentEmployeeProvider);
    final isar = ref.watch(isarProvider);

    if (emp == null) {
      return const Scaffold(
        body: Center(child: Text('Oturum açmış personel bulunamadı.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${emp.fullName} - Gün Sonu Raporum'),
        automaticallyImplyLeading: false,
      ),
      body: FutureBuilder<List<Order>>(
        // Sadece bu garsonun operatorId'sine sahip siparişleri çekiyoruz
        future: isar.orders.filter().operatorIdEqualTo(emp.id).findAll(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final orders = snapshot.data ?? [];
          
          // Sadece ödemesi alınıp kapatılmış satışlar
          final closedOrders = orders.where((o) => o.isFullyPaid).toList();
          
          int totalRevenueKurus = closedOrders.fold(0, (sum, o) => sum + o.totalKurus);
          int totalOrdersCount = closedOrders.length;

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              // Özet Kartı
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      const Text('Kişisel Ciro Özetiniz', 
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _statItem('Kapatılan Masa', '$totalOrdersCount Adet'),
                          _statItem('Toplam Toplanan', Money.format(totalRevenueKurus)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text('Kapatılan Adisyonlarınız', 
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: AppSpacing.sm),
              
              if (closedOrders.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.xxl),
                  child: Center(
                    child: Text('Henüz kapatılmış satışınız bulunmuyor.',
                        style: TextStyle(color: AppColors.dTextDim)),
                  ),
                ),

              for (final o in closedOrders)
                ListTile(
                  leading: const Icon(Icons.receipt_long_outlined, color: AppColors.amber),
                  title: Text('Adisyon #${o.receiptNo}'),
                  subtitle: Text('Kapanış: ${o.closedAt ?? o.createdAt}'),
                  trailing: MoneyText(o.totalKurus, 
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.amber)),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: AppColors.dTextDim, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }
}