import '../models/models.dart';

/// A reading from the health hub: a time span and, for energy, a value.
///
/// Kept free of `package:health` types so the daily-total rules can be unit
/// tested without the plugin.
class HealthSpan {
  const HealthSpan(this.start, this.end, [this.value = 0]);

  final DateTime start;
  final DateTime end;

  /// kcal for active energy; unused for sleep and workouts (we use the span).
  final num value;

  int get minutes => end.difference(start).inMinutes;
}

/// Turns raw readings into one [DailyStats] per day from [from] to [to].
///
/// - [stepsByDay]: already-deduplicated totals keyed by local midnight
///   (phone + watch both count steps, so we never sum raw step samples).
/// - [activeEnergy]: summed into the day it started.
/// - [workouts]: duration summed into the day it started.
/// - [sleep]: duration summed into the day it *ended*, so last night's sleep
///   counts for this morning.
List<DailyStats> buildDailyStats({
  required String userId,
  required DateTime from,
  required DateTime to,
  Map<DateTime, int> stepsByDay = const {},
  Iterable<HealthSpan> activeEnergy = const [],
  Iterable<HealthSpan> workouts = const [],
  Iterable<HealthSpan> sleep = const [],
}) {
  final first = dateOnly(from);
  final last = dateOnly(to);

  final calories = <DateTime, double>{};
  final workoutMinutes = <DateTime, int>{};
  final sleepMinutes = <DateTime, int>{};

  for (final s in activeEnergy) {
    final day = dateOnly(s.start);
    calories[day] = (calories[day] ?? 0) + s.value.toDouble();
  }
  for (final s in workouts) {
    final day = dateOnly(s.start);
    workoutMinutes[day] = (workoutMinutes[day] ?? 0) + _nonNegative(s.minutes);
  }
  for (final s in sleep) {
    final day = dateOnly(s.end);
    sleepMinutes[day] = (sleepMinutes[day] ?? 0) + _nonNegative(s.minutes);
  }

  return [
    for (
      var day = first;
      !day.isAfter(last);
      day = DateTime(day.year, day.month, day.day + 1)
    )
      DailyStats(
        userId: userId,
        date: day,
        steps: _nonNegative(stepsByDay[day] ?? 0),
        activeCalories: _nonNegative((calories[day] ?? 0).round()),
        workoutMinutes: workoutMinutes[day] ?? 0,
        sleepMinutes: sleepMinutes[day] ?? 0,
      ),
  ];
}

int _nonNegative(int n) => n < 0 ? 0 : n;
