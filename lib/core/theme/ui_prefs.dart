import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_spacing.dart';

class UiPrefs {
  UiPrefs._();

  static const Map<String, String> accentLabels = {
    'amber': 'Kehribar',
    'green': 'Yesil',
    'blue': 'Mavi',
    'purple': 'Mor',
  };

  static Color accentColor(String key) {
    switch (key) {
      case 'green':
        return AppColors.success;
      case 'blue':
        return Colors.blue;
      case 'purple':
        return Colors.purple;
      case 'amber':
      default:
        return AppColors.amber;
    }
  }

  // main.dart'ın aradığı lightTheme ve darkTheme tanımları:
  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF5F5F7),
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.amber,
          brightness: Brightness.light,
        ),
      );

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121214),
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.amber,
          brightness: Brightness.dark,
        ),
      );
}