import 'package:flutter_test/flutter_test.dart';
import 'package:life360/data/health/fake_health_source.dart';
import 'package:life360/data/health/health_connection_store.dart';
import 'package:life360/data/health/health_source.dart';
import 'package:life360/data/health_stats_repository.dart';
import 'package:life360/data/mock_friends_repository.dart';
import 'package:life360/data/mock_stats_repository.dart';
import 'package:life360/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ThrowingStore implements HealthConnectionStore {
  @override
  Future<bool> loadConnected() async => throw StateError('no disk');

  @override
  Future<void> saveConnected(bool connected) async =>
      throw StateError('no disk');
}

class _BrokenSource extends FakeHealthSource {
  @override
  Future<HealthAvailability> availability() async =>
      throw StateError('secret steps 12345');
}

void main() {
  late MockFriendsRepository friends;
  late MockStatsRepository mock;

  setUp(() {
    friends = MockFriendsRepository();
    mock = MockStatsRepository(friends: friends);
  });

  HealthStatsRepository repo(
    FakeHealthSource source,
    HealthConnectionStore store,
  ) => HealthStatsRepository(
    source: source,
    fallback: mock,
    friends: friends,
    store: store,
  );

  group('HealthStatsRepository persistence', () {
    test('a successful connect is remembered', () async {
      final store = InMemoryHealthConnectionStore();
      await repo(FakeHealthSource(), store).connect();
      expect(await store.loadConnected(), isTrue);
    });

    test('restoreConnection reconnects after a restart', () async {
      final store = InMemoryHealthConnectionStore();
      await repo(FakeHealthSource(), store).connect();

      final source = FakeHealthSource();
      final restarted = repo(source, store);
      expect(restarted.isConnected, isFalse);
      await restarted.restoreConnection();
      expect(restarted.isConnected, isTrue);
      expect(restarted.availability, HealthAvailability.available);
      expect(restarted.lastSyncedAt, isNotNull);
      expect(source.requestPermissionsCalls, 1);
    });

    test('restoreConnection does nothing when never connected', () async {
      final source = FakeHealthSource();
      final r = repo(source, InMemoryHealthConnectionStore());
      await r.restoreConnection();
      expect(r.isConnected, isFalse);
      expect(r.availability, isNull);
      expect(source.requestPermissionsCalls, 0);
    });

    test('restoreConnection runs once', () async {
      final source = FakeHealthSource();
      final r = repo(source, InMemoryHealthConnectionStore(connected: true));
      await Future.wait([r.restoreConnection(), r.restoreConnection()]);
      await r.restoreConnection();
      expect(source.requestPermissionsCalls, 1);
    });

    test('disconnect clears the saved flag and the connection', () async {
      final store = InMemoryHealthConnectionStore();
      final r = repo(FakeHealthSource(), store);
      await r.connect();
      await r.disconnect();
      expect(r.isConnected, isFalse);
      expect(r.lastSyncedAt, isNull);
      expect(await store.loadConnected(), isFalse);

      final restarted = repo(FakeHealthSource(), store);
      await restarted.restoreConnection();
      expect(restarted.isConnected, isFalse);
    });

    test(
      'revoked permissions on restore stay denied and are forgotten',
      () async {
        final store = InMemoryHealthConnectionStore(connected: true);
        final source = FakeHealthSource(
          permissionOutcome: {
            StatMetric.steps: HealthPermissionStatus.denied,
            StatMetric.sleep: HealthPermissionStatus.denied,
            StatMetric.workout: HealthPermissionStatus.denied,
            StatMetric.calories: HealthPermissionStatus.denied,
          },
        );
        final r = repo(source, store);
        await r.restoreConnection();
        expect(r.isConnected, isFalse);
        expect(r.deniedMetrics, isNotEmpty);
        expect(await store.loadConnected(), isFalse);
      },
    );

    test('an unavailable platform on restore stays unavailable', () async {
      final store = InMemoryHealthConnectionStore(connected: true);
      final r = repo(
        FakeHealthSource(availabilityResult: HealthAvailability.notInstalled),
        store,
      );
      await r.restoreConnection();
      expect(r.isConnected, isFalse);
      expect(r.availability, HealthAvailability.notInstalled);
      expect(await store.loadConnected(), isFalse);
    });

    test(
      'a failing source on restore keeps the flag for next launch',
      () async {
        final store = InMemoryHealthConnectionStore(connected: true);
        final r = repo(_BrokenSource(), store);
        await r.restoreConnection();
        expect(r.isConnected, isFalse);
        expect(await store.loadConnected(), isTrue);
      },
    );

    test('a broken store never breaks connecting', () async {
      final r = repo(FakeHealthSource(), _ThrowingStore());
      await r.restoreConnection();
      expect(r.isConnected, isFalse);
      expect(await r.connect(), isTrue);
    });
  });

  group('SharedPreferencesHealthConnectionStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('defaults to not connected', () async {
      expect(
        await SharedPreferencesHealthConnectionStore().loadConnected(),
        isFalse,
      );
    });

    test('round-trips and clears the flag', () async {
      final store = SharedPreferencesHealthConnectionStore();
      await store.saveConnected(true);
      expect(
        await SharedPreferencesHealthConnectionStore().loadConnected(),
        isTrue,
      );
      await store.saveConnected(false);
      expect(
        await SharedPreferencesHealthConnectionStore().loadConnected(),
        isFalse,
      );
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
    });
  });
}
