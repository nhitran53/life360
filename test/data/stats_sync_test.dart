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
