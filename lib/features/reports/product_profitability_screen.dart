import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/money.dart';
import '../../data/collections/catalog_collections.dart';

class ProductProfitabilityScreen extends ConsumerStatefulWidget {
  const ProductProfitabilityScreen({super.key});

  @override
  ConsumerState<ProductProfitabilityScreen> createState() => _ProductProfitabilityScreenState();
}

class _ProductProfitabilityScreenState extends ConsumerState<ProductProfitabilityScreen> {
  bool _loading = true;
  List<ProductWithCost> _analysisList = [];

  @override
  void initState() {
    super.initState();
    _calculateProfitability();
  }

  Future<void> _calculateProfitability() async {
    final isar = ref.read(isarProvider);
    
    // Tüm ürünleri ve hammaddeleri çek
    final products = await isar.products.filter().isDeletedEqualTo(false).findAll();
    final rawMaterials = await isar.rawMaterials.filter().isDeletedEqualTo(false).findAll();
    
    // Hammadde birim maliyetlerini haritaya çıkar (Basitçe son birim fiyat veya ortalama varsayılabilir)
    // Örnek modelimizde RawMaterial içinde birim maliyet alanı varsayıyoruz veya birim fiyat hesaplıyoruz.
    final rawMap = {for (var r in rawMaterials) r.id: r};

    final list = <ProductWithCost>[];

    for (final p in products) {
      int totalCostKurus = 0;

      // Ürünün reçetesindeki her kalemin maliyetini hesapla
      for (final item in p.recipe) {
        final rm = rawMap[item.rawMaterialId];
        if (rm != null) {
          // Örn: Hammaddenin toplam stok değerine göre veya birim maliyetine göre hesap
          // Basitçe varsayılan birim maliyet çarpanı veya birim maliyet alanı kullanabiliriz
          // Burada örnek olması için reçete miktarını baz alıyoruz
          double unitCost = 0.5; // Örnek birim hammadde maliyeti (kurş/gram veya benzeri)
          totalCostKurus += (item.quantity * unitCost).round();
        }
      }

      final salePrice = p.priceKurus;
      final profitKurus = salePrice - totalCostKurus;
      final margin = salePrice > 0 ? (profitKurus / salePrice) * 100 : 0.0;

      list.add(ProductWithCost(
        productName: p.name,
        salePriceKurus: salePrice,
        costKurus: totalCostKurus,
        profitKurus: profitKurus,
        marginPercent: margin,
      ));
    }

    if (mounted) {
      setState(() {
        _analysisList = list;
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
        title: const Text('Ürün Maliyet ve Kârlılık Analizi'),
      ),
      body: _analysisList.isEmpty
          ? const Center(
              child: Text('Analiz edilecek reçeteli ürün bulunmuyor.', style: TextStyle(color: AppColors.dTextDim)),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: _analysisList.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = _analysisList[index];
                final isProfitable = item.marginPercent > 30;

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.between,
                          children: [
                            Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Chip(
                              label: Text('%${item.marginPercent.toStringAsFixed(1)} Kâr', 
                                style: TextStyle(
                                  color: isProfitable ? AppColors.success : AppColors.warning,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              backgroundColor: (isProfitable ? AppColors.success : AppColors.warning).withValues(alpha: 0.1),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Satış Fiyatı', style: TextStyle(fontSize: 12, color: AppColors.dTextDim)),
                                MoneyText(item.salePriceKurus, style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Tahmini Maliyet', style: TextStyle(fontSize: 12, color: AppColors.dTextDim)),
                                MoneyText(item.costKurus, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.danger)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Net Kâr', style: TextStyle(fontSize: 12, color: AppColors.dTextDim)),
                                MoneyText(item.profitKurus, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class ProductWithCost {
  final String productName;
  final int salePriceKurus;
  final int costKurus;
  final int profitKurus;
  final double marginPercent;

  ProductWithCost({
    required this.productName,
    required this.salePriceKurus,
    required this.costKurus,
    required this.profitKurus,
    required this.marginPercent,
  });
}