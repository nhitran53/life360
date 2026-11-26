import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:life360/data/device_screen_time.dart';
import 'package:life360/screens/circle_screen.dart';
import 'package:life360/theme/app_colors.dart';
import 'package:life360/theme/circle_colors.dart';

// #77: visuals that only speak through color and shape get a spoken label.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel(AndroidUsageScreenTime.channelName),
          (call) async => call.method == 'hasUsageAccess' ? false : null,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel(AndroidUsageScreenTime.channelName),
          null,
        );
  });

  Future<SemanticsHandle> pumpCircle(WidgetTester tester) async {
    final handle = tester.ensureSemantics();
    tester.view.physicalSize = const Size(1170, 2900);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: CircleScreen()));
    await tester.pump();
    return handle;
  }

  group('Circle home', () {
    testWidgets('the pulse map is read as one list of members', (tester) async {
      final handle = await pumpCircle(tester);

      final map = find.bySemanticsLabel(RegExp(r'^Family map: You, '));
      expect(map, findsOneWidget);
      // Made-up heart rates aren't read out (#66).
      final label = tester.getSemantics(map).label;
      expect(label, isNot(contains('bpm')));
      handle.dispose();
    });

    testWidgets('Together today reads the total against the goal', (
      tester,
    ) async {
      final handle = await pumpCircle(tester);

      expect(
        find.bySemanticsLabel(
          RegExp(r'^Together today: [\d,]+ of [\d,]+ steps, (\d+%|goal hit)$'),
        ),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('Member detail', () {
    Future<SemanticsHandle> openMom(WidgetTester tester) async {
      final handle = await pumpCircle(tester);
      await tester.tap(find.text('Walking · now'));
      await tester.pumpAndSettle();
      return handle;
    }

    testWidgets('stat tiles read value and progress', (tester) async {
      final handle = await openMom(tester);

      expect(
        find.bySemanticsLabel(
          RegExp(r'^Steps: [\d,]+, (\d+% of goal|goal hit)$'),
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          RegExp(r'^Active minutes: \d+ min, (\d+% of goal|goal hit)$'),
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('the weekly steps chart reads each day', (tester) async {
      final handle = await openMom(tester);

      final chart = find.bySemanticsLabel(
        RegExp(r'^Steps this week: 54,130 in total\. Monday [\d,]+'),
      );
      expect(chart, findsOneWidget);
      expect(tester.getSemantics(chart).label, contains('today'));
      handle.dispose();
    });
  });

  group('text contrast (WCAG AA, 4.5:1)', () {
    double luminance(Color c) {
      double channel(double v) => v <= 0.03928
          ? v / 12.92
          : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
      return 0.2126 * channel(c.r) +
          0.7152 * channel(c.g) +
          0.0722 * channel(c.b);
    }

    double contrast(Color a, Color b) {
      final (hi, lo) = (
        math.max(luminance(a), luminance(b)),
        math.min(luminance(a), luminance(b)),
      );
      return (hi + 0.05) / (lo + 0.05);
    }

    final text = {
      'ink': AppColors.ink,
      'inkSoft': AppColors.inkSoft,
      'primaryText': AppColors.primaryText,
      'redText': AppColors.redText,
      'CircleColors.secondary': CircleColors.secondary,
      'CircleColors.muted': CircleColors.muted,
      'CircleColors.okText': CircleColors.okText,
      'CircleColors.heart': CircleColors.heart,
      'CircleColors.liveText': CircleColors.liveText,
    };
    final backgrounds = {
      'surface': AppColors.surface,
      'surfaceSunken': AppColors.surfaceSunken,
      'primaryTint': AppColors.primaryTint,
    };

    text.forEach((name, fg) {
      backgrounds.forEach((bgName, bg) {
        test('$name on $bgName', () {
          expect(contrast(fg, bg), greaterThanOrEqualTo(4.5));
        });
      });
    });

    test('white text on the primary button', () {
      // Bold 16px+ button labels count as large text: 3:1.
      expect(
        contrast(AppColors.onPrimary, AppColors.primary),
        greaterThanOrEqualTo(3),
      );
    });
  });
}
