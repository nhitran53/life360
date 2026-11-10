import 'dart:io' show Platform;

import 'package:health/health.dart';

import '../../models/models.dart';
import 'health_aggregation.dart';
import 'health_source.dart';

/// [HealthSource] over the `health` package: HealthKit on iOS and Health
/// Connect on Android.
///
/// Reads steps, sleep, workout minutes and active calories. Screen time is
/// left out (always 0): iOS does not expose it and Android needs a separate
/// usage-access plugin. Only read access is requested, and no raw values are
/// ever logged.
///
/// Needs a real device or emulator with a health store; the logic that can be
/// unit-tested lives in `health_aggregation.dart`.
class HealthPackageSource implements HealthSource {
  HealthPackageSource({Health? health}) : _health = health ?? Health();

  final Health _health;
  bool _configured = false;

  static const _sleepStageTypes = [
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
  ];

  @override
  Set<StatMetric> get readableMetrics => const {
    StatMetric.steps,
    StatMetric.sleep,
    StatMetric.workout,
    StatMetric.calories,
  };

  /// The plugin data types needed for [metric] on this platform.
  List<HealthDataType> _typesFor(StatMetric metric) {
    final types = switch (metric) {
      StatMetric.steps => [HealthDataType.STEPS],
      StatMetric.sleep => [..._sleepStageTypes, HealthDataType.SLEEP_SESSION],
      StatMetric.workout => [HealthDataType.WORKOUT],
      StatMetric.calories => [HealthDataType.ACTIVE_ENERGY_BURNED],
      StatMetric.screenTime => <HealthDataType>[],
    };
    // Stage and session types differ between HealthKit and Health Connect.
    return types.where(_health.isDataTypeAvailable).toList();
  }

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  @override
  String get displayName => Platform.isIOS ? 'Apple Health' : 'Health Connect';

  @override
  Future<void> openInstallPage() => _health.installHealthConnect();

  @override
  Future<HealthAvailability> availability() async {
    if (Platform.isIOS) return HealthAvailability.available;
    if (!Platform.isAndroid) return HealthAvailability.unsupported;
    return switch (await _health.getHealthConnectSdkStatus()) {
      HealthConnectSdkStatus.sdkAvailable => HealthAvailability.available,
      HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired =>
        HealthAvailability.updateRequired,
      _ => HealthAvailability.notInstalled,
    };
  }

  @override
  Future<HealthPermissionResult> requestPermissions() async {
    await _ensureConfigured();
    final types = [for (final m in readableMetrics) ..._typesFor(m)];
    try {
      await _health.requestAuthorization(
        types,
        permissions: List.filled(types.length, HealthDataAccess.READ),
      );
    } catch (_) {
      // The request can fail (e.g. the permission screen cannot open). The
      // per-metric check below still reports what was actually granted.
    }
    return _currentPermissions();
  }

  @override
  Future<HealthPermissionResult> checkPermissions() async {
    await _ensureConfigured();
    return _currentPermissions();
  }

  Future<HealthPermissionResult> _currentPermissions() async {
    final statuses = <StatMetric, HealthPermissionStatus>{};
    for (final metric in readableMetrics) {
      final types = _typesFor(metric);
      final has = await _health.hasPermissions(
        types,
        permissions: List.filled(types.length, HealthDataAccess.READ),
      );
      statuses[metric] = switch (has) {
        true => HealthPermissionStatus.granted,
        false => HealthPermissionStatus.denied,
        null => HealthPermissionStatus.unknown,
      };
    }
    return HealthPermissionResult(statuses);
  }

  @override
  Future<List<DailyStats>> fetchDailyStats(
    String userId, {
    required DateTime from,
    required DateTime to,
  }) async {
    await _ensureConfigured();
    final readable = (await _currentPermissions()).readable;
    if (readable.isEmpty) return [];

    final first = dateOnly(from);
    final last = dateOnly(to);
    if (last.isBefore(first)) return [];

    // Sleep and workouts are read once as raw intervals for the whole range:
    // sleep is attributed to the wake-up day, so its window reaches back to
    // 18:00 the evening before.
    final intervals = <HealthInterval>[];
    if (readable.contains(StatMetric.sleep) ||
        readable.contains(StatMetric.workout)) {
      intervals.addAll(
        await _readIntervals(
          start: DateTime(first.year, first.month, first.day - 1, 18),
          end: DateTime(last.year, last.month, last.day + 1),
          sleep: readable.contains(StatMetric.sleep),
          workout: readable.contains(StatMetric.workout),
        ),
      );
    }

    final result = <DailyStats>[];
    for (
      var day = first;
      !day.isAfter(last);
      day = DateTime(day.year, day.month, day.day + 1)
    ) {
      final next = DateTime(day.year, day.month, day.day + 1);
      final stats = DailyStats(
        userId: userId,
        date: day,
        // Platform aggregates merge overlapping sources (phone plus watch),
        // so steps and calories are never summed from raw samples here.
        steps: readable.contains(StatMetric.steps)
            ? await _health.getTotalStepsInInterval(day, next) ?? 0
            : 0,
        activeCalories: readable.contains(StatMetric.calories)
            ? await _activeCalories(day, next)
            : 0,
        sleepMinutes: readable.contains(StatMetric.sleep)
            ? sleepMinutesForDay(intervals, day)
            : 0,
        workoutMinutes: readable.contains(StatMetric.workout)
            ? workoutMinutesForDay(intervals, day)
            : 0,
      );
      if (_hasData(stats)) result.add(stats);
    }
    return result;
  }

  bool _hasData(DailyStats s) =>
      s.steps > 0 ||
      s.sleepMinutes > 0 ||
      s.workoutMinutes > 0 ||
      s.activeCalories > 0;

  Future<int> _activeCalories(DateTime start, DateTime end) async {
    // One slice covering the whole day, so the platform returns its merged
    // daily total.
    final slices = await _health.getHealthIntervalDataFromTypes(
      startDate: start,
      endDate: end,
      types: [HealthDataType.ACTIVE_ENERGY_BURNED],
      interval: end.difference(start).inSeconds,
    );
    var total = 0.0;
    for (final slice in slices) {
      final value = slice.value;
      if (value is NumericHealthValue) total += value.numericValue;
    }
    return total.round();
  }

  Future<List<HealthInterval>> _readIntervals({
    required DateTime start,
    required DateTime end,
    required bool sleep,
    required bool workout,
  }) async {
    final types = [
      if (sleep) ...[..._sleepStageTypes, HealthDataType.SLEEP_SESSION],
      if (workout) HealthDataType.WORKOUT,
    ].where(_health.isDataTypeAvailable).toList();
    final points = await _health.getHealthDataFromTypes(
      types: types,
      startTime: start,
      endTime: end,
    );
    return [
      for (final p in _health.removeDuplicates(points))
        HealthInterval(_kindOf(p.type), p.dateFrom, p.dateTo),
    ];
  }

  HealthIntervalKind _kindOf(HealthDataType type) => switch (type) {
    HealthDataType.SLEEP_SESSION => HealthIntervalKind.sleepSession,
    HealthDataType.WORKOUT => HealthIntervalKind.workout,
    _ => HealthIntervalKind.asleep,
  };
}
