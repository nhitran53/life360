import 'dart:async';

import '../models/models.dart';
import 'connectable_stats_repository.dart';
import 'firestore_stats_publisher.dart';
import 'sharing_repository.dart';

/// Keeps the user's published stats up to date: reads their own stats from
/// [source] and hands them to [publisher] with their sharing settings.
///
/// Runs when [sync] is called (after a health sync) and whenever the sharing
/// settings change. It publishes nothing unless
/// - the saved sharing settings have loaded ([SharingRepository.isLoaded]),
///   so the private defaults are never mistaken for the user's choice, and
/// - [source] is connected to a real health platform, so demo data is never
///   published as the user's own.
///
/// While sharing is paused it deletes what's published, connected or not.
///
/// Failures are swallowed (the next sync tries again). Errors can carry
/// health details, so they're never logged.
class StatsSync {
  StatsSync({
    required this.source,
    required this.sharing,
    required this.publisher,
    required this.userId,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// The user's own, unfiltered stats.
  final ConnectableStatsRepository source;
  final SharingRepository sharing;
  final FirestoreStatsPublisher publisher;
  final String userId;
  final DateTime Function() _clock;

  var _running = false;
  var _again = false;
  var _disposed = false;

  /// Starts re-publishing when the sharing settings change.
  void start() => sharing.addListener(_onSharingChanged);

  void dispose() {
    _disposed = true;
    sharing.removeListener(_onSharingChanged);
  }

  void _onSharingChanged() => unawaited(sync());

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
    if (_disposed || !sharing.isLoaded) return;
    try {
      final settings = sharing.settingsFor(userId);
      if (settings.isPaused(_clock())) {
        // Paused: take down what's published even if health isn't connected.
        await publisher.publish(const [], settings);
        return;
      }
      if (!source.isConnected) return;
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
    } catch (_) {
      // Deliberately silent: see the class comment.
    }
  }
}
