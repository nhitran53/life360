/// Pure functions that turn raw health intervals into daily minute totals.
///
/// Kept free of the `health` package so the tricky rules (sleep across
/// midnight, overlapping sources) are unit-testable.
library;

enum HealthIntervalKind {
  /// A sleep stage that counts as sleep (asleep, light, deep, REM).
  asleep,

  /// A whole sleep session (Android); includes awake time inside the session.
  sleepSession,

  workout,
}

class HealthInterval {
  HealthInterval(this.kind, this.start, this.end);

  final HealthIntervalKind kind;
  final DateTime start;
  final DateTime end;
}

/// Sleep belongs to the day you wake up. A sample counts for [day] when it
/// ends between 18:00 the evening before and 18:00 on [day], so a
/// 23:00-07:00 night is never split at midnight.
///
/// Overlapping samples (phone plus watch) are merged, not summed. Sleep
/// stages are preferred; whole sessions are only used when no stage exists.
int sleepMinutesForDay(Iterable<HealthInterval> intervals, DateTime day) {
  final windowStart = DateTime(day.year, day.month, day.day - 1, 18);
  final windowEnd = DateTime(day.year, day.month, day.day, 18);
  final inWindow = intervals
      .where(
        (i) =>
            i.end.isAfter(i.start) &&
            i.end.isAfter(windowStart) &&
            !i.end.isAfter(windowEnd),
      )
      .toList();
  var chosen = inWindow.where((i) => i.kind == HealthIntervalKind.asleep);
  if (chosen.isEmpty) {
    chosen = inWindow.where((i) => i.kind == HealthIntervalKind.sleepSession);
  }
  return _unionMinutes(chosen.map((i) => (i.start, i.end)));
}

/// Workout minutes inside the local calendar day of [day]. A workout that
/// crosses midnight is clipped to each day, and overlapping workouts (watch
/// plus an app) are merged so they are not double counted.
int workoutMinutesForDay(Iterable<HealthInterval> intervals, DateTime day) {
  final dayStart = DateTime(day.year, day.month, day.day);
  final dayEnd = DateTime(day.year, day.month, day.day + 1);
  final clipped = <(DateTime, DateTime)>[];
  for (final i in intervals) {
    if (i.kind != HealthIntervalKind.workout) continue;
    final start = i.start.isBefore(dayStart) ? dayStart : i.start;
    final end = i.end.isAfter(dayEnd) ? dayEnd : i.end;
    if (end.isAfter(start)) clipped.add((start, end));
  }
  return _unionMinutes(clipped);
}

/// Total minutes covered by the union of [ranges].
int _unionMinutes(Iterable<(DateTime, DateTime)> ranges) {
  final sorted = ranges.toList()..sort((a, b) => a.$1.compareTo(b.$1));
  var millis = 0;
  DateTime? curStart;
  DateTime? curEnd;
  for (final (start, end) in sorted) {
    if (curEnd == null || start.isAfter(curEnd)) {
      if (curStart != null) {
        millis += curEnd!.difference(curStart).inMilliseconds;
      }
      curStart = start;
      curEnd = end;
    } else if (end.isAfter(curEnd)) {
      curEnd = end;
    }
  }
  if (curStart != null) millis += curEnd!.difference(curStart).inMilliseconds;
  return (millis / Duration.millisecondsPerMinute).round();
}
