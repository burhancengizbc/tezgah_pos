import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/collections/business_collections.dart';

class SmartCampaignsScreen extends ConsumerStatefulWidget {
  const SmartCampaignsScreen({super.key});

  @override
  ConsumerState<SmartCampaignsScreen> createState() => _SmartCampaignsScreenState();
}

class _SmartCampaignsScreenState extends ConsumerState<SmartCampaignsScreen> {
  Future<void> _addCampaignDialog() async {
    final titleCtrl = TextEditingController(text: 'Happy Hour İndirimi');
    final discountCtrl = TextEditingController(text: '15');
    final startCtrl = TextEditingController(text: '14');
    final endCtrl = TextEditingController(text: '17');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeni Happy Hour / Kampanya Ekle'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Kampanya Adı'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: discountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'İndirim Oranı (%)'),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: startCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Başlangıç Saati (0-23)'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextField(
                      controller: endCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Bitiş Saati (0-23)'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () async {
              final title = titleCtrl.text.trim();
              final discount = double.tryParse(discountCtrl.text) ?? 0.0;
              final start = int.tryParse(startCtrl.text) ?? 0;
              final end = int.tryParse(endCtrl.text) ?? 24;

              if (title.isEmpty || discount <= 0) return;

              final isar = ref.read(isarProvider);
              final rule = CampaignRule()
                ..title = title
                ..discountPercent = discount
                ..startHour = start
                ..endHour = end
                ..isActive = true;

              await isar.writeTxn(() async {
                await isar.campaignRules.put(rule);
              });

              if (ctx.mounted) Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('Kuralı Kaydet'),
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
        title: const Text('Happy Hour & Akıllı Kampanya Motoru'),
        actions: [
          IconButton(
            tooltip: 'Kampanya Ekle',
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: _addCampaignDialog,
          ),
        ],
      ),
      body: FutureBuilder<List<CampaignRule>>(
        future: isar.campaignRules.filter().sortByCreatedAtDesc().findAll(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final rules = snapshot.data ?? [];
          if (rules.isEmpty) {
            return const Center(
              child: Text('Tanımlı kampanya veya Happy Hour kuralı bulunmuyor.', 
                  style: TextStyle(color: AppColors.dTextDim)),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: rules.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final rule = rules[index];

              return Card(
                child: SwitchListTile(
                  title: Text(rule.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Zaman Aralığı: ${rule.startHour}:00 - ${rule.endHour}:00 • İndirim: %${rule.discountPercent.toStringAsFixed(0)}'),
                  value: rule.isActive,
                  onChanged: (v) async {
                    final isarRef = ref.read(isarProvider);
                    await isarRef.writeTxn(() async {
                      rule.isActive = v;
                      await isarRef.campaignRules.put(rule);
                    });
                    setState(() {});
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCampaignDialog,
        icon: const Icon(Icons.add),
        label: const Text('Kampanya Ekle'),
      ),
    );
  }
}