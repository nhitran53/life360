import 'package:flutter_test/flutter_test.dart';
import 'package:life360/models/models.dart';

UserProfile _user(String id) => UserProfile(
      id: id,
      displayName: id.toUpperCase(),
      username: id,
      avatarEmoji: '🙂',
      friendCode: id.toUpperCase(),
    );

DailyStats _day(String user, DateTime date,
        {int steps = 0, int sleep = 0, int screen = 0}) =>
    DailyStats(
      userId: user,
      date: date,
      steps: steps,
      sleepMinutes: sleep,
      screenTimeMinutes: screen,
    );

void main() {
  group('dates', () {
    test('startOfWeek snaps to Monday', () {
      // 2026-11-04 is a Wednesday.
      expect(startOfWeek(DateTime(2026, 11, 4, 15, 30)), DateTime(2026, 11, 2));
      expect(startOfWeek(DateTime(2026, 11, 2)), DateTime(2026, 11, 2));
      expect(startOfWeek(DateTime(2026, 11, 8, 23)), DateTime(2026, 11, 2));
    });

    test('dateKey is zero padded', () {
      expect(dateKey(DateTime(2026, 3, 7, 12)), '2026-03-07');
    });
  });

  group('DailyStats', () {
    test('drops the time part of the date', () {
      final s = _day('a', DateTime(2026, 11, 2, 18, 45));
      expect(s.date, DateTime(2026, 11, 2));
    });

    test('round-trips through JSON', () {
      final s = DailyStats(
        userId: 'a',
        date: DateTime(2026, 11, 2),
        steps: 9000,
        sleepMinutes: 420,
        workoutMinutes: 30,
        activeCalories: 500,
        screenTimeMinutes: 200,
      );
      expect(DailyStats.fromJson(s.toJson()), s);
    });

    test('toString does not leak health values', () {
      final s = _day('a', DateTime(2026, 11, 2), steps: 12345);
      expect(s.toString(), isNot(contains('12345')));
    });
  });

  group('WeeklySummary', () {
    final monday = DateTime(2026, 11, 2);
    final stats = [
      _day('a', monday.subtract(const Duration(days: 1)), steps: 99999),
      _day('a', monday, steps: 1000, sleep: 400),
      _day('a', DateTime(2026, 11, 4), steps: 3000, sleep: 500),
      _day('a', DateTime(2026, 11, 9), steps: 99999), // next week
      _day('b', monday, steps: 99999), // other user
    ];

    test('only counts this user\'s days in the week', () {
      final w = WeeklySummary.fromDays(
          userId: 'a', weekStart: DateTime(2026, 11, 5), stats: stats);
      expect(w.weekStart, monday);
      expect(w.daysTracked, 2);
      expect(w.total(StatMetric.steps), 4000);
      expect(w.average(StatMetric.sleep), 450);
    });

    test('average is 0 for an empty week', () {
      final w = WeeklySummary.fromDays(
          userId: 'z', weekStart: monday, stats: stats);
      expect(w.daysTracked, 0);
      expect(w.average(StatMetric.steps), 0);
    });
  });

  group('StatMetric', () {
    test('only screen time is lower-is-better', () {
      expect(
        StatMetric.values.where((m) => !m.higherIsBetter),
        [StatMetric.screenTime],
      );
    });
  });

  group('rankLeaderboard', () {
    final monday = DateTime(2026, 11, 2);
    WeeklySummary week(String id, List<DailyStats> days) =>
        WeeklySummary.fromDays(userId: id, weekStart: monday, stats: days);

    test('ranks steps by weekly total, highest first, ties share rank', () {
      final entries = rankLeaderboard(StatMetric.steps, {
        _user('a'): week('a', [_day('a', monday, steps: 5000)]),
        _user('b'): week('b', [_day('b', monday, steps: 9000)]),
        _user('c'): week('c', [_day('c', monday, steps: 5000)]),
        _user('d'): week('d', [_day('d', monday, steps: 100)]),
      });
      expect(entries.map((e) => e.user.id), ['b', 'a', 'c', 'd']);
      expect(entries.map((e) => e.rank), [1, 2, 2, 4]);
    });

    test('screen time: lowest average wins, empty weeks go last', () {
      final entries = rankLeaderboard(StatMetric.screenTime, {
        _user('a'): week('a', [
          _day('a', monday, screen: 100),
          _day('a', DateTime(2026, 11, 3), screen: 300),
        ]),
        _user('b'): week('b', [_day('b', monday, screen: 150)]),
        _user('z'): week('z', []),
      });
      expect(entries.map((e) => e.user.id), ['b', 'a', 'z']);
      expect(entries.first.value, 150);
      expect(entries[1].value, 200); // average, not total
      expect(entries.last.rank, 3);
    });
  });

  group('Friendship', () {
    final f = Friendship(
      id: 'f1',
      requesterId: 'a',
      addresseeId: 'b',
      status: FriendshipStatus.pending,
      createdAt: DateTime(2026, 11, 2),
    );

    test('otherUserId', () {
      expect(f.otherUserId('a'), 'b');
      expect(f.otherUserId('b'), 'a');
      expect(() => f.otherUserId('c'), throwsArgumentError);
    });

    test('round-trips through JSON', () {
      final back = Friendship.fromJson(f.toJson());
      expect(back.status, FriendshipStatus.pending);
      expect(back.createdAt, f.createdAt);
      expect(back.otherUserId('a'), 'b');
    });
  });
}
