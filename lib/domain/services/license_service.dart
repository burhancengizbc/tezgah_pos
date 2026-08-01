import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/repository_providers.dart';
import '../../data/collections/business_collections.dart';

enum LicenseStatus {
  trialActive, 
  trialWarning, 
  lifetimeActive, 
  licensedActive, 
  licensedWarning, 
  expired, 
}

class LicenseInfo {
  final LicenseStatus status;
  final int remainingDays;
  final String message;
  final bool canOperate; 
  final int maxCouriers;
  final String contactPhone;

  const LicenseInfo({
    required this.status,
    required this.remainingDays,
    required this.message,
    required this.canOperate,
    required this.maxCouriers,
    required this.contactPhone,
  });
}

final licenseServiceProvider = Provider<LicenseService>((ref) {
  return LicenseService(ref);
});

final licenseInfoProvider = FutureProvider<LicenseInfo>((ref) async {
  final service = ref.watch(licenseServiceProvider);
  return await service.checkLicense();
});

class LicenseService {
  final Ref ref;
  LicenseService(this.ref);

  Future<LicenseInfo> checkLicense() async {
    final repo = ref.read(settingsRepositoryProvider);
    final settings = await repo.getSettings();
    final now = DateTime.now();

    if (settings.trialStartDate == null && !settings.isLicensed && !settings.isLifetime) {
      settings.trialStartDate = now;
      await repo.saveSettings(settings);
    }

    final contact = settings.contactPhone;
    final maxC = settings.maxCouriers;

    if (settings.isLifetime) {
      return LicenseInfo(
        status: LicenseStatus.lifetimeActive,
        remainingDays: 99999,
        message: 'Sınırsız / Ömür Boyu Lisans Aktif',
        canOperate: true,
        maxCouriers: maxC,
        contactPhone: contact,
      );
    }

    if (settings.isLicensed && settings.licenseExpireDate != null) {
      final diff = settings.licenseExpireDate!.difference(now).inDays;
      if (diff < 0) {
        return LicenseInfo(
          status: LicenseStatus.expired,
          remainingDays: 0,
          message: 'Yıllık lisans süreniz dolmuştur. Devam etmek için lütfen iletişime geçin.',
          canOperate: false,
          maxCouriers: maxC,
          contactPhone: contact,
        );
      } else if (diff <= 15) {
        return LicenseInfo(
          status: LicenseStatus.licensedWarning,
          remainingDays: diff,
          message: 'Yıllık lisans sürenizin bitmesine $diff gün kaldı. Kesinti yaşamamak için yenileyin.',
          canOperate: true,
          maxCouriers: maxC,
          contactPhone: contact,
        );
      } else {
        return LicenseInfo(
          status: LicenseStatus.licensedActive,
          remainingDays: diff,
          message: 'Lisans Aktif ($diff gün kaldı)',
          canOperate: true,
          maxCouriers: maxC,
          contactPhone: contact,
        );
      }
    }

    final trialStart = settings.trialStartDate ?? now;
    final trialEnd = trialStart.add(const Duration(days: 15));
    final trialDiff = trialEnd.difference(now).inDays;

    if (trialDiff < 0) {
      return LicenseInfo(
        status: LicenseStatus.expired,
        remainingDays: 0,
        message: '15 günlük ücretsiz deneme süreniz dolmuştur. Kullanıma devam etmek için lisans satın alın.',
        canOperate: false,
        maxCouriers: maxC,
        contactPhone: contact,
      );
    } else if (trialDiff <= 3) {
      return LicenseInfo(
        status: LicenseStatus.trialWarning,
        remainingDays: trialDiff,
        message: 'Ücretsiz deneme sürenizin bitmesine $trialDiff gün kaldı.',
        canOperate: true,
        maxCouriers: maxC,
        contactPhone: contact,
      );
    } else {
      return LicenseInfo(
        status: LicenseStatus.trialActive,
        remainingDays: trialDiff,
        message: 'Ücretsiz Deneme ($trialDiff gün kaldı)',
        canOperate: true,
        maxCouriers: maxC,
        contactPhone: contact,
      );
    }
  }
}