import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Colors from the "Circle (home)" Figma frame.
class CircleColors {
  CircleColors._();

  // Shared with the rest of the app: these come from [AppColors] so the
  // Circle screens match everything else.
  static const background = AppColors.surfaceSunken;
  static const surface = AppColors.surface;
  static const border = AppColors.border;
  static const progressTrack = AppColors.border;

  /// Outline of secondary buttons and the note text area.
  static const outline = AppColors.borderDark;

  /// Row dividers, unselected chips and weekly bars' track.
  static const divider = AppColors.border;

  static const ink = AppColors.ink;
  static const secondary = AppColors.inkSoft;
  static const muted = AppColors.inkSoft;

  // "All good" green (normal heart rate, connected device).
  static const okBackground = AppColors.primarySoft;
  static const okText = AppColors.primaryText;
  static const okTextDark = AppColors.primaryDark;

  /// Steps progress and today's bar: the steps color (see stat_colors.dart).
  static const stepsProgress = AppColors.primary;

  /// Past days in the weekly steps chart.
  static const stepsWeekBar = AppColors.primarySoft;

  /// Active minutes progress: the workout color.
  static const activeProgress = AppColors.orange;

  // Only used by the Circle screens.
  static const mapBackground = Color(0xFFECEAE3);

  /// Unselected quick-note rows.
  static const noteBackground = Color(0xFFFBFAF7);

  /// Unchecked checkbox border (3:1 on white).
  static const checkboxOff = Color(0xFF8A8F99);

  /// Outline of destructive buttons (text uses [heart]).
  static const dangerOutline = Color(0xFFE8B4BD);

  static const liveText = Color(0xFF3F4450);

  /// Heart rate text.
  static const heart = Color(0xFFB0213A);

  /// High heart rate highlight (badge fill, avatar ring).
  static const alert = Color(0xFFD6304A);

  /// Ring around an idle member's avatar.
  static const idle = Color(0xFF8A8F99);

  // Avatar fills, one per member.
  static const avatarYou = Color(0xFF15171C);
  static const avatarMom = Color(0xFFF2C6B5);
  static const avatarDad = Color(0xFFBFD3F2);
  static const avatarBao = Color(0xFFCDE5C9);
  static const avatarLinh = Color(0xFFF5E1A4);
}
