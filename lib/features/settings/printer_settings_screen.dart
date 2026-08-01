import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/repository_providers.dart';
import 'package:isar_community/isar.dart';
import '../../core/providers/core_providers.dart';
import '../../core/providers/service_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../data/collections/catalog_collections.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/collections/business_collections.dart';
import '../../domain/models/receipt_data.dart';

class PrinterSettingsScreen extends ConsumerStatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  ConsumerState<PrinterSettingsScreen> createState() =>
      _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState
    extends ConsumerState<PrinterSettingsScreen> {
  AppSettings? _s;
  List<Department> _departments = [];
  final _header = TextEditingController();
  final _footer = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _header.dispose();
    _footer.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final s = await ref.read(settingsRepositoryProvider).getSettings();
    final isar = ref.read(isarProvider);
    final deps = await isar.departments.filter().isDeletedEqualTo(false).findAll();
    
    _header.text = s.receiptHeader;
    _footer.text = s.receiptFooter;
    if (mounted) setState(() {
      _s = s;
      _departments = deps;
      _loading = false;
    });
  }

  Future<void> _addDepartment() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Yeni Departman'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Örn: Fırın, Izgara, Bar'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('İptal')),
          FilledButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: const Text('Ekle')),
        ],
      ),
    );
    
    if (name != null && name.isNotEmpty) {
      final isar = ref.read(isarProvider);
      final newDep = Department()..name = name;
      await isar.writeTxn(() async => await isar.departments.put(newDep));
      await _load();
    }
  }

  Future<void> _deleteDepartment(Department dep) async {
    final isar = ref.read(isarProvider);
    dep.isDeleted = true;
    await isar.writeTxn(() async => await isar.departments.put(dep));
    await _load();
  }

  Future<void> _persist() async {
    final s = _s!;
    s.receiptHeader = _header.text.trim();
    s.receiptFooter = _footer.text.trim();
    await ref.read(settingsRepositoryProvider).saveSettings(s);
  }

  Future<void> _pickPrinter({bool isMain = false, Department? dep}) async {
    final svc = ref.read(thermalPrinterServiceProvider);
    if (!svc.isSupported) {
      _snack('Termal yazici yalnizca Android/iOS\'ta secilebilir.');
      return;
    }
    if (!await svc.isBluetoothOn()) {
      _snack('Once Bluetooth\'u acin.');
      return;
    }
    final devices = await svc.pairedDevices();
    if (!mounted) return;
    if (devices.isEmpty) {
      _snack('Esli Bluetooth cihaz bulunamadi. Once telefondan eslestirin.');
      return;
    }
    final picked = await showModalBottomSheet<({String name, String mac})>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Text('Esli Yazicilar', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            for (final d in devices)
              ListTile(
                leading: const Icon(Icons.print_rounded),
                title: Text(d.name.isEmpty ? '(isimsiz)' : d.name),
                subtitle: Text(d.mac),
                onTap: () => Navigator.pop(c, d),
              ),
          ],
        ),
      ),
    );
    
    if (picked != null) {
      if (isMain) {
        setState(() {
          _s!..printerMac = picked.mac..printerName = picked.name;
        });
        await _persist();
      } else if (dep != null) {
        dep.printerMac = picked.mac;
        dep.printerName = picked.name;
        final isar = ref.read(isarProvider);
        await isar.writeTxn(() async => await isar.departments.put(dep));
        await _load();
      }
      _snack('Yazici secildi: ${picked.name}');
    }
  }

  Future<void> _testPrint() async {
    final s = _s!;
    if ((s.printerMac ?? '').isEmpty) {
      _snack('Once yazici secin.');
      return;
    }
    final now = DateTime.now();
    final data = ReceiptData(
      businessName: _header.text.trim().isEmpty ? 'TEZGAH POS' : _header.text.trim(),
      address: '',
      phone: '',
      taxInfo: '',
      headerNote: 'TEST FISI',
      footerNote: _footer.text.trim(),
      receiptNo: '0',
      dateTime: now,
      typeLabel: 'Test',
      operatorName: null,
      lines: const [
        ReceiptLine(
            name: 'Ornek Urun', qty: 1, unitPriceKurus: 2500, lineTotalKurus: 2500),
      ],
      subtotalKurus: 2500,
      discountKurus: 0,
      totalKurus: 2500,
      vatKurus: 227,
      payments: const [ReceiptPayment('Nakit', 2500)],
    );
    final bytes =
        await ref.read(escPosServiceProvider).build(data, paperMm: s.paperSizeMm);
    final res = await ref
        .read(thermalPrinterServiceProvider)
        .printBytes(mac: s.printerMac!, bytes: bytes);
    _snack(res.message);
  }

  void _snack(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final s = _s!;
    final supported = ref.read(thermalPrinterServiceProvider).isSupported;
    final hasPrinter = (s.printerMac ?? '').isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Yazici / Fis')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _header2('Termal Yazici'),
          if (!supported)
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                'Bu platformda Bluetooth termal yazici desteklenmiyor. '
                'Fisleri PDF olarak onizleyip yazdirabilir veya paylasabilirsiniz.',
                style: TextStyle(color: AppColors.dTextDim),
              ),
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.point_of_sale_rounded, color: AppColors.amber),
            title: Text(hasPrinter ? (s.printerName?.isNotEmpty == true ? s.printerName! : 'Kasa Yazıcısı') : 'Kasa Yazıcısı Seçilmedi'),
            subtitle: hasPrinter ? Text(s.printerMac!) : const Text('Ödeme fişleri için ana yazıcı'),
            trailing: supported ? TextButton(onPressed: () => _pickPrinter(isMain: true), child: const Text('Seç')) : null,
          ),
          
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Departman Yazıcıları', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                TextButton.icon(
                  onPressed: _addDepartment,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Departman Ekle'),
                )
              ],
            ),
          ),
          
          if (_departments.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.md),
              child: Text('Henüz bir üretim departmanı eklenmedi. (Örn: Fırın, Izgara)', style: TextStyle(color: AppColors.dTextDim, fontSize: 13)),
            ),
            
          for (final dep in _departments)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.restaurant_menu_rounded),
              title: Text((dep.printerMac?.isNotEmpty ?? false) ? '${dep.name} (${dep.printerName})' : '${dep.name} (Yazıcı Yok)'),
              subtitle: (dep.printerMac?.isNotEmpty ?? false) ? Text(dep.printerMac!) : const Text('Siparişleri buraya yönlendir'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (supported) 
                    TextButton(onPressed: () => _pickPrinter(dep: dep), child: const Text('Seç')),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                    tooltip: 'Departmanı Sil',
                    onPressed: () => _deleteDepartment(dep),
                  ),
                ],
              ),
            ),
          if (hasPrinter) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _testPrint,
                    icon: const Icon(Icons.receipt_rounded),
                    label: const Text('Test Fisi Bas'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  tooltip: 'Yaziciyi kaldir',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () async {
                    setState(() {
                      s
                        ..printerMac = null
                        ..printerName = null;
                    });
                    await _persist();
                  },
                ),
              ],
            ),
          ],
          const Divider(height: AppSpacing.xl),

          _header2('Kagit Boyu'),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 58, label: Text('58 mm')),
              ButtonSegment(value: 80, label: Text('80 mm')),
            ],
            selected: {s.paperSizeMm == 58 ? 58 : 80},
            onSelectionChanged: (sel) async {
              setState(() => s.paperSizeMm = sel.first);
              await _persist();
            },
          ),
          const Divider(height: AppSpacing.xl),

          _header2('Fis Notlari'),
          TextField(
            controller: _header,
            decoration: const InputDecoration(
                labelText: 'Ust not (bos ise isletme adi)'),
            onEditingComplete: _persist,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _footer,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Alt not (tesekkur vb.)'),
            onEditingComplete: _persist,
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () async {
                await _persist();
                _snack('Kaydedildi.');
              },
              child: const Text('Notlari Kaydet'),
            ),
          ),
          const Divider(height: AppSpacing.xl),

          _header2('Otomatik'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Odeme sonrasi fis bas'),
            subtitle: const Text(
                'Odeme alininca fis ekrani otomatik acilir.'),
            value: s.printAfterPayment,
            onChanged: (v) async {
              setState(() => s.printAfterPayment = v);
              await _persist();
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mutfaga gonderilince otomatik fis bas'),
            subtitle: const Text(
                'Siparis mutfaga iletildiginde termal yazicidan bilet cikar.'),
            value: s.kitchenMode == 'print_only' || s.kitchenMode == 'both',
            onChanged: (v) async {
              setState(() {
                if (v) {
                  s.kitchenMode = 'both';
                } else {
                  s.kitchenMode = 'screen_only';
                }
              });
              await _persist();
            },
          ),
        ],
      ),
    );
  }

  Widget _header2(String t) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(t,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
      );
}
