import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/money.dart';
import '../../data/collections/catalog_collections.dart';

class SemiFinishedScreen extends ConsumerStatefulWidget {
  const SemiFinishedScreen({super.key});

  @override
  ConsumerState<SemiFinishedScreen> createState() => _SemiFinishedScreenState();
}

class _SemiFinishedScreenState extends ConsumerState<SemiFinishedScreen> {
  Future<void> _addSemiFinishedDialog() async {
    final nameCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: 'g');
    final qtyCtrl = TextEditingController(text: '1000');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeni Yarı Mamul (Ara Ürün) Ekle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Ara Ürün Adı (Örn: Pizza Hamuru)'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: unitCtrl,
              decoration: const InputDecoration(labelText: 'Ölçü Birimi (g, ml, adet)'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: qtyCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'İlk Üretim Miktarı'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final unit = unitCtrl.text.trim();
              final qty = double.tryParse(qtyCtrl.text) ?? 0.0;

              if (name.isEmpty) return;

              final isar = ref.read(isarProvider);
              final product = SemiFinishedProduct()
                ..name = name
                ..unit = unit
                ..stockQty = qty;

              await isar.writeTxn(() async {
                await isar.semiFinishedProducts.put(product);
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
        title: const Text('Yarı Mamul & Ara Ürün Yönetimi'),
        actions: [
          IconButton(
            tooltip: 'Yeni Ara Ürün',
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: _addSemiFinishedDialog,
          ),
        ],
      ),
      body: FutureBuilder<List<SemiFinishedProduct>>(
        future: isar.semiFinishedProducts.filter().isDeletedEqualTo(false).findAll(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final list = snapshot.data ?? [];
          if (list.isEmpty) {
            return const Center(
              child: Text('Kayıtlı yarı mamul / ara ürün bulunmuyor.\n(Ayarlardan modülün aktif olduğundan emin olun)', 
                  textAlign: TextAlign.center, style: TextStyle(color: AppColors.dTextDim)),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = list[index];

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                    child: const Icon(Icons.layers_rounded, color: AppColors.primary),
                  ),
                  title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Stok: ${item.stockQty} ${item.unit} • Reçete Kalem Sayısı: ${item.subRecipe.length}'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    // Ara ürün detay / reçete düzenleme sayfasına yönlendirilebilir
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSemiFinishedDialog,
        icon: const Icon(Icons.add),
        label: const Text('Ara Ürün Ekle'),
      ),
    );
  }
}