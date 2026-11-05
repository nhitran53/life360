import 'package:flutter_test/flutter_test.dart';
import 'package:life360/data/health/health_aggregation.dart';

HealthInterval sleep(DateTime s, DateTime e) =>
    HealthInterval(HealthIntervalKind.asleep, s, e);
HealthInterval session(DateTime s, DateTime e) =>
    HealthInterval(HealthIntervalKind.sleepSession, s, e);
HealthInterval workout(DateTime s, DateTime e) =>
    HealthInterval(HealthIntervalKind.workout, s, e);

void main() {
  final tuesday = DateTime(2026, 3, 10);

  group('sleepMinutesForDay', () {
    test('a night across midnight counts fully for the wake-up day', () {
      final night = [sleep(DateTime(2026, 3, 9, 23), DateTime(2026, 3, 10, 7))];
      expect(sleepMinutesForDay(night, tuesday), 8 * 60);
      expect(sleepMinutesForDay(night, DateTime(2026, 3, 9)), 0);
      expect(sleepMinutesForDay(night, DateTime(2026, 3, 11)), 0);
    });

    test('stages ending before midnight stay with the wake-up day', () {
      final night = [
        sleep(DateTime(2026, 3, 9, 21), DateTime(2026, 3, 9, 23, 30)),
        sleep(DateTime(2026, 3, 9, 23, 30), DateTime(2026, 3, 10, 6)),
      ];
      expect(sleepMinutesForDay(night, tuesday), 9 * 60);
    });

    test('overlapping sources are merged, not summed', () {
      final overlap = [
        sleep(DateTime(2026, 3, 9, 23), DateTime(2026, 3, 10, 6)),
        sleep(DateTime(2026, 3, 9, 23, 30), DateTime(2026, 3, 10, 7)),
      ];
      expect(sleepMinutesForDay(overlap, tuesday), 8 * 60);
    });

    test('sessions are used only when there are no stages', () {
      final s = session(DateTime(2026, 3, 9, 23), DateTime(2026, 3, 10, 7));
      final stage = sleep(
        DateTime(2026, 3, 9, 23, 30),
        DateTime(2026, 3, 10, 6),
      );
      expect(sleepMinutesForDay([s], tuesday), 8 * 60);
      expect(sleepMinutesForDay([s, stage], tuesday), 6 * 60 + 30);
    });

    test('a daytime nap counts for its own day', () {
      final nap = [sleep(DateTime(2026, 3, 10, 14), DateTime(2026, 3, 10, 15))];
      expect(sleepMinutesForDay(nap, tuesday), 60);
    });

    test('empty or inverted intervals count as nothing', () {
      final t = DateTime(2026, 3, 10, 3);
      expect(sleepMinutesForDay([], tuesday), 0);
      expect(sleepMinutesForDay([sleep(t, t)], tuesday), 0);
      expect(
        sleepMinutesForDay([
          sleep(t, t.subtract(const Duration(hours: 1))),
        ], tuesday),
        0,
      );
    });
  });

  group('workoutMinutesForDay', () {
    test('sums separate workouts', () {
      final w = [
        workout(DateTime(2026, 3, 10, 7), DateTime(2026, 3, 10, 7, 30)),
        workout(DateTime(2026, 3, 10, 18), DateTime(2026, 3, 10, 19)),
      ];
      expect(workoutMinutesForDay(w, tuesday), 90);
    });

    test('overlapping workouts are merged', () {
      final w = [
        workout(DateTime(2026, 3, 10, 7), DateTime(2026, 3, 10, 8)),
        workout(DateTime(2026, 3, 10, 7, 30), DateTime(2026, 3, 10, 8, 15)),
      ];
      expect(workoutMinutesForDay(w, tuesday), 75);
    });

    test('a workout across midnight is clipped to each day', () {
      final w = [
        workout(DateTime(2026, 3, 10, 23, 30), DateTime(2026, 3, 11, 0, 45)),
      ];
      expect(workoutMinutesForDay(w, tuesday), 30);
      expect(workoutMinutesForDay(w, DateTime(2026, 3, 11)), 45);
    });

    test('ignores sleep intervals', () {
      final s = [sleep(DateTime(2026, 3, 10, 1), DateTime(2026, 3, 10, 5))];
      expect(workoutMinutesForDay(s, tuesday), 0);
    });

    test('day length follows local midnight on a DST day', () {
      // Whole-day workout: minutes equal the real length of the local day.
      final w = [workout(DateTime(2026, 3, 8), DateTime(2026, 3, 9))];
      final expected = DateTime(
        2026,
        3,
        9,
      ).difference(DateTime(2026, 3, 8)).inMinutes;
      expect(workoutMinutesForDay(w, DateTime(2026, 3, 8)), expected);
    });
  });
}
