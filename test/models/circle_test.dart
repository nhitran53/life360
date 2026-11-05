import 'package:flutter_test/flutter_test.dart';
import 'package:life360/models/models.dart';

LeaderboardEntry entry(String id, int rank, double value, StatMetric m) =>
    LeaderboardEntry(
      rank: rank,
      user: UserProfile(
        id: id,
        displayName: id,
        username: id,
        avatarEmoji: '🙂',
        friendCode: id,
      ),
      metric: m,
      value: value,
    );

DailyStats day(DateTime d, {int steps = 0, int workout = 0, int sleep = 0}) =>
    DailyStats(
      userId: 'u',
      date: d,
      steps: steps,
      workoutMinutes: workout,
      sleepMinutes: sleep,
    );

void main() {
  group('Circle JSON', () {
    test('round-trips with and without a reward', () {
      const c = Circle(
        id: 'c1',
        name: 'Gym',
        type: CircleType.friends,
        ownerId: 'a',
        memberIds: ['a', 'b'],
        inviteCode: 'X1',
        rewardText: 'Pick dinner',
      );
      final back = Circle.fromJson(c.toJson());
      expect(back.toJson(), c.toJson());
      expect(c.copyWith(clearReward: true).toJson()['rewardText'], isNull);
    });

    test('CircleReward round-trips', () {
      final r = CircleReward(
        circleId: 'c1',
        text: 'Pick dinner',
        metric: RewardMetric.workout,
        weekStart: DateTime(2026, 11, 2),
        winnerIds: const ['a', 'b'],
      );
      expect(CircleReward.fromJson(r.toJson()).toJson(), r.toJson());
    });

    test('rewards can only be decided on steps or workouts', () {
      expect(RewardMetric.values.map((m) => m.stat), [
        StatMetric.steps,
        StatMetric.workout,
      ]);
    });
  });

  group('rewardWinners', () {
    test('everyone tied for first wins', () {
      final w = rewardWinners(RewardMetric.steps, [
        entry('a', 1, 500, StatMetric.steps),
        entry('b', 1, 500, StatMetric.steps),
        entry('c', 3, 100, StatMetric.steps),
      ]);
      expect(w, ['a', 'b']);
    });

    test('an empty week has no winner', () {
      expect(
        rewardWinners(RewardMetric.steps, [entry('a', 1, 0, StatMetric.steps)]),
        isEmpty,
      );
    });

    test('rejects a leaderboard for another metric', () {
      expect(
        () => rewardWinners(RewardMetric.steps, [
          entry('a', 1, 5, StatMetric.sleep),
        ]),
        throwsArgumentError,
      );
    });
  });

  group('badges', () {
    final mon = DateTime(2026, 11, 2);
    DateTime d(int i) => DateTime(mon.year, mon.month, mon.day + i);

    test('longestStreak counts consecutive active days, gaps end it', () {
      final days = [
        for (final i in [0, 1, 2, 4, 5]) day(d(i), steps: 9000),
        day(d(3), steps: 100),
      ];
      expect(longestStreak(days), 3);
      expect(
        longestStreak([day(d(0), steps: 9000), day(d(2), steps: 9000)]),
        1,
      );
      expect(longestStreak(const []), 0);
    });

    test('streak badges', () {
      final three = [for (var i = 0; i < 3; i++) day(d(i), steps: 9000)];
      expect(earnedBadges(three), [
        RewardBadge.firstActiveDay,
        RewardBadge.threeDayStreak,
      ]);
      final seven = [for (var i = 0; i < 7; i++) day(d(i), steps: 9000)];
      expect(earnedBadges(seven), contains(RewardBadge.sevenDayStreak));
    });

    test('workout week needs 3 workout days in one calendar week', () {
      final inWeek = [
        for (final i in [0, 2, 4]) day(d(i), workout: 40),
      ];
      expect(earnedBadges(inWeek), contains(RewardBadge.workoutWeek));
      final split = [
        for (final i in [5, 6, 7]) day(d(i), workout: 40),
      ];
      expect(earnedBadges(split), isNot(contains(RewardBadge.workoutWeek)));
    });

    test('the same day repeated does not make a workout week', () {
      final dup = [for (var i = 0; i < 3; i++) day(d(0), workout: 40)];
      expect(earnedBadges(dup), isNot(contains(RewardBadge.workoutWeek)));
    });

    test('sleep alone earns nothing', () {
      expect(earnedBadges([day(d(0), sleep: 600)]), isEmpty);
    });
  });
}
