import 'package:flutter/material.dart';

/// Friend 360 color tokens. Widgets use these, never raw hex values.
///
/// Calm and mostly neutral: one green accent, and muted stat colors that
/// show up in icons and progress rather than as big fills. Each color has a
/// `…Dark` partner used for the thin bottom edge of chunky buttons and cards.
abstract final class AppColors {
  static const primary = Color(0xFF2F9E44);
  static const primaryDark = Color(0xFF23803A);
  static const primarySoft = Color(0xFFDCEFDF);

  /// Very light green background, e.g. to highlight "you" in a list.
  static const primaryTint = Color(0xFFF1F7F2);

  /// Green that is dark enough for small text on white (≈4.5:1).
  static const primaryText = Color(0xFF23803A);

  static const blue = Color(0xFF4F7BE0);
  static const blueDark = Color(0xFF3A62C2);

  static const orange = Color(0xFFE0882B);
  static const orangeDark = Color(0xFFB26816);

  static const red = Color(0xFFDD5A4E);
  static const redDark = Color(0xFFB4433A);

  /// Red that is dark enough for small text on white (≈4.5:1).
  static const redText = Color(0xFFB4433A);

  static const purple = Color(0xFF8C6FD6);
  static const purpleDark = Color(0xFF6C52B3);

  static const gold = Color(0xFFD9A92B);
  static const goldDark = Color(0xFF9A7414);

  /// Podium 2nd and 3rd place.
  static const silver = Color(0xFFE3E3DF);
  static const silverDark = Color(0xFFC9C9C4);
  static const bronze = Color(0xFFDDBD9C);
  static const bronzeDark = Color(0xFFB08A63);

  static const ink = Color(0xFF1F1F1F);
  static const muted = Color(0xFFA3A3A3);

  /// Secondary text that still needs to be readable (≈4.5:1 on white).
  static const inkSoft = Color(0xFF6B6B6B);

  static const surface = Color(0xFFFFFFFF);
  static const surfaceSunken = Color(0xFFF6F6F3);
  static const border = Color(0xFFE8E8E4);

  /// Edge color for neutral (white) chunky cards and buttons.
  static const borderDark = Color(0xFFD9D9D5);
}
