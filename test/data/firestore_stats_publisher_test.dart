import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life360/data/firestore_stats_publisher.dart';
import 'package:life360/models/models.dart';

// Checks what gets written. Security rules aren't enforced by the fake: see
// firestore.rules for those.
void main() {
  final now = DateTime(2026, 3, 12, 15);
  late FakeFirebaseFirestore db;
  late FirestoreStatsPublisher publisher;

  DailyStats day(int daysAgo, {int steps = 1000}) => DailyStats(
    userId: 'u1',
    date: DateTime(2026, 3, 12 - daysAgo),
    steps: steps,
    sleepMinutes: 450,
    workoutMinutes: 30,
    activeCalories: 300,
    screenTimeMinutes: 120,
  );

  Future<Map<String, dynamic>?> read(String key) async =>
      (await db.doc('users/u1/daily/$key').get()).data();

  setUp(() {
    db = FakeFirebaseFirestore();
    publisher = FirestoreStatsPublisher(db, uid: 'u1', clock: () => now);
  });

  test(
    'publishes only shared metrics under users/{uid}/daily/{date}',
    () async {
      await publisher.publish([day(0)], const SharingSettings());

      final data = (await read('2026-03-12'))!;
      expect(data.keys.toSet(), {
        'date',
        'steps',
        'workout',
        'calories',
        'updatedAt',
      });
      expect(data['date'], '2026-03-12');
      expect(data['steps'], 1000);
      expect(data['workout'], 30);
      expect(data['calories'], 300);
    },
  );

  test('a hidden metric has no key, not a 0', () async {
    await publisher.publish([
      day(0),
    ], const SharingSettings(hidden: {StatMetric.steps, StatMetric.sleep}));

    final data = (await read('2026-03-12'))!;
    expect(data.containsKey('steps'), isFalse);
    expect(data.containsKey('sleep'), isFalse);
    expect(data['screenTime'], 120); // explicitly shared here
    expect(data['workout'], 30);
  });

  test('shared metrics include sleep and screen time once opted in', () async {
    await publisher.publish([day(0)], const SharingSettings(hidden: {}));
    final data = (await read('2026-03-12'))!;
    expect(data['sleep'], 450);
    expect(data['screenTime'], 120);
  });

  test(
    'unavailable (denied) metrics are omitted, not published as 0',
    () async {
      await publisher.publish(
        [day(0)],
        const SharingSettings(hidden: {}),
        unavailable: {StatMetric.steps},
      );
      expect((await read('2026-03-12'))!.containsKey('steps'), isFalse);
    },
  );

  test(
    'hiding a metric later removes it from days already published',
    () async {
      await publisher.publish([day(0), day(1)], const SharingSettings());
      expect((await read('2026-03-11'))!['steps'], 1000);

      await publisher.publish([
        day(0),
        day(1),
      ], const SharingSettings(hidden: {StatMetric.steps}));

      for (final key in ['2026-03-12', '2026-03-11']) {
        final data = (await read(key))!;
        expect(data.containsKey('steps'), isFalse);
        expect(data['workout'], 30);
      }
    },
  );

  test(
    'while paused nothing is written and published days are deleted',
    () async {
      await publisher.publish([day(0)], const SharingSettings());
      expect(await read('2026-03-12'), isNotNull);

      final paused = const SharingSettings().withPause(
        now.add(const Duration(days: 1)),
      );
      await publisher.publish([day(0)], paused);

      expect(await read('2026-03-12'), isNull);
      expect((await db.collection('users/u1/daily').get()).docs, isEmpty);
    },
  );

  test('an expired pause shares normally', () async {
    final expired = const SharingSettings().withPause(
      now.subtract(const Duration(minutes: 1)),
    );
    await publisher.publish([day(0)], expired);
    expect(await read('2026-03-12'), isNotNull);
  });

  test('sharing nothing writes nothing', () async {
    await publisher.publish([
      day(0),
    ], SharingSettings(hidden: StatMetric.values.toSet()));
    expect((await db.collection('users/u1/daily').get()).docs, isEmpty);
  });

  test(
    'only the last 14 days are written, and missing days are deleted',
    () async {
      await db.doc('users/u1/daily/2026-03-10').set({
        'date': '2026-03-10',
        'steps': 5,
      });
      await publisher.publish([
        day(0),
        day(13),
        day(14),
      ], const SharingSettings());

      expect(await read('2026-03-12'), isNotNull);
      expect(await read('2026-02-27'), isNotNull); // 13 days ago
      expect(await read('2026-02-26'), isNull); // outside the window
      expect(await read('2026-03-10'), isNull); // no data for that day now
    },
  );

  test('values are clamped to what the rules accept', () async {
    await publisher.publish([day(0, steps: 999999)], const SharingSettings());
    expect((await read('2026-03-12'))!['steps'], 200000);
  });

  test('dayFields has the same keys as the metric names', () {
    expect(
      FirestoreStatsPublisher.dayFields(
        day(0),
        StatMetric.values.toSet(),
      )!.keys.toSet(),
      {'date', ...StatMetric.values.map((m) => m.name)},
    );
    expect(FirestoreStatsPublisher.dayFields(day(0), {}), isNull);
  });
}
