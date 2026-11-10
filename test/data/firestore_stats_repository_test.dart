import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life360/data/firestore_stats_publisher.dart';
import 'package:life360/data/firestore_stats_repository.dart';
import 'package:life360/data/mock_data.dart';
import 'package:life360/data/mock_friends_repository.dart';
import 'package:life360/data/mock_stats_repository.dart';
import 'package:life360/models/models.dart';

// Checks reading and aggregating. Security rules aren't enforced by the fake:
// see firestore.rules for who may read.
void main() {
  // A Thursday, so the week is Mon 2026-03-09 .. Sun 2026-03-15.
  final now = DateTime(2026, 3, 12, 15);
  late FakeFirebaseFirestore db;
  late MockFriendsRepository friends;
  late MockStatsRepository own;
  late FirestoreStatsRepository repo;

  Future<void> put(String uid, String key, Map<String, Object?> fields) =>
      db.doc('users/$uid/daily/$key').set({'date': key, ...fields});

  setUp(() {
    db = FakeFirebaseFirestore();
    friends = MockFriendsRepository(clock: () => now);
    own = MockStatsRepository(friends: friends, clock: () => now);
    repo = FirestoreStatsRepository(
      db,
      own: own,
      friends: friends,
      clock: () => now,
    );
  });

  test("reads a friend's published days in the range, oldest first", () async {
    await put('u_alex', '2026-03-11', {'steps': 7000, 'workout': 20});
    await put('u_alex', '2026-03-09', {'steps': 5000});
    await put('u_alex', '2026-03-01', {'steps': 1});
    await put('u_bree', '2026-03-10', {'steps': 9});

    final days = await repo.dailyStats(
      'u_alex',
      from: DateTime(2026, 3, 9),
      to: DateTime(2026, 3, 12),
    );

    expect(days.map((d) => d.date), [
      DateTime(2026, 3, 9),
      DateTime(2026, 3, 11),
    ]);
    expect(days.map((d) => d.userId).toSet(), {'u_alex'});
    expect(days[1].steps, 7000);
    expect(days[1].workoutMinutes, 20);
  });

  test('a metric the friend did not publish reads as 0', () async {
    await put('u_alex', '2026-03-11', {'steps': 7000});
    final day = (await repo.dailyStats(
      'u_alex',
      from: DateTime(2026, 3, 11),
      to: DateTime(2026, 3, 11),
    )).single;
    expect(day.sleepMinutes, 0);
    expect(day.screenTimeMinutes, 0);
    expect(day.activeCalories, 0);
  });

  test('malformed values and documents are ignored', () async {
    await put('u_alex', '2026-03-10', {
      'steps': -5,
      'sleep': 'lots',
      'workout': 12.5,
    });
    await db.doc('users/u_alex/daily/2026-03-1x').set({'date': '2026-03-1x'});

    final days = await repo.dailyStats(
      'u_alex',
      from: DateTime(2026, 3, 1),
      to: DateTime(2026, 3, 31),
    );

    expect(days, hasLength(1));
    expect(days.single.steps, 0);
    expect(days.single.sleepMinutes, 0);
    expect(days.single.workoutMinutes, 0);
  });

  test('a refused read (not friends) returns no days', () async {
    final denied = FirestoreStatsRepository(
      _DeniedDb(),
      own: own,
      friends: friends,
    );
    expect(
      await denied.dailyStats(
        'u_stranger',
        from: DateTime(2026, 3, 9),
        to: DateTime(2026, 3, 15),
      ),
      isEmpty,
    );
  });

  test('your own stats come from the own repository, not Firestore', () async {
    await put(mockMe.id, '2026-03-11', {'steps': 1});
    final days = await repo.dailyStats(
      mockMe.id,
      from: DateTime(2026, 3, 9),
      to: DateTime(2026, 3, 12),
    );
    final expected = await own.dailyStats(
      mockMe.id,
      from: DateTime(2026, 3, 9),
      to: DateTime(2026, 3, 12),
    );
    expect(days, expected);
  });

  test('weeklySummary totals the friend\'s published week', () async {
    await put('u_alex', '2026-03-09', {'steps': 5000});
    await put('u_alex', '2026-03-11', {'steps': 7000});
    await put('u_alex', '2026-03-02', {'steps': 99999}); // last week

    final week = await repo.weeklySummary('u_alex', weekOf: now);

    expect(week.weekStart, DateTime(2026, 3, 9));
    expect(week.daysTracked, 2);
    expect(week.total(StatMetric.steps), 12000);
  });

  test('leaderboard ranks you against friends using published stats', () async {
    await put('u_alex', '2026-03-10', {'steps': 900000});
    await put('u_bree', '2026-03-10', {'steps': 1});

    final board = await repo.leaderboard(StatMetric.steps, weekOf: now);

    expect(board.first.user.id, 'u_alex');
    expect(board.map((e) => e.user.id), contains(mockMe.id));
    final bree = board.firstWhere((e) => e.user.id == 'u_bree');
    expect(bree.value, 1);
  });

  test('a published day round-trips through the publisher', () async {
    final publisher = FirestoreStatsPublisher(
      db,
      uid: 'u_alex',
      clock: () => now,
    );
    await publisher.publish([
      DailyStats(
        userId: 'u_alex',
        date: DateTime(2026, 3, 12),
        steps: 4000,
        sleepMinutes: 400,
      ),
    ], const SharingSettings());

    final day = (await repo.dailyStats(
      'u_alex',
      from: DateTime(2026, 3, 12),
      to: DateTime(2026, 3, 12),
    )).single;
    expect(day.steps, 4000);
    expect(day.sleepMinutes, 0); // private by default: never published
  });
}

class _DeniedDb extends FakeFirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
}
