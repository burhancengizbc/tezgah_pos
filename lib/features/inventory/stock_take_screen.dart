import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/collections/catalog_collections.dart';
import '../../data/collections/business_collections.dart'; // StockTake modeli buradaysa

class StockTakeScreen extends ConsumerStatefulWidget {
  const StockTakeScreen({super.key});

  @override
  ConsumerState<StockTakeScreen> createState() => _StockTakeScreenState();
}

class _StockTakeScreenState extends ConsumerState<StockTakeScreen> {
  bool _loading = true;
  List<RawMaterial> _materials = [];

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  Future<void> _loadMaterials() async {
    final isar = ref.read(isarProvider);
    final list = await isar.rawMaterials.filter().isDeletedEqualTo(false).findAll();
    if (mounted) {
      setState(() {
        _materials = list;
        _loading = false;
      });
    }
  }

  Future<void> _startNewStockTake() async {
    final titleCtrl = TextEditingController(text: '${DateTime.now().month}. Ay Stok Sayımı');
    
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeni Sayım Başlat'),
        content: TextField(
          controller: titleCtrl,
          decoration: const InputDecoration(labelText: 'Sayım Başlığı'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Başlat')),
        ],
      ),
    );

    if (ok == true && titleCtrl.text.trim().isNotEmpty) {
      final isar = ref.read(isarProvider);
      
      final takeItems = _materials.map((m) => StockTakeItem()
        ..rawMaterialId = m.id
        ..materialName = m.name
        ..systemQty = m.stockQty
        ..physicalQty = m.stockQty // Başlangıçta sistemle aynı varsayılır
        ..unit = m.unit
      ).toList();

      final stockTake = StockTake()
        ..title = titleCtrl.text.trim()
        ..items = takeItems
        ..isCompleted = false;

      await isar.writeTxn(() async {
        await isar.stockTakes.put(stockTake);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Yeni sayım oturumu başlatıldı.'), backgroundColor: AppColors.success),
        );
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isar = ref.watch(isarProvider);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stok Sayımı ve Envanter Mutabakatı'),
        actions: [
          IconButton(
            tooltip: 'Yeni Sayım',
            icon: const Icon(Icons.playlist_add_rounded),
            onPressed: _startNewStockTake,
          ),
        ],
      ),
      body: FutureBuilder<List<StockTake>>(
        future: isar.stockTakes.filter().sortByCreatedAtDesc().findAll(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final takes = snapshot.data ?? [];

          if (takes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.dTextDim),
                  const SizedBox(height: AppSpacing.md),
                  const Text('Aktif veya geçmiş sayım kaydı bulunmuyor.', style: TextStyle(color: AppColors.dTextDim)),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton.icon(
                    onPressed: _startNewStockTake,
                    icon: const Icon(Icons.add),
                    label: const Text('İlk Sayımı Başlat'),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: takes.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final take = takes[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: take.isCompleted ? AppColors.success.withValues(alpha: 0.2) : AppColors.amber.withValues(alpha: 0.2),
                    child: Icon(
                      take.isCompleted ? Icons.check_circle_rounded : Icons.pending_rounded,
                      color: take.isCompleted ? AppColors.success : AppColors.amber,
                    ),
                  ),
                  title: Text(take.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Kalem Sayısı: ${take.items.length} • Durum: ${take.isCompleted ? "Tamamlandı" : "Devam Ediyor"}'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    // Detay ve sayım giriş ekranına yönlendirilebilir
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}