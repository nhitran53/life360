import 'package:flutter_test/flutter_test.dart';
import 'package:life360/data/health_aggregation.dart';
import 'package:life360/data/health_source.dart';
import 'package:life360/data/health_stats_repository.dart';
import 'package:life360/data/health_sync.dart';
import 'package:life360/data/mock_data.dart';
import 'package:life360/data/mock_friends_repository.dart';
import 'package:life360/data/mock_health_source.dart';
import 'package:life360/data/mock_stats_repository.dart';
import 'package:life360/models/models.dart';

void main() {
  // A Wednesday afternoon.
  final now = DateTime(2026, 11, 4, 15, 30);
  DateTime clock() => now;
  final today = DateTime(2026, 11, 4);
  final yesterday = DateTime(2026, 11, 3);

  group('buildDailyStats', () {
    test('one entry per day, zeros where nothing was recorded', () {
      final days = buildDailyStats(
        userId: 'u',
        from: yesterday,
        to: now,
        stepsByDay: {today: 4200},
      );
      expect(days.map((d) => d.date), [yesterday, today]);
      expect(days.first.steps, 0);
      expect(days.last.steps, 4200);
    });

    test('sleep counts for the morning you woke up', () {
      final days = buildDailyStats(
        userId: 'u',
        from: yesterday,
        to: today,
        sleep: [
          HealthSpan(DateTime(2026, 11, 3, 23, 0), DateTime(2026, 11, 4, 3)),
          HealthSpan(DateTime(2026, 11, 4, 3, 20), DateTime(2026, 11, 4, 7)),
        ],
      );
      expect(days.first.sleepMinutes, 0);
      expect(days.last.sleepMinutes, 240 + 220);
    });

    test('workouts and active energy count for the day they started', () {
      final days = buildDailyStats(
        userId: 'u',
        from: yesterday,
        to: today,
        workouts: [
          HealthSpan(
            DateTime(2026, 11, 3, 23, 30),
            DateTime(2026, 11, 4, 0, 15),
          ),
        ],
        activeEnergy: [
          HealthSpan(
            DateTime(2026, 11, 4, 9),
            DateTime(2026, 11, 4, 10),
            120.4,
          ),
          HealthSpan(
            DateTime(2026, 11, 4, 12),
            DateTime(2026, 11, 4, 13),
            80.3,
          ),
        ],
      );
      expect(days.first.workoutMinutes, 45);
      expect(days.last.workoutMinutes, 0);
      expect(days.last.activeCalories, 201);
    });
  });

  group('HealthSync', () {
    test('starts disconnected and connects on request', () async {
      final source = MockHealthSource(
        days: {today: DailyStats(userId: 'x', date: today, steps: 6120)},
      );
      final sync = HealthSync(source, userId: 'u_me', clock: clock);
      addTearDown(sync.dispose);

      await sync.start();
      expect(sync.connection, HealthConnection.notConnected);
      expect(sync.today, isNull);

      expect(await sync.connect(), isTrue);
      expect(sync.isConnected, isTrue);
      expect(sync.days, hasLength(14));
      expect(sync.today!.steps, 6120);
      expect(sync.today!.userId, 'u_me');
      expect(sync.lastSynced, now);
    });

    test('stays disconnected when access is denied', () async {
      final sync = HealthSync(
        MockHealthSource(grantOnConnect: false),
        userId: 'u_me',
        clock: clock,
      );
      addTearDown(sync.dispose);

      expect(await sync.connect(), isFalse);
      expect(sync.connection, HealthConnection.notConnected);
      expect(sync.days, isEmpty);
    });

    test('disconnect forgets synced data', () async {
      final sync = HealthSync(
        MockHealthSource(initial: HealthConnection.connected),
        userId: 'u_me',
        clock: clock,
      );
      addTearDown(sync.dispose);

      await sync.start();
      expect(sync.days, isNotEmpty);

      await sync.disconnect();
      expect(sync.isConnected, isFalse);
      expect(sync.days, isEmpty);
      expect(sync.lastSynced, isNull);
    });
  });

  group('HealthStatsRepository', () {
    late MockFriendsRepository friends;
    late MockStatsRepository mock;

    setUp(() {
      friends = MockFriendsRepository(clock: clock);
      mock = MockStatsRepository(friends: friends, clock: clock);
    });

    Future<HealthStatsRepository> repo({required bool connected}) async {
      final sync = HealthSync(
        MockHealthSource(
          initial: connected
              ? HealthConnection.connected
              : HealthConnection.notConnected,
          days: {today: DailyStats(userId: 'x', date: today, steps: 123456)},
        ),
        userId: mockMe.id,
        clock: clock,
      );
      addTearDown(sync.dispose);
      await sync.start();
      return HealthStatsRepository(
        fallback: mock,
        friends: friends,
        health: sync,
        clock: clock,
      );
    }

    test('uses mock data until health is connected', () async {
      final stats = await repo(connected: false);
      final mine = await stats.weeklySummary(mockMe.id);
      final expected = await mock.weeklySummary(mockMe.id);
      expect(mine.total(StatMetric.steps), expected.total(StatMetric.steps));
    });

    test('ranks you with your real numbers once connected', () async {
      final stats = await repo(connected: true);

      final mine = await stats.weeklySummary(mockMe.id);
      // Blank days (watch not worn) are left out of the week.
      expect(mine.daysTracked, 1);
      expect(mine.total(StatMetric.steps), 123456);

      final board = await stats.leaderboard(StatMetric.steps);
      expect(board.first.user.id, mockMe.id);
      expect(board.first.rank, 1);

      // Friends still come from the fallback.
      final friend = (await friends.friends()).first;
      expect(
        (await stats.weeklySummary(friend.id)).total(StatMetric.steps),
        (await mock.weeklySummary(friend.id)).total(StatMetric.steps),
      );
    });
  });
}
