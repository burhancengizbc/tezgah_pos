/// Uygulama geneli sabitler.
class AppConstants {
  AppConstants._();

  static const String appName = 'Tezgah POS';
  static const String appVersion = '1.0.0';
  static const String dbName = 'tezgah';

  // Sayfalama (10.000+ urun / 100.000+ siparis akiciligi icin)
  static const int pageSize = 50;

  // Tekil kayit id'leri
  static const int businessProfileId = 1;
  static const int appSettingsId = 1;

  // Otomatik kilit
  static const int defaultAutoLockMinutes = 5;

  // Yedekleme
  static const String backupFilePrefix = 'tezgah_yedek_';
  static const int backupSchemaVersion = 1;
}
