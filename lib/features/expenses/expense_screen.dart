import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/money.dart';
import '../../data/collections/business_collections.dart'; // Expense modeli buradaysa

class ExpenseScreen extends ConsumerStatefulWidget {
  const ExpenseScreen({super.key});

  @override
  ConsumerState<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends ConsumerState<ExpenseScreen> {
  final List<String> _categories = ['Gıda / Malzeme', 'Faturalar', 'Personel Avans', 'Tamirat / Bakım', 'Diğer'];
  
  Future<void> _addExpenseDialog() async {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String selectedCategory = _categories.first;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Kasadan Masraf / Gider Ekle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Masraf Başlığı (Örn: Manav Ödemesi)'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Tutar (TL)'),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Kategori'),
                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setDialogState(() => selectedCategory = v ?? _categories.first),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(labelText: 'Açıklama / Not (Opsiyonel)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
            FilledButton(
              onPressed: () async {
                final title = titleCtrl.text.trim();
                final amount = Money.parse(amountCtrl.text);

                if (title.isEmpty || amount <= 0) return;

                final isar = ref.read(isarProvider);
                final expense = Expense()
                  ..title = title
                  ..amountKurus = amount
                  ..category = selectedCategory
                  ..note = noteCtrl.text.trim();

                await isar.writeTxn(() async {
                  await isar.expenses.put(expense);
                });

                if (ctx.mounted) Navigator.pop(ctx);
                setState(() {});
              },
              child: const Text('Kaydet ve Kasadan Düş'),
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
        title: const Text('Gider ve Kasa Çıkışları'),
        actions: [
          IconButton(
            tooltip: 'Masraf Ekle',
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: _addExpenseDialog,
          ),
        ],
      ),
      body: FutureBuilder<List<Expense>>(
        future: isar.expenses.filter().sortByCreatedAtDesc().findAll(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final expenses = snapshot.data ?? [];
          int totalExpenseKurus = expenses.fold(0, (sum, e) => sum + e.amountKurus);

          return Column(
            children: [
              // Üst Özet Kartı
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                color: Theme.of(context).colorScheme.surface,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Toplam Gider / Kasa Çıkışı:', style: TextStyle(fontWeight: FontWeight.bold)),
                    MoneyText(totalExpenseKurus, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.danger)),
                  ],
                ),
              ),
              const Divider(height: 1),

              Expanded(
                child: expenses.isEmpty
                    ? const Center(
                        child: Text('Henüz kaydedilmiş masraf yok.', style: TextStyle(color: AppColors.dTextDim)),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: expenses.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, index) {
                          final e = expenses[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.danger.withValues(alpha: 0.2),
                              child: const Icon(Icons.arrow_downward_rounded, color: AppColors.danger),
                            ),
                            title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${e.category} • ${e.createdAt.day}.${e.createdAt.month}.${e.createdAt.year} ${e.createdAt.hour}:${e.createdAt.minute}'),
                            trailing: MoneyText(e.amountKurus, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.danger)),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addExpenseDialog,
        icon: const Icon(Icons.add),
        label: const Text('Masraf Ekle'),
      ),
    );
  }
}