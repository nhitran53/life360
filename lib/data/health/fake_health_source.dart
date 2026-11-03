import '../../models/models.dart';
import 'health_source.dart';

/// Scripted [HealthSource] for tests and mock mode.
class FakeHealthSource implements HealthSource {
  FakeHealthSource({
    this.availabilityResult = HealthAvailability.available,
    Map<StatMetric, HealthPermissionStatus>? permissionOutcome,
    Iterable<DailyStats> stats = const [],
  }) : permissionOutcome =
           permissionOutcome ??
           {for (final m in _fakeMetrics) m: HealthPermissionStatus.granted},
       _stats = List.of(stats);

  static const _fakeMetrics = {
    StatMetric.steps,
    StatMetric.sleep,
    StatMetric.workout,
    StatMetric.calories,
  };

  HealthAvailability availabilityResult;

  /// What [requestPermissions] reports and what [fetchDailyStats] honours.
  Map<StatMetric, HealthPermissionStatus> permissionOutcome;

  final List<DailyStats> _stats;

  /// How many times each method was called, for assertions.
  int requestPermissionsCalls = 0;
  int fetchCalls = 0;

  @override
  Set<StatMetric> get readableMetrics => _fakeMetrics;

  @override
  Future<HealthAvailability> availability() async => availabilityResult;

  @override
  Future<HealthPermissionResult> requestPermissions() async {
    requestPermissionsCalls++;
    return HealthPermissionResult(permissionOutcome);
  }

  @override
  Future<List<DailyStats>> fetchDailyStats(
    String userId, {
    required DateTime from,
    required DateTime to,
  }) async {
    fetchCalls++;
    final readable = HealthPermissionResult(permissionOutcome).readable;
    if (availabilityResult != HealthAvailability.available ||
        readable.isEmpty) {
      return [];
    }
    final start = dateOnly(from);
    final end = dateOnly(to);
    final days = <DailyStats>[];
    for (final s in _stats) {
      if (s.userId != userId || s.date.isBefore(start) || s.date.isAfter(end)) {
        continue;
      }
      // Like the real source: unread metrics are 0 and screen time is never
      // provided.
      final masked = DailyStats(
        userId: s.userId,
        date: s.date,
        steps: readable.contains(StatMetric.steps) ? s.steps : 0,
        sleepMinutes: readable.contains(StatMetric.sleep) ? s.sleepMinutes : 0,
        workoutMinutes: readable.contains(StatMetric.workout)
            ? s.workoutMinutes
            : 0,
        activeCalories: readable.contains(StatMetric.calories)
            ? s.activeCalories
            : 0,
      );
      if (masked.steps +
              masked.sleepMinutes +
              masked.workoutMinutes +
              masked.activeCalories >
          0) {
        days.add(masked);
      }
    }
    return days..sort((a, b) => a.date.compareTo(b.date));
  }
}
