import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life360/data/connectable_stats_repository.dart';
import 'package:life360/data/firestore_sharing_repository.dart';
import 'package:life360/data/firestore_stats_publisher.dart';
import 'package:life360/data/health/health_source.dart';
import 'package:life360/data/sharing_repository.dart';
import 'package:life360/data/stats_sync.dart';
import 'package:life360/models/models.dart';

void main() {
  final now = DateTime(2026, 3, 12, 15);
  late FakeFirebaseFirestore db;
  late FirestoreSharingRepository sharing;
  late _FakeSource source;
  late StatsSync sync;

  Future<List<String>> published() async => [
    for (final d in (await db.collection('users/u1/daily').get()).docs) d.id,
  ];

  setUp(() {
    db = FakeFirebaseFirestore();
    sharing = FirestoreSharingRepository(db, uid: 'u1');
    source = _FakeSource([
      DailyStats(userId: 'u1', date: DateTime(2026, 3, 12), steps: 4000),
    ]);
    sync = StatsSync(
      source: source,
      sharing: sharing,
      publisher: FirestoreStatsPublisher(db, uid: 'u1', clock: () => now),
      userId: 'u1',
      clock: () => now,
    );
  });

  test('publishes nothing until the sharing settings have loaded', () async {
    await sync.sync();
    expect(await published(), isEmpty);

    await sharing.load();
    // A new user never opened the privacy screen: the rules need a saved
    // settings document before they accept published days.
    expect((await db.doc('users/u1/private/settings').get()).exists, isTrue);
    await sync.sync();
    expect(await published(), ['2026-03-12']);
  });

  test('a failed settings load keeps publishing off', () async {
    final unloaded = _NeverLoaded();
    final failClosed = StatsSync(
      source: source,
      sharing: unloaded,
      publisher: FirestoreStatsPublisher(db, uid: 'u1', clock: () => now),
      userId: 'u1',
      clock: () => now,
    );
    await failClosed.sync();
    expect(await published(), isEmpty);
  });

  test('does not publish when health is not connected (demo data)', () async {
    await sharing.load();
    source.connected = false;
    await sync.sync();
    expect(await published(), isEmpty);
  });

  test('denied metrics are not published as 0', () async {
    await sharing.load();
    source.denied = {StatMetric.steps};
    await sync.sync();
    final data = (await db.doc('users/u1/daily/2026-03-12').get()).data()!;
    expect(data.containsKey('steps'), isFalse);
  });

  test('re-publishes when the sharing settings change', () async {
    await sharing.load();
    sync.start();
    addTearDown(sync.dispose);

    await sharing.update(
      'u1',
      const SharingSettings(hidden: {StatMetric.steps}),
    );
    await pumpEventQueue();
    var data = (await db.doc('users/u1/daily/2026-03-12').get()).data();
    expect(data, isNotNull);
    expect(data!.containsKey('steps'), isFalse);

    await sharing.update('u1', const SharingSettings());
    await pumpEventQueue();
    data = (await db.doc('users/u1/daily/2026-03-12').get()).data();
    expect(data!['steps'], 4000);
  });

  test(
    'pausing deletes published days even when health is disconnected',
    () async {
      await sharing.load();
      await sync.sync();
      expect(await published(), isNotEmpty);

      source.connected = false;
      await sharing.update(
        'u1',
        const SharingSettings().withPause(now.add(const Duration(days: 1))),
      );
      await sync.sync();
      expect(await published(), isEmpty);
    },
  );

  test('a source that throws leaves published days untouched', () async {
    await sharing.load();
    await sync.sync();
    source.fail = true;
    await sync.sync();
    expect(await published(), ['2026-03-12']);
  });

  group('revoking needs no health access', () {
    Future<Map<String, dynamic>?> read(String key) async =>
        (await db.doc('users/u1/daily/$key').get()).data();

    Future<void> publishAll() async {
      await sharing.update('u1', const SharingSettings(hidden: {}));
      await sync.sync();
      expect((await read('2026-03-12'))!['steps'], 4000);
    }

    test('hiding a metric while health is disconnected removes it', () async {
      await publishAll();
      source.connected = false;
      await sharing.update(
        'u1',
        const SharingSettings(hidden: {StatMetric.steps}),
      );
      await sync.sync();
      final data = (await read('2026-03-12'))!;
      expect(data.containsKey('steps'), isFalse);
    });

    test('hiding a metric while the health read throws removes it', () async {
      await publishAll();
      source.fail = true;
      await sharing.update(
        'u1',
        const SharingSettings(hidden: {StatMetric.steps}),
      );
      await sync.sync();
      final data = (await read('2026-03-12'))!;
      expect(data.containsKey('steps'), isFalse);
    });

    test(
      'pausing while the health read throws deletes published days',
      () async {
        await publishAll();
        source.fail = true;
        await sharing.update(
          'u1',
          const SharingSettings().withPause(now.add(const Duration(days: 1))),
        );
        await sync.sync();
        expect(await published(), isEmpty);
      },
    );

    test('pausing later deletes days that left the 14-day window', () async {
      await publishAll();
      var later = now.add(const Duration(days: 20));
      source.connected = false;
      final laterSync = StatsSync(
        source: source,
        sharing: sharing,
        publisher: FirestoreStatsPublisher(db, uid: 'u1', clock: () => later),
        userId: 'u1',
        clock: () => later,
      );
      await sharing.update(
        'u1',
        const SharingSettings().withPause(later.add(const Duration(days: 1))),
      );
      await laterSync.sync();
      expect(await published(), isEmpty);
    });
  });

  group('a failed revoke is retried without a health sync', () {
    late _FlakyPublisher flaky;
    late StatsSync retrying;

    Future<Map<String, dynamic>?> read() async =>
        (await db.doc('users/u1/daily/2026-03-12').get()).data();

    Future<void> until(bool Function() done) async {
      for (var i = 0; i < 200 && !done(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    }

    setUp(() async {
      flaky = _FlakyPublisher(db, clock: () => now);
      retrying = StatsSync(
        source: source,
        sharing: sharing,
        publisher: flaky,
        userId: 'u1',
        clock: () => now,
        retryBase: const Duration(milliseconds: 40),
      );
      await sharing.update('u1', const SharingSettings(hidden: {}));
      await retrying.sync();
      expect((await read())!['steps'], 4000);
      expect(retrying.revocationPending, isFalse);
      source.connected = false; // health plays no part from here on
      retrying.start();
      addTearDown(retrying.dispose);
      await pumpEventQueue(); // let the run started by start() finish
    });

    test('a saved hide whose cleanup failed is cleaned up later', () async {
      flaky.failures = 2;
      await sharing.update(
        'u1',
        const SharingSettings(hidden: {StatMetric.steps}),
      );
      await pumpEventQueue();
      expect(retrying.revocationPending, isTrue);
      expect((await read())!['steps'], 4000); // still readable for now

      await until(() => !retrying.revocationPending);

      expect(retrying.revocationPending, isFalse);
      expect(flaky.calls, greaterThanOrEqualTo(3)); // two failures, then ok
      expect((await read())!.containsKey('steps'), isFalse);
    });

    test('a saved pause whose batch failed is cleaned up later', () async {
      flaky.failures = 1;
      await sharing.update(
        'u1',
        const SharingSettings().withPause(now.add(const Duration(days: 1))),
      );
      await pumpEventQueue();
      expect(retrying.revocationPending, isTrue);
      expect(await published(), ['2026-03-12']);

      await until(() => !retrying.revocationPending);

      expect(await published(), isEmpty);
    });

    test('a failed settings load is retried', () async {
      final late = _LateLoad();
      final lateSync = StatsSync(
        source: source,
        sharing: late,
        publisher: flaky,
        userId: 'u1',
        clock: () => now,
        retryBase: const Duration(milliseconds: 40),
      );
      addTearDown(lateSync.dispose);
      lateSync.start();
      await pumpEventQueue();
      expect(lateSync.revocationPending, isTrue);
      late.canLoad = true;
      await until(() => !lateSync.revocationPending);
      expect(lateSync.revocationPending, isFalse);
    });
  });

  test(
    'picks up settings changed from another device before publishing',
    () async {
      await sharing.load();
      await sync.sync();
      expect(
        (await db.doc('users/u1/daily/2026-03-12').get()).data()!['steps'],
        4000,
      );

      // Another session hides steps; this one's cached settings are stale.
      final other = FirestoreSharingRepository(db, uid: 'u1');
      await other.update(
        'u1',
        const SharingSettings(hidden: {StatMetric.steps}),
      );
      expect(sharing.settingsFor('u1').isShared(StatMetric.steps, now), isTrue);

      await sync.sync();

      expect(
        sharing.settingsFor('u1').isShared(StatMetric.steps, now),
        isFalse,
      );
      final data = (await db.doc('users/u1/daily/2026-03-12').get()).data()!;
      expect(data.containsKey('steps'), isFalse);
    },
  );
}

/// A publisher whose [revoke] fails [failures] times first.
class _FlakyPublisher extends FirestoreStatsPublisher {
  _FlakyPublisher(super.db, {super.clock}) : super(uid: 'u1');

  var failures = 0;
  var calls = 0;

  @override
  Future<void> revoke(SharingSettings settings) async {
    calls++;
    if (failures > 0) {
      failures--;
      throw StateError('daily query failed');
    }
    return super.revoke(settings);
  }
}

/// Not loaded until [canLoad] is set and [refresh] runs.
class _LateLoad extends MockSharingRepository {
  var canLoad = false;
  var _loaded = false;

  @override
  bool get isLoaded => _loaded;

  @override
  Future<void> refresh() async {
    if (canLoad && !_loaded) {
      _loaded = true;
      notifyListeners();
    }
  }
}

class _NeverLoaded extends MockSharingRepository {
  @override
  bool get isLoaded => false;
}

class _FakeSource implements ConnectableStatsRepository {
  _FakeSource(this.days);

  final List<DailyStats> days;
  var connected = true;
  var fail = false;
  Set<StatMetric> denied = const {};

  @override
  bool get isConnected => connected;

  @override
  Set<StatMetric> get deniedMetrics => denied;

  @override
  Future<List<DailyStats>> dailyStats(
    String userId, {
    required DateTime from,
    required DateTime to,
  }) async {
    if (fail) throw StateError('read failed');
    return days;
  }

  @override
  String get sourceName => 'Fake';

  @override
  HealthAvailability? get availability => HealthAvailability.available;

  @override
  DateTime? get lastSyncedAt => null;

  @override
  Future<bool> connect() async => true;

  @override
  Future<void> restoreConnection() async {}

  @override
  Future<void> openInstallPage() async {}

  @override
  Future<WeeklySummary> weeklySummary(String userId, {DateTime? weekOf}) =>
      throw UnimplementedError();

  @override
  Future<List<LeaderboardEntry>> leaderboard(
    StatMetric metric, {
    DateTime? weekOf,
    Iterable<String>? userIds,
  }) => throw UnimplementedError();

  @override
  Future<List<LeaderboardEntry>> xpLeaderboard({
    DateTime? weekOf,
    Iterable<String>? userIds,
  }) => throw UnimplementedError();
}
