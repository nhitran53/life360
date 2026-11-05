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
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final HealthSource _source;
  final StatsRepository _fallback;
  final FriendsRepository _friends;
  final DateTime Function() _clock;

  bool _connected = false;
  HealthAvailability? _availability;
  HealthPermissionResult? _permissions;
  DateTime? _lastSyncedAt;

  /// "Apple Health" or "Health Connect", for the UI.
  String get sourceName => _source.displayName;

  /// Whether the current user's stats now come from the health platform.
  bool get isConnected => _connected;

  /// Result of the last [connect], or null before the first attempt.
  HealthAvailability? get availability => _availability;

  /// When the last successful [connect] finished, or null.
  DateTime? get lastSyncedAt => _lastSyncedAt;

  /// Metrics the user turned down in the last [connect]. Their values are
  /// unknown, not 0, so the UI must not show them as numbers. Empty before
  /// connecting; on iOS reads are never reported as denied.
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
  Future<bool> connect() async {
    _availability = await _source.availability();
    if (_availability != HealthAvailability.available) {
      _permissions = null;
      return _connected = false;
    }
    _permissions = await _source.requestPermissions();
    _connected = _permissions!.anyReadable;
    if (_connected) _lastSyncedAt = _clock();
    return _connected;
  }

  /// Sends the user to the store to install or update the health app.
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
  }) async => rankLeaderboard(metric, await _summaries(weekOf));

  @override
  Future<List<LeaderboardEntry>> xpLeaderboard({DateTime? weekOf}) async =>
      rankLeaderboardByXp(await _summaries(weekOf));

  /// Weekly summaries for the current user and their accepted friends.
  Future<Map<UserProfile, WeeklySummary>> _summaries(DateTime? weekOf) async {
    final people = [await _friends.currentUser(), ...await _friends.friends()];
    return {
      for (final p in people) p: await weeklySummary(p.id, weekOf: weekOf),
    };
  }
}
