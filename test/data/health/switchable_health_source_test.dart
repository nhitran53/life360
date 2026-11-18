import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life360/data/health/fake_health_source.dart';
import 'package:life360/data/health/health_connection_store.dart';
import 'package:life360/data/health/health_source.dart';
import 'package:life360/data/health/switchable_health_source.dart';
import 'package:life360/data/health_stats_repository.dart';
import 'package:life360/data/mock_friends_repository.dart';
import 'package:life360/data/mock_stats_repository.dart';
import 'package:life360/models/models.dart';

void main() {
  late FakeHealthSource first;
  late FakeHealthSource second;
  late SwitchableHealthSource switchable;

  setUp(() {
    first = FakeHealthSource(displayName: 'First');
    second = FakeHealthSource(
      displayName: 'Second',
      availabilityResult: HealthAvailability.notInstalled,
    );
    switchable = SwitchableHealthSource(
      options: [
        HealthSourceOption(id: 'a', label: 'A', source: first),
        HealthSourceOption(id: 'b', label: 'B', source: second),
        HealthSourceOption(
          id: 'c',
          label: 'C',
          source: second,
          unavailableNote: 'Nope only',
        ),
      ],
    );
  });

  group('SwitchableHealthSource', () {
    test('starts on the first option and forwards to it', () async {
      expect(switchable.selected.id, 'a');
      expect(switchable.displayName, 'First');
      expect(await switchable.availability(), HealthAvailability.available);
      await switchable.requestPermissions();
      await switchable.checkPermissions();
      await switchable.fetchDailyStats(
        'me',
        from: DateTime(2026),
        to: DateTime(2026),
      );
      await switchable.openInstallPage();
      expect(first.requestPermissionsCalls, 1);
      expect(first.checkPermissionsCalls, 1);
      expect(first.fetchCalls, 1);
      expect(first.openInstallPageCalls, 1);
      expect(second.requestPermissionsCalls, 0);
    });

    test('can start on a chosen option and switch to another', () async {
      expect(
        SwitchableHealthSource(
          options: switchable.options,
          selectedId: 'b',
        ).displayName,
        'Second',
      );
      switchable.select('b');
      expect(switchable.displayName, 'Second');
      expect(await switchable.availability(), HealthAvailability.notInstalled);
    });

    test('rejects unknown and unavailable options, keeping the choice', () {
      expect(() => switchable.select('zzz'), throwsArgumentError);
      expect(() => switchable.select('c'), throwsArgumentError);
      expect(switchable.selected.id, 'a');
    });
  });

  group('HealthStatsRepository.selectSource', () {
    late MockFriendsRepository friends;
    late InMemoryHealthConnectionStore store;
    late HealthStatsRepository repo;

    setUp(() {
      friends = MockFriendsRepository();
      store = InMemoryHealthConnectionStore();
      repo = HealthStatsRepository(
        source: switchable,
        fallback: MockStatsRepository(friends: friends),
        friends: friends,
        store: store,
      );
    });

    test('exposes the options and the selection', () {
      expect(repo.sourceOptions.map((o) => o.id), ['a', 'b', 'c']);
      expect(repo.selectedSourceId, 'a');
    });

    test('disconnects, clears the saved flag and switches', () async {
      expect(await repo.connect(), isTrue);
      expect(await store.loadConnected(), isTrue);
      expect(repo.sourceName, 'First');

      await repo.selectSource('b');

      expect(repo.selectedSourceId, 'b');
      expect(repo.sourceName, 'Second');
      expect(repo.isConnected, isFalse);
      expect(repo.availability, isNull);
      expect(repo.lastSyncedAt, isNull);
      expect(await store.loadConnected(), isFalse);

      // The existing connect flow now runs against the new source.
      expect(await repo.connect(), isFalse);
      expect(repo.availability, HealthAvailability.notInstalled);
      expect(second.requestPermissionsCalls, 0);
    });

    test('a bad id keeps the current connection', () async {
      await repo.connect();
      await expectLater(repo.selectSource('c'), throwsArgumentError);
      await expectLater(repo.selectSource('zzz'), throwsArgumentError);
      expect(repo.selectedSourceId, 'a');
      expect(repo.isConnected, isTrue);
      expect(await store.loadConnected(), isTrue);
    });

    test('a repository over a single source has no options', () async {
      final single = HealthStatsRepository(
        source: first,
        fallback: MockStatsRepository(friends: friends),
        friends: friends,
      );
      expect(single.sourceOptions, isEmpty);
      expect(single.selectedSourceId, isNull);
      await expectLater(single.selectSource('a'), throwsStateError);
    });
  });

  group('buildHealthSourceOptions', () {
    final platformSource = FakeHealthSource(displayName: 'Platform');
    final demo = FakeHealthSource(displayName: 'Demo');
    final takeout = FakeHealthSource(displayName: 'Takeout');

    SwitchableHealthSource build(
      TargetPlatform platform, {
      bool isWeb = false,
      HealthSource? takeoutSource,
    }) => buildHealthSourceOptions(
      platform: platform,
      isWeb: isWeb,
      platformSource: platformSource,
      demoSource: demo,
      takeout: takeoutSource,
      takeoutNote: 'shifted',
    );

    test('iOS: Apple Health usable, Health Connect disabled', () {
      final s = build(TargetPlatform.iOS);
      expect(s.options.map((o) => o.label), ['Apple Health', 'Health Connect']);
      expect(s.options[0].isAvailable, isTrue);
      expect(s.options[1].unavailableNote, 'Android only');
      expect(s.selected.id, appleHealthOptionId);
      expect(s.displayName, 'Platform');
    });

    test('Android: Health Connect usable, Apple Health disabled', () {
      final s = build(TargetPlatform.android);
      expect(s.options[0].unavailableNote, 'iOS only');
      expect(s.options[1].isAvailable, isTrue);
      expect(s.selected.id, healthConnectOptionId);
    });

    test('off a phone both are disabled and the demo source serves', () {
      for (final s in [
        build(TargetPlatform.linux),
        build(TargetPlatform.android, isWeb: true),
      ]) {
        expect(s.options.every((o) => !o.isAvailable), isTrue);
        expect(s.displayName, 'Demo');
      }
    });

    test('Takeout is only an option, and the default, when given', () {
      expect(
        build(TargetPlatform.iOS).options.map((o) => o.id),
        isNot(contains(takeoutOptionId)),
      );
      final s = build(TargetPlatform.iOS, takeoutSource: takeout);
      expect(s.options.last.label, 'Google Takeout (dev)');
      expect(s.options.last.note, 'shifted');
      expect(s.selected.id, takeoutOptionId);
      expect(s.displayName, 'Takeout');
    });
  });

  test('metrics come from the selected source', () {
    expect(switchable.readableMetrics, contains(StatMetric.steps));
  });
}
