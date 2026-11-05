import 'package:flutter/material.dart';

/// Colors from the "Circle (home)" Figma frame.
class CircleColors {
  CircleColors._();

  static const background = Color(0xFFF6F5F1);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE6E4DE);
  static const mapBackground = Color(0xFFECEAE3);
  static const progressTrack = Color(0xFFEFEDE8);
  static const progressFill = Color(0xFF2D5BD8);

  /// Outline of secondary buttons and the note text area.
  static const outline = Color(0xFFD7D4CC);

  /// Row dividers, unselected chips and weekly bars' track.
  static const divider = Color(0xFFEFEDE8);

  /// Unselected quick-note rows.
  static const noteBackground = Color(0xFFFBFAF7);

  /// Unchecked checkbox border.
  static const checkboxOff = Color(0xFF8A8F99);

  // "All good" green (normal heart rate, connected device).
  static const okBackground = Color(0xFFE3F2EA);
  static const okText = Color(0xFF0B6E4A);
  static const okTextDark = Color(0xFF0B5A3C);

  /// Active minutes progress.
  static const active = Color(0xFFC25E00);

  /// Past days in the weekly steps chart (today uses [progressFill]).
  static const weekBar = Color(0xFFC9D6F5);

  /// Outline of destructive buttons (text uses [heart]).
  static const dangerOutline = Color(0xFFE8B4BD);

  static const ink = Color(0xFF15171C);
  static const secondary = Color(0xFF555B67);
  static const muted = Color(0xFF6B717D);
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
