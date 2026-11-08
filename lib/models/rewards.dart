import 'circle.dart';
import 'daily_goals.dart';
import 'daily_stats.dart';
import 'dates.dart';
import 'leaderboard_entry.dart';
import 'stat_metric.dart';

/// Who won a reward, given that week's leaderboard for the reward's metric.
///
/// Everyone tied for first wins. People with nothing to their name (no data,
/// or a total of 0) can't win, so an empty week has no winner.
List<String> rewardWinners(
  RewardMetric metric,
  Iterable<LeaderboardEntry> entries,
) {
  final all = entries.toList();
  if (all.any((e) => e.metric != metric.stat)) {
    throw ArgumentError('Entries must be ranked by ${metric.stat.name}.');
  }
  return [
    for (final e in all)
      if (e.rank == 1 && e.value > 0) e.user.id,
  ];
}

/// Longest run of consecutive active days (see [DailyGoals.isActiveDay]).
/// A day with no data ends the run, like in [currentStreak].
int longestStreak(
  Iterable<DailyStats> days, {
  DailyGoals goals = const DailyGoals(),
}) {
  final active = {
    for (final d in days)
      if (goals.isActiveDay(d)) d.date,
  }.toList()..sort();
  var best = 0;
  var run = 0;
  DateTime? previous;
  for (final date in active) {
    final next = previous == null
        ? null
        : DateTime(previous.year, previous.month, previous.day + 1);
    run = next == date ? run + 1 : 1;
    if (run > best) best = run;
    previous = date;
  }
  return best;
}

/// Badges anyone can earn from their own steps and workouts. Nothing here
/// uses sleep, screen time or calories, so a badge is always safe to show
/// to a circle.
enum RewardBadge {
  firstActiveDay('First step', 'Hit a daily steps or workout goal'),
  threeDayStreak('On a roll', '3 active days in a row'),
  sevenDayStreak('Full week', '7 active days in a row'),
  workoutWeek('Workout week', 'Hit your workout goal 3 days in one week'),
  tenKDay('Ten-K club', 'Walk 10,000 steps in one day'),
  powerHour('Power hour', 'Work out for 60 minutes in one day');

  const RewardBadge(this.title, this.description);

  final String title;
  final String description;
}

/// Thresholds for the single-day badges. Fixed, so they mean the same thing
/// for everyone no matter what goals they set.
abstract final class BadgeRules {
  static const tenKSteps = 10000;
  static const powerHourMinutes = 60;
}

/// The badges earned by [days], in enum order.
List<RewardBadge> earnedBadges(
  Iterable<DailyStats> days, {
  DailyGoals goals = const DailyGoals(),
}) {
  final list = days.toList();
  final streak = longestStreak(list, goals: goals);

  final workoutDaysByWeek = <DateTime, Set<DateTime>>{};
  for (final d in list) {
    if (goals.isHit(StatMetric.workout, d.workoutMinutes)) {
      workoutDaysByWeek.putIfAbsent(startOfWeek(d.date), () => {}).add(d.date);
    }
  }

  return [
    if (list.any(goals.isActiveDay)) RewardBadge.firstActiveDay,
    if (streak >= 3) RewardBadge.threeDayStreak,
    if (streak >= 7) RewardBadge.sevenDayStreak,
    if (workoutDaysByWeek.values.any((days) => days.length >= 3))
      RewardBadge.workoutWeek,
    if (list.any((d) => d.steps >= BadgeRules.tenKSteps)) RewardBadge.tenKDay,
    if (list.any((d) => d.workoutMinutes >= BadgeRules.powerHourMinutes))
      RewardBadge.powerHour,
  ];
}
