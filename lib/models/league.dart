/// Weekly leagues (issue #11).
///
/// Each finished Monday–Sunday week you're ranked by XP against your friends
/// (see `rankLeaderboardByXp`). The top third moves up a league, the bottom
/// third moves down, and everyone else stays. The new week starts from zero.
///
/// Leagues aren't stored anywhere: your current league is worked out by
/// replaying your recent finished weeks from [League.start]
/// (see [leagueAfter]), so it's always consistent with the leaderboard.
library;

/// The league tiers, lowest first.
enum League {
  bronze('Bronze', '🥉'),
  silver('Silver', '🥈'),
  gold('Gold', '🥇'),
  platinum('Platinum', '💠'),
  diamond('Diamond', '💎');

  const League(this.label, this.emoji);

  final String label;
  final String emoji;

  /// Where everyone starts.
  static const start = League.bronze;

  bool get isTop => this == League.values.last;
  bool get isBottom => this == League.values.first;

  /// The league after a week that ended with [move].
  League after(LeagueMove move) => switch (move) {
    LeagueMove.up when !isTop => League.values[index + 1],
    LeagueMove.down when !isBottom => League.values[index - 1],
    _ => this,
  };
}

/// What a week's result does to your league.
enum LeagueMove { up, stay, down }

/// How many people move up (and down) in a group of [groupSize].
int leagueZoneSize(int groupSize) => groupSize < 3 ? 1 : groupSize ~/ 3;

/// The move earned by finishing a week at [rank] (1-based, ties share a rank)
/// out of [groupSize] people with [xp] XP.
///
/// Nobody moves when competing alone or after a week with no XP, so a quiet
/// week never costs you a league. In a pair the winner moves up and the other
/// person stays.
LeagueMove weekOutcome({
  required int rank,
  required int groupSize,
  required int xp,
}) {
  if (rank < 1 || rank > groupSize) {
    throw ArgumentError('rank must be between 1 and groupSize.');
  }
  if (groupSize < 2 || xp <= 0) return LeagueMove.stay;
  final zone = leagueZoneSize(groupSize);
  if (rank <= zone) return LeagueMove.up;
  if (groupSize >= 3 && rank > groupSize - zone) return LeagueMove.down;
  return LeagueMove.stay;
}

/// Your league after the finished weeks in [moves], oldest first.
League leagueAfter(Iterable<LeagueMove> moves) =>
    moves.fold(League.start, (league, move) => league.after(move));

/// The zone you're in this week if it ended now. At the top (or bottom)
/// league there's nowhere further to go, so that edge reads as safe.
LeagueMove zoneFor({
  required int rank,
  required int groupSize,
  required int xp,
  League league = League.silver,
}) {
  final move = weekOutcome(rank: rank, groupSize: groupSize, xp: xp);
  return league.after(move) == league ? LeagueMove.stay : move;
}
