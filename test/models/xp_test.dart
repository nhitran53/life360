import 'package:flutter_test/flutter_test.dart';
import 'package:life360/models/models.dart';

void main() {
  final monday = DateTime(2026, 11, 2);
  DailyStats day(int offset,
          {int steps = 0, int sleep = 0, int workout = 0, int screen = 0}) =>
      DailyStats(
        userId: 'u',
        date: monday.add(Duration(days: offset)),
        steps: steps,
        sleepMinutes: sleep,
        workoutMinutes: workout,
        screenTimeMinutes: screen,
      );

  group('dailyXp', () {
    test('adds steps, workout, sleep and screen time', () {
      // 85 + 60 + 30 + 30
      expect(dailyXp(day(0, steps: 8500, workout: 30, sleep: 450, screen: 120)),
          205);
    });

    test('caps steps and workouts per day', () {
      expect(dailyXp(day(0, steps: 50000)), XpRules.maxStepXpPerDay);
      expect(dailyXp(day(0, workout: 300)),
          XpRules.maxWorkoutMinutesPerDay * XpRules.xpPerWorkoutMinute);
    });

    test('untracked screen time earns nothing', () {
      expect(dailyXp(day(0)), 0);
    });
  });

  test('rankLeaderboardByXp ranks by weekly XP with null metric', () {
    const a = UserProfile(
        id: 'a', displayName: 'A', username: 'a', avatarEmoji: '🙂', friendCode: 'A');
    const b = UserProfile(
        id: 'b', displayName: 'B', username: 'b', avatarEmoji: '🙂', friendCode: 'B');
    WeeklySummary week(String id, int steps) => WeeklySummary.fromDays(
          userId: id,
          weekStart: monday,
          stats: [
            DailyStats(userId: id, date: monday, steps: steps),
          ],
        );

    final board = rankLeaderboardByXp({a: week('a', 3000), b: week('b', 9000)});
    expect(board.map((e) => e.user.id), ['b', 'a']);
    expect(board.first.value, 90);
    expect(board.first.metric, isNull);
    expect(board.map((e) => e.rank), [1, 2]);
  });
}
