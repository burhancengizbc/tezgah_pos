import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/data_streams.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../shared/widgets.dart';
import 'categories_screen.dart';
import 'product_edit_screen.dart';

class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prodsAsync = ref.watch(allProductsStreamProvider);
    final catsAsync = ref.watch(allCategoriesStreamProvider);
    final names = <int, String>{
      for (final c in (catsAsync.value ?? [])) c.id: c.name,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Urunler'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CategoriesScreen()),
            ),
            icon: const Icon(Icons.category_outlined),
            label: const Text('Kategoriler'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ProductEditScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Urun Ekle'),
      ),
      body: prodsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Hata: $e')),
        data: (products) {
          if (products.isEmpty) {
            return const EmptyState(
                icon: Icons.fastfood_outlined,
                message: 'Urun ekleyin.');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.sm),
            itemCount: products.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final p = products[i];
              return ListTile(
                leading: _thumb(p.imagePath, p.name),
                title: Text(p.name),
                subtitle: Text(
                    '${names[p.categoryId] ?? '-'}${p.isActive ? '' : '  •  Pasif'}'),
                trailing: MoneyText(p.salePriceKurus,
                    style: const TextStyle(
                        color: AppColors.amber, fontWeight: FontWeight.w700)),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => ProductEditScreen(product: p)),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _thumb(String? path, String name) {
    final placeholder = CircleAvatar(
      backgroundColor: AppColors.amber.withValues(alpha: 0.2),
      child: Text(name.isNotEmpty ? name.characters.first.toUpperCase() : '?',
          style: const TextStyle(color: AppColors.amber)),
    );
    if (path == null || path.isEmpty) return placeholder;
    return CircleAvatar(
      backgroundImage: FileImage(File(path)),
      onBackgroundImageError: (_, __) {},
    );
  }
}
