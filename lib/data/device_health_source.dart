import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:health/health.dart';

import '../models/models.dart';
import 'health_aggregation.dart';
import 'health_source.dart';

/// [HealthSource] backed by `package:health`: Apple Health (HealthKit) on
/// iOS, Health Connect on Android.
///
/// Asks for the smallest set of read permissions our stats need and never
/// logs the values it reads.
class DeviceHealthSource implements HealthSource {
  DeviceHealthSource({Health? health}) : _health = health ?? Health();

  final Health _health;
  bool _configured = false;

  /// Set after the iOS permission sheet is answered. HealthKit never tells
  /// apps whether *read* access was granted (a denied user just looks like
  /// someone with no data), so on iOS this is the best signal we have.
  /// TODO: persist it with the user's settings once Firestore is in.
  bool _iosAsked = false;

  static bool get _isIOS => !kIsWeb && Platform.isIOS;
  static bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  /// Sleep on iOS comes as stages (Apple Watch writes core/deep/REM; older
  /// sources write plain "asleep"). In-bed and awake time are left out.
  static const _iosSleep = [
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_LIGHT, // "core" sleep on Apple Watch
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
  ];

  /// Health Connect sleep sessions cover the whole night.
  static const _androidSleep = [HealthDataType.SLEEP_SESSION];

  List<HealthDataType> get _sleepTypes => _isIOS ? _iosSleep : _androidSleep;

  List<HealthDataType> get _types => [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.WORKOUT,
    ..._sleepTypes,
  ];

  @override
  String get name => _isIOS ? 'Apple Health' : 'Health Connect';

  Future<void> _configure() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  @override
  Future<HealthConnection> connection() async {
    if (!_isIOS && !_isAndroid) return HealthConnection.unsupported;
    try {
      await _configure();
      if (_isAndroid) {
        final status = await _health.getHealthConnectSdkStatus();
        if (status != HealthConnectSdkStatus.sdkAvailable) {
          return HealthConnection.needsInstall;
        }
        final granted = await _health.hasPermissions(
          _types,
          permissions: [for (final _ in _types) HealthDataAccess.READ],
        );
        return granted == true
            ? HealthConnection.connected
            : HealthConnection.notConnected;
      }
      return _iosAsked
          ? HealthConnection.connected
          : HealthConnection.notConnected;
    } on Exception {
      return HealthConnection.unsupported;
    }
  }

  @override
  Future<bool> connect() async {
    if (!_isIOS && !_isAndroid) return false;
    await _configure();
    final granted = await _health.requestAuthorization(
      _types,
      permissions: [for (final _ in _types) HealthDataAccess.READ],
    );
    if (_isIOS) _iosAsked = granted;
    return granted;
  }

  @override
  Future<void> disconnect() async {
    _iosAsked = false;
    if (_isAndroid) {
      await _configure();
      await _health.revokePermissions();
    }
  }

  @override
  Future<void> installProvider() async {
    if (!_isAndroid) return;
    await _configure();
    await _health.installHealthConnect();
  }

  @override
  Future<List<DailyStats>> readDays(
    String userId, {
    required DateTime from,
    required DateTime to,
  }) async {
    final first = dateOnly(from);
    final last = dateOnly(to);
    final end = DateTime(last.year, last.month, last.day + 1);
    await _configure();

    // Steps: the hub's own deduplicated total per day.
    final stepsByDay = <DateTime, int>{};
    for (
      var day = first;
      day.isBefore(end);
      day = DateTime(day.year, day.month, day.day + 1)
    ) {
      final next = DateTime(day.year, day.month, day.day + 1);
      stepsByDay[day] = await _health.getTotalStepsInInterval(day, next) ?? 0;
    }

    // Start the evening before so the first night's sleep is included.
    final points = await _health.getHealthDataFromTypes(
      types: [
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.WORKOUT,
        ..._sleepTypes,
      ],
      startTime: DateTime(first.year, first.month, first.day - 1, 18),
      endTime: end,
    );

    HealthSpan span(HealthDataPoint p) {
      final v = p.value;
      return HealthSpan(
        p.dateFrom,
        p.dateTo,
        v is NumericHealthValue ? v.numericValue : 0,
      );
    }

    return buildDailyStats(
      userId: userId,
      from: first,
      to: last,
      stepsByDay: stepsByDay,
      activeEnergy: points
          .where((p) => p.type == HealthDataType.ACTIVE_ENERGY_BURNED)
          .map(span),
      workouts: points.where((p) => p.type == HealthDataType.WORKOUT).map(span),
      sleep: points.where((p) => _sleepTypes.contains(p.type)).map(span),
    );
  }
}
