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
}
