import '../models/models.dart';

/// Screen time the user typed in themselves, one total per day.
///
/// This is the fallback for platforms that don't hand us screen time
/// (iOS without the Family Controls entitlement, Android without usage
/// access). Only the current user writes to it.
abstract interface class ScreenTimeLog {
  /// Most you can log for one day.
  static const maxMinutes = 24 * 60;

  /// Logged minutes for each day from [from] to [to] (both inclusive).
  /// Days with nothing logged are left out.
  Future<Map<DateTime, int>> entries({
    required DateTime from,
    required DateTime to,
  });

  /// Logs [minutes] for [day], replacing what was there. 0 clears the day.
  ///
  /// Throws an [ArgumentError] outside 0 to [maxMinutes].
  Future<void> setMinutes(DateTime day, int minutes);
}

/// [ScreenTimeLog] kept in memory until the backend exists.
class InMemoryScreenTimeLog implements ScreenTimeLog {
  final _byDay = <DateTime, int>{};

  @override
  Future<Map<DateTime, int>> entries({
    required DateTime from,
    required DateTime to,
  }) async {
    final start = dateOnly(from);
    final end = dateOnly(to);
    return {
      for (final e in _byDay.entries)
        if (!e.key.isBefore(start) && !e.key.isAfter(end)) e.key: e.value,
    };
  }

  @override
  Future<void> setMinutes(DateTime day, int minutes) async {
    if (minutes < 0 || minutes > ScreenTimeLog.maxMinutes) {
      // Don't echo the value: it's health data.
      throw ArgumentError('Screen time must be 0 to 24 hours.');
    }
    final key = dateOnly(day);
    if (minutes == 0) {
      _byDay.remove(key);
    } else {
      _byDay[key] = minutes;
    }
  }
}
