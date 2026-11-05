import 'package:flutter/widgets.dart';

import '../models/models.dart';
import 'health_source.dart';

/// App-wide state for the user's own health data: whether the phone's health
/// hub is connected, and the last [historyDays] days read from it.
///
/// Screens read it through [HealthScope.of] and rebuild when it changes.
class HealthSync extends ChangeNotifier {
  HealthSync(
    this.source, {
    required this.userId,
    DateTime Function()? clock,
    this.historyDays = 14,
  }) : _clock = clock ?? DateTime.now;

  final HealthSource source;

  /// The signed-in user's id; every synced [DailyStats] carries it.
  final String userId;

  /// Two weeks, so the leaderboard can compare this week with last week.
  final int historyDays;

  final DateTime Function() _clock;

  HealthConnection _connection = HealthConnection.unsupported;
  HealthConnection get connection => _connection;
  bool get isConnected => _connection == HealthConnection.connected;

  bool _busy = false;

  /// True while asking for permission or reading data.
  bool get busy => _busy;

  List<DailyStats> _days = const [];

  /// Oldest first, one entry per day (zeros where nothing was recorded).
  List<DailyStats> get days => _days;

  DateTime? _lastSynced;
  DateTime? get lastSynced => _lastSynced;

  bool _syncFailed = false;

  /// The last read threw (e.g. Health Connect was uninstalled mid-session).
  bool get syncFailed => _syncFailed;

  bool _disposed = false;

  /// Today's stats, or null before the first sync.
  DailyStats? get today {
    if (_days.isEmpty) return null;
    final last = _days.last;
    return last.date == dateOnly(_clock()) ? last : null;
  }

  /// Checks the hub and, if already connected, syncs. Call on launch and
  /// when the app comes back to the foreground.
  Future<void> start() async {
    _setConnection(await source.connection());
    if (isConnected) await refresh();
  }

  /// Shows the system permission sheet, then syncs if access was granted.
  Future<bool> connect() async {
    _setBusy(true);
    try {
      await source.connect();
      _connection = await source.connection();
    } on Exception {
      _connection = await source.connection();
    } finally {
      _setBusy(false);
    }
    if (isConnected) await refresh();
    return isConnected;
  }

  /// Reads the last [historyDays] days. Does nothing when not connected.
  Future<void> refresh() async {
    if (!isConnected || _busy) return;
    _setBusy(true);
    try {
      final now = _clock();
      final from = DateTime(now.year, now.month, now.day - (historyDays - 1));
      _days = List.unmodifiable(
        await source.readDays(userId, from: from, to: now),
      );
      _lastSynced = now;
      _syncFailed = false;
    } on Exception {
      // Keep the last good data; never log it (it's health data).
      _syncFailed = true;
    } finally {
      _setBusy(false);
    }
  }

  /// Forgets the synced data and drops access where the platform allows it.
  Future<void> disconnect() async {
    await source.disconnect();
    _days = const [];
    _lastSynced = null;
    _setConnection(await source.connection());
  }

  /// Android: opens the store so the user can install Health Connect.
  Future<void> installProvider() => source.installProvider();

  void _setConnection(HealthConnection value) {
    _connection = value;
    _notify();
  }

  void _setBusy(bool value) {
    _busy = value;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Puts a [HealthSync] above the app so any screen can read it.
class HealthScope extends InheritedNotifier<HealthSync> {
  const HealthScope({super.key, required HealthSync sync, required super.child})
    : super(notifier: sync);

  /// Used when no scope is above [context] (e.g. a screen pumped on its own
  /// in a test): reports [HealthConnection.unsupported] and never syncs.
  static final _fallback = HealthSync(
    const UnsupportedHealthSource(),
    userId: '',
  );

  static HealthSync of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HealthScope>()?.notifier ??
      _fallback;
}
