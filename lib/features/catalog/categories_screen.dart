import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:isar_community/isar.dart';
import '../../core/providers/core_providers.dart';
import '../../core/providers/data_streams.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/collections/catalog_collections.dart';
import '../shared/widgets.dart';

const _swatches = <int>[
  0xFF1565C0,
  0xFFEF6C00,
  0xFFAD1457,
  0xFF2E7D32,
  0xFF6A1B9A,
  0xFF00838F,
  0xFFC62828,
  0xFF455A64,
];

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, Category? cat) async {
    final isNew = cat == null;
    final ctrl = TextEditingController(text: cat?.name ?? '');
    var color = cat?.colorValue ?? _swatches.first;
    var active = cat?.isActive ?? true;
    int? selectedDepId = cat?.departmentId;

    final isar = ref.read(isarProvider);
    final departments = await isar.departments.filter().isDeletedEqualTo(false).findAll();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => AlertDialog(
          title: Text(isNew ? 'Kategori Ekle' : 'Kategori Duzenle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Kategori adi'),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    for (final s in _swatches)
                      GestureDetector(
                        onTap: () => setM(() => color = s),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Color(s),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: color == s
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Aktif'),
                  value: active,
                  onChanged: (v) => setM(() => active = v),
                ),
                if (departments.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<int>(
                    value: selectedDepId,
                    decoration: const InputDecoration(labelText: 'Departman (Üretim Yeri)'),
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text('Yok (Ana Kasa)'),
                      ),
                      for (final d in departments)
                        DropdownMenuItem<int>(
                          value: d.id,
                          child: Text(d.name),
                        ),
                    ],
                    onChanged: (val) => setM(() => selectedDepId = val),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Vazgec')),
            FilledButton(
              onPressed: () async {
                if (ctrl.text.trim().isEmpty) return;
                final model = cat ?? Category();
                model
                  ..name = ctrl.text.trim()
                  ..colorValue = color
                  ..isActive = active
                  ..departmentId = selectedDepId;
                await ref.read(categoryRepositoryProvider).save(model);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catsAsync = ref.watch(allCategoriesStreamProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Kategoriler')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(context, ref, null),
        child: const Icon(Icons.add),
      ),
      body: catsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Hata: $e')),
        data: (cats) {
          if (cats.isEmpty) {
            return const EmptyState(
                icon: Icons.category_outlined,
                message: 'Kategori ekleyin.');
          }
          return ReorderableListView.builder(
            padding: const EdgeInsets.all(AppSpacing.sm),
            itemCount: cats.length,
            onReorder: (oldI, newI) {
              final ids = cats.map((e) => e.id).toList();
              if (newI > oldI) newI -= 1;
              final id = ids.removeAt(oldI);
              ids.insert(newI, id);
              ref.read(categoryRepositoryProvider).reorder(ids);
            },
            itemBuilder: (_, i) {
              final c = cats[i];
              return Card(
                key: ValueKey(c.id),
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: Color(c.colorValue)),
                  title: Text(c.name),
                  subtitle: c.isActive ? null : const Text('Pasif'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _edit(context, ref, c),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => ref
                            .read(categoryRepositoryProvider)
                            .softDelete(c.id),
                      ),
                      const Icon(Icons.drag_handle),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
