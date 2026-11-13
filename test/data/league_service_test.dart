import 'package:flutter_test/flutter_test.dart';
import 'package:life360/data/league_service.dart';
import 'package:life360/data/mock_data.dart';
import 'package:life360/data/mock_friends_repository.dart';
import 'package:life360/data/stats_repository.dart';
import 'package:life360/models/models.dart';

/// Wednesday, so "this week" started on Monday 2026-11-09.
final _now = DateTime(2026, 11, 11, 15);

UserProfile _person(String id) => UserProfile(
  id: id,
  displayName: id,
  username: id,
  avatarEmoji: '🙂',
  friendCode: id,
);

/// Serves a scripted XP board per week (keyed by the week's Monday).
class _ScriptedXpStats implements StatsRepository {
  _ScriptedXpStats(this.boards);

  final Map<DateTime, List<LeaderboardEntry>> boards;
  final requestedWeeks = <DateTime>[];

  @override
  Future<List<LeaderboardEntry>> xpLeaderboard({
    DateTime? weekOf,
    Iterable<String>? userIds,
  }) async {
    final week = startOfWeek(weekOf ?? _now);
    requestedWeeks.add(week);
    return boards[week] ?? const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// A board where [mockMe] finishes at [myRank] of [size] with [myXp] XP.
List<LeaderboardEntry> _board({
  required int myRank,
  required int size,
  int myXp = 100,
}) => [
  for (var rank = 1; rank <= size; rank++)
    LeaderboardEntry(
      rank: rank,
      user: rank == myRank ? mockMe : _person('p$rank'),
      metric: null,
      value: rank == myRank ? myXp.toDouble() : (size - rank + 1) * 10.0,
    ),
];

DateTime _weeksAgo(int n) =>
    startOfWeek(DateTime(_now.year, _now.month, _now.day - 7 * n));

LeagueService _service(StatsRepository stats, {int historyWeeks = 6}) =>
    LeagueService(
      stats: stats,
      friends: MockFriendsRepository(clock: () => _now),
      clock: () => _now,
      historyWeeks: historyWeeks,
    );

void main() {
  test("a new player starts in Bronze with this week's zone", () async {
    final stats = _ScriptedXpStats({_weeksAgo(0): _board(myRank: 1, size: 3)});

    final standing = await _service(stats).standing();

    expect(standing.league, League.bronze);
    expect(standing.rank, 1);
    expect(standing.groupSize, 3);
    expect(standing.zone, LeagueMove.up);
    expect(standing.lastWeek, isNull);
  });

  test('replays finished weeks, oldest first, to find the league', () async {
    final stats = _ScriptedXpStats({
      _weeksAgo(3): _board(myRank: 1, size: 3), // up → Silver
      _weeksAgo(2): _board(myRank: 1, size: 3), // up → Gold
      _weeksAgo(1): _board(myRank: 3, size: 3), // down → Silver
      _weeksAgo(0): _board(myRank: 2, size: 3),
    });

    final standing = await _service(stats).standing();

    expect(standing.league, League.silver);
    expect(standing.lastWeek, LeagueMove.down);
    expect(standing.zone, LeagueMove.stay);
  });

  test('only looks back historyWeeks finished weeks', () async {
    final stats = _ScriptedXpStats({
      _weeksAgo(3): _board(myRank: 1, size: 3),
      _weeksAgo(2): _board(myRank: 1, size: 3),
      _weeksAgo(1): _board(myRank: 1, size: 3),
    });

    final standing = await _service(stats, historyWeeks: 2).standing();

    expect(standing.league, League.gold);
    expect(stats.requestedWeeks, isNot(contains(_weeksAgo(3))));
  });

  test('a week you are missing from leaves your league alone', () async {
    final stats = _ScriptedXpStats({
      _weeksAgo(2): _board(myRank: 1, size: 3),
      _weeksAgo(1): [
        LeaderboardEntry(
          rank: 1,
          user: _person('p1'),
          metric: null,
          value: 50,
        ),
      ],
    });

    final standing = await _service(stats).standing();

    expect(standing.league, League.silver);
    expect(standing.lastWeek, LeagueMove.stay);
    expect(standing.rank, isNull, reason: "not on this week's board");
    expect(standing.zone, LeagueMove.stay);
  });

  test('passes stats errors through so the screen can hide the card', () {
    expect(_service(_ThrowingStats()).standing(), throwsA(isA<StateError>()));
  });

  test('rejects a negative history window', () {
    expect(
      () => _service(_ScriptedXpStats({}), historyWeeks: -1),
      throwsArgumentError,
    );
  });
}

class _ThrowingStats extends _ScriptedXpStats {
  _ThrowingStats() : super({});

  @override
  Future<List<LeaderboardEntry>> xpLeaderboard({
    DateTime? weekOf,
    Iterable<String>? userIds,
  }) async => throw StateError('offline');
}
