import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import '../../core/providers/data_streams.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/providers/service_providers.dart';
import '../../data/collections/people_collections.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../shared/widgets.dart';
import 'license_gate.dart';

/// Uygulama acilisinda istege bagli giris sifresi kontrolu.
class LockGate extends ConsumerWidget {
  final Widget child;
  const LockGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsStreamProvider);
    final unlocked = ref.watch(appUnlockedProvider);

    return settings.when(
      loading: () => const _Splash(),
      error: (_, __) => child,
      data: (s) {
        if (!s.appLockEnabled || unlocked) return LicenseGate(child: child);
        return const LicenseGate(child: _LockScreen());
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _LockScreen extends ConsumerStatefulWidget {
  const _LockScreen();

  @override
  ConsumerState<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<_LockScreen> {
  Employee? _selectedEmp;
  bool _adminMode = false;

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(activeEmployeesProvider);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _selectedEmp != null
                      ? Color(_selectedEmp!.avatarColorValue)
                      : AppColors.amber,
                  borderRadius: BorderRadius.circular(AppSpacing.rLg),
                ),
                child: Icon(
                  _selectedEmp != null
                      ? Icons.person_rounded
                      : Icons.lock_rounded,
                  color: const Color(0xFF1A1300),
                  size: 32,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_selectedEmp == null && !_adminMode) ...[
                Text('Oturum Açın',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: AppSpacing.xs),
                const Text('Devam etmek için profilinizi seçin',
                    style: TextStyle(color: AppColors.dTextDim)),
                const SizedBox(height: AppSpacing.xl),
                employeesAsync.when(
                  loading: () => const CircularProgressIndicator(),
                  error: (e, _) => Text('Hata: $e'),
                  data: (list) => Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.md,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final emp in list)
                        ActionChip(
                          avatar: CircleAvatar(
                            backgroundColor: Color(emp.avatarColorValue),
                            child: Text(
                              emp.firstName.isNotEmpty
                                  ? emp.firstName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                  color: Color(0xFF1A1300),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12),
                            ),
                          ),
                          label: Text(emp.firstName),
                          onPressed: () => setState(() => _selectedEmp = emp),
                        ),
                      ActionChip(
                        avatar: const Icon(Icons.admin_panel_settings_rounded,
                            size: 16),
                        label: const Text('Yönetici Girişi'),
                        onPressed: () => setState(() => _adminMode = true),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                PinPad(
                  title: _adminMode
                      ? 'Yönetici Şifresi'
                      : '${_selectedEmp?.firstName} - PIN',
                  subtitle: 'Giriş yapmak için şifrenizi tuşlayın',
                  onSubmit: (pin) async {
                    if (_adminMode) {
                      final ok = await ref
                          .read(securityServiceProvider)
                          .verifyAppPin(pin);
                      if (ok) {
                        ref.read(appUnlockedProvider.notifier).state = true;
                      }
                      return ok;
                    } else if (_selectedEmp != null) {
                      final ok = await ref
                          .read(employeeRepositoryProvider)
                          .verifyPin(_selectedEmp!.id, pin);
                      if (ok) {
                        ref.read(activeEmployeeProvider.notifier).state =
                            _selectedEmp;
                        ref.read(appUnlockedProvider.notifier).state = true;
                      }
                      return ok;
                    }
                    return false;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextButton.icon(
                  onPressed: () => setState(() {
                    _selectedEmp = null;
                    _adminMode = false;
                  }),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Profil Seçimine Dön'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
