import 'package:flutter_test/flutter_test.dart';
import 'package:life360/models/models.dart';

void main() {
  final monday = DateTime(2026, 3, 9);
  const alex = UserProfile(
    id: 'u_alex',
    displayName: 'Alex',
    username: 'alex.runs',
    avatarEmoji: '🏃',
    friendCode: 'ALEX42',
  );

  WeeklySummary week(String id, List<DailyStats> days) =>
      WeeklySummary.fromDays(userId: id, weekStart: monday, stats: days);

  DailyStats day(
    String id,
    int offset, {
    int steps = 0,
    int sleep = 0,
    int screen = 0,
  }) => DailyStats(
    userId: id,
    date: DateTime(2026, 3, 9 + offset),
    steps: steps,
    sleepMinutes: sleep,
    screenTimeMinutes: screen,
  );

  FriendSnapshot friend(
    List<DailyStats> days, {
    Set<StatMetric> hidden = const {},
  }) => FriendSnapshot(
    user: alex,
    today: days.isEmpty ? null : days.last,
    week: week('u_alex', days),
    streak: 3,
    hidden: hidden,
  );

  final mine = week('u_me', [
    day('u_me', 0, steps: 8000, sleep: 420, screen: 120),
    day('u_me', 1, steps: 6000, sleep: 400, screen: 200),
  ]);

  group('StatComparison', () {
    test('more steps leads', () {
      final c = StatComparison.of(
        StatMetric.steps,
        mine: mine,
        friend: friend([day('u_alex', 0, steps: 16000)]),
      );
      expect(c.leader, Leader.friend);
      expect(c.gap, 2000);
    });

    test('less screen time leads', () {
      final c = StatComparison.of(
        StatMetric.screenTime,
        mine: mine, // 160 min a day on average
        friend: friend([day('u_alex', 0, screen: 240)]),
      );
      expect(c.leader, Leader.you);
    });

    test('equal values tie', () {
      final c = StatComparison.of(
        StatMetric.steps,
        mine: mine,
        friend: friend([day('u_alex', 0, steps: 14000)]),
      );
      expect(c.leader, Leader.tie);
    });

    test('a private stat has no leader and no value', () {
      final c = StatComparison.of(
        StatMetric.sleep,
        mine: mine,
        friend: friend(
          [day('u_alex', 0, sleep: 0)],
          hidden: {StatMetric.sleep},
        ),
      );
      expect(c.theirs, isNull);
      expect(c.theirsHidden, isTrue);
      expect(c.leader, Leader.unknown);
    });
  });

  group('stepsNudge', () {
    String nudge(StatComparison c) =>
        stepsNudge('Alex', c, formatSteps: (n) => '$n');

    test('friend ahead', () {
      expect(
        nudge(
          const StatComparison(
            metric: StatMetric.steps,
            yours: 1000,
            theirs: 3000,
          ),
        ),
        'Alex is 2000 steps ahead 👀',
      );
    });

    test('you ahead', () {
      expect(
        nudge(
          const StatComparison(
            metric: StatMetric.steps,
            yours: 5000,
            theirs: 3800,
          ),
        ),
        "You're 1200 steps ahead of Alex 💪",
      );
    });

    test('tie, private and no data', () {
      expect(
        nudge(
          const StatComparison(metric: StatMetric.steps, yours: 10, theirs: 10),
        ),
        'Neck and neck with Alex 🤝',
      );
      expect(
        nudge(
          const StatComparison(
            metric: StatMetric.steps,
            yours: 10,
            theirs: null,
            theirsHidden: true,
          ),
        ),
        'Alex keeps steps private 🔒',
      );
      expect(
        nudge(
          const StatComparison(
            metric: StatMetric.steps,
            yours: 10,
            theirs: null,
          ),
        ),
        'No steps from Alex yet this week',
      );
    });
  });

  test('FriendSnapshot hides private values and reads 0 for no data', () {
    final f = friend(
      [day('u_alex', 0, steps: 4200, sleep: 450)],
      hidden: {StatMetric.sleep},
    );
    expect(f.todayValue(StatMetric.steps), 4200);
    expect(f.todayValue(StatMetric.sleep), isNull);
    expect(friend([]).todayValue(StatMetric.steps), 0);
    expect(f.sharesNothing, isFalse);
    expect(friend([], hidden: StatMetric.values.toSet()).sharesNothing, isTrue);
  });
}
