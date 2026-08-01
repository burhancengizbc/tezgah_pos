import 'package:isar_community/isar.dart';

import '../../core/constants/app_constants.dart';
import '../../data/collections/business_collections.dart';
import '../../domain/repositories/settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final Isar isar;
  SettingsRepositoryImpl(this.isar);

  @override
  Future<BusinessProfile> getProfile() async {
    final existing = await isar.collection<BusinessProfile>().get(
          AppConstants.businessProfileId,
        );
    if (existing != null) return existing;
    final p = BusinessProfile()..id = AppConstants.businessProfileId;
    await isar.writeTxn(() => isar.collection<BusinessProfile>().put(p));
    return p;
  }

  @override
  Future<void> saveProfile(BusinessProfile profile) async {
    profile.updatedAt = DateTime.now();
    await isar.writeTxn(() => isar.collection<BusinessProfile>().put(profile));
  }

  @override
  Future<AppSettings> getSettings() async {
    final existing =
        await isar.collection<AppSettings>().get(AppConstants.appSettingsId);
    if (existing != null) return existing;
    final s = AppSettings()..id = AppConstants.appSettingsId;
    await isar.writeTxn(() => isar.collection<AppSettings>().put(s));
    return s;
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    settings.updatedAt = DateTime.now();
    await isar.writeTxn(() => isar.collection<AppSettings>().put(settings));
  }

  @override
  Stream<AppSettings> watchSettings() {
    return isar
        .collection<AppSettings>()
        .watchObject(AppConstants.appSettingsId, fireImmediately: true)
        .map((e) => e ?? (AppSettings()..id = AppConstants.appSettingsId));
  }
}