import 'package:flutter_test/flutter_test.dart';
import 'package:life360/models/models.dart';

void main() {
  const goals = DailyGoals();
  final today = DateTime(2026, 11, 4);

  DailyStats day(int daysAgo, {int steps = 0, int workout = 0}) => DailyStats(
    userId: 'u',
    date: DateTime(today.year, today.month, today.day - daysAgo),
    steps: steps,
    workoutMinutes: workout,
  );

  group('DailyGoals', () {
    test('more-is-better stats hit at or above the target', () {
      expect(goals.isHit(StatMetric.steps, 7999), isFalse);
      expect(goals.isHit(StatMetric.steps, 8000), isTrue);
      expect(goals.isHit(StatMetric.sleep, 420), isTrue);
    });

    test('screen time hits when tracked and under the limit', () {
      expect(goals.isHit(StatMetric.screenTime, 0), isFalse);
      expect(goals.isHit(StatMetric.screenTime, 180), isTrue);
      expect(goals.isHit(StatMetric.screenTime, 181), isFalse);
    });

    test('progress is clamped to 0..1', () {
      expect(goals.progress(StatMetric.steps, 4000), 0.5);
      expect(goals.progress(StatMetric.steps, 20000), 1.0);
    });
  });

  group('currentStreak', () {
    test('counts back through active days', () {
      final days = [
        day(0, steps: 9000),
        day(1, workout: 45),
        day(2, steps: 8000),
        day(3, steps: 100),
        day(4, steps: 9000),
      ];
      expect(currentStreak(days, today: today), 3);
    });

    test("an unfinished today doesn't break the streak", () {
      final days = [
        day(0, steps: 200),
        day(1, steps: 9000),
        day(2, steps: 9000),
      ];
      expect(currentStreak(days, today: today), 2);
    });

    test('a missing day ends the streak', () {
      final days = [day(0, steps: 9000), day(2, steps: 9000)];
      expect(currentStreak(days, today: today), 1);
    });

    test('no data means no streak', () {
      expect(currentStreak([], today: today), 0);
    });
  });
}
