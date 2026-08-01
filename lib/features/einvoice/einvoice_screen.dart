import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/money.dart';
import '../../data/collections/business_collections.dart';

class EInvoiceScreen extends ConsumerStatefulWidget {
  const EInvoiceScreen({super.key});

  @override
  ConsumerState<EInvoiceScreen> createState() => _EInvoiceScreenState();
}

class _EInvoiceScreenState extends ConsumerState<EInvoiceScreen> {
  Future<void> _createEInvoiceDialog() async {
    final titleCtrl = TextEditingController();
    final taxNoCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final emailCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeni e-Arşiv / e-Fatura Kes'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Alıcı Unvanı / Ad Soyad'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: taxNoCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Vergi No veya TCKN (10/11 Hane)'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'E-posta Adresi (Gönderim İçin)'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Fatura Tutarı (TL)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () async {
              final title = titleCtrl.text.trim();
              final taxNo = taxNoCtrl.text.trim();
              final amount = Money.parse(amountCtrl.text);

              if (title.isEmpty || taxNo.isEmpty || amount <= 0) return;

              final isar = ref.read(isarProvider);
              final invoice = EInvoiceRecord()
                ..targetTitle = title
                ..targetVatOrId = taxNo
                ..targetEmail = emailCtrl.text.trim()
                ..totalKurus = amount
                ..gibUuid = 'GIB-${DateTime.now().millisecondsSinceEpoch}'
                ..isSentToGib = false;

              await isar.writeTxn(() async {
                await isar.eInvoiceRecords.put(invoice);
              });

              if (ctx.mounted) Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('Taslak Oluştur'),
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
        title: const Text('GİB e-Fatura ve e-Arşiv Yönetimi'),
        actions: [
          IconButton(
            tooltip: 'Fatura Kes',
            icon: const Icon(Icons.receipt_long_rounded),
            onPressed: _createEInvoiceDialog,
          ),
        ],
      ),
      body: FutureBuilder<List<EInvoiceRecord>>(
        future: isar.eInvoiceRecords.filter().sortByCreatedAtDesc().findAll(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final invoices = snapshot.data ?? [];
          if (invoices.isEmpty) {
            return const Center(
              child: Text('Henüz kesilmiş e-fatura veya e-arşiv belgesi bulunmuyor.', 
                  style: TextStyle(color: AppColors.dTextDim)),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: invoices.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final inv = invoices[index];

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.between,
                        children: [
                          Text(inv.targetTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          MoneyText(inv.totalKurus, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.amber)),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text('VKN / TCKN: ${inv.targetVatOrId} • UUID: ${inv.gibUuid}'),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Chip(
                            label: Text(inv.isSentToGib ? 'GİB Onaylandı ve Gönderildi' : 'Taslak (Gönderilmeyi Bekliyor)'),
                            backgroundColor: (inv.isSentToGib ? AppColors.success : AppColors.amber).withValues(alpha: 0.1),
                            labelStyle: TextStyle(
                              color: inv.isSentToGib ? AppColors.success : AppColors.amber,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (!inv.isSentToGib)
                            FilledButton.icon(
                              onPressed: () async {
                                await isar.writeTxn(() async {
                                  inv.isSentToGib = true;
                                  inv.sentAt = DateTime.now();
                                  await isar.eInvoiceRecords.put(inv);
                                });
                                setState(() {});
                              },
                              style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                              icon: const Icon(Icons.send_rounded, size: 16),
                              label: const Text('GİB\'e Gönder'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createEInvoiceDialog,
        icon: const Icon(Icons.add),
        label: const Text('Yeni e-Fatura'),
      ),
    );
  }
}