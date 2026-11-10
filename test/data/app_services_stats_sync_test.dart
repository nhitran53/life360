import 'package:flutter/foundation.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life360/app_services.dart';
import 'package:life360/data/mock_data.dart';
import 'package:life360/data/mock_friends_repository.dart';
import 'package:life360/data/sharing_repository.dart';
import 'package:life360/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Wiring: connecting health publishes your stats, and friends' stats come
// from Firestore. Without a Firestore session nothing changes.
void main() {
  late FakeFirebaseFirestore db;

  setUp(() {
    // Tests default to Android, which would use the real Health Connect plugin.
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues({});
    db = FakeFirebaseFirestore();
  });

  Future<List<String>> published() async => [
    for (final d
        in (await db.collection('users/${mockMe.id}/daily').get()).docs)
      d.id,
  ];

  test('connecting health publishes only the stats you share', () async {
    final services = AppServices.defaults(
      friends: MockFriendsRepository(),
      sharing: MockSharingRepository(initial: {}),
      statsDb: db,
      userId: mockMe.id,
    );
    addTearDown(services.dispose);

    expect(await published(), isEmpty); // not connected: no demo data out

    expect(await services.stats.connect(), isTrue);
    await pumpEventQueue();

    final docs = (await db.collection('users/${mockMe.id}/daily').get()).docs;
    expect(docs, isNotEmpty);
    for (final doc in docs) {
      expect(doc.data().containsKey('sleep'), isFalse);
      expect(doc.data().containsKey('screenTime'), isFalse);
      expect(doc.data().containsKey('steps'), isTrue);
    }
  });

  test(
    'no Firestore session: nothing is published and friends stay mock',
    () async {
      final services = AppServices.defaults(
        friends: MockFriendsRepository(),
        sharing: MockSharingRepository(initial: {}),
      );
      addTearDown(services.dispose);

      await services.stats.connect();
      await pumpEventQueue();

      expect(await published(), isEmpty);
      final today = DateTime.now();
      final friendDays = await services.stats.dailyStats(
        'u_alex',
        from: DateTime(today.year, today.month, today.day - 6),
        to: today,
      );
      expect(friendDays, isNotEmpty); // mock data
    },
  );

  test(
    "with Firestore, friends' stats come from their published days",
    () async {
      final today = DateTime.now();
      final key = dateKey(today);
      await db.doc('users/u_alex/daily/$key').set({
        'date': key,
        'steps': 12345,
      });
      final services = AppServices.defaults(
        friends: MockFriendsRepository(),
        sharing: MockSharingRepository(initial: {}),
        statsDb: db,
        userId: mockMe.id,
      );
      addTearDown(services.dispose);

      final days = await services.stats.dailyStats(
        'u_alex',
        from: DateTime(today.year, today.month, today.day - 6),
        to: today,
      );

      expect(days.map((d) => d.steps), [12345]);
    },
  );

  group("friends' opted-in stats", () {
    final today = DateTime.now();
    final key = dateKey(today);

    Future<void> publish(String uid, Map<String, Object> fields) =>
        db.doc('users/$uid/daily/$key').set({'date': key, ...fields});

    late AppServices services;

    setUp(() async {
      // Alex shares sleep (and a real 0 of screen time); Bree only steps;
      // Dana has published nothing (paused or hasn't synced).
      await publish('u_alex', {'steps': 8000, 'sleep': 450, 'screenTime': 0});
      await publish('u_bree', {'steps': 9000});
      // The settings repository only has defaults for friends (sleep and
      // screen time private), as with real friends whose settings can't be read.
      services = AppServices.defaults(
        friends: MockFriendsRepository(),
        sharing: MockSharingRepository(initial: {}),
        statsDb: db,
        userId: mockMe.id,
      );
      addTearDown(services.dispose);
    });

    Future<List<String>> board(StatMetric metric) async => [
      for (final e in await services.stats.leaderboard(metric)) e.user.id,
    ];

    test('their sleep and screen time are visible, not zeroed', () async {
      final days = await services.stats.dailyStats(
        'u_alex',
        from: DateTime(today.year, today.month, today.day - 6),
        to: today,
      );
      expect(days.single.steps, 8000);
      expect(days.single.sleepMinutes, 450);
      expect(days.single.screenTimeMinutes, 0);

      final week = await services.stats.weeklySummary('u_alex');
      expect(week.total(StatMetric.sleep), 450);
    });

    test('a metric someone did not publish stays hidden', () async {
      final days = await services.stats.dailyStats(
        'u_bree',
        from: DateTime(today.year, today.month, today.day - 6),
        to: today,
      );
      expect(days.single.sleepMinutes, 0);
      final settings = services.sharing.settingsFor('u_bree');
      expect(settings.isShared(StatMetric.steps, today), isTrue);
      expect(settings.isShared(StatMetric.sleep, today), isFalse);
    });

    test(
      'sleep and screen time boards rank only people publishing them',
      () async {
        expect(await board(StatMetric.sleep), ['u_alex']);
        // A published 0 is a real value, so Alex is on the board.
        expect(await board(StatMetric.screenTime), ['u_alex']);
        expect(
          await board(StatMetric.steps),
          containsAll(['u_alex', 'u_bree']),
        );
      },
    );

    test('nobody who published nothing is on any board', () async {
      final xp = [
        for (final e in await services.stats.xpLeaderboard()) e.user.id,
      ];
      expect(xp, containsAll(['u_alex', 'u_bree']));
      expect(xp, isNot(contains('u_dana')));
      expect(await board(StatMetric.steps), isNot(contains('u_dana')));
    });

    test('the lock follows what was published', () async {
      await services.stats.dailyStats('u_alex', from: today, to: today);
      final alex = services.sharing.settingsFor('u_alex');
      expect(alex.isShared(StatMetric.sleep, today), isTrue);
      expect(alex.isShared(StatMetric.workout, today), isFalse);
      await services.stats.dailyStats('u_dana', from: today, to: today);
      expect(services.sharing.settingsFor('u_dana').isPaused(today), isTrue);
    });
  });
}
