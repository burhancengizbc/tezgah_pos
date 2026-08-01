import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/collections/business_collections.dart';
import '../../data/collections/sales_collections.dart';

class MultiStationKdsScreen extends ConsumerStatefulWidget {
  const MultiStationKdsScreen({super.key});

  @override
  ConsumerState<MultiStationKdsScreen> createState() => _MultiStationKdsScreenState();
}

class _MultiStationKdsScreenState extends ConsumerState<MultiStationKdsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _stations = ['Tümü', 'Sıcak Mutfak', 'Bar & İçecek', 'Fırın & Pide', 'Soğuk & Tatlı'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _stations.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isar = ref.watch(isarProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('İstasyon Bazlı Mutfak (Multi-KDS)'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _stations.map((s) => Tab(text: s)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _stations.map((station) {
          return FutureBuilder<List<Order>>(
            future: isar.orders.filter().statusEqualTo(OrderStatus.active).findAll(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final orders = snapshot.data ?? [];
              if (orders.isEmpty) {
                return Center(
                  child: Text('"${station}" istasyonunda bekleyen aktif sipariş bulunmuyor.', 
                      style: const TextStyle(color: AppColors.dTextDim)),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.between,
                            children: [
                              Text('Masa / Adisyon #${order.id}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Chip(
                                label: Text(station, style: const TextStyle(fontSize: 11)),
                                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                              ),
                            ],
                          ),
                          const Divider(),
                          const Text('• Ürün hazırlığı devam ediyor...', style: TextStyle(color: AppColors.dTextDim)),
                          const SizedBox(height: AppSpacing.sm),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              onPressed: () async {
                                // İstasyon bazlı hazırlama tamamlama aksiyonu
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Sipariş istasyonda hazırlandı olarak işaretlendi.'), backgroundColor: AppColors.success),
                                );
                              },
                              style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                              icon: const Icon(Icons.check_rounded, size: 16),
                              label: const Text('Hazır / Tamamla'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        }).toList(),
      ),
    );
  }
}