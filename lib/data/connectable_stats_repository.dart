import '../models/models.dart';
import 'health/health_source.dart';
import 'stats_repository.dart';

/// A [StatsRepository] whose current-user stats come from a health platform
/// the user connects to. This is all My Stats needs to know about it.
abstract interface class ConnectableStatsRepository implements StatsRepository {
  /// "Apple Health" or "Health Connect", for the UI.
  String get sourceName;

  /// Whether the current user's stats now come from the health platform.
  bool get isConnected;

  /// Result of the last [connect], or null before the first attempt.
  HealthAvailability? get availability;

  /// When the last successful [connect] finished, or null.
  DateTime? get lastSyncedAt;

  /// Metrics the user turned down in the last [connect]. Their values are
  /// unknown, not 0, so the UI must not show them as numbers.
  Set<StatMetric> get deniedMetrics;

  /// Checks availability and asks for read access. Returns true when at least
  /// one metric is readable.
  Future<bool> connect();

  /// Sends the user to the store to install or update the health app.
  Future<void> openInstallPage();
}
