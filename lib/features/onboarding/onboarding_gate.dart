import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/data_streams.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/providers/core_providers.dart';
import '../../core/services/seed_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Ilk acilis: kurulum tamamlanmadiysa sihirbazi gosterir.
class OnboardingGate extends ConsumerWidget {
  final Widget child;
  const OnboardingGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsStreamProvider);
    return settings.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => child,
      data: (s) => s.onboardingDone ? child : const OnboardingScreen(),
    );
  }
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  bool _withSeed = true;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    setState(() => _busy = true);
    final settingsRepo = ref.read(settingsRepositoryProvider);

    final profile = await settingsRepo.getProfile();
    profile
      ..name = _name.text.trim()
      ..phone = _phone.text.trim()
      ..address = _address.text.trim();
    await settingsRepo.saveProfile(profile);

    if (_withSeed) {
      await SeedService(ref.read(isarProvider)).run();
    }

    final s = await settingsRepo.getSettings();
    s.onboardingDone = true;
    await settingsRepo.saveSettings(s);
    // settingsStream guncellenince OnboardingGate child'a gecer.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.amber,
                        borderRadius: BorderRadius.circular(AppSpacing.rLg),
                      ),
                      child: const Icon(Icons.storefront_rounded,
                          color: Color(0xFF1A1300), size: 38),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Tezgah POS\'a Hos Geldiniz',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Baslamak icin isletme bilgilerinizi girin. '
                    'Bu bilgileri sonra Ayarlar\'dan degistirebilirsiniz.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Isletme adi',
                      prefixIcon: Icon(Icons.store_rounded),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Telefon (istege bagli)',
                      prefixIcon: Icon(Icons.phone_rounded),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _address,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Adres (istege bagli)',
                      prefixIcon: Icon(Icons.place_rounded),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Ornek veriyle basla'),
                    subtitle: const Text(
                        'Deneme icin ornek kategori, urun ve masalar olusturur.'),
                    value: _withSeed,
                    onChanged: (v) => setState(() => _withSeed = v),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton.icon(
                    onPressed: _busy ? null : _finish,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.arrow_forward_rounded),
                    label: Text(_busy ? 'Hazirlaniyor...' : 'Basla'),
                    style:
                        FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
