import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../campaigns/smart_campaigns_screen.dart';
import '../inventory/semi_finished_screen.dart';
import '../kitchen/multi_station_kds_screen.dart';
import '../ledger/pdf_ledger_whatsapp_screen.dart';
import '../terminal/mobile_hand_terminal_screen.dart';

class ExecutiveHubScreen extends ConsumerWidget {
  const ExecutiveHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modules = [
      _HubItem(
        title: 'Yarı Mamul (Ara Ürün)',
        subtitle: 'Sos, hamur ve ara reçete yönetimi',
        icon: Icons.layers_rounded,
        color: AppColors.primary,
        screen: const SemiFinishedScreen(),
      ),
      _HubItem(
        title: 'Çoklu Mutfak (Multi-KDS)',
        subtitle: 'İstasyon bazlı bar ve mutfak yönlendirme',
        icon: Icons.soup_kitchen_rounded,
        color: Colors.orange,
        screen: const MultiStationKdsScreen(),
      ),
      _HubItem(
        title: 'Happy Hour & Kampanyalar',
        subtitle: 'Otomatik indirim ve promosyon kuralları',
        icon: Icons.local_offer_rounded,
        color: Colors.purple,
        screen: const SmartCampaignsScreen(),
      ),
      _HubItem(
        title: 'WhatsApp Cari Ekstresi',
        subtitle: 'Veresiye dökümleri ve PDF paylaşımı',
        icon: Icons.share_rounded,
        color: AppColors.success,
        screen: const PdfLedgerWhatsappScreen(),
      ),
      _HubItem(
        title: 'Garson El Terminali',
        subtitle: 'Masadan hızlı mobil sipariş girişi',
        icon: Icons.phone_android_rounded,
        color: Colors.blue,
        screen: const MobileHandTerminalScreen(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yönetici Kontrol Merkezi (Executive Hub)'),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(AppSpacing.lg),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: 1.2,
        ),
        itemCount: modules.length,
        itemBuilder: (context, index) {
          final m = modules[index];
          return InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => m.screen),
            ),
            borderRadius: BorderRadius.circular(AppSpacing.rLg),
            child: Container(
              decoration: BoxDecoration(
                color: m.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.rLg),
                border: Border.all(color: m.color.withValues(alpha: 0.3)),
              ),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(
                    backgroundColor: m.color.withValues(alpha: 0.2),
                    child: Icon(m.icon, color: m.color),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text(m.subtitle, style: const TextStyle(fontSize: 11, color: AppColors.dTextDim), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HubItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget screen;

  _HubItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.screen,
  });
}