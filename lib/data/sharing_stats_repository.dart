import '../models/models.dart';
import 'connectable_stats_repository.dart';
import 'friends_repository.dart';
import 'health/health_source.dart';
import 'published_sharing_repository.dart';
import 'sharing_repository.dart';

/// Wraps a stats repository so everything friends can see respects each
/// person's [SharingSettings]:
///
/// - A metric board only ranks people who share that metric, so someone who
///   keeps sleep private is left off the Sleep board, including the current
///   user on their own screen. That screen is what friends see.
/// - Friends' daily stats and weekly summaries come back with hidden metrics
///   zeroed. Screens should check [SharingRepository.settingsFor] and show 🔒
///   rather than the 0.
/// - Paused users are left off every board, XP included.
///
/// Settings are looked up after the stats are read, because for friends
/// they come from what was published (see [PublishedSharingRepository]).
///
/// Your own stats are never filtered when you read them yourself.
///
/// The XP board still counts every metric, so keeping sleep private never
/// costs XP. It only shows a total, never a hidden value.
class SharingStatsRepository implements ConnectableStatsRepository {
  SharingStatsRepository({
    required this.inner,
    required this.friends,
    required this.sharing,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final ConnectableStatsRepository inner;
  final FriendsRepository friends;
  final SharingRepository sharing;
  final DateTime Function() _clock;

  // --- Connection: unchanged, straight through to [inner]. ---

  @override
  String get sourceName => inner.sourceName;

  @override
  bool get isConnected => inner.isConnected;

  @override
  HealthAvailability? get availability => inner.availability;

  @override
  DateTime? get lastSyncedAt => inner.lastSyncedAt;

  @override
  Set<StatMetric> get deniedMetrics => inner.deniedMetrics;

  @override
  Future<bool> connect() => inner.connect();

  @override
  Future<void> restoreConnection() => inner.restoreConnection();

  @override
  Future<void> openInstallPage() => inner.openInstallPage();

  // --- Stats ---

  Future<bool> _isMe(String userId) async =>
      userId == (await friends.currentUser()).id;

  /// What friends can't see of [userId] right now.
  Set<StatMetric> _hiddenFor(String userId) {
    final settings = sharing.settingsFor(userId);
    return settings.isPaused(_clock())
        ? StatMetric.values.toSet()
        : settings.hidden;
  }

  @override
  Future<List<DailyStats>> dailyStats(
    String userId, {
    required DateTime from,
    required DateTime to,
  }) async {
    final days = await inner.dailyStats(userId, from: from, to: to);
    if (await _isMe(userId)) return days;
    final hidden = _hiddenFor(userId);
    return [for (final d in days) maskStats(d, hidden)];
  }

  @override
  Future<WeeklySummary> weeklySummary(String userId, {DateTime? weekOf}) async {
    final week = await inner.weeklySummary(userId, weekOf: weekOf);
    if (await _isMe(userId)) return week;
    final hidden = _hiddenFor(userId);
    if (hidden.isEmpty) return week;
    return WeeklySummary.fromDays(
      userId: userId,
      weekStart: week.weekStart,
      stats: [for (final d in week.days) maskStats(d, hidden)],
    );
  }

  @override
  Future<List<LeaderboardEntry>> leaderboard(
    StatMetric metric, {
    DateTime? weekOf,
    Iterable<String>? userIds,
  }) async {
    final now = _clock();
    // Rank after reading: for friends, who shares what is learned from the
    // stats they published (see PublishedSharingRepository).
    final summaries = await _summaries(await _people(userIds), weekOf);
    return rankLeaderboard(metric, {
      for (final e in summaries.entries)
        if (sharing.settingsFor(e.key.id).isShared(metric, now)) e.key: e.value,
    });
  }

  @override
  Future<List<LeaderboardEntry>> xpLeaderboard({
    DateTime? weekOf,
    Iterable<String>? userIds,
  }) async {
    final now = _clock();
    final summaries = await _summaries(await _people(userIds), weekOf);
    return rankLeaderboardByXp({
      for (final e in summaries.entries)
        if (!sharing.settingsFor(e.key.id).isPaused(now)) e.key: e.value,
    });
  }

  /// The current user plus their friends, or plus just [userIds] when given
  /// (unknown ids skipped). Same people the inner repository would rank.
  Future<List<UserProfile>> _people(Iterable<String>? userIds) async {
    final me = await friends.currentUser();
    if (userIds == null) return [me, ...await friends.friends()];
    final others = <UserProfile>[];
    for (final id in userIds.toSet()) {
      final user = await friends.userById(id);
      if (user != null && user.id != me.id) others.add(user);
    }
    return [me, ...others];
  }

  /// Unmasked summaries: ranking needs the real value of the shared metric.
  Future<Map<UserProfile, WeeklySummary>> _summaries(
    Iterable<UserProfile> people,
    DateTime? weekOf,
  ) async => {
    for (final p in people) p: await inner.weeklySummary(p.id, weekOf: weekOf),
  };
}

/// [d] with every metric in [hidden] set to 0.
DailyStats maskStats(DailyStats d, Set<StatMetric> hidden) {
  if (hidden.isEmpty) return d;
  int keep(StatMetric m, int v) => hidden.contains(m) ? 0 : v;
  return DailyStats(
    userId: d.userId,
    date: d.date,
    steps: keep(StatMetric.steps, d.steps),
    sleepMinutes: keep(StatMetric.sleep, d.sleepMinutes),
    workoutMinutes: keep(StatMetric.workout, d.workoutMinutes),
    activeCalories: keep(StatMetric.calories, d.activeCalories),
    screenTimeMinutes: keep(StatMetric.screenTime, d.screenTimeMinutes),
  );
}
