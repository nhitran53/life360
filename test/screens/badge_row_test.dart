import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life360/data/mock_data.dart';
import 'package:life360/data/mock_friends_repository.dart';
import 'package:life360/data/mock_stats_repository.dart';
import 'package:life360/models/models.dart';
import 'package:life360/screens/my_stats_screen.dart';
import 'package:life360/theme/app_theme.dart';
import 'package:life360/widgets/badge_row.dart';

void main() {
  final now = DateTime(2026, 11, 4, 15);
  DateTime clock() => now;

  Future<void> pumpWidgetInApp(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: home));
    await tester.pumpAndSettle();
  }

  testWidgets('BadgeRow shows each earned badge', (tester) async {
    await pumpWidgetInApp(
      tester,
      const Scaffold(
        body: BadgeRow(
          badges: [RewardBadge.firstActiveDay, RewardBadge.threeDayStreak],
        ),
      ),
    );

    expect(find.byKey(const ValueKey('badge-firstActiveDay')), findsOneWidget);
    expect(find.byKey(const ValueKey('badge-threeDayStreak')), findsOneWidget);
    expect(find.byKey(const ValueKey('badge-sevenDayStreak')), findsNothing);
    expect(find.text(RewardBadge.firstActiveDay.title), findsOneWidget);
  });

  testWidgets('BadgeRow nudges when nothing is earned yet', (tester) async {
    await pumpWidgetInApp(tester, const Scaffold(body: BadgeRow(badges: [])));

    expect(find.textContaining('No badges yet'), findsOneWidget);
  });

  testWidgets('My Stats shows the badges earned from my stats', (tester) async {
    final friends = MockFriendsRepository(clock: clock);
    final stats = MockStatsRepository(friends: friends, clock: clock);
    final recent = await stats.dailyStats(
      mockMe.id,
      from: DateTime(now.year, now.month, now.day - 60),
      to: now,
    );
    final expected = earnedBadges(recent);
    expect(expected, isNotEmpty);

    await pumpWidgetInApp(
      tester,
      MyStatsScreen(friends: friends, stats: stats, clock: clock),
    );

    expect(find.byKey(const ValueKey('badge-row')), findsOneWidget);
    for (final badge in RewardBadge.values) {
      expect(
        find.byKey(ValueKey('badge-${badge.name}')),
        expected.contains(badge) ? findsOneWidget : findsNothing,
        reason: badge.name,
      );
    }
  });
}
