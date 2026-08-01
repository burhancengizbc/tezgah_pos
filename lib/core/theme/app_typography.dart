import 'package:flutter/material.dart';

/// Tipografi olcegi. Sistem fontu kullanilir (offline, asset gerektirmez).
class AppTypography {
  AppTypography._();

  static TextTheme build(Color text, Color dim) {
    return TextTheme(
      displaySmall: TextStyle(
          fontSize: 32, fontWeight: FontWeight.w700, color: text, height: 1.1),
      headlineMedium: TextStyle(
          fontSize: 24, fontWeight: FontWeight.w700, color: text),
      titleLarge: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w600, color: text),
      titleMedium: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w600, color: text),
      bodyLarge: TextStyle(fontSize: 16, color: text),
      bodyMedium: TextStyle(fontSize: 14, color: text),
      bodySmall: TextStyle(fontSize: 12, color: dim),
      labelLarge: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w600, color: text),
    );
  }
}
