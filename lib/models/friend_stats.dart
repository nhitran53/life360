import 'daily_stats.dart';
import 'stat_metric.dart';
import 'user_profile.dart';
import 'weekly_summary.dart';

/// What you can see of one friend: today's stats, this week, their streak,
/// and which stats they keep private.
///
/// Built from already-filtered data (see `SharingStatsRepository`), so
/// hidden values are 0 here. Always check [isHidden] before showing a number.
class FriendSnapshot {
  const FriendSnapshot({
    required this.user,
    required this.today,
    required this.week,
    required this.streak,
    required this.hidden,
  });

  final UserProfile user;

  /// Null when nothing synced today.
  final DailyStats? today;
  final WeeklySummary week;

  /// Null when the friend shares neither steps nor workouts, the two stats
  /// a streak is made of.
  final int? streak;

  /// Stats the friend doesn't share with you right now (everything when
  /// they paused sharing).
  final Set<StatMetric> hidden;

  bool isHidden(StatMetric metric) => hidden.contains(metric);

  bool get sharesNothing => hidden.length == StatMetric.values.length;

  /// Today's value for [metric], or null when hidden.
  int? todayValue(StatMetric metric) {
    if (isHidden(metric)) return null;
    final t = today;
    return t == null ? 0 : metric.valueOf(t);
  }
}

/// Who's ahead on one stat this week.
enum Leader { you, friend, tie, unknown }

/// You vs a friend on one stat this week, ranked the same way as the
/// leaderboard (weekly totals, or daily averages for sleep and screen time).
class StatComparison {
  const StatComparison({
    required this.metric,
    required this.yours,
    required this.theirs,
    this.theirsHidden = false,
  });

  /// Compares [mine] with [friend]'s week, leaving their value out when they
  /// keep [metric] private.
  factory StatComparison.of(
    StatMetric metric, {
    required WeeklySummary mine,
    required FriendSnapshot friend,
  }) => StatComparison(
    metric: metric,
    yours: mine.daysTracked == 0 ? null : metric.leaderboardValue(mine),
    theirs: friend.isHidden(metric) || friend.week.daysTracked == 0
        ? null
        : metric.leaderboardValue(friend.week),
    theirsHidden: friend.isHidden(metric),
  );

  final StatMetric metric;

  /// Null when you have nothing tracked this week.
  final double? yours;

  /// Null when hidden or nothing tracked.
  final double? theirs;

  /// The friend keeps this stat private (show 🔒, not "no data").
  final bool theirsHidden;

  Leader get leader {
    final a = yours;
    final b = theirs;
    if (a == null || b == null) return Leader.unknown;
    if (a.round() == b.round()) return Leader.tie;
    final youWin = metric.higherIsBetter ? a > b : a < b;
    return youWin ? Leader.you : Leader.friend;
  }

  /// How far apart you are, rounded. Null when [leader] is unknown.
  int? get gap {
    final a = yours;
    final b = theirs;
    if (a == null || b == null) return null;
    return (a - b).abs().round();
  }
}

/// A short, friendly line about your steps this week:
/// "Alex is 2,000 steps ahead 👀", "You're 1,200 steps ahead of Alex 💪".
///
/// Never shames: falling behind is framed as a race, not a failure.
String stepsNudge(
  String friendName,
  StatComparison steps, {
  required String Function(int) formatSteps,
}) {
  assert(steps.metric == StatMetric.steps);
  final gap = steps.gap;
  return switch (steps.leader) {
    Leader.unknown =>
      steps.theirsHidden
          ? '$friendName keeps steps private 🔒'
          : steps.theirs == null
          ? 'No steps from $friendName yet this week'
          : 'Sync your steps to race $friendName 🏁',
    Leader.tie => 'Neck and neck with $friendName 🤝',
    Leader.friend => '$friendName is ${formatSteps(gap!)} steps ahead 👀',
    Leader.you => "You're ${formatSteps(gap!)} steps ahead of $friendName 💪",
  };
}
