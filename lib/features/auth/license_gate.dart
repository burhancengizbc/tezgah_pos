import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../domain/services/license_service.dart';

class LicenseGate extends ConsumerWidget {
  final Widget child;
  const LicenseGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final licenseAsync = ref.watch(licenseInfoProvider);

    return licenseAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => child,
      data: (info) {
        if (!info.canOperate) {
          return Scaffold(
            body: Stack(
              children: [
                IgnorePointer(
                  ignoring: true,
                  child: Opacity(opacity: 0.3, child: child),
                ),
                Center(
                  child: Card(
                    margin: const EdgeInsets.all(AppSpacing.xl),
                    color: Theme.of(context).colorScheme.surface,
                    elevation: 12,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.rLg),
                      side: const BorderSide(color: AppColors.danger, width: 2),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock_clock_rounded, color: AppColors.danger, size: 64),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'KULLANIM SÜRESİ DOLDU',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppColors.danger, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            info.message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.amber.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.phone_in_talk_rounded, color: AppColors.amber),
                                const SizedBox(width: 12),
                                Text(
                                  'İletişim: ${info.contactPhone}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final showWarning = info.status == LicenseStatus.licensedWarning || info.status == LicenseStatus.trialWarning;

        if (showWarning) {
          return Scaffold(
            body: Column(
              children: [
                Container(
                  width: double.infinity,
                  color: info.status == LicenseStatus.trialWarning ? Colors.orange : AppColors.amber,
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.black, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        info.message,
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Expanded(child: child),
              ],
            ),
          );
        }

        return child;
      },
    );
  }
}