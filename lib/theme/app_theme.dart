import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Shared shape and spacing tokens.
abstract final class AppRadius {
  static const card = 20.0;
  static const button = 14.0;
  static const chip = 12.0;
}

/// Height of the solid bottom edge that gives chunky widgets their depth.
/// Kept subtle (2px) so the press animation still reads without looking toy-like.
abstract final class AppDepth {
  static const button = 2.0;
  static const card = 2.0;
  static const chip = 2.0;
}

abstract final class AppTheme {
  /// Bundled in assets/fonts (weights 500–800).
  static const fontFamily = 'Plus Jakarta Sans';

  static OutlineInputBorder _inputBorder(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.button),
        borderSide: BorderSide(color: color, width: 1.5),
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
          fontSize: 40, fontWeight: FontWeight.w800, height: 1.05, letterSpacing: -1),
      headlineLarge: TextStyle(
          fontSize: 30, fontWeight: FontWeight.w700, height: 1.1, letterSpacing: -0.6),
      headlineMedium: TextStyle(
          fontSize: 24, fontWeight: FontWeight.w700, height: 1.15, letterSpacing: -0.4),
      titleLarge: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -0.2),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      titleSmall: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, height: 1.45),
      bodyMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, height: 1.45),
      bodySmall: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.inkSoft),
      labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      labelMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      labelSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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
      // Off-white page so white cards stand out without heavy edges.
      scaffoldBackgroundColor: AppColors.surfaceSunken,
      splashFactory: NoSplash.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surfaceSunken,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
      // Small green text needs the darker green to stay readable.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primaryText),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w500,
          color: AppColors.muted,
        ),
        errorStyle: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
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
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.chip)),
      ),
    );
  }
}
