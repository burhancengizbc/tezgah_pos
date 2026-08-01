import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_keys.dart';
import 'core/constants/app_constants.dart';
import 'core/providers/core_providers.dart';
import 'core/providers/data_streams.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/ui_prefs.dart';
import 'features/auth/lock_gate.dart';
import 'features/caller_id/caller_id_scope.dart';
import 'features/auth/login_screen.dart'; 
import 'features/lan/lan_scope.dart';
import 'features/onboarding/onboarding_gate.dart';

class TezgahApp extends ConsumerWidget {
  const TezgahApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final settings = ref.watch(settingsStreamProvider).value;

    final accentKey = settings?.uiAccent ?? 'amber';
    final accent = UiPrefs.accentColor(accentKey);
    final onAccent = UiPrefs.onAccent(accentKey);
    final scale = UiPrefs.clampScale(settings?.uiScale ?? 1.0);
    final density = UiPrefs.density(settings?.uiDensity ?? 'auto');

    ThemeData tune(ThemeData t) => t.copyWith(
          visualDensity: density ?? t.visualDensity,
          iconTheme: t.iconTheme.copyWith(size: 24 * scale),
        );

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: tune(AppTheme.light(accent: accent, onAccent: onAccent)),
      darkTheme: tune(AppTheme.dark(accent: accent, onAccent: onAccent)),
      themeMode: themeMode,
      builder: (context, child) {
        // Yazi (ve varsayilan ikon) boyutunu kullanici olcegine gore uygula.
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        );
      },
      home: const OnboardingGate(
        child: LanScope(
          child: CallerIdScope(
            child: LockGate(child: LoginScreen()), 
          ),
        ),
      ),
    );
  }
}
