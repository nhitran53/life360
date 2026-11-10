import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Shared shape and spacing tokens.
abstract final class AppRadius {
  static const card = 18.0;
  static const button = 16.0;
  static const chip = 14.0;
}

/// Height of the solid bottom edge that gives chunky widgets their depth.
abstract final class AppDepth {
  static const button = 4.0;
  static const card = 4.0;
  static const chip = 3.0;
}

abstract final class AppTheme {
  static const fontFamily = 'Nunito';

  static OutlineInputBorder _inputBorder(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.button),
        borderSide: BorderSide(color: color, width: 2),
      );

  static ThemeData light() {
    const scheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.blue,
      onSecondary: Colors.white,
      error: AppColors.red,
      onError: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.inkSoft,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
    );

    const text = TextTheme(
      displayLarge: TextStyle(
          fontSize: 44, fontWeight: FontWeight.w900, height: 1.05, letterSpacing: -1),
      headlineLarge: TextStyle(
          fontSize: 32, fontWeight: FontWeight.w900, height: 1.1, letterSpacing: -0.5),
      headlineMedium: TextStyle(
          fontSize: 26, fontWeight: FontWeight.w900, height: 1.15),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
      titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      titleSmall: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      bodyLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.4),
      bodyMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.4),
      bodySmall: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.inkSoft),
      labelLarge: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.4),
      labelMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
      labelSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      textTheme: text.apply(
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
        fontFamily: fontFamily,
      ),
      scaffoldBackgroundColor: AppColors.surface,
      splashFactory: NoSplash.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: AppColors.ink,
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 2),
      // Small green text needs the darker green to stay readable.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primaryText),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceSunken,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          color: AppColors.muted,
        ),
        errorStyle: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          color: AppColors.redText,
        ),
        border: _inputBorder(AppColors.border),
        enabledBorder: _inputBorder(AppColors.border),
        focusedBorder: _inputBorder(AppColors.blue),
        errorBorder: _inputBorder(AppColors.red),
        focusedErrorBorder: _inputBorder(AppColors.red),
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: AppColors.primary),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.chip)),
      ),
    );
  }
}
