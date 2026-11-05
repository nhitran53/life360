import 'stat_metric.dart';
import 'user_profile.dart';
import 'weekly_summary.dart';
import 'xp.dart';

/// One row on the weekly leaderboard.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.user,
    required this.metric,
    required this.value,
  });

  /// 1-based. Ties share a rank (1, 1, 3).
  final int rank;
  final UserProfile user;

  /// The stat this board ranks, or null for the Overall XP board.
  final StatMetric? metric;

  /// See [StatMetric.leaderboardValue]: a weekly total or a daily average.
  /// On the XP board, the week's XP (see [weeklyXp]).
  final double value;
}

/// Ranks [summaries] (one per user) for [metric], best first.
///
/// Users with no tracked days always go last, so an empty week can't win
/// a "lower is better" metric like screen time. Equal values share a rank
/// and are then ordered by display name for stable output.
List<LeaderboardEntry> rankLeaderboard(
  StatMetric metric,
  Map<UserProfile, WeeklySummary> summaries,
) =>
    _rank(summaries,
        metric: metric,
        score: metric.leaderboardValue,
        higherIsBetter: metric.higherIsBetter);

/// Ranks [summaries] by [weeklyXp], most XP first. Same tie and
/// empty-week rules as [rankLeaderboard].
List<LeaderboardEntry> rankLeaderboardByXp(
  Map<UserProfile, WeeklySummary> summaries,
) =>
    _rank(summaries,
        metric: null,
        score: (w) => weeklyXp(w).toDouble(),
        higherIsBetter: true);

List<LeaderboardEntry> _rank(
  Map<UserProfile, WeeklySummary> summaries, {
  required StatMetric? metric,
  required double Function(WeeklySummary) score,
  required bool higherIsBetter,
}) {
  final rows = summaries.entries.toList()
    ..sort((a, b) {
      final aEmpty = a.value.daysTracked == 0;
      final bEmpty = b.value.daysTracked == 0;
      if (aEmpty != bEmpty) return aEmpty ? 1 : -1;
      final av = score(a.value);
      final bv = score(b.value);
      final byValue = higherIsBetter ? bv.compareTo(av) : av.compareTo(bv);
      if (byValue != 0) return byValue;
      return a.key.displayName.compareTo(b.key.displayName);
    });

  final entries = <LeaderboardEntry>[];
  for (var i = 0; i < rows.length; i++) {
    final value = score(rows[i].value);
    final emptyNow = rows[i].value.daysTracked == 0;
    final tiesPrevious = i > 0 &&
        entries[i - 1].value == value &&
        (rows[i - 1].value.daysTracked == 0) == emptyNow;
    entries.add(LeaderboardEntry(
      rank: tiesPrevious ? entries[i - 1].rank : i + 1,
      user: rows[i].key,
      metric: metric,
      value: value,
    ));
  }
  return entries;
}
