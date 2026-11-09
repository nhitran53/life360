import '../models/models.dart';
import 'connectable_stats_repository.dart';
import 'friends_repository.dart';
import 'health/health_connection_store.dart';
import 'health/health_source.dart';
import 'stats_repository.dart';

/// [StatsRepository] that serves the current user's stats from a
/// [HealthSource] and delegates everyone else (friends, and the current user
/// until health is connected) to [_fallback].
///
/// Health data is only used after [connect] succeeds. Until then (or if the
/// user denies everything) the fallback, e.g. the mock repository, serves it.
class HealthStatsRepository implements ConnectableStatsRepository {
  HealthStatsRepository({
    required this._source,
    required this._fallback,
    required this._friends,
    HealthConnectionStore? store,
    DateTime Function()? clock,
  }) : _store = store ?? InMemoryHealthConnectionStore(),
       _clock = clock ?? DateTime.now;

  final HealthSource _source;
  final StatsRepository _fallback;
  final FriendsRepository _friends;
  final HealthConnectionStore _store;
  final DateTime Function() _clock;

  Future<void>? _restoring;
  bool _connected = false;
  HealthAvailability? _availability;
  HealthPermissionResult? _permissions;
  DateTime? _lastSyncedAt;

  /// "Apple Health" or "Health Connect", for the UI.
  @override
  String get sourceName => _source.displayName;

  /// Whether the current user's stats now come from the health platform.
  @override
  bool get isConnected => _connected;

  /// Result of the last [connect], or null before the first attempt.
  @override
  HealthAvailability? get availability => _availability;

  /// When the last successful [connect] finished, or null.
  @override
  DateTime? get lastSyncedAt => _lastSyncedAt;

  /// Metrics the user turned down in the last [connect]. Their values are
  /// unknown, not 0, so the UI must not show them as numbers. Empty before
  /// connecting; on iOS reads are never reported as denied.
  @override
  Set<StatMetric> get deniedMetrics {
    final permissions = _permissions;
    if (permissions == null) return const {};
    return _source.readableMetrics.difference(permissions.readable);
  }

  /// Checks availability and asks for read access. Returns true when at least
  /// one metric is readable, after which the current user's stats come from
  /// health. Otherwise the fallback keeps serving them.
  ///
  /// Also the manual re-sync: it re-checks permissions, which the user may
  /// have changed in the system settings, and stamps [lastSyncedAt].
  @override
  Future<bool> connect() => _sync(_source.requestPermissions);

  /// Shared by [connect] and restore: checks availability, then reads
  /// permissions through [permissions] (the only difference between the two:
  /// connect may prompt, restore never does).
  Future<bool> _sync(
    Future<HealthPermissionResult> Function() permissions,
  ) async {
    _availability = await _source.availability();
    if (_availability != HealthAvailability.available) {
      _permissions = null;
      _connected = false;
    } else {
      _permissions = await permissions();
      _connected = _permissions!.anyReadable;
      if (_connected) _lastSyncedAt = _clock();
    }
    await _remember(_connected);
    return _connected;
  }

  /// On launch: if the user connected last time, re-checks availability and
  /// the current permissions (which may have changed since) so the UI starts
  /// on Sync instead of Connect. Never asks for permission: only [connect]
  /// may show the system dialog. If all access is gone the saved flag is
  /// cleared; if some is gone those metrics show as [deniedMetrics]. Does
  /// nothing when they never connected or disconnected. Runs once; later
  /// calls share the first.
  ///
  /// Never throws. If the source fails, the repository stays disconnected
  /// but the saved flag is kept so the next launch tries again.
  @override
  Future<void> restoreConnection() => _restoring ??= _restore();

  Future<void> _restore() async {
    try {
      if (_connected || !await _store.loadConnected()) return;
      await _sync(_source.checkPermissions);
    } catch (_) {
      // Never surface the error text: it could carry health details.
    }
  }

  /// Forgets the connection: stats fall back to the demo source and the next
  /// launch will not reconnect.
  Future<void> disconnect() async {
    _connected = false;
    _permissions = null;
    _lastSyncedAt = null;
    await _remember(false);
  }

  /// Persists the flag. A broken store must not break connecting.
  Future<void> _remember(bool connected) async {
    try {
      await _store.saveConnected(connected);
    } catch (_) {}
  }

  /// Sends the user to the store to install or update the health app.
  @override
  Future<void> openInstallPage() => _source.openInstallPage();

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
