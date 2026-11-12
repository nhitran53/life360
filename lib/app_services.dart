import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'data/circle_repository.dart';
import 'data/connectable_stats_repository.dart';
import 'data/device_screen_time.dart';
import 'data/firestore_stats_publisher.dart';
import 'data/firestore_stats_repository.dart';
import 'data/friends_repository.dart';
import 'data/health/fake_health_source.dart';
import 'data/health/health_connection_store.dart';
import 'data/health/health_package_source.dart';
import 'data/health/health_source.dart';
import 'data/health/takeout_health_source.dart';
import 'data/health_stats_repository.dart';
import 'data/mock_circle_repository.dart';
import 'data/mock_data.dart';
import 'data/mock_friends_repository.dart';
import 'data/manual_screen_time_repository.dart';
import 'data/mock_stats_repository.dart';
import 'data/published_sharing_repository.dart';
import 'data/screen_time_log.dart';
import 'data/sharing_repository.dart';
import 'data/sharing_stats_repository.dart';
import 'data/stats_repository.dart';
import 'data/stats_sync.dart';
import 'utils/platform_support.dart';

/// The app's repositories, created once and passed down to screens.
class AppServices {
  /// [stats] gets the current user's logged screen time merged in, then is
  /// wrapped so friends only ever see what each person shares.
  AppServices({
    required this.friends,
    required ConnectableStatsRepository stats,
    CircleRepository? circles,
    SharingRepository? sharing,
    ScreenTimeLog? screenTime,
    this.deviceScreenTime = const NoDeviceScreenTime(),
  }) : circles = circles ?? MockCircleRepository(),
       sharing = sharing ?? MockSharingRepository(),
       screenTime = screenTime ?? InMemoryScreenTimeLog() {
    rawStats = ManualScreenTimeRepository(
      inner: stats,
      friends: friends,
      log: this.screenTime,
      device: deviceScreenTime,
    );
    this.stats = SharingStatsRepository(
      inner: rawStats,
      friends: friends,
      sharing: this.sharing,
    );
  }

  /// Real health data on Android/iOS; on other platforms (no health store)
  /// a fake source seeded with mock data so the UI is still demo-able.
  /// Pass [friends] to use real friends (signed in through Firebase);
  /// otherwise everyone comes from the mock data. Pass [sharing] to save
  /// the user's sharing settings (Firebase session); otherwise they're
  /// in-memory and reset on every launch.
  ///
  /// Pass [statsDb] and [userId] (Firebase session, with [sharing]) to
  /// publish the user's own stats and read friends' stats from Firestore;
  /// otherwise stats stay on the device and friends' come from the mock data.
  factory AppServices.defaults({
    FriendsRepository? friends,
    SharingRepository? sharing,
    FirebaseFirestore? statsDb,
    String? userId,
  }) {
    friends ??= MockFriendsRepository();
    final mockStats = MockStatsRepository(friends: friends);
    final onPhone = isPhone;
    // Debug only: `--dart-define=TAKEOUT_JSON=/path/daily.json` serves real
    // daily totals from a Takeout export instead of the platform store.
    const takeoutPath = String.fromEnvironment('TAKEOUT_JSON');
    final HealthSource source = kDebugMode && !kIsWeb && takeoutPath.isNotEmpty
        ? TakeoutHealthSource(load: () => File(takeoutPath).readAsString())
        : onPhone
        ? HealthPackageSource()
        : FakeHealthSource(
            stats: generateMockStats(today: DateTime.now())
                .where((s) => s.userId == mockMe.id),
          );
    final publishing = statsDb != null && userId != null && sharing != null;
    StatsSync? sync;
    // Friends' settings are private to them: with Firestore, what they share
    // is read off their published days instead.
    final published = statsDb == null
        ? null
        : PublishedSharingRepository(sharing ?? MockSharingRepository());
    final StatsRepository fallback = statsDb == null
        ? mockStats
        : FirestoreStatsRepository(
            statsDb,
            own: mockStats,
            friends: friends,
            published: published,
          );
    final health = HealthStatsRepository(
      source: source,
      fallback: fallback,
      friends: friends,
      store: SharedPreferencesHealthConnectionStore(),
      onSynced: () => unawaited(sync?.sync()),
    );
    final services = AppServices(
      friends: friends,
      stats: health,
      sharing: published ?? sharing,
      // Only Android lets apps read screen time (with usage access).
      deviceScreenTime: canReadDeviceScreenTime
          ? AndroidUsageScreenTime()
          : const NoDeviceScreenTime(),
    );
    if (publishing) {
      sync = services._sync = StatsSync(
        source: services.rawStats,
        sharing: sharing,
        publisher: FirestoreStatsPublisher(statsDb, uid: userId),
        userId: userId,
      )..start();
    }
    // Reconnect in the background so other screens see health stats too;
    // My Stats waits for the same (shared) future.
    unawaited(health.restoreConnection());
    return services;
  }

  StatsSync? _sync;

  /// Stops publishing stats. Call when the user signs out.
  void dispose() => _sync?.dispose();

  final FriendsRepository friends;

  /// Stats with everyone's sharing settings applied. Screens use this.
  late final ConnectableStatsRepository stats;

  /// The unfiltered repository (logged screen time included), for tests and
  /// the backend sync later.
  late final ConnectableStatsRepository rawStats;

  /// Screen time the user logs by hand. My Stats writes to it.
  final ScreenTimeLog screenTime;

  /// Screen time this phone measures (Android with usage access).
  final DeviceScreenTime deviceScreenTime;

  final CircleRepository circles;

  /// Who shares which stats.
  final SharingRepository sharing;
}
