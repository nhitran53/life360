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
/// It holds totals only (no raw samples, heart rate or location) and never
/// logs values. Not meant for release builds.
class TakeoutHealthSource implements HealthSource {
  TakeoutHealthSource({required this._load});

  final Future<String> Function() _load;

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
    final days = <DailyStats>[];
    for (final row in rows) {
      final s = _parseRow(row, userId);
      if (s == null || s.date.isBefore(start) || s.date.isAfter(end)) continue;
      if (s.steps + s.sleepMinutes + s.workoutMinutes + s.activeCalories > 0) {
        days.add(s);
      }
    }
    return days..sort((a, b) => a.date.compareTo(b.date));
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
