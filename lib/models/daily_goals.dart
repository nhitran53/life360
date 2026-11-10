import 'daily_stats.dart';
import 'dates.dart';
import 'stat_metric.dart';

/// Daily targets for each stat. Defaults line up with [XpRules] so hitting
/// a goal and earning its XP bonus feel like the same thing.
///
/// Screen time is a limit, not a target: staying at or under it counts.
class DailyGoals {
  const DailyGoals({
    this.steps = 8000,
    this.sleepMinutes = 7 * 60,
    this.workoutMinutes = 30,
    this.activeCalories = 400,
    this.screenTimeMinutes = 3 * 60,
  }) : assert(
         steps > 0 &&
             sleepMinutes > 0 &&
             workoutMinutes > 0 &&
             activeCalories > 0 &&
             screenTimeMinutes > 0,
       );

  final int steps;
  final int sleepMinutes;
  final int workoutMinutes;
  final int activeCalories;
  final int screenTimeMinutes;

  DailyGoals copyWith({
    int? steps,
    int? sleepMinutes,
    int? workoutMinutes,
    int? activeCalories,
    int? screenTimeMinutes,
  }) => DailyGoals(
    steps: steps ?? this.steps,
    sleepMinutes: sleepMinutes ?? this.sleepMinutes,
    workoutMinutes: workoutMinutes ?? this.workoutMinutes,
    activeCalories: activeCalories ?? this.activeCalories,
    screenTimeMinutes: screenTimeMinutes ?? this.screenTimeMinutes,
  );

  /// A copy with [metric]'s target set to [value].
  DailyGoals withTarget(StatMetric metric, int value) => switch (metric) {
    StatMetric.steps => copyWith(steps: value),
    StatMetric.sleep => copyWith(sleepMinutes: value),
    StatMetric.workout => copyWith(workoutMinutes: value),
    StatMetric.calories => copyWith(activeCalories: value),
    StatMetric.screenTime => copyWith(screenTimeMinutes: value),
  };

  /// Missing keys fall back to the defaults.
  factory DailyGoals.fromJson(Map<String, dynamic> json) {
    const d = DailyGoals();
    return DailyGoals(
      steps: json['steps'] as int? ?? d.steps,
      sleepMinutes: json['sleepMinutes'] as int? ?? d.sleepMinutes,
      workoutMinutes: json['workoutMinutes'] as int? ?? d.workoutMinutes,
      activeCalories: json['activeCalories'] as int? ?? d.activeCalories,
      screenTimeMinutes:
          json['screenTimeMinutes'] as int? ?? d.screenTimeMinutes,
    );
  }

  Map<String, dynamic> toJson() => {
    'steps': steps,
    'sleepMinutes': sleepMinutes,
    'workoutMinutes': workoutMinutes,
    'activeCalories': activeCalories,
    'screenTimeMinutes': screenTimeMinutes,
  };

  @override
  bool operator ==(Object other) =>
      other is DailyGoals &&
      other.steps == steps &&
      other.sleepMinutes == sleepMinutes &&
      other.workoutMinutes == workoutMinutes &&
      other.activeCalories == activeCalories &&
      other.screenTimeMinutes == screenTimeMinutes;

  @override
  int get hashCode => Object.hash(
    steps,
    sleepMinutes,
    workoutMinutes,
    activeCalories,
    screenTimeMinutes,
  );

  int target(StatMetric metric) => switch (metric) {
    StatMetric.steps => steps,
    StatMetric.sleep => sleepMinutes,
    StatMetric.workout => workoutMinutes,
    StatMetric.calories => activeCalories,
    StatMetric.screenTime => screenTimeMinutes,
  };

  /// Whether [value] meets the goal for [metric].
  ///
  /// Screen time of 0 usually means it isn't tracked, so it doesn't count.
  bool isHit(StatMetric metric, int value) => metric.higherIsBetter
      ? value >= target(metric)
      : value > 0 && value <= target(metric);

  /// How far along [value] is, from 0 to 1. For screen time this is how
  /// much of the limit has been used.
  double progress(StatMetric metric, int value) =>
      (value / target(metric)).clamp(0.0, 1.0);

  /// A day keeps your streak alive if you hit your steps or workout goal.
  bool isActiveDay(DailyStats day) =>
      isHit(StatMetric.steps, day.steps) ||
      isHit(StatMetric.workout, day.workoutMinutes);
}

/// Consecutive active days (see [DailyGoals.isActiveDay]) ending today.
///
/// If today isn't active yet the streak isn't broken: it still counts back
/// from yesterday. A day with no data ends the streak.
int currentStreak(
  Iterable<DailyStats> days, {
  required DateTime today,
  DailyGoals goals = const DailyGoals(),
}) {
  final byDate = {for (final d in days) d.date: d};
  final start = dateOnly(today);
  var streak = 0;
  for (var i = 0; ; i++) {
    final date = DateTime(start.year, start.month, start.day - i);
    final day = byDate[date];
    final active = day != null && goals.isActiveDay(day);
    if (active) {
      streak++;
    } else if (i > 0) {
      return streak;
    }
  }
}
