import 'package:flutter/foundation.dart';

import 'data/connectable_stats_repository.dart';
import 'data/friends_repository.dart';
import 'data/health/fake_health_source.dart';
import 'data/health/health_package_source.dart';
import 'data/health/health_source.dart';
import 'data/health_stats_repository.dart';
import 'data/mock_data.dart';
import 'data/mock_friends_repository.dart';
import 'data/mock_stats_repository.dart';

/// The app's repositories, created once and passed down to screens.
class AppServices {
  AppServices({required this.friends, required this.stats});

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
  final ConnectableStatsRepository stats;
}
