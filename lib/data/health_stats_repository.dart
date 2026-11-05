import '../models/models.dart';
import 'friends_repository.dart';
import 'health_sync.dart';
import 'stats_repository.dart';

/// [StatsRepository] that uses the phone's real health data for the
/// signed-in user and [fallback] (mock data, later Firestore) for everyone
/// else.
///
/// Until health access is granted, it behaves exactly like [fallback].
class HealthStatsRepository implements StatsRepository {
  HealthStatsRepository({
    required this.fallback,
    required this.friends,
    required this.health,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final StatsRepository fallback;
  final FriendsRepository friends;
  final HealthSync health;
  final DateTime Function() _clock;

  bool _useHealth(String userId) =>
      health.isConnected && userId == health.userId;

  /// Synced days that actually have something in them. A blank day usually
  /// means the watch wasn't worn, and counting it would drag averages down.
  Iterable<DailyStats> get _trackedDays => health.days.where(
    (d) =>
        d.steps > 0 ||
        d.sleepMinutes > 0 ||
        d.workoutMinutes > 0 ||
        d.activeCalories > 0,
  );

  @override
  Future<List<DailyStats>> dailyStats(
    String userId, {
    required DateTime from,
    required DateTime to,
  }) async {
    if (!_useHealth(userId)) {
      return fallback.dailyStats(userId, from: from, to: to);
    }
    final start = dateOnly(from);
    final end = dateOnly(to);
    return _trackedDays
        .where((d) => !d.date.isBefore(start) && !d.date.isAfter(end))
        .toList();
  }

  @override
  Future<WeeklySummary> weeklySummary(String userId, {DateTime? weekOf}) async {
    if (!_useHealth(userId)) {
      return fallback.weeklySummary(userId, weekOf: weekOf);
    }
    return WeeklySummary.fromDays(
      userId: userId,
      weekStart: weekOf ?? _clock(),
      stats: _trackedDays,
    );
  }

  @override
  Future<List<LeaderboardEntry>> leaderboard(
    StatMetric metric, {
    DateTime? weekOf,
  }) async => rankLeaderboard(metric, await _summaries(weekOf));

  @override
  Future<List<LeaderboardEntry>> xpLeaderboard({DateTime? weekOf}) async =>
      rankLeaderboardByXp(await _summaries(weekOf));

  Future<Map<UserProfile, WeeklySummary>> _summaries(DateTime? weekOf) async {
    final people = [await friends.currentUser(), ...await friends.friends()];
    return {
      for (final p in people) p: await weeklySummary(p.id, weekOf: weekOf),
    };
  }
}
