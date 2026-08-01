import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/database/isar_service.dart';
import 'core/providers/core_providers.dart';
import 'core/theme/ui_prefs.dart';
import 'features/caller_id/caller_id_listener.dart'; // Eklendi
import 'features/home/home_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Türkçe tarih biçimlendirmesini başlatıyoruz
  await initializeDateFormatting('tr_TR', null);
  
  final isar = await IsarService.init();

  runApp(
    ProviderScope(
      overrides: [
        isarProvider.overrideWithValue(isar),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Tezgah POS',
      debugShowCheckedModeBanner: false,
      theme: UiPrefs.lightTheme,
      darkTheme: UiPrefs.darkTheme,
      themeMode: ThemeMode.dark,
      // CallerIdListener ile sarmalandı
      home: const CallerIdListener(
        child: HomeShell(),
      ),
    );
  }
}