import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/core_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../data/collections/business_collections.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  final VoidCallback onCompleted;
  const OnboardingScreen({Key? key, required final this.onCompleted}) : super(key: key);

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _nameCtrl = TextEditingController(text: 'Esnaf İşletmem');
  
  // Modül Seçim Başlangıç Değerleri
  bool _isTableService = true;
  bool _isKitchenDisplay = true;
  bool _courierModule = false;
  bool _ledgerModule = true;
  bool _expenseTracker = true;
  bool _recipeStock = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('İşletme Kurulum Sihirbazı'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'İşletmenize Hoş Geldiniz! 🚀',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Dükkanınızın çalışma şekline göre sistemi saniyeler içinde özelleştirin.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            
            // İşletme Adı
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'İşletme Adı',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.store),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),

            const Text(
              'Modül ve Akış Tercihleri',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // 1. İşletme Tipi
            SwitchListTile(
              title: const Text('Masalı Restoran / Kafe Modu'),
              subtitle: const Text('Masa yönetimi ve garson adisyon takibi açık olsun.'),
              value: _isTableService,
              onChanged: (val) => setState(() => _isTableService = val),
            ),

            // 2. Mutfak Ekranı
            SwitchListTile(
              title: const Text('Mutfak Ekranı (KDS) / Fiş Akışı'),
              subtitle: const Text('Siparişler mutfağa veya hazırlık yazıcısına gitsin.'),
              value: _isKitchenDisplay,
              onChanged: (val) => setState(() => _isKitchenDisplay = val),
            ),

            // 3. Kurye Modülü
            SwitchListTile(
              title: const Text('Paket Servis & Kurye Takibi'),
              subtitle: const Text('Adresli paket siparişler ve kurye atama modülü aktif olsun.'),
              value: _courierModule,
              onChanged: (val) => setState(() => _courierModule = val),
            ),

            // 4. Veresiye Defteri
            SwitchListTile(
              title: const Text('Veresiye / Borç Defteri (Cari)'),
              subtitle: const Text('Müşterilerin borç/alacak takibi yapılsın.'),
              value: _ledgerModule,
              onChanged: (val) => setState(() => _ledgerModule = val),
            ),

            // 5. Gider Takibi
            SwitchListTile(
              title: const Text('Gider / Masraf Takibi'),
              subtitle: const Text('Kira, fatura, tüp gibi günlük harcamalar kaydedilsin.'),
              value: _expenseTracker,
              onChanged: (val) => setState(() => _expenseTracker = val),
            ),

            // 6. Reçete ve Stok
            SwitchListTile(
              title: const Text('Akıllı Reçete ve Stok Düşümü'),
              subtitle: const Text('Satış yaptıkça malzemeler depodan otomatik düşsün.'),
              value: _recipeStock,
              onChanged: (val) => setState(() => _recipeStock = val),
            ),

            const SizedBox(height: 32),

            // Tamamla Butonu
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
              ),
              onPressed: () async {
                final settingsRepo = ref.read(settingsRepositoryProvider);
                final settings = await settingsRepo.getSettings();

                settings.onboardingDone = true;
                settings.isTableServiceEnabled = _isTableService;
                settings.isKitchenDisplayEnabled = _isKitchenDisplay;
                settings.courierModuleEnabled = _courierModule;
                settings.ledgerModuleEnabled = _ledgerModule;
                settings.expenseTrackerEnabled = _expenseTracker;
                settings.recipeStockEnabled = _recipeStock;

                await settingsRepo.saveSettings(settings);

                widget.onCompleted();
              },
              child: const Text(
                'Sistemi Başlat ve Kurulumu Bitir',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}