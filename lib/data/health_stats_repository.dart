import '../models/models.dart';
import 'friends_repository.dart';
import 'health/health_source.dart';
import 'stats_repository.dart';

/// [StatsRepository] that serves the current user's stats from a
/// [HealthSource] and delegates everyone else (friends, and the current user
/// until health is connected) to [_fallback].
///
/// Health data is only used after [connect] succeeds. Until then (or if the
/// user denies everything) the fallback, e.g. the mock repository, serves it.
class HealthStatsRepository implements StatsRepository {
  HealthStatsRepository({
    required this._source,
    required this._fallback,
    required this._friends,
  });

  final HealthSource _source;
  final StatsRepository _fallback;
  final FriendsRepository _friends;

  bool _connected = false;

  /// Whether the current user's stats now come from the health platform.
  bool get isConnected => _connected;

  /// Checks availability and asks for read access. Returns true when at least
  /// one metric is readable, after which the current user's stats come from
  /// health. Otherwise the fallback keeps serving them.
  Future<bool> connect() async {
    if (await _source.availability() != HealthAvailability.available) {
      return _connected = false;
    }
    final permissions = await _source.requestPermissions();
    return _connected = permissions.anyReadable;
  }

  Future<bool> _usesHealth(String userId) async =>
      _connected && userId == (await _friends.currentUser()).id;

  @override
  Future<List<DailyStats>> dailyStats(
    String userId, {
    required DateTime from,
    required DateTime to,
  }) async {
    if (!await _usesHealth(userId)) {
      return _fallback.dailyStats(userId, from: from, to: to);
    }
    return _source.fetchDailyStats(userId, from: from, to: to);
  }

  @override
  Future<WeeklySummary> weeklySummary(String userId, {DateTime? weekOf}) async {
    if (!await _usesHealth(userId)) {
      return _fallback.weeklySummary(userId, weekOf: weekOf);
    }
    final weekStart = startOfWeek(weekOf ?? DateTime.now());
    final days = await _source.fetchDailyStats(
      userId,
      from: weekStart,
      to: DateTime(weekStart.year, weekStart.month, weekStart.day + 6),
    );
    return WeeklySummary.fromDays(
      userId: userId,
      weekStart: weekStart,
      stats: days,
    );
  }

  @override
  Future<List<LeaderboardEntry>> leaderboard(
    StatMetric metric, {
    DateTime? weekOf,
  }) async {
    final people = [await _friends.currentUser(), ...await _friends.friends()];
    final summaries = {
      for (final p in people) p: await weeklySummary(p.id, weekOf: weekOf),
    };
    return rankLeaderboard(metric, summaries);
  }
}
