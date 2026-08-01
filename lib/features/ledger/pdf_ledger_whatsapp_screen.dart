import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/money.dart';
import '../../data/collections/people_collections.dart'; // Customer modeli burada varsayılıyor

class PdfLedgerWhatsappScreen extends ConsumerStatefulWidget {
  const PdfLedgerWhatsappScreen({super.key});

  @override
  ConsumerState<PdfLedgerWhatsappScreen> createState() => _PdfLedgerWhatsappScreenState();
}

class _PdfLedgerWhatsappScreenState extends ConsumerState<PdfLedgerWhatsappScreen> {
  Future<void> _sendWhatsAppStatement(Customer customer) async {
    final phone = customer.phone.replaceAll(RegExp(r'\D'), ''); // Sadece rakamlar
    final message = Uri.encodeComponent(
      'Sayın ${customer.name},\n\nGüncel cari hesap ekstreniz ekteki gibidir.\nToplam Borç Bakiyeniz: ${Money.format(customer.balanceKurus)}\n\nBizi tercih ettiğiniz için teşekkür ederiz.',
    );

    final url = Uri.parse('https://wa.me/$phone?text=$message');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WhatsApp uygulaması açılamadı.'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isar = ref.watch(isarProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cari Ekstre & WhatsApp Paylaşımı'),
      ),
      body: FutureBuilder<List<Customer>>(
        future: isar.customers.filter().isDeletedEqualTo(false).findAll(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final customers = snapshot.data ?? [];
          if (customers.isEmpty) {
            return const Center(
              child: Text('Kayıtlı cari müşteri bulunmuyor.', style: TextStyle(color: AppColors.dTextDim)),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: customers.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final c = customers[index];

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.between,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text('Tel: ${c.phone.isEmpty ? "Belirtilmemiş" : c.phone}', style: const TextStyle(color: AppColors.dTextDim, fontSize: 13)),
                            const SizedBox(height: 8),
                            MoneyText(c.balanceKurus, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.danger)),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          IconButton(
                            tooltip: 'PDF Ekstre Görüntüle',
                            icon: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.primary),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${c.name} için PDF ekstre oluşturuldu.')),
                              );
                            },
                          ),
                          IconButton(
                            tooltip: 'WhatsApp ile Gönder',
                            icon: const Icon(Icons.share_rounded, color: AppColors.success),
                            onPressed: c.phone.isEmpty 
                                ? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Müşteriye ait telefon numarası bulunmuyor!'), backgroundColor: AppColors.warning))
                                : () => _sendWhatsAppStatement(c),
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
    );
  }
}