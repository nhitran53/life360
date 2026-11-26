import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life360/models/models.dart';
import 'package:life360/theme/app_colors.dart';
import 'package:life360/theme/circle_colors.dart';
import 'package:life360/theme/stat_colors.dart';

// #78: one palette. The Circle screens' colors come from AppColors, and
// widgets never hard-code white or black.
void main() {
  group('CircleColors is built from AppColors', () {
    final shared = <String, (Color, Color)>{
      'surface': (CircleColors.surface, AppColors.surface),
      'background': (CircleColors.background, AppColors.surfaceSunken),
      'border': (CircleColors.border, AppColors.border),
      'outline': (CircleColors.outline, AppColors.borderDark),
      'divider': (CircleColors.divider, AppColors.border),
      'progressTrack': (CircleColors.progressTrack, AppColors.border),
      'ink': (CircleColors.ink, AppColors.ink),
      'secondary': (CircleColors.secondary, AppColors.inkSoft),
      'muted': (CircleColors.muted, AppColors.inkSoft),
      'okBackground': (CircleColors.okBackground, AppColors.primarySoft),
      'okText': (CircleColors.okText, AppColors.primaryText),
      'okTextDark': (CircleColors.okTextDark, AppColors.primaryDark),
    };
    shared.forEach((name, pair) {
      test(name, () => expect(pair.$1, pair.$2));
    });

    test('stat progress uses the stat colors', () {
      expect(CircleColors.stepsProgress, StatMetric.steps.color);
      expect(CircleColors.activeProgress, StatMetric.workout.color);
    });
  });

  test('onPrimary is white, for text and icons on colored fills', () {
    expect(AppColors.onPrimary, const Color(0xFFFFFFFF));
  });

  group('no hard-coded colors outside lib/theme', () {
    final files = [
      for (final dir in ['lib/screens', 'lib/widgets'])
        ...Directory(dir)
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart')),
      File('lib/main.dart'),
    ];

    test('scans some files', () => expect(files.length, greaterThan(10)));

    for (final pattern in [
      RegExp(r'Colors\.(white|black)\b'),
      RegExp(r'Color\(0x[0-9A-Fa-f]{8}\)'),
    ]) {
      test(pattern.pattern, () {
        final hits = [
          for (final f in files)
            for (final (i, line) in f.readAsLinesSync().indexed)
              if (pattern.hasMatch(line)) '${f.path}:${i + 1}',
        ];
        expect(hits, isEmpty, reason: 'use a token from lib/theme/');
      });
    }
  });
}
