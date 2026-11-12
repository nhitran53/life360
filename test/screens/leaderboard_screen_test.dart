import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life360/data/family_store.dart';
import 'package:life360/data/mock_circle.dart';
import 'package:life360/data/mock_data.dart';
import 'package:life360/data/mock_friends_repository.dart';
import 'package:life360/data/mock_stats_repository.dart';
import 'package:life360/models/models.dart';
import 'package:life360/screens/leaderboard_screen.dart';
import 'package:life360/utils/format.dart';
import 'package:life360/theme/app_theme.dart';

void main() {
  // A Wednesday afternoon.
  final now = DateTime(2026, 11, 4, 15);
  DateTime clock() => now;

  late MockFriendsRepository friends;
  late MockStatsRepository stats;

  setUp(() {
    friends = MockFriendsRepository(clock: clock);
    stats = MockStatsRepository(friends: friends, clock: clock);
  });

  Future<void> pumpBoard(
      WidgetTester tester, {
        FamilyStore? families,
        CircleFamily? initialFamily,
      }) async {
    // A tall phone so the whole board (family picker, podium and every row)
    // is on screen. Rows below the fold aren't built, so tests that check
    // every row would miss them on a shorter screen.
    tester.view.physicalSize = const Size(1170, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: LeaderboardScreen(
        friends: friends,
        stats: stats,
        clock: clock,
        familyStore: families ?? FamilyStore(),
        initialFamily: initialFamily,
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> selectBoard(WidgetTester tester, LeaderboardBoard b) async {
    final chip = find.byKey(ValueKey('board-${b.name}'));
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
  }

  String nameIn(WidgetTester tester, String key) => tester
      .widgetList<Text>(find.descendant(
      of: find.byKey(ValueKey(key)), matching: find.byType(Text)))
      .map((t) => t.data)
      .firstWhere((d) => mockAllUsers.any((u) => u.displayName == d))!;

  testWidgets('opens on Overall XP with the top 3 on the podium',
          (tester) async {
        await pumpBoard(tester);
        final board = await stats.xpLeaderboard(weekOf: now);

        expect(find.text('This week'), findsOneWidget);
        expect(find.text('Resets in 4 days'), findsOneWidget);
        expect(nameIn(tester, 'podium-1'), board[0].user.displayName);
        expect(nameIn(tester, 'podium-2'), board[1].user.displayName);
        expect(nameIn(tester, 'podium-3'), board[2].user.displayName);
        // Everyone else gets a row.
        for (final e in board.skip(3)) {
          expect(find.byKey(ValueKey('row-${e.user.id}')), findsOneWidget);
        }
      });

  testWidgets('Overall XP shows your league; other boards do not',
      (tester) async {
    await pumpBoard(tester);
    expect(find.byKey(const ValueKey('league-card')), findsOneWidget);
    expect(find.textContaining('League'), findsWidgets);

    await selectBoard(tester, LeaderboardBoard.steps);
    expect(find.byKey(const ValueKey('league-card')), findsNothing);
  });

  testWidgets('switching to Steps re-ranks and shows step totals',
          (tester) async {
        await pumpBoard(tester);
        await selectBoard(tester, LeaderboardBoard.steps);

        final board = await stats.leaderboard(StatMetric.steps, weekOf: now);
        expect(nameIn(tester, 'podium-1'), board[0].user.displayName);
        final leaderSteps = '${formatThousands(board[0].value.round())} steps';
        expect(find.text(leaderSteps), findsOneWidget);
      });

  testWidgets('every board shows a friendly line about the current user',
          (tester) async {
        await pumpBoard(tester);
        for (final b in LeaderboardBoard.values) {
          await selectBoard(tester, b);
          final entries = b.metric == null
              ? await stats.xpLeaderboard(weekOf: now)
              : await stats.leaderboard(b.metric!, weekOf: now);
          expect(find.text(nudgeMessage(b, entries, mockMe.id)), findsOneWidget,
              reason: b.label);
        }
      });

  testWidgets('rows announce rank movement to screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpBoard(tester);
    expect(find.bySemanticsLabel(RegExp(r'^\d+(st|nd|rd|th) place, ')),
        findsNWidgets(mockFriends.length + 1));
    handle.dispose();
  });

  group('family leaderboards', () {
    test('userIds ranks you against just that family', () async {
      final board = await stats.leaderboard(StatMetric.steps,
          userIds: circleTranFamily.profileIds);
      expect(board.map((e) => e.user.id).toSet(),
          {mockMe.id, for (final u in mockFamily) u.id});
      expect(board.map((e) => e.user), isNot(contains(mockFriends.first)));
    });

    testWidgets('picker switches from all friends to the Tran family',
            (tester) async {
          await pumpBoard(tester);
          expect(find.byKey(const ValueKey('row-u_mom')), findsNothing);

          await tester.tap(find.text('All friends'));
          await tester.pumpAndSettle();
          expect(find.text('Whose leaderboard?'), findsOneWidget);
          expect(find.text('5 members'), findsOneWidget);

          await tester.tap(find.text('Tran family'));
          await tester.pumpAndSettle();

          final board = await stats.xpLeaderboard(
              weekOf: now, userIds: circleTranFamily.profileIds);
          expect(find.text('Tran family'), findsOneWidget);
          expect(nameIn(tester, 'podium-1'), board[0].user.displayName);
          for (final e in board.skip(3)) {
            expect(find.byKey(ValueKey('row-${e.user.id}')), findsOneWidget);
          }
          // Friends who aren't family are gone.
          expect(find.byKey(const ValueKey('row-u_alex')), findsNothing);
          // Leagues are between all your friends, not one family.
          expect(find.byKey(const ValueKey('league-card')), findsNothing);
          expect(find.text('Alex'), findsNothing);

          // And back again.
          await tester.tap(find.text('Tran family'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('All friends'));
          await tester.pumpAndSettle();
          expect(find.text('All friends'), findsOneWidget);
          expect(find.byKey(const ValueKey('row-u_mom')), findsNothing);
        });

    testWidgets('a brand-new family asks you to invite people',
            (tester) async {
          const roommates = CircleFamily(id: 'roommates', name: 'Roommates');
          await pumpBoard(
            tester,
            families: FamilyStore()..add(roommates),
            initialFamily: roommates,
          );

          expect(find.text('Roommates'), findsOneWidget);
          expect(find.textContaining("It's just you in Roommates"), findsOneWidget);
          expect(find.byKey(const ValueKey('podium-1')), findsNothing);
        });
  });

  group('nudgeMessage', () {
    LeaderboardEntry e(int rank, UserProfile u, double v) => LeaderboardEntry(
        rank: rank, user: u, metric: StatMetric.steps, value: v);

    test('says how far behind the next person you are', () {
      final entries = [
        e(1, mockFriends[0], 60000),
        e(2, mockMe, 57860),
      ];
      expect(nudgeMessage(LeaderboardBoard.steps, entries, mockMe.id),
          "You're 2,140 steps behind Alex 👀");
    });

    test('celebrates first place and notices ties', () {
      expect(
          nudgeMessage(LeaderboardBoard.steps,
              [e(1, mockMe, 10), e(2, mockFriends[0], 5)], mockMe.id),
          contains('#1'));
      expect(
          nudgeMessage(LeaderboardBoard.steps,
              [e(1, mockFriends[0], 10), e(1, mockMe, 10)], mockMe.id),
          contains('tied'));
    });
  });

  group('formatting', () {
    test('weekResetLabel counts down to Monday 00:00', () {
      expect(weekResetLabel(DateTime(2026, 11, 2, 0, 0)), 'Resets in 7 days');
      expect(weekResetLabel(DateTime(2026, 11, 7, 12)), 'Resets in 1 day');
      expect(weekResetLabel(DateTime(2026, 11, 8, 20)), 'Resets in 4 hours');
      expect(weekResetLabel(DateTime(2026, 11, 8, 23, 50)), 'Resets in 10 min');
    });

    test('values read naturally', () {
      expect(LeaderboardBoard.steps.format(62140), '62,140 steps');
      expect(LeaderboardBoard.sleep.format(432), '7h 12m');
      expect(LeaderboardBoard.screenTime.format(45), '45m');
      expect(LeaderboardBoard.xp.format(1240), '1,240 XP');
      expect(ordinal(1), '1st');
      expect(ordinal(12), '12th');
      expect(ordinal(23), '23rd');
    });
  });
}