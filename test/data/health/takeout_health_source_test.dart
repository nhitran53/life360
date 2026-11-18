import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:life360/data/health/takeout_health_source.dart';

void main() {
  final from = DateTime(2026, 1, 1);
  final to = DateTime(2026, 1, 31);

  TakeoutHealthSource source(String json) =>
      TakeoutHealthSource(load: () async => json);

  test('reads daily totals in range, sorted, for the given user', () async {
    final s = source('''{"days":[
      {"date":"2026-01-03","steps":30,"sleepMinutes":4,"workoutMinutes":5,"activeCalories":6},
      {"date":"2026-01-02","steps":10},
      {"date":"2026-02-02","steps":99},
      {"date":"2026-01-04","steps":0}
    ]}''');
    final out = await s.fetchDailyStats('me', from: from, to: to);
    expect(out.map((d) => d.date.day), [2, 3]);
    expect(out.first.userId, 'me');
    expect(out.last.sleepMinutes, 4);
    expect(out.last.workoutMinutes, 5);
    expect(out.last.activeCalories, 6);
    expect(out.last.screenTimeMinutes, 0);
  });

  test('bad json, wrong shape, or bad rows yield no crash', () async {
    expect(
      await source('nope').fetchDailyStats('me', from: from, to: to),
      isEmpty,
    );
    expect(
      await source('[]').fetchDailyStats('me', from: from, to: to),
      isEmpty,
    );
    final out = await source(
      '{"days":[1,{"date":"x"},{"date":"2026-01-02","steps":5}]}',
    ).fetchDailyStats('me', from: from, to: to);
    expect(out.length, 1);
  });

  test('a failing load surfaces a sanitized TakeoutLoadException', () async {
    final s = TakeoutHealthSource(
      load: () async => throw const FileSystemException('x', '/secret/path'),
    );
    await expectLater(
      s.fetchDailyStats('me', from: from, to: to),
      throwsA(
        isA<TakeoutLoadException>().having(
          (e) => e.toString(),
          'message',
          allOf(isNot(contains('secret')), contains('Could not read')),
        ),
      ),
    );
  });

  test('malformed json yields no days without throwing', () async {
    for (final bad in [
      '{"days":',
      '',
      '{"days":"x"}',
      '{"days":[null,[],"a"]}',
    ]) {
      expect(
        await source(bad).fetchDailyStats('me', from: from, to: to),
        isEmpty,
        reason: 'input: $bad',
      );
    }
  });

  test('skips rows with negative totals', () async {
    final out = await source(
      '{"days":[{"date":"2026-01-02","steps":-1},'
      '{"date":"2026-01-03","steps":5}]}',
    ).fetchDailyStats('me', from: from, to: to);
    expect(out.map((d) => d.date.day), [3]);
  });

  test('grants all readable metrics', () async {
    final r = await source('{}').requestPermissions();
    expect(r.readable, source('{}').readableMetrics);
  });

  group('shiftToToday', () {
    // Export ends Fri 2026-01-09 with a gap on the 8th; "today" is Wed
    // 2026-01-14, so everything moves 5 days later.
    const json = '''{"days":[
      {"date":"2026-01-07","steps":70,"sleepMinutes":7},
      {"date":"2026-01-09","steps":90,"activeCalories":9},
      {"date":"2026-01-05","steps":0}
    ]}''';

    TakeoutHealthSource shifted({String data = json}) => TakeoutHealthSource(
      load: () async => data,
      shiftToToday: true,
      clock: () => DateTime(2026, 1, 14, 15),
    );

    test('moves the latest export day to today and fills the gaps', () async {
      final out = await shifted().fetchDailyStats(
        'me',
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 1, 31),
      );
      // Span 5th..9th becomes 10th..14th: every day appears.
      expect(out.map((d) => d.date.day), [10, 11, 12, 13, 14]);
      expect(out.last.steps, 90);
      expect(out.last.activeCalories, 9);
      expect(out.last.sleepMinutes, 0);
      expect(out[2].steps, 70);
      expect(out[2].sleepMinutes, 7);
      expect(out[3].steps + out[3].sleepMinutes, 0);
      expect(out.first.steps, 0);
      expect(out.every((d) => d.userId == 'me'), isTrue);
    });

    test('today is found by a normal range query', () async {
      final out = await shifted().fetchDailyStats(
        'me',
        from: DateTime(2026, 1, 12),
        to: DateTime(2026, 1, 14),
      );
      expect(out.map((d) => d.date.day), [12, 13, 14]);
      expect(out.last.steps, 90);
    });

    test('an empty or unreadable export stays empty', () async {
      for (final data in ['{"days":[]}', 'nope']) {
        expect(
          await shifted(data: data)
              .fetchDailyStats('me', from: from, to: DateTime(2026, 2, 28)),
          isEmpty,
        );
      }
    });

    test('off by default: dates are kept and empty days omitted', () async {
      final out = await source(json).fetchDailyStats('me', from: from, to: to);
      expect(out.map((d) => d.date.day), [7, 9]);
    });
  });
}
