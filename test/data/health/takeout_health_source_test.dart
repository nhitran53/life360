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

  test('grants all readable metrics', () async {
    final r = await source('{}').requestPermissions();
    expect(r.readable, source('{}').readableMetrics);
  });
}
