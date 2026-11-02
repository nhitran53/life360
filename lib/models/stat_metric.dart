import 'daily_stats.dart';
import 'weekly_summary.dart';

/// The stats we track and compete on.
///
/// Colors live in the theme (sleep = blue, screen time = purple, ...);
/// this enum only carries data-related behavior.
enum StatMetric {
  steps(label: 'Steps', unit: 'steps', emoji: '👟'),
  sleep(label: 'Sleep', unit: 'min', emoji: '😴'),
  workout(label: 'Workouts', unit: 'min', emoji: '💪'),
  calories(label: 'Active calories', unit: 'kcal', emoji: '🔥'),
  screenTime(label: 'Screen time', unit: 'min', emoji: '📱');

  const StatMetric({
    required this.label,
    required this.unit,
    required this.emoji,
  });

  final String label;
  final String unit;
  final String emoji;

  /// Screen time is the only stat where less is better.
  bool get higherIsBetter => this != StatMetric.screenTime;

  /// Sleep and screen time compare fairly as a nightly/daily average;
  /// the rest are weekly totals.
  bool get rankByAverage =>
      this == StatMetric.sleep || this == StatMetric.screenTime;

  int valueOf(DailyStats s) => switch (this) {
        StatMetric.steps => s.steps,
        StatMetric.sleep => s.sleepMinutes,
        StatMetric.workout => s.workoutMinutes,
        StatMetric.calories => s.activeCalories,
        StatMetric.screenTime => s.screenTimeMinutes,
      };

  /// The number used to rank people on the leaderboard for this metric.
  double leaderboardValue(WeeklySummary w) =>
      rankByAverage ? w.average(this) : w.total(this).toDouble();
}
