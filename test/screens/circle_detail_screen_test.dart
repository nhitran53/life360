import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life360/data/mock_circle_repository.dart';
import 'package:life360/data/mock_friends_repository.dart';
import 'package:life360/data/mock_stats_repository.dart';
import 'package:life360/data/stats_repository.dart';
import 'package:life360/models/models.dart';
import 'package:life360/screens/circle_detail_screen.dart';
import 'package:life360/theme/app_theme.dart';

/// A stats source that ranks nobody above zero, like a week with no data.
class _EmptyWeekStats extends MockStatsRepository {
  _EmptyWeekStats({required super.friends, super.clock});

  @override
  Future<List<LeaderboardEntry>> leaderboard(
    StatMetric metric, {
    DateTime? weekOf,
    Iterable<String>? userIds,
  }) async => [
    for (final e in await super.leaderboard(
      metric,
      weekOf: weekOf,
      userIds: userIds,
    ))
      LeaderboardEntry(rank: 1, user: e.user, metric: metric, value: 0),
  ];
}

void main() {
  // A Wednesday afternoon.
  final now = DateTime(2026, 11, 4, 15);
  DateTime clock() => now;
  final lastWeek = DateTime(now.year, now.month, now.day - 7);

  late MockFriendsRepository friends;
  late MockCircleRepository circles;
  late StatsRepository stats;

  setUp(() {
    friends = MockFriendsRepository(clock: clock);
    stats = MockStatsRepository(friends: friends, clock: clock);
    circles = MockCircleRepository();
  });

  /// c_gym is mine (owner); c_dorm is owned by someone else.
  Future<void> pumpDetail(WidgetTester tester, String circleId) async {
    tester.view.physicalSize = const Size(1170, 3000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final circle = (await circles.circles()).firstWhere(
      (c) => c.id == circleId,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: CircleDetailScreen(
          circle: circle,
          circles: circles,
          friends: friends,
          stats: stats,
          clock: clock,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows standings for the members and the reward banner', (
    tester,
  ) async {
    await pumpDetail(tester, 'c_gym');

    for (final id in ['u_me', 'u_alex', 'u_bree', 'u_chris']) {
      expect(find.byKey(ValueKey('standing-$id')), findsOneWidget, reason: id);
    }
    expect(find.text('Winner picks the restaurant'), findsOneWidget);
  });

  testWidgets('only steps and workouts can be ranked', (tester) async {
    await pumpDetail(tester, 'c_gym');

    expect(find.byKey(const ValueKey('metric-steps')), findsOneWidget);
    expect(find.byKey(const ValueKey('metric-workout')), findsOneWidget);
    expect(find.textContaining('Sleep'), findsNothing);
    expect(find.textContaining('Screen time'), findsNothing);
    expect(find.textContaining('calories'), findsNothing);

    final expected = await stats.leaderboard(
      StatMetric.workout,
      userIds: ['u_me', 'u_alex', 'u_bree', 'u_chris'],
    );
    await tester.tap(find.byKey(const ValueKey('metric-workout')));
    await tester.pumpAndSettle();
    final top = expected.first;
    expect(
      find.descendant(
        of: find.byKey(ValueKey('standing-${top.user.id}')),
        matching: find.text('${top.value.round()} min'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('owner can edit the reward, capped at 80 characters', (
    tester,
  ) async {
    await pumpDetail(tester, 'c_gym');

    await tester.tap(find.byKey(const ValueKey('edit-reward-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('reward-field')),
      'x' * 100,
    );
    await tester.pump();
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('reward-field')),
    );
    expect(field.controller!.text.length, maxRewardLength);

    await tester.enterText(
      find.byKey(const ValueKey('reward-field')),
      'Winner picks the movie',
    );
    await tester.tap(find.byKey(const ValueKey('reward-save-button')));
    await tester.pumpAndSettle();
    expect(find.text('Winner picks the movie'), findsOneWidget);
    expect(
      (await circles.circles()).first.rewardText,
      'Winner picks the movie',
    );
  });

  testWidgets('owner can clear the reward with blank text', (tester) async {
    await pumpDetail(tester, 'c_gym');

    await tester.tap(find.byKey(const ValueKey('edit-reward-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('reward-field')), '');
    await tester.tap(find.byKey(const ValueKey('reward-save-button')));
    await tester.pumpAndSettle();

    expect(find.text('No reward set yet'), findsOneWidget);
    expect((await circles.circles()).first.rewardText, isNull);
  });

  testWidgets('non-owner sees the reward area without an edit button', (
    tester,
  ) async {
    await pumpDetail(tester, 'c_dorm');

    expect(find.byKey(const ValueKey('reward-banner')), findsOneWidget);
    expect(find.text('No reward set yet'), findsOneWidget);
    expect(find.byKey(const ValueKey('edit-reward-button')), findsNothing);
  });

  testWidgets('winner card names last week\'s winner', (tester) async {
    await pumpDetail(tester, 'c_gym');

    final board = await stats.leaderboard(
      StatMetric.steps,
      weekOf: lastWeek,
      userIds: ['u_me', 'u_alex', 'u_bree', 'u_chris'],
    );
    final winnerIds = rewardWinners(RewardMetric.steps, board);
    expect(winnerIds, isNotEmpty);
    final names = [
      for (final e in board)
        if (winnerIds.contains(e.user.id)) e.user.displayName,
    ];

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('winner-card')),
        matching: find.text('${names.join(' & ')} won'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('winner-empty')), findsNothing);
  });

  testWidgets('winner card is empty when nobody has data', (tester) async {
    stats = _EmptyWeekStats(friends: friends, clock: clock);
    await pumpDetail(tester, 'c_gym');

    expect(find.byKey(const ValueKey('winner-empty')), findsOneWidget);
    expect(find.byKey(const ValueKey('winner-names')), findsNothing);
  });

  testWidgets('leaving shows the repository error for an owner', (
    tester,
  ) async {
    await pumpDetail(tester, 'c_gym');

    await tester.ensureVisible(find.byKey(const ValueKey('leave-button')));
    await tester.tap(find.byKey(const ValueKey('leave-button')));
    await tester.pumpAndSettle();

    expect(find.text('Hand the circle to someone else first.'), findsOneWidget);
    expect((await circles.circles()).map((c) => c.id), contains('c_gym'));
  });

  testWidgets('a member can leave and goes back', (tester) async {
    await pumpDetail(tester, 'c_dorm');

    await tester.ensureVisible(find.byKey(const ValueKey('leave-button')));
    await tester.tap(find.byKey(const ValueKey('leave-button')));
    await tester.pumpAndSettle();

    expect(
      (await circles.circles()).map((c) => c.id),
      isNot(contains('c_dorm')),
    );
  });
}
