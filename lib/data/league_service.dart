import '../models/models.dart';
import 'friends_repository.dart';
import 'stats_repository.dart';

/// Where the current user stands in the weekly leagues (see `league.dart`).
class LeagueStanding {
  const LeagueStanding({
    required this.league,
    required this.zone,
    required this.groupSize,
    this.rank,
    this.lastWeek,
  });

  /// The league you're competing in this week.
  final League league;

  /// What happens if the week ended now.
  final LeagueMove zone;

  /// Your rank on this week's XP board, or null when you're not on it
  /// (e.g. sharing is paused).
  final int? rank;

  /// How many people are on this week's XP board.
  final int groupSize;

  /// How last week ended for you, or null if this is your first week.
  final LeagueMove? lastWeek;
}

/// Works out the current user's league by replaying recent finished weeks of
/// the friends XP board. Nothing is stored, so the league always matches the
/// leaderboard and resets cleanly each Monday.
class LeagueService {
  LeagueService({
    required this._stats,
    required this._friends,
    DateTime Function()? clock,
    this.historyWeeks = defaultHistoryWeeks,
  }) : _clock = clock ?? DateTime.now {
    if (historyWeeks < 0) {
      throw ArgumentError.value(historyWeeks, 'historyWeeks', 'must be >= 0');
    }
  }

  /// Enough weeks to climb from Bronze to Diamond, while keeping reads low.
  static const defaultHistoryWeeks = 6;

  final StatsRepository _stats;
  final FriendsRepository _friends;
  final DateTime Function() _clock;

  /// How many finished weeks to replay.
  final int historyWeeks;

  Future<LeagueStanding> standing() async {
    final now = _clock();
    final meId = (await _friends.currentUser()).id;
    // Oldest week first; the last one is this week.
    final weeks = [
      for (var ago = historyWeeks; ago >= 0; ago--)
        DateTime(now.year, now.month, now.day - 7 * ago),
    ];
    final boards = await Future.wait([
      for (final week in weeks) _stats.xpLeaderboard(weekOf: week),
    ]);
    final finishedBoards = boards.take(historyWeeks).toList();
    final moves = [for (final b in finishedBoards) _moveFor(b, meId)];
    final league = leagueAfter(moves);
    final playedBefore = finishedBoards.any((b) => _entryFor(b, meId) != null);

    final current = boards.last;
    final mine = _entryFor(current, meId);
    return LeagueStanding(
      league: league,
      rank: mine?.rank,
      groupSize: current.length,
      zone: mine == null
          ? LeagueMove.stay
          : zoneFor(
              rank: mine.rank,
              groupSize: current.length,
              xp: mine.value.round(),
              league: league,
            ),
      lastWeek: playedBefore ? moves.last : null,
    );
  }

  static LeaderboardEntry? _entryFor(
    List<LeaderboardEntry> board,
    String meId,
  ) => board.where((e) => e.user.id == meId).firstOrNull;

  static LeagueMove _moveFor(List<LeaderboardEntry> board, String meId) {
    final mine = _entryFor(board, meId);
    if (mine == null) return LeagueMove.stay;
    return weekOutcome(
      rank: mine.rank,
      groupSize: board.length,
      xp: mine.value.round(),
    );
  }
}
