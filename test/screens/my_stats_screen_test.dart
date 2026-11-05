import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life360/data/connectable_stats_repository.dart';
import 'package:life360/data/health/fake_health_source.dart';
import 'package:life360/data/health/health_source.dart';
import 'package:life360/data/health_stats_repository.dart';
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

  group('health connect card', () {
    late MockFriendsRepository realFriends;
    late String me;

    setUp(() async {
      realFriends = MockFriendsRepository();
      me = (await realFriends.currentUser()).id;
    });

    FakeHealthSource sourceWith({
      String displayName = 'Health Connect',
      HealthAvailability availability = HealthAvailability.available,
      Map<StatMetric, HealthPermissionStatus>? permissions,
    }) => FakeHealthSource(
      displayName: displayName,
      availabilityResult: availability,
      permissionOutcome: permissions,
      stats: [
        DailyStats(
          userId: me,
          date: DateTime.now(),
          steps: 4321,
          sleepMinutes: 450,
          workoutMinutes: 40,
          activeCalories: 300,
          screenTimeMinutes: 0,
        ),
      ],
    );

    Future<void> pumpConnectable(
      WidgetTester tester,
      ConnectableStatsRepository stats,
    ) async {
      tester.view.physicalSize = const Size(1170, 2900);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: MyStatsScreen(friends: realFriends, stats: stats),
        ),
      );
    }

    Future<void> pumpSource(
      WidgetTester tester,
      FakeHealthSource source,
    ) async {
      await pumpConnectable(
        tester,
        HealthStatsRepository(
          source: source,
          fallback: MockStatsRepository(friends: realFriends),
          friends: realFriends,
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> tapKey(WidgetTester tester, String key) async {
      final finder = find.byKey(ValueKey(key));
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    testWidgets('a plain stats repository shows no connect card', (
      tester,
    ) async {
      await pumpScreen(tester);
      expect(find.byKey(const ValueKey('connect-card')), findsNothing);
    });

    testWidgets('offers to connect the platform source by name', (
      tester,
    ) async {
      await pumpSource(tester, sourceWith(displayName: 'Apple Health'));
      expect(find.text('Connect Apple Health'), findsOneWidget);
      expect(find.text('Showing demo data'), findsOneWidget);
    });

    testWidgets('connecting syncs real stats and offers Sync now', (
      tester,
    ) async {
      final source = sourceWith();
      await pumpSource(tester, source);
      await tapKey(tester, 'connect-button');

      expect(source.requestPermissionsCalls, 1);
      expect(find.text('Health Connect connected'), findsOneWidget);
      expect(find.textContaining('Synced at'), findsOneWidget);
      expect(find.textContaining('4,321 steps'), findsOneWidget);
      expect(find.text('Sync now'), findsOneWidget);

      await tapKey(tester, 'connect-button');
      expect(source.requestPermissionsCalls, 2);
    });

    testWidgets('denied metrics show No access instead of 0', (tester) async {
      await pumpSource(
        tester,
        sourceWith(
          permissions: {
            StatMetric.steps: HealthPermissionStatus.granted,
            StatMetric.sleep: HealthPermissionStatus.denied,
            StatMetric.workout: HealthPermissionStatus.granted,
            StatMetric.calories: HealthPermissionStatus.granted,
          },
        ),
      );
      await tapKey(tester, 'connect-button');

      expect(find.textContaining('Sleep not allowed'), findsOneWidget);
      final sleepCard = find.byKey(const ValueKey('today-sleep'));
      await tester.ensureVisible(sleepCard);
      expect(
        find.descendant(of: sleepCard, matching: find.text('No access')),
        findsOneWidget,
      );
      expect(find.textContaining('4,321 steps'), findsOneWidget);
      expect(find.text('0h 00m'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('view-week')));
      await tester.pumpAndSettle();
      final sleepWeek = find.byKey(const ValueKey('week-sleep'));
      await tester.ensureVisible(sleepWeek);
      expect(
        find.descendant(
          of: sleepWeek,
          matching: find.textContaining('No access'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('all permissions denied explains how to retry', (tester) async {
      await pumpSource(
        tester,
        sourceWith(
          permissions: {
            for (final m in StatMetric.values) m: HealthPermissionStatus.denied,
          },
        ),
      );
      await tapKey(tester, 'connect-button');

      expect(find.text('No access to Health Connect'), findsOneWidget);
      expect(find.text('Connect Health Connect'), findsOneWidget);
      expect(find.text('Showing demo data'), findsNothing);
    });

    testWidgets('missing Health Connect offers install and retry', (
      tester,
    ) async {
      final source = sourceWith(availability: HealthAvailability.notInstalled);
      await pumpSource(tester, source);
      await tapKey(tester, 'connect-button');

      expect(find.text('Health Connect is not installed'), findsOneWidget);
      expect(source.requestPermissionsCalls, 0);

      await tapKey(tester, 'install-button');
      expect(source.openInstallPageCalls, 1);

      // Installed now: Try again connects.
      source.availabilityResult = HealthAvailability.available;
      await tapKey(tester, 'connect-button');
      await tester.drag(find.byType(ListView), const Offset(0, 2000));
      await tester.pumpAndSettle();
      expect(find.text('Health Connect connected'), findsOneWidget);
    });

    testWidgets('outdated Health Connect offers an update', (tester) async {
      await pumpSource(
        tester,
        sourceWith(availability: HealthAvailability.updateRequired),
      );
      await tapKey(tester, 'connect-button');
      expect(find.text('Health Connect needs an update'), findsOneWidget);
      expect(find.text('Update Health Connect'), findsOneWidget);
    });

    testWidgets('unsupported platform shows no connect button', (tester) async {
      await pumpSource(
        tester,
        sourceWith(availability: HealthAvailability.unsupported),
      );
      await tapKey(tester, 'connect-button');
      expect(find.text('Health Connect is not available'), findsOneWidget);
      expect(find.byKey(const ValueKey('connect-button')), findsNothing);
    });

    testWidgets('an empty week says no data instead of showing zeros', (
      tester,
    ) async {
      await pumpSource(tester, FakeHealthSource());
      await tapKey(tester, 'connect-button');

      expect(find.text('Health Connect connected'), findsOneWidget);
      expect(find.textContaining('Nothing synced yet today'), findsOneWidget);
      expect(find.textContaining('0 steps'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('view-week')));
      await tester.pumpAndSettle();
      expect(
        find.text('No data yet this week'),
        findsNWidgets(StatMetric.values.length),
      );
    });

    group('with a stats repository that misbehaves', () {
      testWidgets('a failed fetch shows a generic error and Retry works', (
        tester,
      ) async {
        final stub = _StubStats(me: () => me)..fail = true;
        await pumpConnectable(tester, stub);
        await tester.pumpAndSettle();

        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.textContaining("Couldn't load your stats"), findsOneWidget);
        expect(find.textContaining('secret'), findsNothing);

        stub.fail = false;
        await tapKey(tester, 'retry-button');
        expect(find.textContaining("Couldn't load your stats"), findsNothing);
        expect(find.byKey(const ValueKey('connect-card')), findsOneWidget);
      });

      testWidgets('leaving the screen while a fetch is pending is safe', (
        tester,
      ) async {
        final gate = Completer<void>();
        final stub = _StubStats(me: () => me)..gate = gate.future;
        await pumpConnectable(tester, stub);
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        gate.complete();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    });
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

/// Stats repository with a switchable failure and a gate to delay fetches.
class _StubStats implements ConnectableStatsRepository {
  _StubStats({required this.me});

  final String Function() me;
  bool fail = false;
  Future<void>? gate;

  @override
  Future<List<DailyStats>> dailyStats(
    String userId, {
    required DateTime from,
    required DateTime to,
  }) async {
    await gate;
    if (fail) throw StateError('secret steps 12345');
    return const [];
  }

  @override
  Future<WeeklySummary> weeklySummary(String userId, {DateTime? weekOf}) async {
    return WeeklySummary.fromDays(
      userId: userId,
      weekStart: weekOf ?? DateTime.now(),
      stats: const [],
    );
  }

  @override
  Future<List<LeaderboardEntry>> leaderboard(
    StatMetric metric, {
    DateTime? weekOf,
    Iterable<String>? userIds,
  }) async => const [];

  @override
  Future<List<LeaderboardEntry>> xpLeaderboard({
    DateTime? weekOf,
    Iterable<String>? userIds,
  }) async => const [];

  @override
  String get sourceName => 'Health Connect';

  @override
  bool get isConnected => false;

  @override
  HealthAvailability? get availability => null;

  @override
  DateTime? get lastSyncedAt => null;

  @override
  Set<StatMetric> get deniedMetrics => const {};

  @override
  Future<bool> connect() async => false;

  @override
  Future<void> openInstallPage() async {}
}
