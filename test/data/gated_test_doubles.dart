import 'dart:async';

import 'package:flutter_test/flutter_test.dart' show pumpEventQueue;
import 'package:life360/data/friends_repository.dart';
import 'package:life360/data/mock_friends_repository.dart';
import 'package:life360/data/stats_repository.dart';
import 'package:life360/models/models.dart';

/// Holds every call until [open] or [openReversed] so a test can check that
/// calls were all started before any finished (i.e. they overlap), and that
/// results are matched up correctly when they finish out of order. Calls made
/// after the gate is open pass straight through.
class Gate {
  final _waiting = <Completer<void>>[];
  bool _isOpen = false;

  /// Completes when this call is released.
  Future<void> wait() {
    if (_isOpen) return Future.value();
    final completer = Completer<void>();
    _waiting.add(completer);
    return completer.future;
  }

  /// Releases every waiting call, first call first.
  void open() {
    _isOpen = true;
    for (final completer in _waiting) {
      completer.complete();
    }
    _waiting.clear();
  }

  /// Releases the waiting calls one at a time, last call first, letting each
  /// one finish before the next is released.
  Future<void> openReversed() async {
    _isOpen = true;
    final waiting = _waiting.reversed.toList();
    _waiting.clear();
    for (final completer in waiting) {
      completer.complete();
      await pumpEventQueue();
    }
  }
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
    await gate.wait();
    if (failIds.contains(userId)) throw StateError('userById $userId');
    return super.userById(userId);
  }
}

/// A [StatsRepository] whose [weeklySummary] and [dailyStats] wait on [gate].
/// Each summary has one day (the first of the week) with [stepsByUser] steps
/// for that user, or 100 when the user is not listed. Ids in [failIds] throw
/// once the gate opens.
class GatedStatsRepository implements StatsRepository {
  GatedStatsRepository(
    this.gate, {
    this.failIds = const {},
    this.stepsByUser = const {},
  });

  final Gate gate;
  final Set<String> failIds;
  final Map<String, int> stepsByUser;

  int _steps(String userId) => stepsByUser[userId] ?? 100;

  /// Ids in the order [weeklySummary] or [dailyStats] was called.
  final started = <String>[];

  @override
  Future<WeeklySummary> weeklySummary(String userId, {DateTime? weekOf}) async {
    started.add(userId);
    await gate.wait();
    if (failIds.contains(userId)) throw StateError('weeklySummary $userId');
    final weekStart = startOfWeek(weekOf ?? DateTime.now());
    return WeeklySummary.fromDays(
      userId: userId,
      weekStart: weekStart,
      stats: [
        DailyStats(userId: userId, date: weekStart, steps: _steps(userId)),
      ],
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
    await gate.wait();
    if (failIds.contains(userId)) throw StateError('weeklySummary $userId');
    return [
      DailyStats(userId: userId, date: dateOnly(from), steps: _steps(userId)),
    ];
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
