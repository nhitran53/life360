import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life360/data/health/fake_health_source.dart';
import 'package:life360/data/health_stats_repository.dart';
import 'package:life360/data/manual_screen_time_repository.dart';
import 'package:life360/data/mock_data.dart';
import 'package:life360/data/mock_friends_repository.dart';
import 'package:life360/data/mock_stats_repository.dart';
import 'package:life360/data/screen_time_log.dart';
import 'package:life360/models/models.dart';
import 'package:life360/screens/my_stats_screen.dart';
import 'package:life360/theme/app_theme.dart';
import 'package:life360/utils/format.dart';

void main() {
  // A Wednesday afternoon.
  final now = DateTime(2026, 11, 4, 15);
  final today = dateOnly(now);
  DateTime clock() => now;

  late MockFriendsRepository friends;
  late HealthStatsRepository health;
  late InMemoryScreenTimeLog log;
  late ManualScreenTimeRepository stats;

  setUp(() {
    friends = MockFriendsRepository(clock: clock);
    // Health gives steps but never screen time, like on a real phone.
    health = HealthStatsRepository(
      source: FakeHealthSource(
        stats: [DailyStats(userId: mockMe.id, date: today, steps: 5000)],
      ),
      fallback: MockStatsRepository(friends: friends, clock: clock),
      friends: friends,
      clock: clock,
    );
    log = InMemoryScreenTimeLog();
    stats = ManualScreenTimeRepository(
      inner: health,
      friends: friends,
      log: log,
      clock: clock,
    );
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    ScreenTimeLog? screenTimeLog,
  }) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MyStatsScreen(
          friends: friends,
          stats: stats,
          clock: clock,
          screenTimeLog: screenTimeLog,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> connect(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('connect-button')));
    await tester.pumpAndSettle();
  }

  /// Scrolls [finder] into view, then taps it.
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Finder inScreenTimeCard(String text) => find.descendant(
    of: find.byKey(const ValueKey('today-screenTime')),
    matching: find.text(text),
  );

  testWidgets('No log button without a screen time log', (tester) async {
    await pumpScreen(tester);
    expect(find.byKey(const ValueKey('log-screen-time')), findsNothing);
  });

  testWidgets('Logging screen time updates the Today card', (tester) async {
    await pumpScreen(tester, screenTimeLog: log);
    await connect(tester);

    expect(inScreenTimeCard('Not tracked yet today'), findsOneWidget);
    final button = find.byKey(const ValueKey('log-screen-time'));
    expect(find.text('Log screen time'), findsOneWidget);
    await tapVisible(tester, button);

    // Starts at 2h; 2h − 15m + 1h = 2h 45m.
    expect(find.byKey(const ValueKey('screen-time-sheet')), findsOneWidget);
    expect(find.text(formatMinutes(120)), findsOneWidget);
    expect(find.byKey(const ValueKey('screen-time-clear')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('screen-time-minus')));
    await tester.tap(find.byKey(const ValueKey('screen-time-plus-hour')));
    await tester.pump();
    expect(find.text(formatMinutes(165)), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('screen-time-save')));
    await tester.pumpAndSettle();

    expect(await log.entries(from: today, to: today), {today: 165});
    expect(find.text('Screen time logged 📱'), findsOneWidget);
    expect(
      inScreenTimeCard(
        goalStatus(StatMetric.screenTime, 165, const DailyGoals()),
      ),
      findsOneWidget,
    );
    expect(find.text('Edit screen time'), findsOneWidget);
  });

  testWidgets('Editing starts from the logged value and can clear it', (
    tester,
  ) async {
    await log.setMinutes(today, 200);
    await pumpScreen(tester, screenTimeLog: log);
    await connect(tester);

    final button = find.byKey(const ValueKey('log-screen-time'));
    await tapVisible(tester, button);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('screen-time-sheet')),
        matching: find.text(formatMinutes(200)),
      ),
      findsOneWidget,
    );

    final clear = find.byKey(const ValueKey('screen-time-clear'));
    await tapVisible(tester, clear);

    expect(await log.entries(from: today, to: today), isEmpty);
    expect(find.text('Screen time cleared'), findsOneWidget);
    expect(inScreenTimeCard('Not tracked yet today'), findsOneWidget);
  });

  testWidgets("Can't go below 0 or above 24 hours", (tester) async {
    await pumpScreen(tester, screenTimeLog: log);
    final button = find.byKey(const ValueKey('log-screen-time'));
    await tapVisible(tester, button);

    final value = find.byKey(const ValueKey('screen-time-value'));
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byKey(const ValueKey('screen-time-minus-hour')));
    }
    await tester.pump();
    expect(tester.widget<Text>(value).data, formatMinutes(0));

    for (var i = 0; i < 30; i++) {
      await tester.tap(find.byKey(const ValueKey('screen-time-plus-hour')));
    }
    await tester.pump();
    expect(
      tester.widget<Text>(value).data,
      formatMinutes(ScreenTimeLog.maxMinutes),
    );
  });

  testWidgets('Dismissing the sheet saves nothing', (tester) async {
    await pumpScreen(tester, screenTimeLog: log);
    final button = find.byKey(const ValueKey('log-screen-time'));
    await tapVisible(tester, button);

    await tester.tapAt(const Offset(20, 20)); // the barrier
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('screen-time-sheet')), findsNothing);
    expect(await log.entries(from: today, to: today), isEmpty);
  });

  testWidgets('The freeze line explains how to earn a freeze', (tester) async {
    await pumpScreen(tester);
    final recent = await stats.dailyStats(
      mockMe.id,
      from: DateTime(now.year, now.month, now.day - 60),
      to: now,
    );
    final status = streakWithFreezes(recent, today: now);
    final l10n = const DefaultMaterialLocalizations();

    expect(find.byKey(const ValueKey('freeze-line')), findsOneWidget);
    expect(find.text(freezeLine(status, l10n)), findsOneWidget);
  });

  group('freezeLine', () {
    const l10n = DefaultMaterialLocalizations();

    test('nudges toward the first freeze', () {
      expect(freezeLine(StreakStatus.none, l10n), contains('7-day streak'));
    });

    test('counts banked freezes', () {
      expect(
        freezeLine(
          const StreakStatus(days: 7, freezesLeft: 1, frozenDays: []),
          l10n,
        ),
        '1 streak freeze ready.',
      );
      expect(
        freezeLine(
          const StreakStatus(days: 14, freezesLeft: 2, frozenDays: []),
          l10n,
        ),
        '2 streak freezes ready.',
      );
    });

    test('says when a freeze saved the streak', () {
      final saved = StreakStatus(
        days: 9,
        freezesLeft: 0,
        frozenDays: [DateTime(2026, 11, 3)],
      );
      expect(
        freezeLine(saved, l10n),
        'A freeze saved your streak on ${l10n.formatShortMonthDay(DateTime(2026, 11, 3))} 🧊',
      );
    });
  });
}
