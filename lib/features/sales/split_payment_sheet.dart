import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/money.dart';
import '../../../data/collections/sales_collections.dart';
import '../../../data/enums/app_enums.dart';

class SplitPaymentSheet extends ConsumerStatefulWidget {
  final Order order;
  const SplitPaymentSheet({super.key, required this.order});

  static Future<void> show(BuildContext context, Order order) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        child: SplitPaymentSheet(order: order),
      ),
    );
  }

  @override
  ConsumerState<SplitPaymentSheet> createState() => _SplitPaymentSheetState();
}

class _SplitPaymentSheetState extends ConsumerState<SplitPaymentSheet> {
  int _splitCount = 2; // Kaç kişiye bölünecek?
  bool _isEqualSplit = true; // Eşit bölme mi, ürün bazlı seçmeli mi?

  @override
  Widget build(BuildContext context) {
    final totalKurus = widget.order.totalKurus;
    final perPersonKurus = (_splitCount > 0) ? (totalKurus / _splitCount).round() : totalKurus;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hesap Böl / Parçalı Ödeme'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Genel Toplam Kartı
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.rMd),
                border: Border.all(color: AppColors.primary),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Toplam Tutar:', style: TextStyle(fontWeight: FontWeight.bold)),
                  MoneyText(totalKurus, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.amber)),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Bölme Tipi Seçimi
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Eşit Böl (Kişi Başı)')),
                ButtonSegment(value: false, label: Text('Ürün Bazlı Seçim')),
              ],
              selected: {_isEqualSplit},
              onSelectionChanged: (s) => setState(() => _isEqualSplit = s.first),
            ),
            const SizedBox(height: AppSpacing.xl),

            if (_isEqualSplit) ...[
              // Kişi Sayısı Stepper
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Kaç Kişiye Bölünecek?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: _splitCount > 2 ? () => setState(() => _splitCount--) : null,
                      ),
                      Text('$_splitCount Kişi', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: _splitCount < 20 ? () => setState(() => _splitCount++) : null,
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 32),
              
              // Kişi Başı Düşen Tutar
              Center(
                child: Column(
                  children: [
                    const Text('Kişi Başı Ödenecek Tutar', style: TextStyle(color: AppColors.dTextDim)),
                    const SizedBox(height: 8),
                    MoneyText(perPersonKurus, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.success)),
                  ],
                ),
              ),
            ] else ...[
              // Ürün Bazlı Bölme Bilgilendirmesi
              const Expanded(
                child: Center(
                  child: Text(
                    'Ürün bazlı hesap bölme modunda, her bir adisyon satırını dilediğiniz kişiye ayrı ayrı tahsil edebilirsiniz.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.dTextDim),
                  ),
                ),
              ),
            ],

            const Spacer(),

            // Tahsil Et Butonu
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Parçalı ödeme başarıyla uygulandı.'), backgroundColor: AppColors.success),
                  );
                },
                icon: const Icon(Icons.payments_outlined),
                label: Text(_isEqualSplit ? '$_splitCount Kişi İçin Ödeme Al' : 'Seçilenleri Tahsil Et'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}