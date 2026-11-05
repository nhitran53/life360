import '../models/models.dart';

/// Where the phone's health hub stands for this app.
enum HealthConnection {
  /// No health hub on this platform (web, desktop, tests).
  unsupported,

  /// Android only: Health Connect is missing or needs an update.
  needsInstall,

  /// The hub is there but the user hasn't granted access yet.
  notConnected,

  /// Access granted; stats can be read.
  connected,
}

/// Reads the user's own stats from the phone's health hub: Apple Health on
/// iOS, Health Connect on Android. Watches (Apple Watch, Pixel Watch,
/// Galaxy Watch, Fitbit) sync into these hubs, so the app never talks to a
/// watch directly.
///
/// Read only: we never write to the user's health data.
abstract interface class HealthSource {
  /// Shown in the UI, e.g. "Apple Health" or "Health Connect".
  String get name;

  Future<HealthConnection> connection();

  /// Shows the system permission sheet. Returns true when access was
  /// granted (on iOS: when the sheet was answered, see [DeviceHealthSource]).
  Future<bool> connect();

  /// Forgets access. On Android this revokes the Health Connect permissions;
  /// iOS doesn't allow apps to revoke, so the user does it in the Health app.
  Future<void> disconnect();

  /// Android only: opens the store page for Health Connect.
  Future<void> installProvider();

  /// One [DailyStats] per local calendar day from [from] to [to] (both
  /// inclusive), oldest first, all tagged with [userId]. Days with no data
  /// have zero values. Screen time always stays 0: the health hubs don't
  /// expose it.
  Future<List<DailyStats>> readDays(
    String userId, {
    required DateTime from,
    required DateTime to,
  });
}

/// For platforms without a health hub. Everything is a no-op.
class UnsupportedHealthSource implements HealthSource {
  const UnsupportedHealthSource();

  @override
  String get name => 'Health data';

  @override
  Future<HealthConnection> connection() async => HealthConnection.unsupported;

  @override
  Future<bool> connect() async => false;

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> installProvider() async {}

  @override
  Future<List<DailyStats>> readDays(
    String userId, {
    required DateTime from,
    required DateTime to,
  }) async => const [];
}
