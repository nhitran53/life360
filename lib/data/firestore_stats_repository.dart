import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';
import 'firestore_stats_publisher.dart';
import 'friends_repository.dart';
import 'published_sharing_repository.dart';
import 'stats_repository.dart';

/// [StatsRepository] that reads friends' published daily stats from
/// `users/{uid}/daily/{yyyy-MM-dd}` (see [FirestoreStatsPublisher]). The
/// current user's own stats come from [own].
///
/// A friend's document only has the metrics they share, so a missing key
/// reads as 0 here, while a present key is a real value (0 included). Which
/// keys were present is handed to [published], which is how the app knows
/// what each friend shares (their settings aren't readable).
/// Firestore only lets accepted friends read these documents. A failed or
/// refused read returns no days.
class FirestoreStatsRepository implements StatsRepository {
  FirestoreStatsRepository(
    this._db, {
    required this.own,
    required this._friends,
    this.published,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final FirebaseFirestore _db;
  final FriendsRepository _friends;
  final DateTime Function() _clock;

  /// Told which metrics each friend's published days contain.
  final PublishedSharingRepository? published;

  /// Serves the current user's stats (e.g. the demo data before health is
  /// connected).
  final StatsRepository own;

  Future<bool> _isMe(String userId) async =>
      userId == (await _friends.currentUser()).id;

  @override
  Future<List<DailyStats>> dailyStats(
    String userId, {
    required DateTime from,
    required DateTime to,
  }) async {
    if (await _isMe(userId)) return own.dailyStats(userId, from: from, to: to);
    final QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('daily')
          .where('date', isGreaterThanOrEqualTo: dateKey(from))
          .where('date', isLessThanOrEqualTo: dateKey(to))
          .get();
    } on FirebaseException {
      published?.record(userId, const {});
      return const [];
    }
    final shared = <StatMetric>{};
    final days = [
      for (final doc in snapshot.docs)
        ?_parse(userId, doc.id, doc.data(), shared),
    ]..sort((a, b) => a.date.compareTo(b.date));
    published?.record(userId, shared);
    return days;
  }

  /// Null for a document that isn't a valid day (its id must be the date).
  /// Adds the metrics the document has a valid value for to [shared].
  DailyStats? _parse(
    String userId,
    String id,
    Map<String, dynamic> data,
    Set<StatMetric> shared,
  ) {
    final date = DateTime.tryParse(id);
    if (date == null || dateKey(date) != id) return null;
    int value(StatMetric m) {
      final n = data[m.name];
      if (n is! int || n < 0) return 0;
      shared.add(m);
      return n;
    }

    return DailyStats(
      userId: userId,
      date: date,
      steps: value(StatMetric.steps),
      sleepMinutes: value(StatMetric.sleep),
      workoutMinutes: value(StatMetric.workout),
      activeCalories: value(StatMetric.calories),
      screenTimeMinutes: value(StatMetric.screenTime),
    );
  }

  @override
  Future<WeeklySummary> weeklySummary(String userId, {DateTime? weekOf}) async {
    if (await _isMe(userId)) return own.weeklySummary(userId, weekOf: weekOf);
    final weekStart = startOfWeek(weekOf ?? _clock());
    final days = await dailyStats(
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
    Iterable<String>? userIds,
  }) async => rankLeaderboard(metric, await _summaries(weekOf, userIds));

  @override
  Future<List<LeaderboardEntry>> xpLeaderboard({
    DateTime? weekOf,
    Iterable<String>? userIds,
  }) async => rankLeaderboardByXp(await _summaries(weekOf, userIds));

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
    return {
      for (final p in [me, ...others])
        p: await weeklySummary(p.id, weekOf: weekOf),
    };
  }
}
