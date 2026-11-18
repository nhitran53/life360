import 'dart:convert';

import '../../models/models.dart';
import 'health_source.dart';

/// Thrown when the Takeout daily-totals file cannot be read. The message is
/// fixed: it never carries the path, the file contents or health values.
class TakeoutLoadException implements Exception {
  const TakeoutLoadException();

  @override
  String toString() => 'Could not read the Takeout daily-totals file';
}

/// Dev-only [HealthSource] that reads a small daily-totals JSON produced
/// outside the repo from a Google Takeout export:
/// `{"days": [{"date": "yyyy-mm-dd", "steps": 0, "sleepMinutes": 0,
/// "workoutMinutes": 0, "activeCalories": 0}]}`.
///
/// With [shiftToToday] every date moves by the same number of days so the
/// latest day in the export is today (per [clock]), and every day from the
/// first to the latest export day is returned, missing metrics as 0. That
/// keeps the current week from looking empty with an old export. Dev only.
///
/// It holds totals only (no raw samples, heart rate or location) and never
/// logs values. Not meant for release builds.
class TakeoutHealthSource implements HealthSource {
  TakeoutHealthSource({
    required this._load,
    this.shiftToToday = false,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Future<String> Function() _load;
  final DateTime Function() _clock;

  /// Moves the export so its latest day is today.
  final bool shiftToToday;

  @override
  String get displayName => 'Google Takeout (dev)';

  @override
  Set<StatMetric> get readableMetrics => const {
    StatMetric.steps,
    StatMetric.sleep,
    StatMetric.workout,
    StatMetric.calories,
  };

  @override
  Future<HealthAvailability> availability() async =>
      HealthAvailability.available;

  @override
  Future<void> openInstallPage() async {}

  @override
  Future<HealthPermissionResult> requestPermissions() async =>
      HealthPermissionResult({
        for (final m in readableMetrics) m: HealthPermissionStatus.granted,
      });

  @override
  Future<HealthPermissionResult> checkPermissions() => requestPermissions();

  @override
  Future<List<DailyStats>> fetchDailyStats(
    String userId, {
    required DateTime from,
    required DateTime to,
  }) async {
    final start = dateOnly(from);
    final end = dateOnly(to);
    final String raw;
    try {
      raw = await _load();
    } on Exception {
      // Drop the original error: it could carry a path.
      throw const TakeoutLoadException();
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return [];
    }
    final rows = decoded is Map ? decoded['days'] : null;
    if (rows is! List) return [];
    final parsed = <DailyStats>[];
    for (final row in rows) {
      final s = _parseRow(row, userId);
      if (s != null) parsed.add(s);
    }
    final days = shiftToToday ? _shifted(parsed, userId) : parsed;
    return [
      for (final s in days)
        if (!s.date.isBefore(start) &&
            !s.date.isAfter(end) &&
            (shiftToToday ||
                s.steps + s.sleepMinutes + s.workoutMinutes + s.activeCalories >
                    0))
          s,
    ]..sort((a, b) => a.date.compareTo(b.date));
  }

  /// [parsed] moved so its latest day is today, with a (possibly all-zero)
  /// entry for every day in between.
  List<DailyStats> _shifted(List<DailyStats> parsed, String userId) {
    if (parsed.isEmpty) return parsed;
    final dates = [for (final s in parsed) dateOnly(s.date)]..sort();
    final today = dateOnly(_clock());
    final shiftDays = DateTime.utc(today.year, today.month, today.day)
        .difference(
          DateTime.utc(dates.last.year, dates.last.month, dates.last.day),
        )
        .inDays;
    DateTime moved(DateTime d) => DateTime(d.year, d.month, d.day + shiftDays);
    final byDate = {for (final s in parsed) moved(dateOnly(s.date)): s};
    final first = moved(dates.first);
    final last = moved(dates.last);
    return [
      for (
        var d = first;
        !d.isAfter(last);
        d = DateTime(d.year, d.month, d.day + 1)
      )
        DailyStats(
          userId: userId,
          date: d,
          steps: byDate[d]?.steps ?? 0,
          sleepMinutes: byDate[d]?.sleepMinutes ?? 0,
          workoutMinutes: byDate[d]?.workoutMinutes ?? 0,
          activeCalories: byDate[d]?.activeCalories ?? 0,
          screenTimeMinutes: byDate[d]?.screenTimeMinutes ?? 0,
        ),
    ];
  }

  /// One day from an export row, or null for a malformed row: a missing or
  /// unparseable date, a metric that isn't a whole number, or a negative
  /// health metric.
  static DailyStats? _parseRow(Object? row, String userId) {
    if (row is! Map) return null;
    final date = switch (row['date']) {
      final String d => DateTime.tryParse(d),
      _ => null,
    };
    if (date == null) return null;
    int? count(String key, {bool allowNegative = false}) => switch (row[key]) {
      null => 0,
      final int v when allowNegative || v >= 0 => v,
      _ => null,
    };
    final steps = count('steps');
    final sleep = count('sleepMinutes');
    final workout = count('workoutMinutes');
    final calories = count('activeCalories');
    final screenTime = count('screenTimeMinutes', allowNegative: true);
    if (steps == null ||
        sleep == null ||
        workout == null ||
        calories == null ||
        screenTime == null) {
      return null;
    }
    return DailyStats(
      userId: userId,
      date: date,
      steps: steps,
      sleepMinutes: sleep,
      workoutMinutes: workout,
      activeCalories: calories,
      screenTimeMinutes: screenTime,
    );
  }
}
