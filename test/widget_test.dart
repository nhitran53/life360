// Widget tests for the Friend 360 home screen.
//
// The home screen intro plays once, but we still pump fixed durations so the
// tests don't depend on exactly how long it runs.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:life360/data/family_store.dart';
import 'package:life360/hub_screen.dart';
import 'package:life360/main.dart';
import 'package:life360/screens/circle_screen.dart';
import 'package:life360/screens/leaderboard_screen.dart';
import 'package:life360/screens/my_stats_screen.dart';
import 'package:life360/widgets/circle_widgets.dart';

/// A tall phone so whole Circle screens fit without scrolling.
void useTallPhone(WidgetTester tester) {
      tester.view.physicalSize = const Size(1170, 2900);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
}

void main() {
      testWidgets('Home screen shows logo, name, tagline and button',
              (WidgetTester tester) async {
                await tester.pumpWidget(const Friend360App());

                // Let the intro animation (ring sweep, "360" pop) finish.
                await tester.pump(const Duration(seconds: 2));

                expect(find.text('Friend 360'), findsOneWidget);
                expect(find.text('360'), findsOneWidget);
                expect(find.bySemanticsLabel('Friend 360 logo'), findsOneWidget);
                expect(find.textContaining('See who wins the week.'), findsOneWidget);
                expect(find.text("Let's go"), findsOneWidget);
          });

      testWidgets('Tapping the button goes to the circle home',
              (WidgetTester tester) async {
                await tester.pumpWidget(const Friend360App());
                await tester.pump(const Duration(seconds: 2));

                // Circle home shouldn't be showing yet.
                expect(find.text('Together today'), findsNothing);

                // Tap the button, then let the transition play.
                await tester.tap(find.text("Let's go"));
                await tester.pump(); // start the navigation
                await tester.pump(const Duration(seconds: 2));

                expect(find.text('Tran family'), findsOneWidget);
                expect(find.text('Together today'), findsOneWidget);
                expect(find.text('Circle'), findsOneWidget);
          });

      testWidgets('Circle home shows totals and members',
              (WidgetTester tester) async {
                useTallPhone(tester);

                await tester.pumpWidget(const MaterialApp(home: CircleScreen()));
                await tester.pump();

                expect(find.text('38,412'), findsOneWidget);
                expect(find.text('Goal 50,000'), findsOneWidget);
                expect(find.text('steps · 77%'), findsOneWidget);
                expect(find.text('Mom'), findsOneWidget);
                expect(find.text('Dad'), findsOneWidget);
                expect(find.text('Bao'), findsOneWidget);
                expect(find.text('78 bpm'), findsOneWidget);
                expect(find.text('Live · synced 1 min ago'), findsOneWidget);
          });

      testWidgets('Circle home links to My Stats with the connect button',
              (WidgetTester tester) async {
                useTallPhone(tester);

                await tester.pumpWidget(const MaterialApp(home: CircleScreen()));
                await tester.pump();
                await tester.tap(find.text('My stats and health sync'));
                await tester.pump();
                await tester.pump(const Duration(milliseconds: 500));

                expect(find.byType(MyStatsScreen), findsOneWidget);
                expect(find.byKey(const ValueKey('connect-button')), findsOneWidget);
          });

      testWidgets('Nudging Dad opens the nudge tab and sends',
              (WidgetTester tester) async {
                useTallPhone(tester);

                await tester.pumpWidget(const MaterialApp(home: CircleScreen()));
                await tester.pump();

                await tester.tap(find.text('Nudge'));
                await tester.pump();

                expect(find.text('Send a nudge'), findsOneWidget);
                expect(find.text('Dad has been idle for 3 hours · 3,105 steps today'),
                    findsOneWidget);

                await tester.ensureVisible(find.text('Send to Dad'));
                await tester.tap(find.text('Send to Dad'));
                await tester.pump();

                expect(find.text('Nudge sent to Dad 👋'), findsOneWidget);
          });

      testWidgets('Tapping a member opens their detail page',
              (WidgetTester tester) async {
                useTallPhone(tester);

                await tester.pumpWidget(const MaterialApp(home: CircleScreen()));
                await tester.pump();

                await tester.tap(find.text('Walking · now'));
                await tester.pumpAndSettle();

                expect(find.text('Shares heart rate, steps & sleep'), findsOneWidget);
                expect(find.text('bpm · walking'), findsOneWidget);
                expect(find.text('Steps this week'), findsOneWidget);
                expect(find.text('54,130'), findsOneWidget);
                expect(find.text('Cheer her on'), findsOneWidget);

                // "Send a note" goes back and starts a nudge to Mom.
                await tester.ensureVisible(find.text('Send a note'));
                await tester.tap(find.text('Send a note'));
                await tester.pumpAndSettle();

                expect(find.text('Send to Mom'), findsOneWidget);
          });

      testWidgets('Nudge screen picks recipients and quick notes',
              (WidgetTester tester) async {
                useTallPhone(tester);

                await tester.pumpWidget(const MaterialApp(
                    home: CircleScreen(initialTab: CircleTab.nudges)));
                await tester.pump();

                expect(find.text('Send to Dad'), findsOneWidget);

                await tester.ensureVisible(find.text('Linh'));
                await tester.tap(find.text('Linh'));
                await tester.pump();
                expect(find.text('Send to Linh'), findsOneWidget);

                await tester.ensureVisible(find.text('Join me for a walk at 6 tonight?'));
                await tester.tap(find.text('Join me for a walk at 6 tonight?'));
                await tester.pump();
                final note = tester.widget<TextField>(find.byType(TextField));
                expect(note.controller!.text, 'Join me for a walk at 6 tonight?');
          });

      testWidgets('Privacy screen keeps sleep private and toggles sharing',
              (WidgetTester tester) async {
                useTallPhone(tester);

                await tester.pumpWidget(const MaterialApp(
                    home: CircleScreen(initialTab: CircleTab.privacy)));
                await tester.pump();

                Finder switches(String state) => find.byWidgetPredicate(
                        (w) => w is CircleSvg && w.name == 'switch_$state');

                expect(find.text('Sharing & privacy'), findsOneWidget);
                // Steps, workouts and calories on; sleep and screen time
                // private by default.
                expect(switches('on'), findsNWidgets(3));
                expect(switches('off'), findsNWidgets(2));

                await tester.ensureVisible(find.text('Sleep'));
                await tester.tap(find.text('Sleep'));
                await tester.pump();
                expect(switches('on'), findsNWidgets(4));
                expect(switches('off'), findsOneWidget);

                await tester.ensureVisible(find.text('Pause for 24 h'));
                await tester.tap(find.text('Pause for 24 h'));
                await tester.pump();
                expect(find.text('Paused: friends see none of your stats for now 🔒'),
                    findsOneWidget);
                expect(find.text('Resume sharing'), findsOneWidget);
          });

      testWidgets('Family button creates a new family and switches back',
              (WidgetTester tester) async {
                useTallPhone(tester);

                await tester.pumpWidget(
                    MaterialApp(home: CircleScreen(familyStore: FamilyStore())));
                await tester.pump();

                // Open the switcher from the header.
                await tester.tap(find.text('Tran family'));
                await tester.pumpAndSettle();
                expect(find.text('Your families'), findsOneWidget);
                expect(find.text('5 members'), findsOneWidget);

                // Create "Roommates".
                await tester.tap(find.text('Create a new family'));
                await tester.pumpAndSettle();
                expect(find.text('New family'), findsOneWidget);

                await tester.enterText(
                      find.descendant(
                          of: find.byType(Dialog), matching: find.byType(TextField)),
                      'Roommates',
                );
                await tester.tap(find.text('Create'));
                await tester.pumpAndSettle();

                // The Circle home now shows the new, empty family.
                expect(find.text('Roommates'), findsOneWidget);
                expect(find.text('Tran family'), findsNothing);
                expect(find.text('Mom'), findsNothing);
                expect(find.text('Just you so far'), findsOneWidget);
                expect(find.text('10,527'), findsOneWidget);
                expect(find.text('Goal 10,000'), findsOneWidget);

                // Switch back to the Tran family.
                await tester.tap(find.text('Roommates'));
                await tester.pumpAndSettle();
                await tester.tap(find.text('Tran family'));
                await tester.pumpAndSettle();

                expect(find.text('Tran family'), findsOneWidget);
                expect(find.text('Mom'), findsOneWidget);
                expect(find.text('38,412'), findsOneWidget);
          });

      testWidgets('New family needs a name that is not already taken',
              (WidgetTester tester) async {
                useTallPhone(tester);

                await tester.pumpWidget(
                    MaterialApp(home: CircleScreen(familyStore: FamilyStore())));
                await tester.pump();

                await tester.tap(find.text('Tran family'));
                await tester.pumpAndSettle();
                await tester.tap(find.text('Create a new family'));
                await tester.pumpAndSettle();

                final nameField = find.descendant(
                    of: find.byType(Dialog), matching: find.byType(TextField));

                await tester.tap(find.text('Create'));
                await tester.pump();
                expect(find.text('Give your family a name'), findsOneWidget);

                await tester.enterText(nameField, 'tran FAMILY');
                await tester.tap(find.text('Create'));
                await tester.pump();
                expect(find.text('You already have a family called "tran FAMILY"'),
                    findsOneWidget);

                // Cancel leaves everything as it was.
                await tester.tap(find.text('Cancel'));
                await tester.pumpAndSettle();
                expect(find.text('Tran family'), findsOneWidget);
                expect(find.text('Mom'), findsOneWidget);
          });

      testWidgets('Ranks opens the leaderboard for the family you are viewing',
              (WidgetTester tester) async {
                useTallPhone(tester);

                await tester.pumpWidget(
                    MaterialApp(home: CircleScreen(familyStore: FamilyStore())));
                await tester.pump();

                // Tran family first: family members are on the board.
                await tester.tap(find.text('Ranks'));
                await tester.pumpAndSettle();
                expect(find.byType(LeaderboardScreen), findsOneWidget);
                expect(find.text('Tran family'), findsOneWidget);
                expect(find.text('Alex'), findsNothing);

                // Back to the Circle, create a new family, then check its board.
                await tester.pageBack();
                await tester.pumpAndSettle();
                await tester.tap(find.text('Tran family'));
                await tester.pumpAndSettle();
                await tester.tap(find.text('Create a new family'));
                await tester.pumpAndSettle();
                await tester.enterText(
                      find.descendant(
                          of: find.byType(Dialog), matching: find.byType(TextField)),
                      'Roommates',
                );
                await tester.tap(find.text('Create'));
                await tester.pumpAndSettle();

                await tester.tap(find.text('Ranks'));
                await tester.pumpAndSettle();
                expect(find.textContaining("It's just you in Roommates"),
                    findsOneWidget);

                // The new family is in the leaderboard's picker too.
                await tester.tap(find.text('Roommates'));
                await tester.pumpAndSettle();
                expect(find.text('Whose leaderboard?'), findsOneWidget);
                expect(find.text('Tran family'), findsOneWidget);
                expect(find.text('All friends'), findsOneWidget);
          });

      testWidgets("Friends' Stats hub card opens the coming soon page",
              (WidgetTester tester) async {
                await tester.pumpWidget(const MaterialApp(home: HubScreen()));
                await tester.pump(const Duration(seconds: 2));

                await tester.tap(find.text("Friends' Stats"));
                await tester.pump();
                await tester.pump(const Duration(seconds: 1));

                expect(find.text('Coming soon 👀'), findsOneWidget);
          });

      testWidgets('My Stats hub card opens the My Stats screen',
              (WidgetTester tester) async {
                await tester.pumpWidget(const MaterialApp(home: HubScreen()));
                await tester.tap(find.text('My Stats'));
                await tester.pumpAndSettle();

                expect(find.byType(MyStatsScreen), findsOneWidget);
                expect(find.text('Coming soon 👀'), findsNothing);
          });

      testWidgets('Ranks tab on the circle home opens the leaderboard',
              (WidgetTester tester) async {
                tester.view.physicalSize = const Size(1170, 2532);
                tester.view.devicePixelRatio = 3.0;
                addTearDown(tester.view.reset);

                await tester.pumpWidget(const MaterialApp(home: CircleScreen()));
                await tester.tap(find.text('Ranks'));
                await tester.pumpAndSettle();

                expect(find.byType(LeaderboardScreen), findsOneWidget);
                expect(find.text('This week'), findsOneWidget);
          });

      testWidgets('Leaderboard hub card opens the leaderboard',
              (WidgetTester tester) async {
                await tester.pumpWidget(const MaterialApp(home: HubScreen()));
                await tester.tap(find.text('Leaderboard'));
                await tester.pumpAndSettle();

                expect(find.byType(LeaderboardScreen), findsOneWidget);
          });

      testWidgets('Hub shows all three destinations',
              (WidgetTester tester) async {
                await tester.pumpWidget(const MaterialApp(home: HubScreen()));
                await tester.pump();

                expect(find.text('My Stats'), findsOneWidget);
                expect(find.text("Friends' Stats"), findsOneWidget);
                expect(find.text('Leaderboard'), findsOneWidget);
          });
}