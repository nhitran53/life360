import 'dart:async';

import 'package:life360/data/friends_repository.dart';
import 'package:life360/data/mock_friends_repository.dart';
import 'package:life360/data/stats_repository.dart';
import 'package:life360/models/models.dart';

/// Holds every call until [open] so a test can check that calls were all
/// started before any finished (i.e. they overlap).
class Gate {
  final _completer = Completer<void>();
  Future<void> get opened => _completer.future;
  void open() => _completer.complete();
}

/// [MockFriendsRepository] whose [userById] waits on [gate]. Ids in [failIds]
/// throw once the gate opens.
class GatedFriendsRepository extends MockFriendsRepository
    implements FriendsRepository {
  GatedFriendsRepository(this.gate, {this.failIds = const {}});

  final Gate gate;
  final Set<String> failIds;

  /// Ids in the order [userById] was called.
  final started = <String>[];

  @override
  Future<UserProfile?> userById(String userId) async {
    started.add(userId);
    await gate.opened;
    if (failIds.contains(userId)) throw StateError('userById $userId');
    return super.userById(userId);
  }
}

/// A [StatsRepository] whose [weeklySummary] and [dailyStats] wait on [gate]. Each summary
/// has 100 steps on the first day of the week. Ids in [failIds] throw once
/// the gate opens.
class GatedStatsRepository implements StatsRepository {
  GatedStatsRepository(this.gate, {this.failIds = const {}});

  final Gate gate;
  final Set<String> failIds;

  /// Ids in the order [weeklySummary] or [dailyStats] was called.
  final started = <String>[];

  @override
  Future<WeeklySummary> weeklySummary(String userId, {DateTime? weekOf}) async {
    started.add(userId);
    await gate.opened;
    if (failIds.contains(userId)) throw StateError('weeklySummary $userId');
    final weekStart = startOfWeek(weekOf ?? DateTime.now());
    return WeeklySummary.fromDays(
      userId: userId,
      weekStart: weekStart,
      stats: [DailyStats(userId: userId, date: weekStart, steps: 100)],
    );
  }

  /// Used for the current user by repositories that rebuild their summary
  /// from days. Same gating and failures as [weeklySummary].
  @override
  Future<List<DailyStats>> dailyStats(
    String userId, {
    required DateTime from,
    required DateTime to,
  }) async {
    started.add(userId);
    await gate.opened;
    if (failIds.contains(userId)) throw StateError('weeklySummary $userId');
    return [DailyStats(userId: userId, date: dateOnly(from), steps: 100)];
  }

  @override
  Future<List<LeaderboardEntry>> leaderboard(
    StatMetric metric, {
    DateTime? weekOf,
    Iterable<String>? userIds,
  }) => throw UnimplementedError();

  @override
  Future<List<LeaderboardEntry>> xpLeaderboard({
    DateTime? weekOf,
    Iterable<String>? userIds,
  }) => throw UnimplementedError();
}
