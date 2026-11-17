import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:life360/data/health/health_package_source.dart';

/// Scripts only what [HealthPackageSource.fetchDailyStats] calls when just
/// steps and calories are readable. Anything else throws via [Fake].
class _FakeHealth extends Fake implements Health {
  _FakeHealth({required this.steps, required this.calories});

  /// Steps for the day starting at the given time.
  final Future<int?> Function(DateTime dayStart) steps;

  /// Calories for the day starting at the given time.
  final Future<double> Function(DateTime dayStart) calories;

  final stepCalls = <DateTime>[];
  final calorieCalls = <DateTime>[];

  /// Platform calls started but not yet finished, and the most there ever
  /// were at once.
  int inFlight = 0;
  int maxInFlight = 0;

  Future<T> _tracked<T>(Future<T> Function() call) async {
    maxInFlight = max(maxInFlight, ++inFlight);
    try {
      return await call();
    } finally {
      inFlight--;
    }
  }

  @override
  Future<void> configure() async {}

  @override
  bool isDataTypeAvailable(HealthDataType dataType) => true;

  @override
  Future<bool?> hasPermissions(
    List<HealthDataType> types, {
    List<HealthDataAccess>? permissions,
  }) async =>
      types.contains(HealthDataType.STEPS) ||
      types.contains(HealthDataType.ACTIVE_ENERGY_BURNED);

  @override
  Future<int?> getTotalStepsInInterval(
    DateTime startTime,
    DateTime endTime, {
    bool includeManualEntry = true,
  }) {
    stepCalls.add(startTime);
    return _tracked(() => steps(startTime));
  }

  @override
  Future<List<HealthDataPoint>> getHealthIntervalDataFromTypes({
    required DateTime startDate,
    required DateTime endDate,
    required List<HealthDataType> types,
    required int interval,
    List<RecordingMethod> recordingMethodsToFilter = const [],
  }) async {
    calorieCalls.add(startDate);
    final kcal = await _tracked(() => calories(startDate));
    return [
      HealthDataPoint(
        uuid: 'u${startDate.day}',
        value: NumericHealthValue(numericValue: kcal),
        type: HealthDataType.ACTIVE_ENERGY_BURNED,
        unit: HealthDataUnit.KILOCALORIE,
        dateFrom: startDate,
        dateTo: endDate,
        sourcePlatform: HealthPlatformType.appleHealth,
        sourceDeviceId: 'device',
        sourceId: 'source',
        sourceName: 'source',
      ),
    ];
  }

  @override
  List<HealthDataPoint> removeDuplicates(List<HealthDataPoint> points) =>
      points;
}

void main() {
  final from = DateTime(2026, 3, 9); // Monday
  final to = DateTime(2026, 3, 13);

  group('HealthPackageSource.fetchDailyStats', () {
    test(
      'returns days oldest first, omitting days with no steps or calories',
      () async {
        final health = _FakeHealth(
          // Day 11 has nothing; day 12 has only calories; day 13 only steps.
          steps: (d) async => switch (d.day) {
            9 => 100,
            10 => null,
            13 => 300,
            _ => 0,
          },
          calories: (d) async => switch (d.day) {
            9 => 10.4,
            12 => 49.6,
            _ => 0,
          },
        );
        final days = await HealthPackageSource(health: health)
            .fetchDailyStats('me', from: from, to: to);

        expect(days.map((d) => d.date.day), [9, 12, 13]);
        expect(days.map((d) => d.steps), [100, 0, 300]);
        expect(days.map((d) => d.activeCalories), [10, 50, 0]);
        expect(days.every((d) => d.userId == 'me'), isTrue);
      },
    );

    test('starts every steps and calories call before any finishes', () async {
      final gate = Completer<void>();
      final health = _FakeHealth(
        steps: (d) async {
          await gate.future;
          return d.day * 10;
        },
        calories: (d) async {
          await gate.future;
          return d.day.toDouble();
        },
      );
      final result = HealthPackageSource(health: health)
          .fetchDailyStats('me', from: from, to: to);

      await pumpEventQueue();
      // All five days, both calls, are already in flight.
      expect(health.stepCalls, [
        for (var d = 9; d <= 13; d++) DateTime(2026, 3, d),
      ]);
      expect(health.calorieCalls, health.stepCalls);

      gate.complete();
      final days = await result;
      expect(days.map((d) => d.date.day), [9, 10, 11, 12, 13]);
      expect(days.map((d) => d.steps), [90, 100, 110, 120, 130]);
      expect(days.map((d) => d.activeCalories), [9, 10, 11, 12, 13]);
    });

    test(
      'returns days oldest first when calls finish in reverse order',
      () async {
        final steps = {for (var d = 9; d <= 13; d++) d: Completer<int?>()};
        final calories = {for (var d = 9; d <= 13; d++) d: Completer<double>()};
        final health = _FakeHealth(
          steps: (d) => steps[d.day]!.future,
          calories: (d) => calories[d.day]!.future,
        );
        final result = HealthPackageSource(health: health)
            .fetchDailyStats('me', from: from, to: to);

        await pumpEventQueue();
        // Newest day finishes first, oldest last.
        for (var d = 13; d >= 9; d--) {
          steps[d]!.complete(d * 10);
          calories[d]!.complete(d.toDouble());
          await pumpEventQueue();
        }

        final days = await result;
        expect(days.map((d) => d.date.day), [9, 10, 11, 12, 13]);
        expect(days.map((d) => d.steps), [90, 100, 110, 120, 130]);
        expect(days.map((d) => d.activeCalories), [9, 10, 11, 12, 13]);
      },
    );

    test(
      'keeps at most maxConcurrentDays days in flight over a long range',
      () async {
        const dayCount = 61;
        final health = _FakeHealth(
          steps: (d) async {
            await Future<void>.delayed(Duration.zero);
            return d.difference(DateTime(2026)).inDays + 1;
          },
          calories: (d) async {
            await Future<void>.delayed(Duration.zero);
            return 5;
          },
        );
        final days = await HealthPackageSource(health: health).fetchDailyStats(
          'me',
          from: DateTime(2026),
          to: DateTime(2026, 1, dayCount),
        );

        // Each day makes two calls (steps and calories) at the same time.
        expect(health.maxInFlight, HealthPackageSource.maxConcurrentDays * 2);
        expect(health.inFlight, 0);
        expect(days.length, dayCount);
        expect(days.map((d) => d.date), [
          for (var i = 1; i <= dayCount; i++) DateTime(2026, 1, i),
        ]);
        expect(days.map((d) => d.steps), [
          for (var i = 1; i <= dayCount; i++) i,
        ]);
      },
    );

    test('stops starting new days after a failure', () async {
      final health = _FakeHealth(
        steps: (d) async => d.day == 1 ? throw StateError('steps 1') : 1,
        calories: (d) async => 5,
      );
      await expectLater(
        HealthPackageSource(health: health).fetchDailyStats(
          'me',
          from: DateTime(2026),
          to: DateTime(2026, 1, 61),
        ),
        throwsA(
          isA<StateError>().having((e) => e.message, 'message', 'steps 1'),
        ),
      );
      await pumpEventQueue();
      expect(health.stepCalls.length, lessThan(61));
    });

    test('a failing steps call throws its error and returns nothing', () async {
      final health = _FakeHealth(
        steps: (d) async => d.day == 11 ? throw StateError('steps 11') : d.day,
        calories: (d) async => 5,
      );
      await expectLater(
        HealthPackageSource(health: health)
            .fetchDailyStats('me', from: from, to: to),
        throwsA(
          isA<StateError>().having((e) => e.message, 'message', 'steps 11'),
        ),
      );
    });

    test('a failing calories call throws its error', () async {
      final health = _FakeHealth(
        steps: (d) async => d.day,
        calories: (d) async =>
            d.day == 12 ? throw StateError('calories 12') : 5,
      );
      await expectLater(
        HealthPackageSource(health: health)
            .fetchDailyStats('me', from: from, to: to),
        throwsA(
          isA<StateError>().having((e) => e.message, 'message', 'calories 12'),
        ),
      );
    });
  });
}
