import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/collections/business_collections.dart';

class CustomerFeedbackScreen extends ConsumerStatefulWidget {
  const CustomerFeedbackScreen({super.key});

  @override
  ConsumerState<CustomerFeedbackScreen> createState() => _CustomerFeedbackScreenState();
}

class _CustomerFeedbackScreenState extends ConsumerState<CustomerFeedbackScreen> {
  Future<void> _addFeedbackDialog() async {
    final nameCtrl = TextEditingController();
    final tableCtrl = TextEditingController();
    final commentCtrl = TextEditingController();
    int rating = 5;
    String category = 'Yemek Kalitesi';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Yeni Geri Bildirim / Puan Ekle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Müşteri Adı (Opsiyonel)'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: tableCtrl,
                  decoration: const InputDecoration(labelText: 'Masa Adı / No (Örn: Masa 5)'),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Değerlendirme Kategorisi'),
                  items: ['Yemek Kalitesi', 'Servis Hızı', 'Temizlik ve Hijyen', 'Genel Deneyim']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => category = v ?? 'Yemek Kalitesi'),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final star = index + 1;
                    return IconButton(
                      icon: Icon(
                        star <= rating ? Icons.star_rounded : Icons.star_border_rounded,
                        color: AppColors.amber,
                        size: 32,
                      ),
                      onPressed: () => setDialogState(() => rating = star),
                    );
                  }),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: commentCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Müşteri Yorumu / Notu'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
            FilledButton(
              onPressed: () async {
                final isar = ref.read(isarProvider);
                final feedback = CustomerFeedback()
                  ..customerName = nameCtrl.text.trim().isEmpty ? 'Misafir' : nameCtrl.text.trim()
                  ..tableName = tableCtrl.text.trim().isEmpty ? 'Bilinmiyor' : tableCtrl.text.trim()
                  ..rating = rating
                  ..category = category
                  ..comment = commentCtrl.text.trim();

                await isar.writeTxn(() async {
                  await isar.customerFeedbacks.put(feedback);
                });

                if (ctx.mounted) Navigator.pop(ctx);
                setState(() {});
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isar = ref.watch(isarProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Müşteri Memnuniyeti ve Geri Bildirimler'),
        actions: [
          IconButton(
            tooltip: 'Geri Bildirim Ekle',
            icon: const Icon(Icons.rate_review_rounded),
            onPressed: _addFeedbackDialog,
          ),
        ],
      ),
      body: FutureBuilder<List<CustomerFeedback>>(
        future: isar.customerFeedbacks.filter().sortByCreatedAtDesc().findAll(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final feedbacks = snapshot.data ?? [];
          if (feedbacks.isEmpty) {
            return const Center(
              child: Text('Henüz kaydedilmiş müşteri değerlendirmesi bulunmuyor.', 
                  style: TextStyle(color: AppColors.dTextDim)),
            );
          }

          double avgRating = feedbacks.isNotEmpty 
              ? feedbacks.fold(0, (sum, f) => sum + f.rating) / feedbacks.length 
              : 0;

          return Column(
            children: [
              // Üst Özet Kartı
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                color: Theme.of(context).colorScheme.surface,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Genel Ortalama Puan', style: TextStyle(color: AppColors.dTextDim, fontSize: 13)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(avgRating.toStringAsFixed(1), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.amber)),
                            const SizedBox(width: 8),
                            const Icon(Icons.star_rounded, color: AppColors.amber, size: 28),
                          ],
                        ),
                      ],
                    ),
                    Chip(
                      label: Text('${feedbacks.length} Değerlendirme'),
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: feedbacks.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final f = feedbacks[index];

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.between,
                              children: [
                                Text('${f.customerName} • ${f.tableName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                Row(
                                  children: List.generate(f.rating, (_) => const Icon(Icons.star_rounded, color: AppColors.amber, size: 16)),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Chip(
                              label: Text(f.category, style: const TextStyle(fontSize: 11)),
                              visualDensity: VisualDensity.compact,
                            ),
                            if (f.comment.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Text('"${f.comment}"', style: const TextStyle(fontStyle: FontStyle.italic, color: AppColors.dTextDim)),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addFeedbackDialog,
        icon: const Icon(Icons.add),
        label: const Text('Değerlendirme Ekle'),
      ),
    );
  }
}