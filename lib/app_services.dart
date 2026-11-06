import 'package:flutter/foundation.dart';

import 'data/circle_repository.dart';
import 'data/connectable_stats_repository.dart';
import 'data/friends_repository.dart';
import 'data/health/fake_health_source.dart';
import 'data/health/health_package_source.dart';
import 'data/health/health_source.dart';
import 'data/health_stats_repository.dart';
import 'data/mock_circle_repository.dart';
import 'data/mock_data.dart';
import 'data/mock_friends_repository.dart';
import 'data/mock_stats_repository.dart';
import 'data/sharing_repository.dart';
import 'data/sharing_stats_repository.dart';

/// The app's repositories, created once and passed down to screens.
class AppServices {
  /// [stats] is wrapped so friends only ever see what each person shares.
  AppServices({
    required this.friends,
    required ConnectableStatsRepository stats,
    CircleRepository? circles,
    SharingRepository? sharing,
  })  : circles = circles ?? MockCircleRepository(),
        sharing = sharing ?? MockSharingRepository(),
        rawStats = stats {
    this.stats = SharingStatsRepository(
      inner: stats,
      friends: friends,
      sharing: this.sharing,
    );
  }

  /// Real health data on Android/iOS; on other platforms (no health store)
  /// a fake source seeded with mock data so the UI is still demo-able.
  factory AppServices.defaults() {
    final friends = MockFriendsRepository();
    final mockStats = MockStatsRepository(friends: friends);
    final onPhone = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    final HealthSource source = onPhone
        ? HealthPackageSource()
        : FakeHealthSource(
            stats: generateMockStats(today: DateTime.now())
                .where((s) => s.userId == mockMe.id),
          );
    return AppServices(
      friends: friends,
      stats: HealthStatsRepository(
        source: source,
        fallback: mockStats,
        friends: friends,
      ),
    );
  }

  final FriendsRepository friends;

  /// Stats with everyone's sharing settings applied. Screens use this.
  late final ConnectableStatsRepository stats;

  /// The unfiltered repository, for tests and the backend sync later.
  final ConnectableStatsRepository rawStats;

  final CircleRepository circles;

  /// Who shares which stats.
  final SharingRepository sharing;
}
