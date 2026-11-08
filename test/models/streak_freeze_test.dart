import 'package:flutter_test/flutter_test.dart';
import 'package:life360/models/models.dart';

void main() {
  final today = DateTime(2026, 11, 20);
  DateTime ago(int n) => DateTime(today.year, today.month, today.day - n);

  DailyStats active(int daysAgo) =>
      DailyStats(userId: 'u', date: ago(daysAgo), steps: 9000);
  DailyStats lazy(int daysAgo) =>
      DailyStats(userId: 'u', date: ago(daysAgo), steps: 100);

  /// Active every day from [from] days ago to [to] days ago (inclusive).
  List<DailyStats> activeRun(int from, int to) => [
    for (var i = from; i >= to; i--) active(i),
  ];

  group('streakWithFreezes', () {
    test('no data means no streak', () {
      expect(streakWithFreezes(const [], today: today), StreakStatus.none);
    });

    test('without a freeze it matches currentStreak', () {
      final days = [...activeRun(10, 6), lazy(5), ...activeRun(4, 0)];
      final status = streakWithFreezes(days, today: today);
      expect(status.days, currentStreak(days, today: today));
      expect(status.days, 5);
      expect(status.freezesLeft, 0);
      expect(status.frozenDays, isEmpty);
    });

    test('7 active days in a row earn a freeze', () {
      expect(streakWithFreezes(activeRun(5, 0), today: today).freezesLeft, 0);
      final status = streakWithFreezes(activeRun(6, 0), today: today);
      expect(status.days, 7);
      expect(status.freezesLeft, 1);
    });

    test('a banked freeze covers a missed day', () {
      final days = [...activeRun(10, 4), lazy(3), ...activeRun(2, 0)];
      final status = streakWithFreezes(days, today: today);
      // 7 days, then the freeze bridges day 3, then 3 more days.
      expect(status.days, 10);
      expect(status.freezesLeft, 0);
      expect(status.frozenDays, [ago(3)]);
      expect(currentStreak(days, today: today), 3);
    });

    test('a freeze also covers a day with no data', () {
      final days = [...activeRun(10, 4), ...activeRun(2, 0)];
      final status = streakWithFreezes(days, today: today);
      expect(status.days, 10);
      expect(status.frozenDays, [ago(3)]);
    });

    test('two missed days in a row with one freeze still break it', () {
      final days = [...activeRun(12, 5), lazy(4), lazy(3), ...activeRun(2, 0)];
      final status = streakWithFreezes(days, today: today);
      expect(status.days, 3);
      expect(status.freezesLeft, 0);
      expect(status.frozenDays, isEmpty);
    });

    test('you bank at most ${StreakFreezeRules.maxFreezes} freezes', () {
      final status = streakWithFreezes(activeRun(29, 0), today: today);
      expect(status.days, 30);
      expect(status.freezesLeft, StreakFreezeRules.maxFreezes);
    });

    test("an unfinished today doesn't use a freeze", () {
      final days = [...activeRun(7, 1), lazy(0)];
      final status = streakWithFreezes(days, today: today);
      expect(status.days, 7);
      expect(status.freezesLeft, 1);
      expect(status.frozenDays, isEmpty);
    });

    test('days after today are ignored', () {
      final days = [...activeRun(2, 0), active(-1), active(-2)];
      expect(streakWithFreezes(days, today: today).days, 3);
    });

    test('respects custom goals', () {
      final days = [for (var i = 2; i >= 0; i--) lazy(i)];
      expect(streakWithFreezes(days, today: today).days, 0);
      expect(
        streakWithFreezes(
          days,
          today: today,
          goals: const DailyGoals(steps: 50),
        ).days,
        3,
      );
    });

    test("toString doesn't leak health values", () {
      final s = streakWithFreezes(activeRun(2, 0), today: today).toString();
      expect(s, isNot(contains('9000')));
    });
  });
}
