import 'daily_stats.dart';
import 'weekly_summary.dart';

/// How XP is earned. Ranks the Overall XP leaderboard, which also decides
/// the weekly leagues (see `league.dart`).
///
/// Every stat is capped per day so one extreme day can't decide the week,
/// and sleep / screen time reward healthy ranges rather than extremes.
abstract final class XpRules {
  /// 1 XP per 100 steps, up to 20,000 steps a day.
  static const stepsPerXp = 100;
  static const maxStepXpPerDay = 200;

  /// 2 XP per workout minute, up to 90 minutes a day.
  static const xpPerWorkoutMinute = 2;
  static const maxWorkoutMinutesPerDay = 90;

  /// Bonus for a night of 7+ hours.
  static const goodSleepMinutes = 7 * 60;
  static const goodSleepXp = 30;

  /// Bonus for keeping screen time to 3 hours or less.
  static const lowScreenTimeMinutes = 3 * 60;
  static const lowScreenTimeXp = 30;
}

int dailyXp(DailyStats d) {
  var xp = (d.steps ~/ XpRules.stepsPerXp).clamp(0, XpRules.maxStepXpPerDay);
  xp += d.workoutMinutes.clamp(0, XpRules.maxWorkoutMinutesPerDay) *
      XpRules.xpPerWorkoutMinute;
  if (d.sleepMinutes >= XpRules.goodSleepMinutes) xp += XpRules.goodSleepXp;
  // 0 usually means screen time isn't tracked, so it earns nothing.
  if (d.screenTimeMinutes > 0 &&
      d.screenTimeMinutes <= XpRules.lowScreenTimeMinutes) {
    xp += XpRules.lowScreenTimeXp;
  }
  return xp;
}

int weeklyXp(WeeklySummary w) => w.days.fold(0, (sum, d) => sum + dailyXp(d));
