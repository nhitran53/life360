import 'package:flutter_test/flutter_test.dart';
import 'package:life360/data/health/fake_health_source.dart';
import 'package:life360/data/health/health_source.dart';
import 'package:life360/data/health_stats_repository.dart';
import 'package:life360/data/mock_friends_repository.dart';
import 'package:life360/data/mock_stats_repository.dart';
import 'package:life360/models/models.dart';

void main() {
  final today = DateTime(2026, 3, 11); // Wednesday
  late MockFriendsRepository friends;
  late MockStatsRepository mock;
  late String me;

  setUp(() async {
    friends = MockFriendsRepository();
    mock = MockStatsRepository(friends: friends, clock: () => today);
    me = (await friends.currentUser()).id;
  });

  DailyStats day(
    int d, {
    int steps = 0,
    int sleep = 0,
    int workout = 0,
    int cals = 0,
  }) => DailyStats(
    userId: me,
    date: DateTime(2026, 3, d),
    steps: steps,
    sleepMinutes: sleep,
    workoutMinutes: workout,
    activeCalories: cals,
    screenTimeMinutes: 0,
  );

  HealthStatsRepository repo(FakeHealthSource source) =>
      HealthStatsRepository(source: source, fallback: mock, friends: friends);

  group('FakeHealthSource', () {
    test(
      'returns scripted days in range, oldest first, omitting empty days',
      () async {
        final source = FakeHealthSource(
          stats: [
            day(10, steps: 500),
            day(9, steps: 100),
            day(8),
            day(7, steps: 900),
          ],
        );
        final days = await source.fetchDailyStats(
          me,
          from: DateTime(2026, 3, 8),
          to: DateTime(2026, 3, 10, 22),
        );
        expect(days.map((d) => d.date.day), [9, 10]);
      },
    );

    test('denied metrics read as 0 and never include screen time', () async {
      final source = FakeHealthSource(
        permissionOutcome: {
          StatMetric.steps: HealthPermissionStatus.granted,
          StatMetric.sleep: HealthPermissionStatus.denied,
          StatMetric.workout: HealthPermissionStatus.unknown,
          StatMetric.calories: HealthPermissionStatus.denied,
        },
        stats: [
          DailyStats(
            userId: me,
            date: DateTime(2026, 3, 10),
            steps: 4000,
            sleepMinutes: 400,
            workoutMinutes: 30,
            activeCalories: 250,
            screenTimeMinutes: 90,
          ),
        ],
      );
      final d = (await source.fetchDailyStats(
        me,
        from: DateTime(2026, 3, 10),
        to: DateTime(2026, 3, 10),
      )).single;
      expect(d.steps, 4000);
      expect(d.sleepMinutes, 0);
      expect(d.workoutMinutes, 30);
      expect(d.activeCalories, 0);
      expect(d.screenTimeMinutes, 0);
    });

    test('everything denied or unavailable yields no days', () async {
      final denied = FakeHealthSource(
        permissionOutcome: {
          for (final m in [StatMetric.steps, StatMetric.sleep])
            m: HealthPermissionStatus.denied,
        },
        stats: [day(10, steps: 10)],
      );
      expect(await denied.fetchDailyStats(me, from: today, to: today), isEmpty);
      final missing = FakeHealthSource(
        availabilityResult: HealthAvailability.notInstalled,
        stats: [day(10, steps: 10)],
      );
      expect(
        await missing.fetchDailyStats(
          me,
          from: DateTime(2026, 3, 1),
          to: today,
        ),
        isEmpty,
      );
    });
  });

  group('HealthStatsRepository', () {
    test('uses the fallback until connected', () async {
      final source = FakeHealthSource(stats: [day(10, steps: 1234)]);
      final r = repo(source);
      final expected = await mock.dailyStats(
        me,
        from: DateTime(2026, 3, 9),
        to: today,
      );
      expect(
        await r.dailyStats(me, from: DateTime(2026, 3, 9), to: today),
        expected,
      );
      expect(source.fetchCalls, 0);
      expect(r.isConnected, isFalse);
    });

    test('serves the current user from health after connect', () async {
      final source = FakeHealthSource(
        stats: [day(9, steps: 1000), day(10, steps: 2000, sleep: 420)],
      );
      final r = repo(source);
      expect(await r.connect(), isTrue);
      expect(source.requestPermissionsCalls, 1);
      final days = await r.dailyStats(
        me,
        from: DateTime(2026, 3, 9),
        to: DateTime(2026, 3, 10),
      );
      expect(days.map((d) => d.steps), [1000, 2000]);
    });

    test('friends still come from the fallback after connect', () async {
      final r = repo(FakeHealthSource(stats: [day(10, steps: 1)]));
      await r.connect();
      final friendId = (await friends.friends()).first.id;
      final expected = await mock.dailyStats(
        friendId,
        from: DateTime(2026, 3, 9),
        to: today,
      );
      expect(
        await r.dailyStats(friendId, from: DateTime(2026, 3, 9), to: today),
        expected,
      );
    });

    test(
      'connect fails and keeps the fallback when health is unavailable',
      () async {
        final source = FakeHealthSource(
          availabilityResult: HealthAvailability.notInstalled,
        );
        final r = repo(source);
        expect(await r.connect(), isFalse);
        expect(source.requestPermissionsCalls, 0);
        expect(r.isConnected, isFalse);
      },
    );

    test('connect fails when every permission is denied', () async {
      final source = FakeHealthSource(
        permissionOutcome: {
          StatMetric.steps: HealthPermissionStatus.denied,
          StatMetric.sleep: HealthPermissionStatus.denied,
        },
      );
      final r = repo(source);
      expect(await r.connect(), isFalse);
      expect(r.isConnected, isFalse);
    });

    test('partial permissions still connect', () async {
      final source = FakeHealthSource(
        permissionOutcome: {
          StatMetric.steps: HealthPermissionStatus.granted,
          StatMetric.sleep: HealthPermissionStatus.denied,
        },
        stats: [day(9, steps: 700, sleep: 480)],
      );
      final r = repo(source);
      expect(await r.connect(), isTrue);
      final d = (await r.dailyStats(
        me,
        from: DateTime(2026, 3, 9),
        to: today,
      )).single;
      expect(d.steps, 700);
      expect(d.sleepMinutes, 0);
    });

    test('weekly summary covers Monday to Sunday of the week', () async {
      final source = FakeHealthSource(
        stats: [
          day(8, steps: 1000), // Sunday of the previous week
          day(9, steps: 2000), // Monday
          day(11, steps: 4000, workout: 30),
          day(16, steps: 8000), // Monday of the next week
        ],
      );
      final r = repo(source);
      await r.connect();
      final week = await r.weeklySummary(me, weekOf: today);
      expect(week.total(StatMetric.steps), 6000);
      expect(week.daysTracked, 2);
    });

    test(
      'leaderboard ranks the health-backed user among mock friends',
      () async {
        final source = FakeHealthSource(stats: [day(9, steps: 5000000)]);
        final r = repo(source);
        await r.connect();
        final board = await r.leaderboard(StatMetric.steps, weekOf: today);
        expect(board.first.user.id, me);
        expect(board.first.rank, 1);
        expect(board.length, (await friends.friends()).length + 1);
      },
    );

    test('xp leaderboard ranks the health-backed user among friends', () async {
      final source = FakeHealthSource(stats: [day(9, steps: 5000, workout: 10)]);
      final r = repo(source);
      await r.connect();
      final board = await r.xpLeaderboard(weekOf: today);
      expect(board.length, (await friends.friends()).length + 1);
      // 50 XP for steps + 20 XP for workout minutes.
      expect(board.firstWhere((e) => e.user.id == me).value, 70);
    });

    test('reports the source name, availability and sync time', () async {
      final r = HealthStatsRepository(
        source: FakeHealthSource(displayName: 'Apple Health'),
        fallback: mock,
        friends: friends,
        clock: () => today,
      );
      expect(r.sourceName, 'Apple Health');
      expect(r.availability, isNull);
      expect(r.lastSyncedAt, isNull);
      await r.connect();
      expect(r.availability, HealthAvailability.available);
      expect(r.lastSyncedAt, today);
    });

    test('lists denied metrics, but not unknown (iOS) ones', () async {
      final r = repo(
        FakeHealthSource(
          permissionOutcome: {
            StatMetric.steps: HealthPermissionStatus.granted,
            StatMetric.sleep: HealthPermissionStatus.denied,
            StatMetric.workout: HealthPermissionStatus.unknown,
            StatMetric.calories: HealthPermissionStatus.denied,
          },
        ),
      );
      expect(r.deniedMetrics, isEmpty);
      await r.connect();
      expect(r.deniedMetrics, {StatMetric.sleep, StatMetric.calories});
    });

    test('a failed re-sync drops back to the fallback', () async {
      final source = FakeHealthSource(stats: [day(9, steps: 1)]);
      final r = repo(source);
      expect(await r.connect(), isTrue);
      source.availabilityResult = HealthAvailability.notInstalled;
      expect(await r.connect(), isFalse);
      expect(r.isConnected, isFalse);
      expect(r.availability, HealthAvailability.notInstalled);
    });

    test('openInstallPage goes to the source', () async {
      final source = FakeHealthSource();
      await repo(source).openInstallPage();
      expect(source.openInstallPageCalls, 1);
    });
  });
}
