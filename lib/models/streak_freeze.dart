import 'daily_goals.dart';
import 'daily_stats.dart';
import 'dates.dart';

/// How streak freezes are earned and how many you can hold.
abstract final class StreakFreezeRules {
  /// Every this many active days in a row earns one freeze.
  static const daysPerFreeze = 7;

  /// You can bank at most this many freezes at a time.
  static const maxFreezes = 2;
}

/// The current streak, with streak freezes applied.
class StreakStatus {
  const StreakStatus({
    required this.days,
    required this.freezesLeft,
    required this.frozenDays,
  });

  static const none = StreakStatus(days: 0, freezesLeft: 0, frozenDays: []);

  /// Active days in the current run. Frozen days keep the run alive but
  /// don't add to it.
  final int days;

  /// Freezes banked and ready to cover the next missed day.
  final int freezesLeft;

  /// Missed days a freeze covered in the current run, oldest first.
  final List<DateTime> frozenDays;

  @override
  bool operator ==(Object other) =>
      other is StreakStatus &&
      other.days == days &&
      other.freezesLeft == freezesLeft &&
      other.frozenDays.length == frozenDays.length &&
      Iterable<int>.generate(frozenDays.length)
          .every((i) => other.frozenDays[i] == frozenDays[i]);

  @override
  int get hashCode =>
      Object.hash(days, freezesLeft, Object.hashAll(frozenDays));

  @override
  String toString() =>
      'StreakStatus(days: $days, freezesLeft: $freezesLeft, '
      'frozen: ${frozenDays.map(dateKey).join(', ')})';
}

/// The streak ending [today], where a banked freeze covers a missed day.
///
/// Works through [days] from the oldest one, so the result only depends on
/// history and needs no stored inventory:
/// - every [StreakFreezeRules.daysPerFreeze] active days in a row earn one
///   freeze, up to [StreakFreezeRules.maxFreezes];
/// - a missed day (not active, or no data) uses a freeze if one is banked,
///   otherwise the streak and any banked freezes reset;
/// - an unfinished today never breaks the streak, like [currentStreak].
StreakStatus streakWithFreezes(
  Iterable<DailyStats> days, {
  required DateTime today,
  DailyGoals goals = const DailyGoals(),
}) {
  final end = dateOnly(today);
  final byDate = {
    for (final d in days)
      if (!d.date.isAfter(end)) d.date: d,
  };
  if (byDate.isEmpty) return StreakStatus.none;

  var date = byDate.keys.reduce((a, b) => a.isBefore(b) ? a : b);
  var run = 0;
  var freezes = 0;
  var frozen = <DateTime>[];
  // Active days since the run started or the last freeze was earned.
  var towardFreeze = 0;

  while (!date.isAfter(end)) {
    final day = byDate[date];
    final active = day != null && goals.isActiveDay(day);
    if (active) {
      run++;
      towardFreeze++;
      if (towardFreeze == StreakFreezeRules.daysPerFreeze) {
        towardFreeze = 0;
        if (freezes < StreakFreezeRules.maxFreezes) freezes++;
      }
    } else if (date == end) {
      // Today isn't over yet.
    } else if (run > 0 && freezes > 0) {
      freezes--;
      frozen.add(date);
    } else {
      run = 0;
      freezes = 0;
      towardFreeze = 0;
      frozen = [];
    }
    date = DateTime(date.year, date.month, date.day + 1);
  }

  return StreakStatus(
    days: run,
    freezesLeft: run == 0 ? 0 : freezes,
    frozenDays: run == 0 ? const [] : List.unmodifiable(frozen),
  );
}
