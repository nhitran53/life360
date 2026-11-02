import 'daily_stats.dart';
import 'dates.dart';
import 'stat_metric.dart';

/// Totals and averages of one user's stats over a Monday–Sunday week.
class WeeklySummary {
  WeeklySummary._(this.userId, this.weekStart, this.days);

  /// Builds a summary for the week starting [weekStart] (snapped to Monday)
  /// from [stats]. Days from other weeks or other users are ignored.
  factory WeeklySummary.fromDays({
    required String userId,
    required DateTime weekStart,
    required Iterable<DailyStats> stats,
  }) {
    final start = startOfWeek(weekStart);
    final end = DateTime(start.year, start.month, start.day + 7);
    final days = stats
        .where((s) =>
            s.userId == userId &&
            !s.date.isBefore(start) &&
            s.date.isBefore(end))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return WeeklySummary._(userId, start, List.unmodifiable(days));
  }

  final String userId;
  final DateTime weekStart;

  /// The tracked days in this week, oldest first (may be fewer than 7).
  final List<DailyStats> days;

  int get daysTracked => days.length;

  int total(StatMetric metric) =>
      days.fold(0, (sum, d) => sum + metric.valueOf(d));

  /// Average per tracked day, or 0 when nothing was tracked.
  double average(StatMetric metric) =>
      daysTracked == 0 ? 0 : total(metric) / daysTracked;
}
