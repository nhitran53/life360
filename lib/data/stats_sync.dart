import 'dart:async';

import '../models/models.dart';
import 'connectable_stats_repository.dart';
import 'firestore_stats_publisher.dart';
import 'sharing_repository.dart';

/// Keeps the user's published stats up to date: reads their own stats from
/// [source] and hands them to [publisher] with their sharing settings.
///
/// Runs when [sync] is called (after a health sync) and whenever the sharing
/// settings change. Each run first re-reads the saved settings (another
/// device may have changed them) and then
/// - takes down everything the settings no longer allow
///   ([FirestoreStatsPublisher.revoke]), which needs no health data, so it
///   happens even when health is disconnected or unreadable, and
/// - publishes new values only if the saved sharing settings have loaded
///   ([SharingRepository.isLoaded]), so the private defaults are never
///   mistaken for the user's choice, and [source] is connected to a real
///   health platform, so demo data is never published as the user's own.
///
/// Taking data down is not allowed to fail silently. Until a revoke has
/// succeeded for the current settings, [revocationPending] is true and a
/// timer retries it with growing delays (and re-reads the settings first, so
/// a failed first load is retried too), whether or not health is connected.
/// The retry also runs on every [sync], including the first one after
/// sign-in or app start. A failure to publish new values is only swallowed
/// (the next sync tries again). Errors can carry health details, so they're
/// never logged.
class StatsSync {
  StatsSync({
    required this.source,
    required this.sharing,
    required this.publisher,
    required this.userId,
    DateTime Function()? clock,
    this.retryBase = const Duration(seconds: 5),
  }) : _clock = clock ?? DateTime.now;

  /// The user's own, unfiltered stats.
  final ConnectableStatsRepository source;
  final SharingRepository sharing;
  final FirestoreStatsPublisher publisher;
  final String userId;
  final DateTime Function() _clock;

  /// The first retry delay of a failed revoke; it doubles each failure up to
  /// 64 times this.
  final Duration retryBase;

  var _revocationPending = true;

  /// True until the published stats were last cleaned up for the current
  /// settings: starts true, becomes true on every settings change, and goes
  /// back to false only when a revoke finished with no newer change.
  bool get revocationPending => _revocationPending;

  /// Counts settings changes, so a revoke that started before a change can't
  /// clear [revocationPending] for it.
  var _settingsVersion = 0;
  var _failures = 0;
  Timer? _retryTimer;

  var _running = false;
  var _again = false;
  var _disposed = false;

  /// Starts re-publishing when the sharing settings change, and runs once
  /// now so a failed first settings load gets retried.
  void start() {
    sharing.addListener(_onSharingChanged);
    unawaited(sync());
  }

  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    sharing.removeListener(_onSharingChanged);
  }

  void _onSharingChanged() {
    _settingsVersion++;
    _revocationPending = true;
    unawaited(sync());
  }

  /// Publishes now. A call made while one is running makes it run once more
  /// afterwards, so the latest settings always win. Never throws.
  Future<void> sync() async {
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    try {
      do {
        _again = false;
        await _publishOnce();
      } while (_again && !_disposed);
    } finally {
      _running = false;
    }
  }

  Future<void> _publishOnce() async {
    if (_disposed) return;
    if (!sharing.isLoaded) {
      _scheduleRetry();
      return;
    }
    try {
      final SharingSettings settings;
      final int version;
      try {
        await sharing.refresh();
        if (_disposed) return;
        settings = sharing.settingsFor(userId);
        version = _settingsVersion;
        await publisher.revoke(settings);
      } on Object {
        // Background sync must survive any failure: retry later instead.
        _scheduleRetry();
        return;
      }
      if (version == _settingsVersion) {
        _revocationPending = false;
        _failures = 0;
        _retryTimer?.cancel();
      }
      if (settings.isPaused(_clock()) || !source.isConnected) return;
      final today = dateOnly(_clock());
      final days = await source.dailyStats(
        userId,
        from: DateTime(
          today.year,
          today.month,
          today.day - (FirestoreStatsPublisher.windowDays - 1),
        ),
        to: today,
      );
      // Read after the (slow) fetch so a change made meanwhile is honoured.
      if (_disposed || !sharing.isLoaded) return;
      await publisher.publish(
        days,
        sharing.settingsFor(userId),
        unavailable: source.deniedMetrics,
      );
    } on Object {
      // Deliberately silent: see the class comment.
    }
  }

  void _scheduleRetry() {
    if (_disposed) return;
    _failures++;
    final factor = 1 << (_failures - 1).clamp(0, 6);
    _retryTimer?.cancel();
    _retryTimer = Timer(retryBase * factor, () async {
      try {
        // Re-reads the settings (or loads them, if the first load failed).
        await sharing.refresh();
      } on Object {
        // The sync below schedules the next retry.
      }
      await sync();
    });
  }
}
