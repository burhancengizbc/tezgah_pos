import '../../data/collections/business_collections.dart';

/// Isletme profili + uygulama ayarlari erisimi.
abstract interface class SettingsRepository {
  Future<BusinessProfile> getProfile();
  Future<void> saveProfile(BusinessProfile profile);

  Future<AppSettings> getSettings();
  Future<void> saveSettings(AppSettings settings);
  Stream<AppSettings> watchSettings();
}
