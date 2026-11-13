import 'package:flutter_test/flutter_test.dart';
import 'package:life360/app_services.dart';
import 'package:life360/data/device_screen_time.dart';
import 'package:life360/data/health/fake_health_source.dart';
import 'package:life360/data/health_stats_repository.dart';
import 'package:life360/data/manual_screen_time_repository.dart';
import 'package:life360/data/mock_data.dart';
import 'package:life360/data/mock_friends_repository.dart';
import 'package:life360/data/mock_stats_repository.dart';
import 'package:life360/data/screen_time_log.dart';
import 'package:life360/models/models.dart';

void main() {
  // A Wednesday afternoon.
  final now = DateTime(2026, 11, 4, 15);
  final today = dateOnly(now);
  DateTime clock() => now;

  group('InMemoryScreenTimeLog', () {
    test('stores one total per day and returns a range', () async {
      final log = InMemoryScreenTimeLog();
      await log.setMinutes(DateTime(2026, 11, 3, 22, 30), 90);
      await log.setMinutes(today, 150);
      await log.setMinutes(today, 120); // replaces

      expect(await log.entries(from: today, to: today), {today: 120});
      expect(await log.entries(from: DateTime(2026, 11, 1), to: today), {
        DateTime(2026, 11, 3): 90,
        today: 120,
      });
    });

    test('0 clears a day', () async {
      final log = InMemoryScreenTimeLog();
      await log.setMinutes(today, 60);
      await log.setMinutes(today, 0);
      expect(await log.entries(from: today, to: today), isEmpty);
    });

    test('rejects values outside 0 to 24 hours', () async {
      final log = InMemoryScreenTimeLog();
      expect(() => log.setMinutes(today, -1), throwsArgumentError);
      expect(
        () => log.setMinutes(today, ScreenTimeLog.maxMinutes + 1),
        throwsArgumentError,
      );
      await log.setMinutes(today, ScreenTimeLog.maxMinutes);
    });
  });

  group('ManualScreenTimeRepository', () {
    late MockFriendsRepository friends;
    late HealthStatsRepository health;
    late InMemoryScreenTimeLog log;
    late ManualScreenTimeRepository repo;

    // Health only has steps for today, never screen time.
    setUp(() {
      friends = MockFriendsRepository(clock: clock);
      health = HealthStatsRepository(
        source: FakeHealthSource(
          stats: [DailyStats(userId: mockMe.id, date: today, steps: 5000)],
        ),
        fallback: MockStatsRepository(friends: friends, clock: clock),
        friends: friends,
        clock: clock,
      );
      log = InMemoryScreenTimeLog();
      repo = ManualScreenTimeRepository(
        inner: health,
        friends: friends,
        log: log,
        clock: clock,
      );
    });

    test('merges a logged day into my stats, keeping the rest', () async {
      await health.connect();
      await log.setMinutes(today, 95);

      final day = (await repo.dailyStats(
        mockMe.id,
        from: today,
        to: today,
      )).single;
      expect(day.screenTimeMinutes, 95);
      expect(day.steps, 5000);
    });

    test('a logged day with no other data still shows up', () async {
      await health.connect();
      final yesterday = DateTime(2026, 11, 3);
      await log.setMinutes(yesterday, 200);

      final days = await repo.dailyStats(mockMe.id, from: yesterday, to: today);
      expect(days.map((d) => d.date), [yesterday, today]);
      expect(days.first.screenTimeMinutes, 200);
      expect(days.first.steps, 0);
    });

    test("friends' stats are untouched", () async {
      await log.setMinutes(today, 10);
      final friend = (await friends.friends()).first;

      expect(
        await repo.dailyStats(friend.id, from: today, to: today),
        await health.dailyStats(friend.id, from: today, to: today),
      );
    });

    test('weekly summary and the screen time board use the entry', () async {
      await health.connect();
      await log.setMinutes(today, 30);

      final week = await repo.weeklySummary(mockMe.id, weekOf: now);
      expect(week.total(StatMetric.screenTime), 30);

      final board = await repo.leaderboard(StatMetric.screenTime, weekOf: now);
      final me = board.singleWhere((e) => e.user.id == mockMe.id);
      expect(me.value, 30);
      // Least screen time wins, and 30 min a day beats every mock friend.
      expect(me.rank, 1);
    });

    test('logging under the limit earns the screen time XP', () async {
      await health.connect();
      final before = (await repo.xpLeaderboard(weekOf: now))
          .singleWhere((e) => e.user.id == mockMe.id)
          .value;

      await log.setMinutes(today, 60);
      final after = (await repo.xpLeaderboard(weekOf: now))
          .singleWhere((e) => e.user.id == mockMe.id)
          .value;

      expect(after - before, XpRules.lowScreenTimeXp);
    });

    test('screen time is never reported as denied', () async {
      expect(repo.deniedMetrics, isNot(contains(StatMetric.screenTime)));
    });
  });

  group('screen time from the device', () {
    late MockFriendsRepository friends;
    late HealthStatsRepository health;
    late InMemoryScreenTimeLog log;
    late FakeDeviceScreenTime device;
    late ManualScreenTimeRepository repo;
    final yesterday = DateTime(2026, 11, 3);

    setUp(() async {
      friends = MockFriendsRepository(clock: clock);
      health = HealthStatsRepository(
        source: FakeHealthSource(
          stats: [DailyStats(userId: mockMe.id, date: today, steps: 5000)],
        ),
        fallback: MockStatsRepository(friends: friends, clock: clock),
        friends: friends,
        clock: clock,
      );
      await health.connect();
      log = InMemoryScreenTimeLog();
      device = FakeDeviceScreenTime(minutes: {yesterday: 210, today: 75});
      repo = ManualScreenTimeRepository(
        inner: health,
        friends: friends,
        log: log,
        device: device,
        clock: clock,
      );
    });

    test('fills my screen time from the phone once access is on', () async {
      final days = await repo.dailyStats(mockMe.id, from: yesterday, to: today);

      expect(days.map((d) => d.date), [yesterday, today]);
      expect(days.first.screenTimeMinutes, 210);
      expect(days.last.screenTimeMinutes, 75);
      expect(days.last.steps, 5000);
    });

    test('a logged day wins over what the phone measured', () async {
      await log.setMinutes(today, 30);

      final day = (await repo.dailyStats(
        mockMe.id,
        from: today,
        to: today,
      )).single;
      expect(day.screenTimeMinutes, 30);
    });

    test('nothing is read without usage access', () async {
      device.access = false;

      final day = (await repo.dailyStats(
        mockMe.id,
        from: today,
        to: today,
      )).single;
      expect(day.screenTimeMinutes, 0);
      expect(device.reads, 0);
    });

    test("friends never get this phone's screen time", () async {
      final friend = (await friends.friends()).first;

      expect(
        await repo.dailyStats(friend.id, from: today, to: today),
        await health.dailyStats(friend.id, from: today, to: today),
      );
      expect(device.reads, 0);
    });
  });

  test(
    'AppServices merges logged screen time into what screens read',
    () async {
      final friends = MockFriendsRepository(clock: clock);
      final services = AppServices(
        friends: friends,
        stats: HealthStatsRepository(
          source: FakeHealthSource(stats: const []),
          fallback: MockStatsRepository(friends: friends, clock: clock),
          friends: friends,
          clock: clock,
        ),
      );
      await services.screenTime.setMinutes(today, 42);

      final day = (await services.stats.dailyStats(
        mockMe.id,
        from: today,
        to: today,
      )).single;
      expect(day.screenTimeMinutes, 42);
    },
  );
}
