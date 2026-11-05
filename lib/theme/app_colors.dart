import 'package:flutter/material.dart';

/// Friend 360 color tokens. Widgets use these, never raw hex values.
///
/// Each bright color has a `…Dark` partner used for the 3D bottom edge of
/// chunky buttons and cards.
abstract final class AppColors {
  static const primary = Color(0xFF58CC02);
  static const primaryDark = Color(0xFF46A302);
  static const primarySoft = Color(0xFFD7FFB8);

  static const blue = Color(0xFF1CB0F6);
  static const blueDark = Color(0xFF1899D6);

  static const orange = Color(0xFFFF9600);
  static const orangeDark = Color(0xFFCC7800);

  static const red = Color(0xFFFF4B4B);
  static const redDark = Color(0xFFEA2B2B);

  static const purple = Color(0xFFCE82FF);
  static const purpleDark = Color(0xFFA568CC);

  static const gold = Color(0xFFFFC800);
  static const goldDark = Color(0xFFE0A800);

  /// Podium 2nd and 3rd place.
  static const silver = Color(0xFFCFD8DF);
  static const silverDark = Color(0xFFA9B6C0);
  static const bronze = Color(0xFFF0A868);
  static const bronzeDark = Color(0xFFCC8448);

  static const ink = Color(0xFF3C3C3C);
  static const muted = Color(0xFFAFAFAF);

  /// Secondary text that still needs to be readable (≈4.5:1 on white).
  static const inkSoft = Color(0xFF777777);

  static const surface = Color(0xFFFFFFFF);
  static const surfaceSunken = Color(0xFFF7F7F7);
  static const border = Color(0xFFE5E5E5);

  /// Edge color for neutral (white) chunky cards and buttons.
  static const borderDark = Color(0xFFD5D5D5);
}
