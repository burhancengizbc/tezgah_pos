import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/core_providers.dart';
import '../../core/providers/data_streams.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/seed_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/ui_prefs.dart';
import '../../data/collections/business_collections.dart';
import '../backup/backup_screen.dart';
import '../caller_id/caller_id_controller.dart';
import '../lan/lan_settings_screen.dart';
import '../shared/widgets.dart';
import 'printer_settings_screen.dart';
import 'caller_bridge_screen.dart'; 
import '../shared/app_confirm_dialog.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _taxOffice = TextEditingController();
  final _taxNo = TextEditingController();
  final _footer = TextEditingController();
  BusinessProfile? _profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await ref.read(settingsRepositoryProvider).getProfile();
    setState(() {
      _profile = p;
      _name.text = p.name;
      _phone.text = p.phone;
      _address.text = p.address;
      _taxOffice.text = p.taxOffice;
      _taxNo.text = p.taxNumber;
      _footer.text = p.receiptFooter;
    });
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _phone,
      _address,
      _taxOffice,
      _taxNo,
      _footer
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final p = _profile;
    if (p == null) return;
    p
      ..name = _name.text.trim()
      ..phone = _phone.text.trim()
      ..address = _address.text.trim()
      ..taxOffice = _taxOffice.text.trim()
      ..taxNumber = _taxNo.text.trim()
      ..receiptFooter = _footer.text.trim();
    await ref.read(settingsRepositoryProvider).saveProfile(p);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Isletme bilgileri kaydedildi.')));
    }
  }

  /// Iki adimli yeni PIN olusturma.
  Future<String?> _askNewPin() {
    String? first;
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => AlertDialog(
          content: SizedBox(
            width: 320,
            child: PinPad(
              title: first == null ? 'Yeni Sifre' : 'Sifreyi Tekrar Girin',
              subtitle: first == null ? null : 'Dogrulamak icin tekrar girin',
              onSubmit: (pin) async {
                if (first == null) {
                  setM(() => first = pin);
                  return true;
                }
                if (first == pin) {
                  Navigator.pop(ctx, pin);
                  return true;
                }
                setM(() => first = null);
                return false;
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsStreamProvider).value;
    final security = ref.read(securityServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _header('Isletme Bilgileri'),
          _field(_name, 'Isletme adi'),
          _field(_phone, 'Telefon'),
          _field(_address, 'Adres'),
          _field(_taxOffice, 'Vergi dairesi'),
          _field(_taxNo, 'Vergi no'),
          _field(_footer, 'Fis alt bilgisi'),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            onPressed: _profile == null ? null : _saveProfile,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Bilgileri Kaydet'),
          ),
          const Divider(height: AppSpacing.xxl),

          // ==================================================================
          // + MODÜLER AKIŞ VE DÜKKAN TİPİ AYARLARI
          // ==================================================================
          _header('İşletme Akışı & Modüller'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Masalı Restoran / Kafe Modu'),
            subtitle: const Text('Masa yönetimi ve garson adisyon takibi aktif'),
            value: settings?.isTableServiceEnabled ?? true,
            onChanged: (v) => _setUi((s) => s.isTableServiceEnabled = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mutfak Ekranı (KDS) Akışı'),
            subtitle: const Text('Siparişlerin mutfağa veya yazıcıya yönlendirilmesi'),
            value: settings?.isKitchenDisplayEnabled ?? true,
            onChanged: (v) => _setUi((s) => s.isKitchenDisplayEnabled = v),
          ),
          if (settings?.isKitchenDisplayEnabled ?? true)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Mutfak Çalışma Senaryosu'),
              subtitle: const Text('Sipariş mutfağa düştüğünde nasıl yönetilsin?'),
              trailing: DropdownButton<String>(
                // Gelen değer bizim listemizde yoksa zorla 'both' yapıyoruz:
                value: ['print_only', 'screen_only', 'both'].contains(settings?.kitchenMode) 
                    ? settings?.kitchenMode 
                    : 'both',
                items: const [
                  DropdownMenuItem(value: 'print_only', child: Text('Sadece Fiş Çıkar')),
                  DropdownMenuItem(value: 'screen_only', child: Text('Sadece Ekran (KDS)')),
                  DropdownMenuItem(value: 'both', child: Text('Hem Fiş Hem Ekran')),
                ],
                onChanged: (v) {
                  if (v != null) _setUi((s) => s.kitchenMode = v);
                },
              ),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Paket Servis & Kurye Modülü'),
            subtitle: const Text('Adresli paketler ve kurye atama ekranı'),
            value: settings?.courierModuleEnabled ?? false,
            onChanged: (v) => _setUi((s) => s.courierModuleEnabled = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Veresiye / Borç Defteri (Cari)'),
            subtitle: const Text('Müşteri bakiye ve veresiye takibi'),
            value: settings?.ledgerModuleEnabled ?? true,
            onChanged: (v) => _setUi((s) => s.ledgerModuleEnabled = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Gider / Masraf Takibi'),
            subtitle: const Text('Kira, fatura, avans gibi işletme harcamaları'),
            value: settings?.expenseTrackerEnabled ?? true,
            onChanged: (v) => _setUi((s) => s.expenseTrackerEnabled = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Akıllı Reçete ve Stok Düşümü'),
            subtitle: const Text('Satış yapıldıkça malzemelerin depodan düşmesi'),
            value: settings?.recipeStockEnabled ?? false,
            onChanged: (v) => _setUi((s) => s.recipeStockEnabled = v),
          ),


          
          // ==================================================================
          // + YENİ NESİL İLERİ DÜZEY MODÜLLER (Patron Kontrol Paneli)
          // ==================================================================
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Yarı Mamul (Ara Ürün) Yönetimi'),
            subtitle: const Text('Sos, hamur gibi ara ürün reçetelerini etkinleştirir'),
            value: settings?.semiFinishedGoodsEnabled ?? false,
            onChanged: (v) async {
              final confirmed = await AppConfirmDialog.show(
                context,
                title: 'Modül Durumu Değiştirilsin mi?',
                message: v ? 'Yarı Mamul modülü aktif edilsin mi?' : 'Yarı Mamul modülü kapatılsın mı?',
              );
              if (confirmed == true) {
                _setUi((s) => s.semiFinishedGoodsEnabled = v);
              }
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('İstasyon Bazlı Mutfak/Bar Yönlendirme'),
            subtitle: const Text('Siparişleri ürün grubuna göre ilgili mutfak/bar ekranına ayırır'),
            value: settings?.multiStationKdsEnabled ?? false,
            onChanged: (v) async {
              final confirmed = await AppConfirmDialog.show(
                context,
                title: 'Modül Durumu Değiştirilsin mi?',
                message: v ? 'İstasyon Bazlı Mutfak modülü aktif edilsin mi?' : 'Bu modül kapatılsın mı?',
              );
              if (confirmed == true) {
                _setUi((s) => s.multiStationKdsEnabled = v);
              }
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Happy Hour & Akıllı Kampanya Motoru'),
            subtitle: const Text('Belirli saatlerde otomatik indirim ve promosyon kuralları'),
            value: settings?.smartCampaignsEnabled ?? false,
            onChanged: (v) async {
              final confirmed = await AppConfirmDialog.show(
                context,
                title: 'Modül Durumu Değiştirilsin mi?',
                message: v ? 'Kampanya motoru aktif edilsin mi?' : 'Bu modül kapatılsın mı?',
              );
              if (confirmed == true) {
                _setUi((s) => s.smartCampaignsEnabled = v);
              }
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('PDF Cari Ekstresi ve WhatsApp Paylaşımı'),
            subtitle: const Text('Veresiye dökümlerini PDF yapıp WhatsApp ile gönderme'),
            value: settings?.whatsappPdfLedgerEnabled ?? false,
            onChanged: (v) async {
              final confirmed = await AppConfirmDialog.show(
                context,
                title: 'Modül Durumu Değiştirilsin mi?',
                message: v ? 'WhatsApp/PDF cari modülü aktif edilsin mi?' : 'Bu modül kapatılsın mı?',
              );
              if (confirmed == true) {
                _setUi((s) => s.whatsappPdfLedgerEnabled = v);
              }
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Garson Cep/El Terminali Hızlı Satış Modu'),
            subtitle: const Text('Garsonların telefonlarından masada sipariş alması'),
            value: settings?.mobileHandTerminalEnabled ?? false,
            onChanged: (v) async {
              final confirmed = await AppConfirmDialog.show(
                context,
                title: 'Modül Durumu Değiştirilsin mi?',
                message: v ? 'El terminali modülü aktif edilsin mi?' : 'Bu modül kapatılsın mı?',
              );
              if (confirmed == true) {
                _setUi((s) => s.mobileHandTerminalEnabled = v);
              }
            },
          ),

          const Divider(height: AppSpacing.xxl),

          _header('Gorunum'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Karanlik tema'),
            value: settings?.darkMode ?? true,
            onChanged: (v) async {
              ref.read(themeModeProvider.notifier).state =
                  v ? ThemeMode.dark : ThemeMode.light;
              final s = await ref.read(settingsRepositoryProvider).getSettings();
              s.darkMode = v;
              await ref.read(settingsRepositoryProvider).saveSettings(s);
            },
          ),

          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final e in UiPrefs.accentLabels.entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: (settings?.uiAccent ?? 'amber') == e.key,
                    avatar: CircleAvatar(
                        backgroundColor: UiPrefs.accentColor(e.key), radius: 8),
                    onSelected: (_) => _setUi((s) => s.uiAccent = e.key),
                  ),
              ],
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Yazi & ikon boyutu'),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: SegmentedButton<double>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 0.9, label: Text('Kucuk')),
                  ButtonSegment(value: 1.0, label: Text('Normal')),
                  ButtonSegment(value: 1.15, label: Text('Buyuk')),
                  ButtonSegment(value: 1.3, label: Text('Cok Buyuk')),
                ],
                selected: {_nearestScale(settings?.uiScale ?? 1.0)},
                onSelectionChanged: (sel) => _setUi((s) => s.uiScale = sel.first),
              ),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Yogunluk (masaustu/tablet)'),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'auto', label: Text('Oto')),
                  ButtonSegment(value: 'comfortable', label: Text('Ferah')),
                  ButtonSegment(value: 'compact', label: Text('Sikisik')),
                ],
                selected: {settings?.uiDensity ?? 'auto'},
                onSelectionChanged: (sel) =>
                    _setUi((s) => s.uiDensity = sel.first),
              ),
            ),
          ),
          const Divider(height: AppSpacing.xxl),

          _header('Guvenlik'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Uygulama giris sifresi'),
            subtitle: const Text('Istege bagli. Acilista PIN sorar.'),
            value: settings?.appLockEnabled ?? false,
            onChanged: (v) async {
              if (v) {
                final pin = await _askNewPin();
                if (pin != null) await security.setAppPin(pin);
              } else {
                await security.disableAppLock();
              }
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.admin_panel_settings_outlined),
            title: const Text('Yonetici sifresi'),
            subtitle: Text((settings?.adminPinHash != null)
                ? 'Tanimli'
                : 'Tanimli degil'),
            trailing: Wrap(
              children: [
                TextButton(
                  onPressed: () async {
                    final pin = await _askNewPin();
                    if (pin != null) await security.setAdminPin(pin);
                  },
                  child: const Text('Ayarla'),
                ),
                if (settings?.adminPinHash != null)
                  TextButton(
                    onPressed: () => security.clearAdminPin(),
                    child: const Text('Kaldir'),
                  ),
              ],
            ),
          ),
          if (settings?.appLockEnabled ?? false)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Otomatik kilit'),
              subtitle: Text(
                  'Boşta ${settings?.autoLockMinutes ?? 5} dk sonra kilitle'),
              value: settings?.autoLockEnabled ?? true,
              onChanged: (v) async {
                await security.setAutoLock(
                    v, settings?.autoLockMinutes ?? 5);
              },
            ),
          const Divider(height: AppSpacing.xxl),

          _header('Gelen Arama & Sipariş (Caller ID)'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.contact_phone_rounded, color: AppColors.amber),
            title: const Text('Arayan Numara Köprüsü (Caller ID)'),
            subtitle: const Text('Telefon çaldığında Windows kasaya aktar (Sadece Android)'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CallerBridgeScreen()),
              );
            },
          ),
          const Divider(height: AppSpacing.xxl),

          _header('Stok / Fire'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Fire (zayi) modulu'),
            subtitle: const Text('Stok ekraninda fire kaydi al/kapat'),
            value: settings?.wasteModuleEnabled ?? false,
            onChanged: (v) => _setUi((s) => s.wasteModuleEnabled = v),
          ),
          if (settings?.wasteModuleEnabled ?? false)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Fireyi gidere yansit'),
              subtitle: const Text('Maliyet uzerinden otomatik gider kaydi'),
              value: settings?.wasteAsExpense ?? true,
              onChanged: (v) => _setUi((s) => s.wasteAsExpense = v),
            ),
          const Divider(height: AppSpacing.xxl),

          _header('Yerel Ag & Moduller'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.wifi_tethering_rounded),
            title: const Text('Yerel ag, Cagri & Kurye baglantisi'),
            subtitle: const Text('Sunucu, eslesme kodu, modul anahtarlari'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LanSettingsScreen()),
            ),
          ),
          const Divider(height: AppSpacing.xxl),

          _header('Yazici / Fis'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.print_rounded),
            title: const Text('Yazici ve fis ayarlari'),
            subtitle: const Text('Termal yazici, kagit boyu, fis notlari'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const PrinterSettingsScreen()),
            ),
          ),
          const Divider(height: AppSpacing.xxl),

          _header('Veri'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.backup_rounded),
            title: const Text('Yedekleme'),
            subtitle: const Text('Tum veriyi .zip olarak al / geri yukle'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BackupScreen()),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.dataset_outlined),
            title: const Text('Ornek veri ekle'),
            subtitle: const Text('Deneme icin kategori, urun ve masa olusturur.'),
            trailing: FilledButton(
              onPressed: () async {
                await SeedService(ref.read(isarProvider)).run();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ornek veri eklendi.')));
                }
              },
              child: const Text('Ekle'),
            ),
          ),
          const Divider(height: AppSpacing.xxl),

          _header('Hakkinda'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('${AppConstants.appName}'),
            subtitle: const Text('Surum ${AppConstants.appVersion}'
                ' • Tamamen yerel / offline POS'),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Future<void> _setUi(void Function(dynamic s) mutate) async {
    final repo = ref.read(settingsRepositoryProvider);
    final s = await repo.getSettings();
    mutate(s);
    await repo.saveSettings(s);
  }

  double _nearestScale(double v) {
    const opts = [0.9, 1.0, 1.15, 1.3];
    return opts.reduce((a, b) => (a - v).abs() <= (b - v).abs() ? a : b);
  }

  Widget _header(String t) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(t,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
      );

  Widget _field(TextEditingController c, String label) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: TextField(
            controller: c,
            decoration: InputDecoration(labelText: label)),
      );
}