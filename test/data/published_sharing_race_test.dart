import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life360/data/firestore_stats_repository.dart';
import 'package:life360/data/health/fake_health_source.dart';
import 'package:life360/data/health_stats_repository.dart';
import 'package:life360/data/mock_friends_repository.dart';
import 'package:life360/data/mock_stats_repository.dart';
import 'package:life360/data/published_sharing_repository.dart';
import 'package:life360/data/sharing_repository.dart';
import 'package:life360/data/sharing_stats_repository.dart';
import 'package:life360/data/stats_repository.dart';
import 'package:life360/models/models.dart';

// Reads of different weeks run at the same time and finish in any order. What
// a friend shares must not depend on which one finishes last (issue #46).
void main() {
  // A Thursday, so the week is Mon 2026-03-09 .. Sun 2026-03-15.
  final now = DateTime(2026, 3, 12, 15);
  final lastWeek = DateTime(2026, 3, 5);
  const friendId = 'u_alex';

  late _FlakyDb db;
  late MockFriendsRepository friends;
  late _GatedStatsRepository gated;
  late PublishedSharingRepository published;
  late SharingStatsRepository stats;

  Future<void> put(String key, Map<String, Object?> fields) =>
      db.doc('users/$friendId/daily/$key').set({'date': key, ...fields});

  /// Lets reads that are free to run finish.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  setUp(() async {
    db = _FlakyDb();
    friends = MockFriendsRepository(clock: () => now);
    final own = MockStatsRepository(friends: friends, clock: () => now);
    published = PublishedSharingRepository(MockSharingRepository(initial: {}));
    addTearDown(published.dispose);
    gated = _GatedStatsRepository(
      FirestoreStatsRepository(
        db,
        own: own,
        friends: friends,
        published: published,
        clock: () => now,
      ),
    );
    stats = SharingStatsRepository(
      inner: HealthStatsRepository(
        source: FakeHealthSource(),
        fallback: gated,
        friends: friends,
      ),
      friends: friends,
      sharing: published,
      clock: () => now,
    );
    // This week: steps only. The week before also had sleep.
    await put('2026-03-10', {'steps': 8000});
    await put('2026-03-04', {'steps': 5000, 'sleep': 420});
  });

  for (final lastWeekFinishesFirst in [true, false]) {
    final order = lastWeekFinishesFirst
        ? 'last week finishes first'
        : 'this week finishes first';
    test('hidden sleep stays hidden when $order', () async {
      final thisWeekGate = gated.hold(friendId, startOfWeek(now));
      final lastWeekGate = gated.hold(friendId, startOfWeek(lastWeek));

      final sleepBoard = stats.leaderboard(StatMetric.sleep, weekOf: now);
      final lastWeekSummary = stats.weeklySummary(friendId, weekOf: lastWeek);
      await settle();

      final (first, second) = lastWeekFinishesFirst
          ? (lastWeekGate, thisWeekGate)
          : (thisWeekGate, lastWeekGate);
      first.complete();
      await settle();
      second.complete();

      final board = await sleepBoard;
      final summary = await lastWeekSummary;
      expect(board.map((e) => e.user.id), isNot(contains(friendId)));
      expect(summary.total(StatMetric.sleep), 0);
      expect(summary.total(StatMetric.steps), 5000);

      final stepsBoard = await stats.leaderboard(StatMetric.steps, weekOf: now);
      expect(stepsBoard.map((e) => e.user.id), contains(friendId));
    });
  }

  test(
    'a failed read after a good one leaves what is shared unchanged',
    () async {
      await stats.weeklySummary(friendId, weekOf: now);
      final before = published.settingsFor(friendId);
      expect(before.isShared(StatMetric.steps, now), isTrue);

      db.failing = true;
      await stats.weeklySummary(friendId, weekOf: now);
      await stats.weeklySummary(friendId, weekOf: lastWeek);
      expect(published.settingsFor(friendId), before);
    },
  );

  test('a failed current-week lookup leaves a hidden metric masked', () async {
    // Last week's read succeeds (steps + sleep); only the lookup of this
    // week, which would show sleep is hidden, fails.
    db.readsBeforeFailing = 1;
    final summary = await stats.weeklySummary(friendId, weekOf: lastWeek);
    expect(summary.total(StatMetric.sleep), 0);
    expect(published.recordedThrough(friendId), isNull);
    expect(
      published.settingsFor(friendId).isShared(StatMetric.sleep, now),
      isFalse,
    );

    db.readsBeforeFailing = null;
    final board = await stats.leaderboard(StatMetric.sleep, weekOf: lastWeek);
    expect(board.map((e) => e.user.id), isNot(contains(friendId)));
  });

  test('a future-week read does not hide a friend sharing this week', () async {
    final nextWeek = DateTime(2026, 3, 16);
    final future = await stats.weeklySummary(friendId, weekOf: nextWeek);
    expect(future.total(StatMetric.steps), 0);
    expect(published.recordedThrough(friendId), isNull);

    await stats.weeklySummary(friendId, weekOf: now);
    final board = await stats.leaderboard(StatMetric.steps, weekOf: now);
    expect(board.map((e) => e.user.id), contains(friendId));
    final summary = await stats.weeklySummary(friendId, weekOf: now);
    expect(summary.total(StatMetric.steps), 8000);
    expect(published.settingsFor(friendId).isPaused(now), isFalse);
  });

  test('a failed first read leaves the private defaults', () async {
    db.failing = true;
    await stats.weeklySummary(friendId, weekOf: now);
    final settings = published.settingsFor(friendId);
    expect(settings, const SharingSettings());
    expect(settings.isPaused(now), isFalse);
  });
}

/// Fails every read while [failing], or every read after the first
/// [readsBeforeFailing] ones.
class _FlakyDb extends FakeFirebaseFirestore {
  bool failing = false;
  int? readsBeforeFailing;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    final left = readsBeforeFailing;
    if (left != null) readsBeforeFailing = left - 1;
    if (failing || (left != null && left <= 0)) {
      throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
    }
    return super.collection(path);
  }
}

/// Holds a user's reads of one week until released, so a test picks the order
/// they reach Firestore (and so the order they are recorded in).
class _GatedStatsRepository implements StatsRepository {
  _GatedStatsRepository(this._inner);

  final StatsRepository _inner;
  final _gates = <String, Completer<void>>{};

  String _key(String userId, DateTime weekStart) => '$userId $weekStart';

  Completer<void> hold(String userId, DateTime weekStart) =>
      _gates[_key(userId, weekStart)] = Completer<void>();

  @override
  Future<WeeklySummary> weeklySummary(String userId, {DateTime? weekOf}) async {
    final gate = _gates[_key(userId, startOfWeek(weekOf!))];
    if (gate != null) await gate.future;
    return _inner.weeklySummary(userId, weekOf: weekOf);
  }

  @override
  Future<List<DailyStats>> dailyStats(
    String userId, {
    required DateTime from,
    required DateTime to,
  }) => _inner.dailyStats(userId, from: from, to: to);

  @override
  Future<List<LeaderboardEntry>> leaderboard(
    StatMetric metric, {
    DateTime? weekOf,
    Iterable<String>? userIds,
  }) => _inner.leaderboard(metric, weekOf: weekOf, userIds: userIds);

  @override
  Future<List<LeaderboardEntry>> xpLeaderboard({
    DateTime? weekOf,
    Iterable<String>? userIds,
  }) => _inner.xpLeaderboard(weekOf: weekOf, userIds: userIds);
}
