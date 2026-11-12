import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import 'screen_time_log.dart';

/// Screen time measured by the phone itself (issue #10).
///
/// Android exposes it through `UsageStatsManager` once the user grants
/// "usage access" in Settings. iOS only offers it through the Screen Time
/// APIs, which need the restricted Family Controls entitlement, so iOS falls
/// back to manual entry (see [ScreenTimeLog]).
///
/// Values are daily totals in minutes and are never logged.
abstract interface class DeviceScreenTime {
  /// Whether this phone can measure screen time at all.
  bool get isSupported;

  /// Whether the user has granted access. Never shows any UI.
  Future<bool> hasAccess();

  /// Opens the system page where the user can grant access.
  Future<void> openAccessSettings();

  /// Minutes of screen time per local day from [from] to [to] (both
  /// inclusive). Days with none are left out. Empty without access.
  Future<Map<DateTime, int>> dailyMinutes({
    required DateTime from,
    required DateTime to,
  });
}

/// For platforms that don't measure screen time (iOS, web, desktop).
class NoDeviceScreenTime implements DeviceScreenTime {
  const NoDeviceScreenTime();

  @override
  bool get isSupported => false;

  @override
  Future<bool> hasAccess() async => false;

  @override
  Future<void> openAccessSettings() async {}

  @override
  Future<Map<DateTime, int>> dailyMinutes({
    required DateTime from,
    required DateTime to,
  }) async => const {};
}

/// [DeviceScreenTime] over Android's `UsageStatsManager`, through a method
/// channel implemented in `MainActivity.kt`.
class AndroidUsageScreenTime implements DeviceScreenTime {
  AndroidUsageScreenTime({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'friend360/screen_time';

  final MethodChannel _channel;

  @override
  bool get isSupported => true;

  @override
  Future<bool> hasAccess() async {
    try {
      return await _channel.invokeMethod<bool>('hasUsageAccess') ?? false;
    } on PlatformException catch (e) {
      _report('hasUsageAccess', e.code);
      return false;
    } on MissingPluginException {
      _report('hasUsageAccess', 'missing plugin');
      return false;
    }
  }

  @override
  Future<void> openAccessSettings() async {
    try {
      await _channel.invokeMethod<void>('openUsageAccessSettings');
    } on PlatformException catch (e) {
      _report('openUsageAccessSettings', e.code);
    } on MissingPluginException {
      _report('openUsageAccessSettings', 'missing plugin');
    }
  }

  @override
  Future<Map<DateTime, int>> dailyMinutes({
    required DateTime from,
    required DateTime to,
  }) async {
    final days = _daysBetween(from, to);
    if (days.isEmpty) return const {};
    // Local midnights, worked out here so DST days come out right: one per
    // day plus the end of the last day.
    final last = days.last;
    final boundaries = [
      for (final d in days) d.millisecondsSinceEpoch,
      DateTime(last.year, last.month, last.day + 1).millisecondsSinceEpoch,
    ];
    final List<Object?>? reply;
    try {
      reply = await _channel.invokeMethod<List<Object?>>('dailyScreenTime', {
        'boundaries': boundaries,
      });
    } on PlatformException catch (e) {
      _report('dailyScreenTime', e.code);
      return const {};
    } on MissingPluginException {
      _report('dailyScreenTime', 'missing plugin');
      return const {};
    }
    if (reply == null || reply.length != days.length) {
      _report('dailyScreenTime', 'unexpected reply shape');
      return const {};
    }
    return Map.unmodifiable({
      for (var i = 0; i < days.length; i++)
        if (_validMinutes(reply[i]) case final minutes? when minutes > 0)
          days[i]: minutes,
    });
  }

  /// Minutes capped at a full day; null for anything that isn't a
  /// non-negative whole number.
  static int? _validMinutes(Object? value) => switch (value) {
    final int m when m >= 0 =>
      m > ScreenTimeLog.maxMinutes ? ScreenTimeLog.maxMinutes : m,
    _ => null,
  };

  static List<DateTime> _daysBetween(DateTime from, DateTime to) {
    final start = dateOnly(from);
    final end = dateOnly(to);
    return [
      for (
        var d = start;
        !d.isAfter(end);
        d = DateTime(d.year, d.month, d.day + 1)
      )
        d,
    ];
  }

  /// Only the call and an error code: never any screen time values.
  static void _report(String method, String code) =>
      debugPrint('Screen time $method failed: $code');
}

/// In-memory [DeviceScreenTime] for tests and demos.
class FakeDeviceScreenTime implements DeviceScreenTime {
  FakeDeviceScreenTime({
    Map<DateTime, int> minutes = const {},
    this.access = true,
  }) : _minutes = Map.unmodifiable({
         for (final e in minutes.entries) dateOnly(e.key): e.value,
       });

  final Map<DateTime, int> _minutes;

  /// Whether usage access is granted. Tests flip it.
  bool access;

  /// How many times [openAccessSettings] was called.
  int settingsOpened = 0;

  /// How many times screen time was actually read.
  int reads = 0;

  @override
  bool get isSupported => true;

  @override
  Future<bool> hasAccess() async => access;

  @override
  Future<void> openAccessSettings() async => settingsOpened++;

  @override
  Future<Map<DateTime, int>> dailyMinutes({
    required DateTime from,
    required DateTime to,
  }) async {
    if (!access) return const {};
    reads++;
    final start = dateOnly(from);
    final end = dateOnly(to);
    return {
      for (final e in _minutes.entries)
        if (!e.key.isBefore(start) && !e.key.isAfter(end) && e.value > 0)
          e.key: e.value,
    };
  }
}
