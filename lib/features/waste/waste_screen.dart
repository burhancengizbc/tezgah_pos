import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/money.dart';
import '../../data/collections/business_collections.dart';

class WasteScreen extends ConsumerStatefulWidget {
  const WasteScreen({super.key});

  @override
  ConsumerState<WasteScreen> createState() => _WasteScreenState();
}

class _WasteScreenState extends ConsumerState<WasteScreen> {
  final List<String> _reasons = ['Son Kullanma Tarihi Geçti', 'Pişirme Hatası / Yanık', 'Saklama Koşulu Bozulması', 'Müşteri İadesi / Zayi', 'Diğer'];

  Future<void> _addWasteDialog() async {
    final nameCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    String selectedReason = _reasons.first;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Yeni Fire / Zayi Kaydı'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Malzeme / Ürün Adı (Örn: Dana Kıyma)'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: costCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Toplam Maliyet (TL)'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Miktar / Adet'),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  value: selectedReason,
                  decoration: const InputDecoration(labelText: 'Fire Nedeni'),
                  items: _reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (v) => setDialogState(() => selectedReason = v ?? _reasons.first),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final cost = Money.parse(costCtrl.text);
                final qty = double.tryParse(qtyCtrl.text) ?? 1.0;

                if (name.isEmpty || cost <= 0) return;

                final isar = ref.read(isarProvider);
                final waste = WasteLog()
                  ..itemName = name
                  ..costKurus = cost
                  ..qty = qty
                  ..reason = selectedReason;

                await isar.writeTxn(() async {
                  await isar.wasteLogs.put(waste);
                });

                if (ctx.mounted) Navigator.pop(ctx);
                setState(() {});
              },
              child: const Text('Kaydet ve Maliyete Ekle'),
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
        title: const Text('Fire ve Zayi Takip Paneli'),
        actions: [
          IconButton(
            tooltip: 'Fire Ekle',
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: _addWasteDialog,
          ),
        ],
      ),
      body: FutureBuilder<List<WasteLog>>(
        future: isar.wasteLogs.filter().sortByCreatedAtDesc().findAll(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final logs = snapshot.data ?? [];
          int totalWasteKurus = logs.fold(0, (sum, w) => sum + w.costKurus);

          return Column(
            children: [
              // Üst Özet Kartı
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                color: Theme.of(context).colorScheme.surface,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Toplam Zayi Maliyeti:', style: TextStyle(fontWeight: FontWeight.bold)),
                    MoneyText(totalWasteKurus, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.danger)),
                  ],
                ),
              ),
              const Divider(height: 1),

              Expanded(
                child: logs.isEmpty
                    ? const Center(
                        child: Text('Kayıtlı fire veya zayi bulunmuyor.', style: TextStyle(color: AppColors.dTextDim)),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: logs.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, index) {
                          final w = logs[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.danger.withValues(alpha: 0.2),
                              child: const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
                            ),
                            title: Text(w.itemName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Sebep: ${w.reason} • ${w.createdAt.day}.${w.createdAt.month}.${w.createdAt.year}'),
                            trailing: MoneyText(w.costKurus, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.danger)),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addWasteDialog,
        icon: const Icon(Icons.add),
        label: const Text('Fire Ekle'),
      ),
    );
  }
}