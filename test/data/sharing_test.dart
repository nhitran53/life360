import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life360/data/health/fake_health_source.dart';
import 'package:life360/data/health_stats_repository.dart';
import 'package:life360/data/mock_data.dart';
import 'package:life360/data/mock_friends_repository.dart';
import 'package:life360/data/mock_stats_repository.dart';
import 'package:life360/data/sharing_repository.dart';
import 'package:life360/data/sharing_stats_repository.dart';
import 'package:life360/models/models.dart';
import 'package:life360/screens/leaderboard_screen.dart';
import 'package:life360/data/family_store.dart';
import 'package:life360/screens/privacy_screen.dart';
import 'package:life360/theme/app_theme.dart';

import 'gated_test_doubles.dart';

void main() {
  // A Wednesday.
  final now = DateTime(2026, 3, 11, 12);
  DateTime clock() => now;

  group('SharingSettings', () {
    test('sleep and screen time are private by default', () {
      const s = SharingSettings();
      expect(s.isShared(StatMetric.steps, now), isTrue);
      expect(s.isShared(StatMetric.workout, now), isTrue);
      expect(s.isShared(StatMetric.calories, now), isTrue);
      expect(s.isShared(StatMetric.sleep, now), isFalse);
      expect(s.isShared(StatMetric.screenTime, now), isFalse);
    });

    test('toggling a metric flips only that metric', () {
      final s = const SharingSettings()
          .withShared(StatMetric.sleep, true)
          .withShared(StatMetric.steps, false);
      expect(s.hidden, {StatMetric.steps, StatMetric.screenTime});
    });

    test('pausing hides everything until it ends', () {
      final s = const SharingSettings().withPause(
        now.add(const Duration(hours: 24)),
      );
      for (final m in StatMetric.values) {
        expect(s.isShared(m, now), isFalse);
      }
      expect(
        s.isShared(StatMetric.steps, now.add(const Duration(hours: 25))),
        isTrue,
      );
      expect(s.withPause(null).isPaused(now), isFalse);
    });

    test('round-trips through JSON', () {
      final s = const SharingSettings(hidden: {StatMetric.calories})
          .withPause(now);
      expect(SharingSettings.fromJson(s.toJson()), s);
    });

    test('JSON stores the pause as UTC and only metric names', () {
      final json = const SharingSettings(hidden: {StatMetric.sleep})
          .withPause(DateTime.utc(2026, 3, 12, 9))
          .toJson();
      expect(json, {
        'hidden': ['sleep'],
        'pausedUntil': '2026-03-12T09:00:00.000Z',
      });
    });

    test('missing or malformed JSON stays private', () {
      expect(
        SharingSettings.fromJson({}).hidden,
        SharingSettings.defaultHidden,
      );
      expect(
        SharingSettings.fromJson({'hidden': 'steps'}).hidden,
        SharingSettings.defaultHidden,
      );
      final s = SharingSettings.fromJson({
        'hidden': ['nonsense', 'steps'],
        'pausedUntil': 'not a date',
      });
      expect(s.hidden, {StatMetric.steps});
      expect(s.pausedUntil, isNull);
    });
  });

  group('SharingStatsRepository', () {
    late MockFriendsRepository friends;
    late MockSharingRepository sharing;
    late MockStatsRepository raw;
    late SharingStatsRepository stats;

    setUp(() {
      friends = MockFriendsRepository(clock: clock);
      raw = MockStatsRepository(friends: friends, clock: clock);
      sharing = MockSharingRepository(
        initial: {
          'u_alex': const SharingSettings(hidden: {}),
          'u_bree': const SharingSettings(
            hidden: {StatMetric.steps, StatMetric.sleep},
          ),
        },
      );
      stats = SharingStatsRepository(
        inner: HealthStatsRepository(
          // Never connected, so everyone's stats come from the mock.
          source: FakeHealthSource(),
          fallback: raw,
          friends: friends,
        ),
        friends: friends,
        sharing: sharing,
        clock: clock,
      );
    });

    Future<Set<String>> boardIds(StatMetric metric) async => {
      for (final e in await stats.leaderboard(metric)) e.user.id,
    };

    test('a metric board only ranks people who share it', () async {
      final sleepBoard = await boardIds(StatMetric.sleep);
      // Only Alex opted in to sharing sleep; you keep the default.
      expect(sleepBoard, {'u_alex'});

      final stepsBoard = await boardIds(StatMetric.steps);
      expect(stepsBoard, contains(mockMe.id));
      expect(stepsBoard, isNot(contains('u_bree')));
      expect(stepsBoard, contains('u_alex'));
    });

    test('ranks stay 1, 2, 3 after people are left out', () async {
      final board = await stats.leaderboard(StatMetric.steps);
      expect(board.first.rank, 1);
      expect(board.map((e) => e.rank).toList(), [
        for (var i = 0; i < board.length; i++) i + 1,
      ]);
    });

    test('opting in puts you on the board', () async {
      expect(await boardIds(StatMetric.sleep), isNot(contains(mockMe.id)));
      await sharing.update(
        mockMe.id,
        sharing.settingsFor(mockMe.id).withShared(StatMetric.sleep, true),
      );
      expect(await boardIds(StatMetric.sleep), contains(mockMe.id));
    });

    test('pausing takes you off every board, XP included', () async {
      await sharing.update(
        mockMe.id,
        const SharingSettings().withPause(now.add(const Duration(hours: 24))),
      );
      expect(await boardIds(StatMetric.steps), isNot(contains(mockMe.id)));
      final xp = {for (final e in await stats.xpLeaderboard()) e.user.id};
      expect(xp, isNot(contains(mockMe.id)));
      expect(xp, contains('u_bree'));
    });

    test("friends' hidden stats come back as 0; yours never do", () async {
      final bree = await stats.weeklySummary('u_bree');
      expect(bree.total(StatMetric.steps), 0);
      expect(bree.total(StatMetric.sleep), 0);
      expect(
        bree.total(StatMetric.workout),
        (await raw.weeklySummary('u_bree')).total(StatMetric.workout),
      );

      final mine = await stats.weeklySummary(mockMe.id);
      expect(
        mine.total(StatMetric.sleep),
        (await raw.weeklySummary(mockMe.id)).total(StatMetric.sleep),
      );

      final days = await stats.dailyStats(
        'u_bree',
        from: now.subtract(const Duration(days: 6)),
        to: now,
      );
      expect(days.every((d) => d.steps == 0 && d.sleepMinutes == 0), isTrue);
    });

    test('family boards respect sharing too', () async {
      final board = await stats.leaderboard(
        StatMetric.sleep,
        userIds: const ['u_alex', 'u_bree'],
      );
      expect(board.map((e) => e.user.id), ['u_alex']);
    });
  });

  test('nudge line explains a board you keep private', () {
    expect(
      nudgeMessage(
        LeaderboardBoard.sleep,
        const [],
        mockMe.id,
        youKeepPrivate: true,
      ),
      "You keep this one private, so you're not on this board 🔒",
    );
    expect(
      nudgeMessage(LeaderboardBoard.sleep, const [], mockMe.id),
      'Sync your stats to join the race 🏁',
    );
  });

  testWidgets('Privacy switches save to the sharing repository', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2900);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final sharing = MockSharingRepository(initial: {});
    addTearDown(sharing.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrivacyScreen(sharing: sharing, clock: clock),
        ),
      ),
    );

    await tester.tap(find.text('Screen time'));
    await tester.pump();
    expect(
      sharing.settingsFor(mockMe.id).isShared(StatMetric.screenTime, now),
      isTrue,
    );

    await tester.tap(find.text('Steps'));
    await tester.pump();
    expect(
      sharing.settingsFor(mockMe.id).isShared(StatMetric.steps, now),
      isFalse,
    );

    await tester.ensureVisible(find.text('Pause for 24 h'));
    await tester.tap(find.text('Pause for 24 h'));
    await tester.pump();
    expect(sharing.settingsFor(mockMe.id).isPaused(now), isTrue);
    expect(find.text('Resume sharing'), findsOneWidget);
  });

  testWidgets('A board nobody shares explains why it is empty', (tester) async {
    tester.view.physicalSize = const Size(1170, 3000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final friends = MockFriendsRepository(clock: clock);
    // Everyone keeps the defaults, so nobody shares sleep.
    final sharing = MockSharingRepository(initial: {});
    addTearDown(sharing.dispose);
    final stats = SharingStatsRepository(
      inner: HealthStatsRepository(
        source: FakeHealthSource(),
        fallback: MockStatsRepository(friends: friends, clock: clock),
        friends: friends,
      ),
      friends: friends,
      sharing: sharing,
      clock: clock,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: LeaderboardScreen(
          friends: friends,
          stats: stats,
          sharing: sharing,
          clock: clock,
          familyStore: FamilyStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final chip = find.byKey(const ValueKey('board-sleep'));
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Nobody here shares their sleep yet 🔒\n'
        'Turn it on in Privacy to be the first.',
      ),
      findsOneWidget,
    );
  });

  group('SharingStatsRepository leaderboard summaries run concurrently', () {
    SharingStatsRepository gatedRepo(
      GatedFriendsRepository gatedFriends,
      GatedStatsRepository gatedStats,
    ) => SharingStatsRepository(
      inner: HealthStatsRepository(
        source: FakeHealthSource(),
        fallback: gatedStats,
        friends: gatedFriends,
        clock: clock,
      ),
      friends: gatedFriends,
      sharing: MockSharingRepository(
        initial: {
          for (final id in [mockMe.id, 'u_alex', 'u_bree'])
            id: const SharingSettings(hidden: {}),
        },
      ),
      clock: clock,
    );

    test('start every lookup and summary before any finishes, '
        'skipping unknown ids and me', () async {
      final friendsGate = Gate();
      final statsGate = Gate();
      final gatedFriends = GatedFriendsRepository(friendsGate);
      final gatedStats = GatedStatsRepository(
        statsGate,
        stepsByUser: {mockMe.id: 300, 'u_bree': 500, 'u_alex': 200},
      );
      final board = gatedRepo(gatedFriends, gatedStats).leaderboard(
        StatMetric.steps,
        weekOf: now,
        userIds: ['u_bree', 'nobody', 'u_alex', mockMe.id, 'u_bree'],
      );

      await pumpEventQueue();
      // Duplicates are dropped, and every lookup is already in flight.
      expect(gatedFriends.started, ['u_bree', 'nobody', 'u_alex', mockMe.id]);
      expect(gatedStats.started, isEmpty);
      // Lookups finish in reverse order.
      await friendsGate.openReversed();

      await pumpEventQueue();
      // Me first, then the found users in the order given; all in flight.
      // My summary is rebuilt from days, so it may start at a different
      // moment; the others keep their order.
      expect(gatedStats.started.toSet(), {mockMe.id, 'u_bree', 'u_alex'});
      expect(gatedStats.started.where((id) => id != mockMe.id), [
        'u_bree',
        'u_alex',
      ]);
      // Summaries finish in reverse order but still land on the right people.
      await statsGate.openReversed();

      final entries = await board;
      expect(entries.map((e) => e.user.id), ['u_bree', mockMe.id, 'u_alex']);
      expect(entries.map((e) => e.value), [500, 300, 200]);
      expect(entries.map((e) => e.rank), [1, 2, 3]);
      expect(entries.every((e) => e.metric == StatMetric.steps), isTrue);
    });

    test('without userIds, me then friends are summarised together', () async {
      final statsGate = Gate();
      final friendIds = [
        for (final f in await GatedFriendsRepository(Gate()).friends()) f.id,
      ];
      // Friend k gets (k + 2) thousand steps and me 1,000, so everyone has a
      // different XP and the order is the friends reversed, then me.
      final steps = {
        mockMe.id: 1000,
        for (var i = 0; i < friendIds.length; i++) friendIds[i]: (i + 2) * 1000,
      };
      final gatedStats = GatedStatsRepository(statsGate, stepsByUser: steps);
      final board = gatedRepo(
        GatedFriendsRepository(Gate()),
        gatedStats,
      ).xpLeaderboard(weekOf: now);

      await pumpEventQueue();
      expect(gatedStats.started.toSet(), {mockMe.id, ...friendIds});
      expect(gatedStats.started.where((id) => id != mockMe.id), friendIds);
      await statsGate.openReversed();

      final entries = await board;
      final expectedIds = [...friendIds.reversed, mockMe.id];
      expect(entries.map((e) => e.user.id), expectedIds);
      expect(entries.map((e) => e.rank), [
        for (var i = 1; i <= expectedIds.length; i++) i,
      ]);
      expect(entries.map((e) => e.value), [
        for (final id in expectedIds)
          dailyXp(
            DailyStats(userId: id, date: DateTime(2026), steps: steps[id]!),
          ),
      ]);
      expect(entries.every((e) => e.metric == null), isTrue);
    });

    test('a failing user lookup surfaces its error', () async {
      final r = gatedRepo(
        GatedFriendsRepository(Gate()..open(), failIds: {'u_alex'}),
        GatedStatsRepository(Gate()..open()),
      );
      await expectLater(
        r.leaderboard(
          StatMetric.steps,
          weekOf: now,
          userIds: ['u_bree', 'u_alex'],
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'userById u_alex',
          ),
        ),
      );
    });

    test('a failing weekly summary surfaces its error', () async {
      final r = gatedRepo(
        GatedFriendsRepository(Gate()..open()),
        GatedStatsRepository(Gate()..open(), failIds: {'u_bree'}),
      );
      await expectLater(
        r.leaderboard(StatMetric.steps, weekOf: now),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'weeklySummary u_bree',
          ),
        ),
      );
    });
  });
}
