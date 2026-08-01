import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Material 3 tabanli koyu/aydinlik temalar.
class AppTheme {
  AppTheme._();

  static ThemeData dark({
    Color accent = AppColors.amber,
    Color onAccent = const Color(0xFF1A1300),
  }) =>
      _build(
        brightness: Brightness.dark,
        bg: AppColors.dBg,
        surface: AppColors.dSurface,
        surface2: AppColors.dSurface2,
        border: AppColors.dBorder,
        text: AppColors.dText,
        dim: AppColors.dTextDim,
        accent: accent,
        onAccent: onAccent,
      );

  static ThemeData light({
    Color accent = AppColors.amber,
    Color onAccent = const Color(0xFF1A1300),
  }) =>
      _build(
        brightness: Brightness.light,
        bg: AppColors.lBg,
        surface: AppColors.lSurface,
        surface2: AppColors.lSurface2,
        border: AppColors.lBorder,
        text: AppColors.lText,
        dim: AppColors.lTextDim,
        accent: accent,
        onAccent: onAccent,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color bg,
    required Color surface,
    required Color surface2,
    required Color border,
    required Color text,
    required Color dim,
    Color accent = AppColors.amber,
    Color onAccent = const Color(0xFF1A1300),
  }) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: onAccent,
      secondary: AppColors.teal,
      onSecondary: Colors.white,
      error: AppColors.danger,
      onError: Colors.white,
      surface: surface,
      onSurface: text,
      surfaceContainerHighest: surface2,
      outline: border,
    );

    final radius = BorderRadius.circular(AppSpacing.rMd);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: scheme,
      textTheme: AppTypography.build(text, dim),
      dividerColor: border,
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.rLg),
          side: BorderSide(color: border),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: text,
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface2,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        border: OutlineInputBorder(
            borderRadius: radius, borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: radius, borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: const BorderSide(color: AppColors.amber, width: 2)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, AppSpacing.touchTarget),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, AppSpacing.touchTarget),
          side: BorderSide(color: border),
          foregroundColor: text,
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        indicatorColor: AppColors.amber.withValues(alpha: 0.18),
        selectedIconTheme: const IconThemeData(color: AppColors.amber),
        selectedLabelTextStyle: const TextStyle(
            color: AppColors.amber, fontWeight: FontWeight.w600),
        unselectedIconTheme: IconThemeData(color: dim),
        unselectedLabelTextStyle: TextStyle(color: dim),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: AppColors.amber.withValues(alpha: 0.18),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    );
  }
}
