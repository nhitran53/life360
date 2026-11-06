import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life360/data/health/fake_health_source.dart';
import 'package:life360/data/health_stats_repository.dart';
import 'package:life360/data/mock_friends_repository.dart';
import 'package:life360/data/mock_stats_repository.dart';
import 'package:life360/data/sharing_repository.dart';
import 'package:life360/data/sharing_stats_repository.dart';
import 'package:life360/models/models.dart';
import 'package:life360/screens/friend_detail_screen.dart';
import 'package:life360/screens/friends_stats_screen.dart';
import 'package:life360/theme/app_theme.dart';

void main() {
  // A Wednesday afternoon.
  final now = DateTime(2026, 3, 11, 15);
  DateTime clock() => now;

  late MockFriendsRepository friends;
  late MockSharingRepository sharing;
  late SharingStatsRepository stats;

  setUp(() {
    friends = MockFriendsRepository(clock: clock);
    sharing = MockSharingRepository(
      initial: {
        'u_alex': const SharingSettings(hidden: {}),
        // Shares only steps.
        'u_chris': const SharingSettings(
          hidden: {
            StatMetric.sleep,
            StatMetric.workout,
            StatMetric.calories,
            StatMetric.screenTime,
          },
        ),
        'u_dana': SharingSettings(
          pausedUntil: now.add(const Duration(hours: 5)),
        ),
      },
    );
    stats = SharingStatsRepository(
      inner: HealthStatsRepository(
        source: FakeHealthSource(),
        fallback: MockStatsRepository(friends: friends, clock: clock),
        friends: friends,
      ),
      friends: friends,
      sharing: sharing,
      clock: clock,
    );
  });

  tearDown(() => sharing.dispose());

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 4000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: FriendsStatsScreen(
          friends: friends,
          stats: stats,
          sharing: sharing,
          clock: clock,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder inCard(String userId, Finder f) =>
      find.descendant(of: find.byKey(ValueKey('friend-$userId')), matching: f);

  testWidgets('lists every friend with their day and a nudge', (tester) async {
    await pumpScreen(tester);

    for (final f in await friends.friends()) {
      expect(
        find.byKey(ValueKey('friend-${f.id}')),
        findsOneWidget,
        reason: f.displayName,
      );
    }
    expect(
      inCard('u_alex', find.textContaining('steps ahead')),
      findsOneWidget,
    );
    expect(inCard('u_alex', find.textContaining('🔥')), findsOneWidget);
  });

  testWidgets('private stats show a lock, paused friends take a break', (
    tester,
  ) async {
    await pumpScreen(tester);

    // Chris shares only steps.
    String locked(StatMetric m) => '${m.emoji} 🔒';
    expect(
      inCard('u_chris', find.text(locked(StatMetric.sleep))),
      findsOneWidget,
    );
    expect(
      inCard('u_chris', find.text(locked(StatMetric.workout))),
      findsOneWidget,
    );
    expect(
      inCard('u_chris', find.text(locked(StatMetric.steps))),
      findsNothing,
    );

    // Dana paused sharing.
    expect(
      inCard('u_dana', find.text('Taking a break from sharing 🔒')),
      findsOneWidget,
    );
    expect(inCard('u_dana', find.text('🔥 🔒')), findsOneWidget);
  });

  testWidgets('tapping a friend compares your week with theirs', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('friend-u_alex')));
    await tester.pumpAndSettle();

    expect(find.byType(FriendDetailScreen), findsOneWidget);
    expect(find.text('This week: you vs Alex'), findsOneWidget);
    for (final m in StatMetric.values) {
      expect(find.byKey(ValueKey('compare-${m.name}')), findsOneWidget);
    }
    // Alex shares everything, so every row with data has a leader.
    expect(find.textContaining('👑'), findsWidgets);
    expect(find.byKey(const ValueKey('nudge')), findsOneWidget);
  });

  testWidgets("a friend's private stats can't be compared", (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('friend-u_chris')));
    await tester.pumpAndSettle();

    final sleepRow = tester.getSemantics(
      find.byKey(const ValueKey('compare-sleep')),
    );
    expect(sleepRow.label, contains('Chris 🔒'));
    expect(sleepRow.label, contains('Chris keeps it private'));
  });
}
