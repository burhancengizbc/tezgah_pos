import 'dart:io' show Platform;

import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

/// Esli (paired) bir Bluetooth termal yaziciya bayt gonderir.
/// Yalnizca Android/iOS'ta calisir; diger platformlarda guvenli sekilde
/// devre disidir (cagiranlar PDF fise duser).
class ThermalPrinterService {
  bool get isSupported => Platform.isAndroid || Platform.isIOS;

  Future<bool> isBluetoothOn() async {
    if (!isSupported) return false;
    try {
      return await PrintBluetoothThermal.bluetoothEnabled;
    } catch (_) {
      return false;
    }
  }

  /// Esli cihazlar (ad + mac).
  Future<List<({String name, String mac})>> pairedDevices() async {
    if (!isSupported) return const [];
    try {
      final list = await PrintBluetoothThermal.pairedBluetooths;
      return [for (final b in list) (name: b.name, mac: b.macAdress)];
    } catch (_) {
      return const [];
    }
  }

  /// Bytlari yaziciya gonderir. Sonuc + mesaj doner.
  Future<({bool ok, String message})> printBytes({
    required String mac,
    required List<int> bytes,
  }) async {
    if (!isSupported) {
      return (ok: false, message: 'Termal yazici bu platformda desteklenmiyor.');
    }
    try {
      final on = await PrintBluetoothThermal.bluetoothEnabled;
      if (!on) return (ok: false, message: 'Bluetooth kapali.');

      var connected = await PrintBluetoothThermal.connectionStatus;
      if (!connected) {
        await PrintBluetoothThermal.disconnect; // Askıda kalmış eski oturumu garantili temizle
        connected =
            await PrintBluetoothThermal.connect(macPrinterAddress: mac);
      }
      if (!connected) {
        return (ok: false, message: 'Yaziciya baglanilamadi.');
      }

      final ok = await PrintBluetoothThermal.writeBytes(bytes);
      return ok
          ? (ok: true, message: 'Fis yaziciya gonderildi.')
          : (ok: false, message: 'Yazma basarisiz.');
    } catch (e) {
      return (ok: false, message: 'Hata: $e');
    }
  }

  Future<void> disconnect() async {
    if (!isSupported) return;
    try {
      await PrintBluetoothThermal.disconnect;
    } catch (_) {}
  }
}
