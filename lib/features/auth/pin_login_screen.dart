import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

import '../../core/providers/core_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/collections/people_collections.dart';

class PinLoginScreen extends ConsumerStatefulWidget {
  const PinLoginScreen({super.key});

  @override
  ConsumerState<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends ConsumerState<PinLoginScreen> {
  String _pin = '';
  bool _isError = false;

  void _onKeyPress(String key) async {
    // Ayarlardan titreşim açıksa ufak bir "tık" titreşimi ver
    final settings = await ref.read(settingsRepositoryProvider).getSettings();
    if (settings.enableVibration) {
      HapticFeedback.lightImpact();
    }

    if (_pin.length < 4) {
      setState(() {
        _pin += key;
        _isError = false;
      });

      if (_pin.length == 4) {
        _verifyPin();
      }
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _isError = false;
      });
    }
  }

  Future<void> _verifyPin() async {
    final isar = ref.read(isarProvider);
    // Hash'lenmiş PIN ile veritabanında personel ara (Gerçekte hash kontrolü yapılır, şimdilik direkt arıyoruz)
    final employee = await isar.employees
        .filter()
        .pinHashEqualTo(_pin)
        .isDeletedEqualTo(false)
        .isActiveEqualTo(true)
        .findFirst();

    if (employee != null) {
      // Başarılı giriş! Personeli sisteme tanıt ve ana ekrana geç
      ref.read(currentEmployeeProvider.notifier).state = employee;
      
      // Ses açıksa onay sesi çal
      final settings = await ref.read(settingsRepositoryProvider).getSettings();
      if (settings.enableSound) {
        SystemSound.play(SystemSoundType.click); 
      }
      
      // Yönlendirme (Router yapınıza göre değiştirin)
      // context.go('/dashboard'); 
    } else {
      // Hatalı şifre
      setState(() {
        _pin = '';
        _isError = true;
      });
      // Hata titreşimi
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_person_outlined, size: 64, color: AppColors.primary),
                const SizedBox(height: AppSpacing.lg),
                const Text('Personel Girişi', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _isError ? 'Hatalı Şifre! Tekrar Deneyin.' : 'Lütfen 4 haneli şifrenizi girin',
                  style: TextStyle(color: _isError ? AppColors.danger : AppColors.dTextDim),
                ),
                const SizedBox(height: AppSpacing.xl),
                
                // Şifre Noktaları (Örn: * * * *)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final isFilled = index < _pin.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isFilled ? AppColors.primary : Colors.transparent,
                        border: Border.all(
                          color: isFilled ? AppColors.primary : AppColors.outline,
                          width: 2,
                        ),
                      ),
                    );
                  }),
                ),
                
                const SizedBox(height: AppSpacing.xxl),
                
                // Numpad
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1.5,
                    mainAxisSpacing: AppSpacing.md,
                    crossAxisSpacing: AppSpacing.md,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    if (index == 9) return const SizedBox(); // Sol alt boşluk
                    if (index == 11) {
                      return InkWell(
                        onTap: _onBackspace,
                        borderRadius: BorderRadius.circular(16),
                        child: const Icon(Icons.backspace_outlined, size: 28),
                      );
                    }
                    final number = index == 10 ? '0' : '${index + 1}';
                    return InkWell(
                      onTap: () => _onKeyPress(number),
                      borderRadius: BorderRadius.circular(16),
                      child: Center(
                        child: Text(number, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w500)),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}