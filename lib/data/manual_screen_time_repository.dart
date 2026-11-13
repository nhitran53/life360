import '../models/models.dart';
import 'connectable_stats_repository.dart';
import 'device_screen_time.dart';
import 'friends_repository.dart';
import 'health/health_source.dart';
import 'screen_time_log.dart';

/// Wraps another [ConnectableStatsRepository] and puts the current user's
/// screen time into their stats: what this phone measured (see
/// [DeviceScreenTime], Android only, once usage access is on), with anything
/// they logged by hand (see [ScreenTimeLog]) taking priority.
///
/// Screen time from either source replaces whatever the inner source had for
/// that day, and a day with only screen time still shows up. Everyone else's
/// stats pass through unchanged.
class ManualScreenTimeRepository implements ConnectableStatsRepository {
  ManualScreenTimeRepository({
    required this._inner,
    required this._friends,
    required this.log,
    this.device = const NoDeviceScreenTime(),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final ConnectableStatsRepository _inner;
  final FriendsRepository _friends;
  final DateTime Function() _clock;

  /// Where the entries come from. The UI writes to this, then reloads.
  final ScreenTimeLog log;

  /// Screen time this phone measured. Only read for the current user.
  final DeviceScreenTime device;

  @override
  String get sourceName => _inner.sourceName;

  @override
  bool get isConnected => _inner.isConnected;

  @override
  HealthAvailability? get availability => _inner.availability;

  @override
  DateTime? get lastSyncedAt => _inner.lastSyncedAt;

  /// Screen time is never "denied" once you can type it in yourself.
  @override
  Set<StatMetric> get deniedMetrics =>
      _inner.deniedMetrics.difference({StatMetric.screenTime});

  @override
  Future<bool> connect() => _inner.connect();

  @override
  Future<void> restoreConnection() => _inner.restoreConnection();

  @override
  Future<void> openInstallPage() => _inner.openInstallPage();

  @override
  Future<List<DailyStats>> dailyStats(
    String userId, {
    required DateTime from,
    required DateTime to,
  }) async {
    final days = await _inner.dailyStats(userId, from: from, to: to);
    if (userId != (await _friends.currentUser()).id) return days;
    final measured = await device.hasAccess()
        ? await device.dailyMinutes(from: from, to: to)
        : const <DateTime, int>{};
    final logged = await log.entries(from: from, to: to);
    // A logged day wins: it's the user correcting the phone.
    final screenTime = {...measured, ...logged};
    if (screenTime.isEmpty) return days;

    final byDate = {for (final d in days) d.date: d};
    for (final MapEntry(key: date, value: minutes) in screenTime.entries) {
      byDate[date] = (byDate[date] ?? DailyStats(userId: userId, date: date))
          .copyWith(screenTimeMinutes: minutes);
    }
    return byDate.values.toList()..sort((a, b) => a.date.compareTo(b.date));
  }

  @override
  Future<WeeklySummary> weeklySummary(String userId, {DateTime? weekOf}) async {
    if (userId != (await _friends.currentUser()).id) {
      return _inner.weeklySummary(userId, weekOf: weekOf);
    }
    final weekStart = startOfWeek(weekOf ?? _clock());
    return WeeklySummary.fromDays(
      userId: userId,
      weekStart: weekStart,
      stats: await dailyStats(
        userId,
        from: weekStart,
        to: DateTime(weekStart.year, weekStart.month, weekStart.day + 6),
      ),
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

  /// Same people as the inner repository ranks, with the current user's
  /// summary rebuilt to include their logged screen time.
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
