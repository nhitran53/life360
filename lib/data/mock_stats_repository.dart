import '../models/models.dart';
import 'friends_repository.dart';
import 'mock_data.dart';
import 'stats_repository.dart';

/// [StatsRepository] backed by [generateMockStats]: two weeks of realistic,
/// deterministic fake data for the current user and every mock friend.
class MockStatsRepository implements StatsRepository {
  MockStatsRepository({
    required this._friends,
    DateTime Function()? clock,
    int seed = 360,
  })  : _clock = clock ?? DateTime.now,
        _stats = generateMockStats(
            today: (clock ?? DateTime.now)(), seed: seed);

  final FriendsRepository _friends;
  final DateTime Function() _clock;
  final List<DailyStats> _stats;

  @override
  Future<List<DailyStats>> dailyStats(
      String userId, {
        required DateTime from,
        required DateTime to,
      }) async {
    final start = dateOnly(from);
    final end = dateOnly(to);
    return _stats
        .where((s) =>
    s.userId == userId &&
        !s.date.isBefore(start) &&
        !s.date.isAfter(end))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  @override
  Future<WeeklySummary> weeklySummary(String userId,
      {DateTime? weekOf}) async =>
      WeeklySummary.fromDays(
        userId: userId,
        weekStart: weekOf ?? _clock(),
        stats: _stats,
      );

  @override
  Future<List<LeaderboardEntry>> leaderboard(
      StatMetric metric, {
        DateTime? weekOf,
        Iterable<String>? userIds,
      }) async =>
      rankLeaderboard(metric, await _summaries(weekOf, userIds));

  @override
  Future<List<LeaderboardEntry>> xpLeaderboard({
    DateTime? weekOf,
    Iterable<String>? userIds,
  }) async =>
      rankLeaderboardByXp(await _summaries(weekOf, userIds));

  /// Weekly summaries for the current user plus their accepted friends, or
  /// plus just [userIds] when given (unknown ids are skipped).
  Future<Map<UserProfile, WeeklySummary>> _summaries(
      DateTime? weekOf,
      Iterable<String>? userIds,
      ) async {
    final me = await _friends.currentUser();
    final others = <UserProfile>[];
    if (userIds == null) {
      others.addAll(await _friends.friends());
    } else {
      for (final id in userIds.toSet()) {
        final user = await _friends.userById(id);
        if (user != null && user.id != me.id) others.add(user);
      }
    }
    final people = [me, ...others];
    return {
      for (final p in people) p: await weeklySummary(p.id, weekOf: weekOf),
    };
  }
}