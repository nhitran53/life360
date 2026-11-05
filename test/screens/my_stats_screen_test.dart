import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life360/data/mock_data.dart';
import 'package:life360/data/mock_friends_repository.dart';
import 'package:life360/data/mock_stats_repository.dart';
import 'package:life360/models/models.dart';
import 'package:life360/screens/leaderboard_screen.dart';
import 'package:life360/screens/my_stats_screen.dart';
import 'package:life360/theme/app_theme.dart';
import 'package:life360/utils/format.dart';

void main() {
  // A Wednesday afternoon.
  final now = DateTime(2026, 11, 4, 15);
  DateTime clock() => now;
  const goals = DailyGoals();

  late MockFriendsRepository friends;
  late MockStatsRepository stats;

  setUp(() {
    friends = MockFriendsRepository(clock: clock);
    stats = MockStatsRepository(friends: friends, clock: clock);
  });

  Future<void> pumpScreen(WidgetTester tester, {DailyGoals? goals}) async {
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
          goals: goals ?? const DailyGoals(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<DailyStats> myToday() async =>
      (await stats.dailyStats(mockMe.id, from: now, to: now)).single;

  testWidgets('Today shows a card per stat with goal progress', (tester) async {
    await pumpScreen(tester);
    final today = await myToday();

    for (final m in StatMetric.values) {
      final card = find.byKey(ValueKey('today-${m.name}'));
      await tester.ensureVisible(card);
      expect(card, findsOneWidget, reason: m.label);
      expect(
        find.descendant(
          of: card,
          matching: find.text(goalStatus(m, m.valueOf(today), goals)),
        ),
        findsOneWidget,
        reason: m.label,
      );
    }
    expect(find.text(todayHeadline(today, goals)), findsOneWidget);
  });

  testWidgets('Header shows the streak and this week\'s XP', (tester) async {
    await pumpScreen(tester);
    final recent = await stats.dailyStats(
      mockMe.id,
      from: now.subtract(const Duration(days: 30)),
      to: now,
    );
    final streak = currentStreak(recent, today: now);
    final xp = weeklyXp(await stats.weeklySummary(mockMe.id, weekOf: now));

    expect(find.bySemanticsLabel('$streak day streak'), findsOneWidget);
    expect(find.text('$streak'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('XP this week')), findsOneWidget);
    expect(find.text(formatThousands(xp)), findsOneWidget);
  });

  testWidgets('A hit goal pops a check mark', (tester) async {
    // Tiny goals so every "more is better" stat is hit.
    await pumpScreen(
      tester,
      goals: const DailyGoals(
        steps: 1,
        sleepMinutes: 1,
        workoutMinutes: 1,
        activeCalories: 1,
      ),
    );
    final today = await myToday();

    for (final m in StatMetric.values.where((m) => m.higherIsBetter)) {
      // A rest day (0 workout minutes) can't hit even a 1-minute goal.
      if (m.valueOf(today) == 0) continue;
      expect(
        find.byKey(ValueKey('goal-hit-${m.name}')),
        findsOneWidget,
        reason: m.label,
      );
    }
    expect(find.byKey(const ValueKey('goal-hit-screenTime')), findsNothing);
  });

  testWidgets('This week shows a chart per stat', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(const ValueKey('view-week')));
    await tester.pumpAndSettle();

    for (final m in StatMetric.values) {
      final card = find.byKey(ValueKey('week-${m.name}'));
      await tester.ensureVisible(card);
      expect(card, findsOneWidget, reason: m.label);
    }
    // Monday to Sunday labels on each chart.
    expect(find.text('M'), findsNWidgets(StatMetric.values.length));
    expect(find.byKey(const ValueKey('today-steps')), findsNothing);
  });

  testWidgets('Leaderboard opens My Stats from the app bar', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: LeaderboardScreen(friends: friends, stats: stats, clock: clock),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('My stats'));
    await tester.pumpAndSettle();
    expect(find.byType(MyStatsScreen), findsOneWidget);
  });

  group('copy', () {
    test('goal status is encouraging', () {
      expect(goalStatus(StatMetric.steps, 6240, goals), '1,760 steps to go 👟');
      expect(goalStatus(StatMetric.steps, 9000, goals), 'Goal hit! 🎉');
      expect(
        goalStatus(StatMetric.sleep, 300, goals),
        'A little short. Rest up tonight 😴',
      );
      expect(
        goalStatus(StatMetric.screenTime, 100, goals),
        '1h 20m left under your limit 📵',
      );
      expect(
        goalStatus(StatMetric.screenTime, 0, goals),
        'Not tracked yet today',
      );
    });

    test('formatStat reads naturally', () {
      expect(formatStat(StatMetric.steps, 12345), '12,345 steps');
      expect(formatStat(StatMetric.sleep, 432), '7h 12m');
      expect(formatStat(StatMetric.workout, 25), '25 min');
      expect(formatStat(StatMetric.calories, 1200), '1,200 kcal');
    });

    test('week summary counts goal days', () {
      expect(
        weekSummaryLine(StatMetric.steps, [9000, 4000, 8000], goals),
        '21,000 steps total · goal hit 2/3 days',
      );
      expect(
        weekSummaryLine(StatMetric.screenTime, [120, 240], goals),
        '3h 00m a day · under your limit 1/2 days',
      );
      expect(
        weekSummaryLine(StatMetric.sleep, [], goals),
        'No data yet this week',
      );
    });
  });
}
