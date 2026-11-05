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
    } on Object {
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
      try {
        final r = Map<String, dynamic>.from(row as Map);
        const metricKeys = [
          'steps',
          'sleepMinutes',
          'workoutMinutes',
          'activeCalories',
        ];
        if (metricKeys.any((k) => ((r[k] as int?) ?? 0) < 0)) continue;
        final s = DailyStats.fromJson({...r, 'userId': userId});
        if (s.date.isBefore(start) || s.date.isAfter(end)) continue;
        if (s.steps + s.sleepMinutes + s.workoutMinutes + s.activeCalories >
            0) {
          days.add(s);
        }
      } on FormatException {
        continue; // skip malformed rows
      } on TypeError {
        continue;
      }
    }
    return days..sort((a, b) => a.date.compareTo(b.date));
  }
}
