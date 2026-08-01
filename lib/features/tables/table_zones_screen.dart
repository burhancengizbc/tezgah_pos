import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/collections/people_collections.dart';

class TableZonesScreen extends ConsumerStatefulWidget {
  const TableZonesScreen({super.key});

  @override
  ConsumerState<TableZonesScreen> createState() => _TableZonesScreenState();
}

class _TableZonesScreenState extends ConsumerState<TableZonesScreen> {
  String _selectedZone = 'Tümü';
  final List<String> _zones = ['Tümü', 'Ana Salon', 'Bahçe', 'Teras', 'VIP'];

  Future<void> _assignZoneDialog(DiningTable table) async {
    String currentZone = table.zoneName;

    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${table.name} - Salon / Kat Değiştir'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _zones.where((z) => z != 'Tümü').map((z) => RadioListTile<String>(
            title: Text(z),
            value: z,
            groupValue: currentZone,
            onChanged: (val) => Navigator.pop(ctx, val),
          )).toList(),
        ),
      ),
    );

    if (selected != null && selected != table.zoneName) {
      final isar = ref.read(isarProvider);
      await isar.writeTxn(() async {
        table.zoneName = selected;
        table.updatedAt = DateTime.now();
        await isar.diningTables.put(table);
      });
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isar = ref.watch(isarProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Salon ve Kat Yönetimi'),
      ),
      body: Column(
        children: [
          // Kategori / Salon Filtre Butonları
          SizedBox(
            height: 60,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
              children: _zones.map((zone) {
                final isSelected = _selectedZone == zone;
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(
                    label: Text(zone),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedZone = zone),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),

          // Masalar Listesi
          Expanded(
            child: FutureBuilder<List<DiningTable>>(
              future: isar.diningTables.filter().isDeletedEqualTo(false).findAll(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allTables = snapshot.data ?? [];
                final filteredTables = _selectedZone == 'Tümü' 
                    ? allTables 
                    : allTables.where((t) => t.zoneName == _selectedZone).toList();

                if (filteredTables.isEmpty) {
                  return Center(
                    child: Text('"${_selectedZone}" kategorisinde kayıtlı masa bulunmuyor.', 
                        style: const TextStyle(color: AppColors.dTextDim)),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: AppSpacing.md,
                    crossAxisSpacing: AppSpacing.md,
                    childAspectRatio: 1.3,
                  ),
                  itemCount: filteredTables.length,
                  itemBuilder: (context, index) {
                    final t = filteredTables[index];
                    return InkWell(
                      onTap: () => _assignZoneDialog(t),
                      borderRadius: BorderRadius.circular(AppSpacing.rMd),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppSpacing.rMd),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(t.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            Chip(
                              label: Text(t.zoneName, style: const TextStyle(fontSize: 10)),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}