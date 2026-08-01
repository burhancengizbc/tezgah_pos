import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/money.dart';
import '../../data/collections/sales_collections.dart';

class ZReportScreen extends ConsumerStatefulWidget {
  const ZReportScreen({super.key});

  @override
  ConsumerState<ZReportScreen> createState() => _ZReportScreenState();
}

class _ZReportScreenState extends ConsumerState<ZReportScreen> {
  bool _loading = true;
  int _totalSalesCount = 0;
  int _totalRevenueKurus = 0;
  int _cashTotalKurus = 0;
  int _cardTotalKurus = 0;
  int _mealTotalKurus = 0;
  int _cancelledCount = 0;

  @override
  void initState() {
    super.initState();
    _calculateZReport();
  }

  Future<void> _calculateZReport() async {
    final isar = ref.read(isarProvider);
    
    // Bugün kapatılmış olan tüm siparişler
    final orders = await isar.orders
        .filter()
        .statusEqualTo(OrderStatus.closed)
        .findAll();

    int rev = 0;
    int cash = 0;
    int card = 0;
    int meal = 0;

    for (final order in orders) {
      rev += order.totalKurus;
      
      // Ödeme detaylarını çek
      final payments = await isar.payments
          .filter()
          .orderIdEqualTo(order.id)
          .findAll();

      for (final p in payments) {
        if (p.method == PaymentMethod.cash) cash += p.amountKurus;
        else if (p.method == PaymentMethod.card) card += p.amountKurus;
        else if (p.method == PaymentMethod.meal) meal += p.amountKurus;
      }
    }

    final cancelledOrders = await isar.orders
        .filter()
        .statusEqualTo(OrderStatus.cancelled)
        .findAll();

    if (mounted) {
      setState(() {
        _totalSalesCount = orders.length;
        _totalRevenueKurus = rev;
        _cashTotalKurus = cash;
        _cardTotalKurus = card;
        _mealTotalKurus = meal;
        _cancelledCount = cancelledOrders.length;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Z-Raporu (Gün Sonu Özeti)'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // Ana Ciro Kartı
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.rLg),
              border: Border.all(color: AppColors.primary, width: 2),
            ),
            child: Column(
              children: [
                const Text('TOPLAM GÜNLÜK CİRO', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.dTextDim)),
                const SizedBox(height: 8),
                MoneyText(_totalRevenueKurus, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.amber)),
                const SizedBox(height: 4),
                Text('$_totalSalesCount Adet Adisyon Kapatıldı', style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          const Text('Ödeme Türü Dağılımı', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.sm),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.payments_rounded, color: AppColors.success),
                  title: const Text('Nakit Ödemeler'),
                  trailing: MoneyText(_cashTotalKurus, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.credit_card_rounded, color: Colors.blue),
                  title: const Text('Kredi Kartı Ödemeleri'),
                  trailing: MoneyText(_cardTotalKurus, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.restaurant_rounded, color: Colors.orange),
                  title: const Text('Yemek Kartı (Ticket/Multinet vb.)'),
                  trailing: MoneyText(_mealTotalKurus, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),
          const Text('İşlem İstatistikleri', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.sm),

          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('İptal Edilen Adisyonlar'),
                  trailing: Text('$_cancelledCount Adet', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.danger)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}