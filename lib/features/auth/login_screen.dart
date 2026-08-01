import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/service_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../home/home_shell.dart';
import '../courier/courier_shell.dart'; 
import '../shared/widgets.dart'; 

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  // Seçilen rol: 'restaurant' veya 'courier'
  String? _selectedRole;

  void _selectRole(String role) {
    setState(() {
      _selectedRole = role;
    });
  }

  void _goBack() {
    setState(() {
      _selectedRole = null;
    });
  }

  void _routeToApp(String role) {
    if (role == 'restaurant') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeShell()),
      );
    } else if (role == 'courier') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const CourierShell()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Eğer bir rol seçildiyse, PIN girme ekranını göster (veya direkt içeri al)
    if (_selectedRole != null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _goBack,
          ),
          title: Text(_selectedRole == 'restaurant' ? 'Restoran Girişi' : 'Kurye Girişi'),
        ),
        body: Center(
          child: SizedBox(
            width: 320,
            child: PinPad(
              title: 'Şifrenizi Girin',
              subtitle: 'İşleme devam etmek için PIN kodu gereklidir',
              onSubmit: (pin) async {
                // TODO: İleride burada Garson/Yönetici/Kurye yetki kontrolü yapılacak
                // Şimdilik herhangi bir 4 haneli şifre girildiğinde içeri alıyoruz
                if (pin.length >= 4) {
                  _routeToApp(_selectedRole!);
                  return true;
                }
                return false;
              },
            ),
          ),
        ),
      );
    }

    // Rol Seçim Ekranı (Gateway)
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.storefront_rounded, size: 80, color: AppColors.amber),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Tezgah POS',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 1.5),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Lütfen giriş yapmak istediğiniz bölümü seçin',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 48),
              
              // Rol Butonları
              Wrap(
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.lg,
                alignment: WrapAlignment.center,
                children: [
                  _RoleButton(
                    title: 'Kasa & Restoran',
                    icon: Icons.point_of_sale_rounded,
                    color: AppColors.amber,
                    onTap: () => _selectRole('restaurant'),
                  ),
                  _RoleButton(
                    title: 'Saha & Kurye',
                    icon: Icons.two_wheeler_rounded,
                    color: Colors.blueAccent,
                    onTap: () => _selectRole('courier'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Özel Rol Seçim Butonu Tasarımı
class _RoleButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _RoleButton({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.rLg),
      child: Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
          borderRadius: BorderRadius.circular(AppSpacing.rLg),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }
}