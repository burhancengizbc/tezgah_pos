import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/money.dart';
import '../../data/collections/business_collections.dart';

class TipManagementScreen extends ConsumerStatefulWidget {
  const TipManagementScreen({super.key});

  @override
  ConsumerState<TipManagementScreen> createState() => _TipManagementScreenState();
}

class _TipManagementScreenState extends ConsumerState<TipManagementScreen> {
  Future<void> _addTipDialog() async {
    final amountCtrl = TextEditingController();
    final waiterNameCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Manuel Bahşiş Girişi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: waiterNameCtrl,
              decoration: const InputDecoration(labelText: 'Garson Adı Soyadı'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Bahşiş Tutarı (TL)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () async {
              final amount = Money.parse(amountCtrl.text);
              final name = waiterNameCtrl.text.trim();

              if (amount <= 0 || name.isEmpty) return;

              final isar = ref.read(isarProvider);
              final tip = TipRecord()
                ..employeeName = name
                ..amountKurus = amount
                ..paymentMethod = 'Nakit';

              await isar.writeTxn(() async {
                await isar.tipRecords.put(tip);
              });

              if (ctx.mounted) Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('Kaydet'),
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
        title: const Text('Bahşiş ve Performans Havuzu'),
        actions: [
          IconButton(
            tooltip: 'Bahşiş Ekle',
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: _addTipDialog,
          ),
        ],
      ),
      body: FutureBuilder<List<TipRecord>>(
        future: isar.tipRecords.filter().sortByCreatedAtDesc().findAll(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final tips = snapshot.data ?? [];
          int totalTipsKurus = tips.fold(0, (sum, t) => sum + t.amountKurus);

          return Column(
            children: [
              // Özet Kartı
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                color: Theme.of(context).colorScheme.surface,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Toplam Biriken Bahşiş:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    MoneyText(totalTipsKurus, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.success)),
                  ],
                ),
              ),
              const Divider(height: 1),

              Expanded(
                child: tips.isEmpty
                    ? const Center(
                        child: Text('Henüz kaydedilmiş bahşiş hareketi bulunmuyor.', style: TextStyle(color: AppColors.dTextDim)),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: tips.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final t = tips[index];

                          return ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Colors.amber,
                              child: Icon(Icons.card_giftcard_rounded, color: Colors.black),
                            ),
                            title: Text(t.employeeName.isEmpty ? 'Genel Havuz' : t.employeeName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Ödeme Türü: ${t.paymentMethod} • ${t.createdAt.day}.${t.createdAt.month}.${t.createdAt.year} ${t.createdAt.hour}:${t.createdAt.minute}'),
                            trailing: MoneyText(t.amountKurus, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.success)),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTipDialog,
        icon: const Icon(Icons.add),
        label: const Text('Bahşiş Ekle'),
      ),
    );
  }
}