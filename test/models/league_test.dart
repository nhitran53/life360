import 'package:flutter_test/flutter_test.dart';
import 'package:life360/models/models.dart';

void main() {
  group('weekOutcome', () {
    test('promotes the top third of the group', () {
      expect(weekOutcome(rank: 1, groupSize: 6, xp: 500), LeagueMove.up);
      expect(weekOutcome(rank: 2, groupSize: 6, xp: 400), LeagueMove.up);
      expect(weekOutcome(rank: 3, groupSize: 6, xp: 300), LeagueMove.stay);
    });

    test('demotes the bottom third once there are 3 or more people', () {
      expect(weekOutcome(rank: 5, groupSize: 6, xp: 50), LeagueMove.down);
      expect(weekOutcome(rank: 4, groupSize: 6, xp: 80), LeagueMove.stay);
      expect(weekOutcome(rank: 3, groupSize: 3, xp: 10), LeagueMove.down);
    });

    test('in a pair the winner moves up and nobody moves down', () {
      expect(weekOutcome(rank: 1, groupSize: 2, xp: 100), LeagueMove.up);
      expect(weekOutcome(rank: 2, groupSize: 2, xp: 50), LeagueMove.stay);
    });

    test('nobody moves when you compete alone', () {
      expect(weekOutcome(rank: 1, groupSize: 1, xp: 900), LeagueMove.stay);
    });

    test('a week with no XP never promotes or demotes', () {
      expect(weekOutcome(rank: 1, groupSize: 4, xp: 0), LeagueMove.stay);
      expect(weekOutcome(rank: 4, groupSize: 4, xp: 0), LeagueMove.stay);
    });

    test('rejects ranks outside the group', () {
      expect(
        () => weekOutcome(rank: 0, groupSize: 3, xp: 10),
        throwsArgumentError,
      );
      expect(
        () => weekOutcome(rank: 4, groupSize: 3, xp: 10),
        throwsArgumentError,
      );
    });
  });

  group('League', () {
    test('starts in Bronze and moves one tier at a time', () {
      expect(League.start, League.bronze);
      expect(League.bronze.after(LeagueMove.up), League.silver);
      expect(League.gold.after(LeagueMove.down), League.silver);
      expect(League.silver.after(LeagueMove.stay), League.silver);
    });

    test('cannot move past the top or bottom tier', () {
      expect(League.diamond.after(LeagueMove.up), League.diamond);
      expect(League.bronze.after(LeagueMove.down), League.bronze);
      expect(League.diamond.isTop, isTrue);
      expect(League.bronze.isBottom, isTrue);
    });

    test('replaying finished weeks gives the current league', () {
      final league = leagueAfter(const [
        LeagueMove.up,
        LeagueMove.up,
        LeagueMove.stay,
        LeagueMove.down,
        LeagueMove.up,
      ]);
      expect(league, League.gold);
    });
  });

  group('zoneFor', () {
    test('flags the promotion and demotion zones for this week', () {
      expect(zoneFor(rank: 1, groupSize: 6, xp: 10), LeagueMove.up);
      expect(zoneFor(rank: 6, groupSize: 6, xp: 10), LeagueMove.down);
    });

    test('at the top or bottom tier that edge zone is just safe', () {
      expect(
        zoneFor(rank: 1, groupSize: 6, xp: 10, league: League.diamond),
        LeagueMove.stay,
      );
      expect(
        zoneFor(rank: 6, groupSize: 6, xp: 10, league: League.bronze),
        LeagueMove.stay,
      );
    });
  });
}
