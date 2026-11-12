import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life360/data/league_service.dart';
import 'package:life360/models/models.dart';
import 'package:life360/theme/app_theme.dart';
import 'package:life360/widgets/league_card.dart';

void main() {
  Future<void> pumpCard(WidgetTester tester, LeagueStanding standing) =>
      tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: LeagueCard(standing: standing)),
        ),
      );

  testWidgets('shows the league name and the promotion zone', (tester) async {
    await pumpCard(
      tester,
      const LeagueStanding(
        league: League.silver,
        zone: LeagueMove.up,
        rank: 1,
        groupSize: 6,
      ),
    );

    expect(find.text('🥈 Silver League'), findsOneWidget);
    expect(find.textContaining('Gold'), findsOneWidget);
  });

  test('copy for each situation stays friendly', () {
    expect(
      leagueMessage(
        const LeagueStanding(
          league: League.gold,
          zone: LeagueMove.down,
          rank: 6,
          groupSize: 6,
        ),
      ),
      contains('drop zone'),
    );
    expect(
      leagueMessage(
        const LeagueStanding(
          league: League.gold,
          zone: LeagueMove.stay,
          rank: 3,
          groupSize: 6,
        ),
      ),
      contains('Top 2 move up'),
    );
    expect(
      leagueMessage(
        const LeagueStanding(
          league: League.bronze,
          zone: LeagueMove.stay,
          rank: 1,
          groupSize: 1,
        ),
      ),
      contains('Add friends'),
    );
    expect(
      leagueMessage(
        const LeagueStanding(
          league: League.bronze,
          zone: LeagueMove.stay,
          groupSize: 4,
        ),
      ),
      contains('sharing'),
    );
    expect(
      leagueMessage(
        const LeagueStanding(
          league: League.diamond,
          zone: LeagueMove.stay,
          rank: 1,
          groupSize: 6,
        ),
      ),
      contains('top league'),
    );
  });

  testWidgets("celebrates last week's promotion", (tester) async {
    await pumpCard(
      tester,
      const LeagueStanding(
        league: League.gold,
        zone: LeagueMove.stay,
        rank: 3,
        groupSize: 6,
        lastWeek: LeagueMove.up,
      ),
    );

    expect(find.byKey(const ValueKey('league-last-week')), findsOneWidget);
    expect(find.textContaining('Promoted'), findsOneWidget);
  });
}
