import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../../data/collections/business_collections.dart';
import '../../domain/repositories/settings_repository.dart';

/// Guvenlik servisi.
/// - Uygulamaya giris sifresi: ISTEGE BAGLI (appLockEnabled). Ayarlardan acilir/kapanir.
/// - Yonetici sifresi: korumali islemler icin.
/// Sifreler tuzlanmis (salt) SHA-256 ile saklanir; duz metin tutulmaz.
class SecurityService {
  final SettingsRepository settings;
  SecurityService(this.settings);

  String _newSalt() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    return base64Url.encode(bytes);
  }

  String _hash(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  // -------- Uygulama giris sifresi (istege bagli) --------

  Future<bool> isAppLockEnabled() async =>
      (await settings.getSettings()).appLockEnabled;

  /// Giris sifresini ayarla ve kilidi etkinlestir.
  Future<void> setAppPin(String pin) async {
    final s = await settings.getSettings();
    final salt = _newSalt();
    s
      ..appPinSalt = salt
      ..appPinHash = _hash(pin, salt)
      ..appLockEnabled = true;
    await settings.saveSettings(s);
  }

  /// Giris sifresini kaldir (kilit kapanir).
  Future<void> disableAppLock() async {
    final s = await settings.getSettings();
    s
      ..appLockEnabled = false
      ..appPinHash = null
      ..appPinSalt = null;
    await settings.saveSettings(s);
  }

  Future<bool> verifyAppPin(String pin) async {
    final s = await settings.getSettings();
    if (!s.appLockEnabled || s.appPinHash == null || s.appPinSalt == null) {
      return true; // kilit yoksa serbest
    }
    return _hash(pin, s.appPinSalt!) == s.appPinHash;
  }

  // -------- Yonetici sifresi --------

  Future<bool> hasAdminPin() async =>
      (await settings.getSettings()).adminPinHash != null;

  Future<void> setAdminPin(String pin) async {
    final s = await settings.getSettings();
    final salt = _newSalt();
    s
      ..adminPinSalt = salt
      ..adminPinHash = _hash(pin, salt);
    await settings.saveSettings(s);
  }

  Future<void> clearAdminPin() async {
    final s = await settings.getSettings();
    s
      ..adminPinHash = null
      ..adminPinSalt = null;
    await settings.saveSettings(s);
  }

  Future<bool> verifyAdminPin(String pin) async {
    final s = await settings.getSettings();
    if (s.adminPinHash == null || s.adminPinSalt == null) return true;
    return _hash(pin, s.adminPinSalt!) == s.adminPinHash;
  }

  /// Otomatik kilit ayarini guncelle.
  Future<void> setAutoLock(bool enabled, int minutes) async {
    final s = await settings.getSettings();
    s
      ..autoLockEnabled = enabled
      ..autoLockMinutes = minutes;
    await settings.saveSettings(s);
  }

  Future<AppSettings> current() => settings.getSettings();
}
