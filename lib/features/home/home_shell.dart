import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import '../../core/providers/data_streams.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../accounting/accounting_screen.dart';
import '../cash/cash_screen.dart';
import '../catalog/products_screen.dart';
import '../courier/courier_hub_screen.dart';
import '../customers/customers_screen.dart';
import '../employees/employees_screen.dart';
import '../home/dashboard_screen.dart';
import '../kitchen/kitchen_screen.dart';
import '../reports/reports_screen.dart';
import '../platform/platform_inbox_screen.dart';
import '../sales/sales_hub_screen.dart';
import '../settings/settings_screen.dart';
import '../stock/stock_screen.dart';
import '../tables/tables_screen.dart';
import '../../core/services/caller_id_server.dart'; // <-- EKLENDİ

/// Bir ana bolum.
class _Section {
  final String label;
  final IconData icon;
  final Widget screen;
  const _Section(this.label, this.icon, this.screen);
}

/// Adaptif ana iskelet: ayarlara gore dinamik filtrelenen menu.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Uygulama açıldığında Caller ID sunucusunu arka planda başlatıyoruz
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(callerIdServerProvider).start();
    });
  }

  @override
  void dispose() {
    // Uygulama kapanırken portu serbest bırakıyoruz
    ref.read(callerIdServerProvider).stop();
    super.dispose();
  }

  // Gelen Çağrı Ekranda Şık Bir Pop-up Olarak Gösterilir
  void _showIncomingCallDialog(IncomingCall call) {
    showDialog(
      context: context,
      barrierDismissible: false, // Ekrana tıklayarak geçilmesin, personel görsün
      builder: (context) {
        final isKnown = call.customer != null;
        
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                Icons.phone_in_talk_rounded, 
                color: isKnown ? Colors.green : AppColors.amber, 
                size: 28,
              ),
              const SizedBox(width: 12),
              const Text('Gelen Çağrı', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                call.phone,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
              const SizedBox(height: 12),
              if (isKnown) ...[
                Text('👤 ${call.customer!.fullName}', style: const TextStyle(fontSize: 18, color: Colors.green)),
                if (call.customer!.address.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('📍 ${call.customer!.address}', style: const TextStyle(color: Colors.white70)),
                  ),
              ] else
                const Text('⚠️ Kayıtsız Yeni Müşteri', style: TextStyle(fontSize: 16, color: AppColors.amber)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                ref.read(incomingCallProvider.notifier).state = null; // State'i temizle
                Navigator.pop(context);
              },
              child: const Text('Kapat', style: TextStyle(color: Colors.white54)),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: isKnown ? Colors.green : AppColors.amber,
                foregroundColor: isKnown ? Colors.white : Colors.black,
              ),
              onPressed: () {
                ref.read(incomingCallProvider.notifier).state = null; // State'i temizle
                Navigator.pop(context);
                
                // Pop-up kapandıktan sonra otomatik olarak "Paket" sekmesine (index: 1) yönlendir.
                setState(() => _index = 1); 
              },
              icon: const Icon(Icons.add_shopping_cart_rounded),
              label: Text(isKnown ? 'Siparişe Git' : 'Müşteriyi Kaydet'),
            ),
          ],
        );
      },
    );
  }

  List<_Section> _getSections(WidgetRef ref) {
    final settings = ref.watch(settingsStreamProvider).value;

    // Ayarlara gore varsayilan degerler (eger ayar yuklenmediyse hepsi acik baslasin)
    final bool tableService = settings?.isTableServiceEnabled ?? true;
    final bool kitchenDisplay = settings?.isKitchenDisplayEnabled ?? true;
    final bool courierModule = settings?.courierModuleEnabled ?? false;
    final bool ledgerModule = settings?.ledgerModuleEnabled ?? true;
    final bool expenseTracker = settings?.expenseTrackerEnabled ?? true;

    final list = <_Section>[
      const _Section('Panel', Icons.dashboard_rounded, DashboardScreen()),
      const _Section('Paket', Icons.point_of_sale_rounded, SalesHubScreen()),
    ];

    // 1. Masali Sistem Aciksa Masalar Ekranini Ekle
    if (tableService) {
      list.add(const _Section('Masalar', Icons.table_restaurant_rounded, TablesScreen()));
    }

    // 2. Mutfak KDS Aciksa Mutfak Ekranini Ekle
    if (kitchenDisplay) {
      list.add(const _Section('Mutfak', Icons.soup_kitchen_rounded, KitchenScreen()));
    }

    // Standart temel ekranlar
    list.addAll([
      const _Section('Urunler', Icons.fastfood_rounded, ProductsScreen()),
      const _Section('Stok', Icons.inventory_2_rounded, StockScreen()),
      const _Section('Kasa', Icons.account_balance_wallet_rounded, CashScreen()),
      const _Section('Musteriler', Icons.people_alt_rounded, CustomersScreen()),
      const _Section('Personeller', Icons.badge_rounded, EmployeesScreen()),
    ]);

    // 3. Kurye Modulu Aciksa Kurye Ekranini Ekle
    if (courierModule) {
      list.add(const _Section('Kurye', Icons.delivery_dining_rounded, CourierHubScreen()));
    }

    list.add(const _Section('Platform', Icons.storefront_rounded, PlatformInboxScreen()));

    // 4. Muhasebe / Gider modulu aciksa Muhasebe Ekle
    if (expenseTracker || ledgerModule) {
      list.add(const _Section('Muhasebe', Icons.calculate_rounded, AccountingScreen()));
    }

    list.addAll([
      const _Section('Raporlar', Icons.insights_rounded, ReportsScreen()),
      const _Section('Ayarlar', Icons.settings_rounded, SettingsScreen()),
    ]);

    return list;
  }

  @override
  Widget build(BuildContext context) {
    // Provider'ı dinleyerek telefon çaldığı anda tetiklenmesini sağlıyoruz
    ref.listen<IncomingCall?>(incomingCallProvider, (previous, next) {
      if (next != null) {
        _showIncomingCallDialog(next);
      }
    });

    final sections = _getSections(ref);
    
    // Index sinir kontrolu (filtre degistiginde index tasma yapmasin)
    if (_index >= sections.length) {
      _index = 0;
    }

    final primaryCount = sections.length >= 4 ? 4 : sections.length;
    final wide = MediaQuery.sizeOf(context).width >= 760;
    
    final body = IndexedStack(
      index: _index,
      children: [for (final s in sections) s.screen],
    );

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: MediaQuery.sizeOf(context).width >= 1100,
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: _Brand(),
              ),
              destinations: [
                for (final s in sections)
                  NavigationRailDestination(
                    icon: Icon(s.icon),
                    label: Text(s.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    // Dar ekran: Ana sekmeler + "Daha Fazla" (Eger toplam bolum sayisi primaryCount'tan fazlaysa)
    final hasMore = sections.length > primaryCount;
    final barSelected = _index < primaryCount || !hasMore ? _index : primaryCount;

    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: barSelected > primaryCount ? primaryCount : barSelected,
        onDestinationSelected: (i) {
          if (i < primaryCount || !hasMore) {
            setState(() => _index = i);
          } else {
            _openMore(sections, primaryCount);
          }
        },
        destinations: [
          for (var i = 0; i < primaryCount; i++)
            NavigationDestination(
              icon: Icon(sections[i].icon),
              label: sections[i].label,
            ),
          if (hasMore)
            const NavigationDestination(
              icon: Icon(Icons.more_horiz_rounded),
              label: 'Daha Fazla',
            ),
        ],
      ),
    );
  }

  Future<void> _openMore(List<_Section> sections, int primaryCount) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = primaryCount; i < sections.length; i++)
                ListTile(
                  leading: Icon(sections[i].icon),
                  title: Text(sections[i].label),
                  selected: _index == i,
                  selectedColor: AppColors.amber,
                  onTap: () => Navigator.pop(c, i),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) setState(() => _index = picked);
  }
}

class _Brand extends StatelessWidget {
  const _Brand();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.amber,
            borderRadius: BorderRadius.circular(AppSpacing.rMd),
          ),
          child: const Icon(Icons.storefront_rounded, color: Color(0xFF1A1300)),
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text('Tezgah', style: TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}