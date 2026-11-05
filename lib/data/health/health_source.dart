import '../../models/models.dart';

/// Whether the platform's health store can be used right now.
enum HealthAvailability {
  available,

  /// Android below 14 without the Health Connect app installed.
  notInstalled,

  /// Android: Health Connect is installed but too old to use.
  updateRequired,

  /// No health store on this platform (web, desktop).
  unsupported,
}

/// Outcome of asking for read access to one metric.
enum HealthPermissionStatus {
  granted,
  denied,

  /// iOS never reveals whether read access was granted: a denied read just
  /// looks like no data. Reads are attempted, and empty results are not
  /// treated as a real zero.
  unknown,
}

/// Per-metric result of [HealthSource.requestPermissions].
class HealthPermissionResult {
  const HealthPermissionResult(this.statuses);

  /// One entry per metric the source can read.
  final Map<StatMetric, HealthPermissionStatus> statuses;

  HealthPermissionStatus statusOf(StatMetric metric) =>
      statuses[metric] ?? HealthPermissionStatus.denied;

  /// Metrics that may be read: granted, or unknown (iOS).
  Set<StatMetric> get readable => {
    for (final e in statuses.entries)
      if (e.value != HealthPermissionStatus.denied) e.key,
  };

  bool get anyReadable => readable.isNotEmpty;
}

/// A phone health platform (HealthKit, Health Connect, later Fitbit).
///
/// Implementations return daily totals only and never log health values.
abstract interface class HealthSource {
  /// What to call this source in the UI: "Apple Health" or "Health Connect".
  String get displayName;

  /// Metrics this source can read. Screen time is not one of them: iOS does
  /// not expose it and Android needs a separate usage-access permission.
  Set<StatMetric> get readableMetrics;

  Future<HealthAvailability> availability();

  /// Sends the user to the store to install or update the health app. Only
  /// meaningful for [HealthAvailability.notInstalled] and
  /// [HealthAvailability.updateRequired]; otherwise does nothing.
  Future<void> openInstallPage();

  /// Asks the user for read access to [readableMetrics] (the minimum set
  /// needed) and reports the outcome per metric.
  Future<HealthPermissionResult> requestPermissions();

  /// Daily stats for [userId] from [from] to [to] (both inclusive, by local
  /// day), oldest first. Metrics without read access stay 0 and days with no
  /// data at all are omitted, so a missing day never reads as a real zero.
  Future<List<DailyStats>> fetchDailyStats(
    String userId, {
    required DateTime from,
    required DateTime to,
  });
}
