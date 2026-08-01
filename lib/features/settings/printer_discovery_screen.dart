import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

class PrinterDevice {
  final String name;
  final String address; // Bluetooth MAC veya IP adresi
  final PrinterConnectionType type;

  PrinterDevice({
    required this.name,
    required this.address,
    required this.type,
  });
}

enum PrinterConnectionType { bluetooth, network }

class PrinterDiscoveryScreen extends ConsumerStatefulWidget {
  final String targetSettingKey; // 'printerMac' (Kasa) veya 'kitchenPrinterMac' (Mutfak)
  const PrinterDiscoveryScreen({super.key, required this.targetSettingKey});

  static Future<String?> show(BuildContext context, String targetKey) async {
    return await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => PrinterDiscoveryScreen(targetSettingKey: targetKey),
      ),
    );
  }

  @override
  ConsumerState<PrinterDiscoveryScreen> createState() => _PrinterDiscoveryScreenState();
}

class _PrinterDiscoveryScreenState extends ConsumerState<PrinterDiscoveryScreen> {
  bool _isScanning = false;
  final List<PrinterDevice> _devices = [];

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _devices.clear();
    });

    // Gerçek ortamda burada flutter_blue_plus veya ağ ping taraması çalıştırılır.
    // Simüle edilmiş örnek tarama süreci:
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() {
        _isScanning = false;
        // Örnek bulunan cihazlar listesi
        _devices.addAll([
          PrinterDevice(name: 'POS-58 Termal Yazıcı (Bluetooth)', address: '00:11:22:33:44:55', type: PrinterConnectionType.bluetooth),
          PrinterDevice(name: 'XP-80M Mutfak Yazıcısı (LAN)', address: '192.168.1.150', type: PrinterConnectionType.network),
          PrinterDevice(name: 'Bar Kiosk Yazıcısı (Bluetooth)', address: '66:55:44:33:22:11', type: PrinterConnectionType.bluetooth),
        ]);
      });
    }
  }

  Future<void> _selectDevice(PrinterDevice device) async {
    final repo = ref.read(settingsRepositoryProvider);
    final settings = await repo.getSettings();

    if (widget.targetSettingKey == 'kitchenPrinterMac') {
      settings.kitchenPrinterMac = device.address;
      settings.kitchenPrinterName = device.name;
    } else if (widget.targetSettingKey == 'barPrinterMac') {
      settings.barPrinterMac = device.address;
      settings.barPrinterName = device.name;
    } else {
      settings.printerMac = device.address;
      settings.printerName = device.name;
    }

    await repo.saveSettings(settings);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Yazıcı başarıyla bağlandı: ${device.name}')),
      );
      Navigator.pop(context, device.address);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yazıcı Otomatik Arama'),
        actions: [
          IconButton(
            tooltip: 'Yeniden Tara',
            icon: Icon(_isScanning ? Icons.hourglass_top_rounded : Icons.refresh_rounded),
            onPressed: _isScanning ? null : _startScan,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isScanning)
            const LinearProgressIndicator(color: AppColors.amber),
          
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              _isScanning 
                  ? 'Çevredeki Bluetooth ve Ağ (LAN) termal yazıcıları aranıyor...' 
                  : 'Bulunan yazıcılar listelenmiştir. Eşleştirmek istediğiniz cihaza dokunun.',
              style: const TextStyle(color: AppColors.dTextDim),
            ),
          ),

          Expanded(
            child: _devices.isEmpty && !_isScanning
                ? const Center(
                    child: Text('Hiçbir yazıcı bulunamadı. Cihazın açık ve eşleşmeye hazır olduğundan emin olun.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.dTextDim)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: _devices.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final dev = _devices[index];
                      final isBt = dev.type == PrinterConnectionType.bluetooth;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isBt ? Colors.blue.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                          child: Icon(
                            isBt ? Icons.bluetooth_rounded : Icons.wifi_rounded,
                            color: isBt ? Colors.blue : Colors.orange,
                          ),
                        ),
                        title: Text(dev.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Adres / MAC: ${dev.address}'),
                        trailing: FilledButton.tonal(
                          onPressed: () => _selectDevice(dev),
                          child: const Text('Seç ve Bağlan'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}