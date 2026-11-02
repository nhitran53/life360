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
  }) async {
    final people = [await _friends.currentUser(), ...await _friends.friends()];
    final summaries = {
      for (final p in people) p: await weeklySummary(p.id, weekOf: weekOf),
    };
    return rankLeaderboard(metric, summaries);
  }
}
