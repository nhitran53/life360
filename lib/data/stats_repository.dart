import '../models/models.dart';

/// Source of health stats. Screens depend on this interface only, so the
/// mock can later be swapped for HealthKit / Health Connect + Firestore.
abstract interface class StatsRepository {
  /// Daily stats for [userId] from [from] to [to] (both inclusive, by day),
  /// oldest first. Days with no data are omitted.
  Future<List<DailyStats>> dailyStats(
      String userId, {
        required DateTime from,
        required DateTime to,
      });

  /// Summary of the week containing [weekOf] (defaults to this week).
  Future<WeeklySummary> weeklySummary(String userId, {DateTime? weekOf});

  /// The current user and their accepted friends ranked for [metric] over
  /// the week containing [weekOf] (defaults to this week).
  ///
  /// Pass [userIds] to rank the current user against just those people
  /// (e.g. one family) instead of their friends.
  Future<List<LeaderboardEntry>> leaderboard(
      StatMetric metric, {
        DateTime? weekOf,
        Iterable<String>? userIds,
      });

  /// Same people as [leaderboard], ranked by the week's XP (see [weeklyXp]).
  Future<List<LeaderboardEntry>> xpLeaderboard({
    DateTime? weekOf,
    Iterable<String>? userIds,
  });
}