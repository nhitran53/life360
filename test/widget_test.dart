// Widget tests for the Friend 360 home screen.
//
// The home screen intro plays once, but we still pump fixed durations so the
// tests don't depend on exactly how long it runs.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:life360/data/health_source.dart';
import 'package:life360/data/health_sync.dart';
import 'package:life360/data/mock_health_source.dart';
import 'package:life360/hub_screen.dart';
import 'package:life360/models/models.dart';
import 'package:life360/main.dart';
import 'package:life360/screens/circle_screen.dart';
import 'package:life360/screens/leaderboard_screen.dart';
import 'package:life360/widgets/circle_widgets.dart';

/// A tall phone so whole Circle screens fit without scrolling.
void useTallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2900);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

/// A Circle screen with a fake health hub above it.
Widget circleWithHealth(HealthSync sync,
        {CircleTab initialTab = CircleTab.circle}) =>
    HealthScope(
      sync: sync,
      child: MaterialApp(home: CircleScreen(initialTab: initialTab)),
    );

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
        // Heart rate, steps and active minutes on; sleep private.
        expect(switches('on'), findsNWidgets(3));
        expect(switches('off'), findsOneWidget);

        await tester.ensureVisible(find.text('Sleep'));
        await tester.tap(find.text('Sleep'));
        await tester.pump();
        expect(switches('on'), findsNWidgets(4));
        expect(switches('off'), findsNothing);

        await tester.ensureVisible(find.text('Pause for 24 h'));
        await tester.tap(find.text('Pause for 24 h'));
        await tester.pump();
        expect(find.text('Resume sharing'), findsOneWidget);
      });

  testWidgets('Tapping a hub card opens its page',
          (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(home: HubScreen()));
        await tester.pump(const Duration(seconds: 2));

        await tester.tap(find.text('My Stats'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('Coming soon 👀'), findsOneWidget);
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

  testWidgets('Circle home invites you to connect, then shows your stats',
          (WidgetTester tester) async {
        useTallPhone(tester);
        final today = dateOnly(DateTime.now());
        final sync = HealthSync(
          MockHealthSource(days: {
            today: DailyStats(
              userId: 'u_me',
              date: today,
              steps: 6120,
              workoutMinutes: 34,
              sleepMinutes: 7 * 60 + 5,
            ),
          }),
          userId: 'u_me',
        );
        addTearDown(sync.dispose);
        await tester.runAsync(sync.start);

        await tester.pumpWidget(circleWithHealth(sync));
        expect(find.text('Bring your watch in'), findsOneWidget);
        expect(find.text('Sync from Apple Health'), findsOneWidget);

        await tester.ensureVisible(find.text('Connect'));
        await tester.runAsync(() async {
          await tester.tap(find.text('Connect'));
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pump();

        expect(find.text('You · today'), findsOneWidget);
        expect(find.text('6,120'), findsOneWidget);
        expect(find.text('34'), findsOneWidget);
        expect(find.text('7h 5m'), findsOneWidget);
        expect(find.text('Apple Health · synced just now'), findsOneWidget);
      });

  testWidgets('Circle home hides the health card without a health hub',
          (WidgetTester tester) async {
        useTallPhone(tester);
        await tester.pumpWidget(const MaterialApp(home: CircleScreen()));
        await tester.pump();

        expect(find.text('Bring your watch in'), findsNothing);
        expect(find.text('You · today'), findsNothing);
      });

  testWidgets('Privacy card connects and disconnects the health hub',
          (WidgetTester tester) async {
        useTallPhone(tester);
        final sync = HealthSync(
          MockHealthSource(name: 'Health Connect'),
          userId: 'u_me',
        );
        addTearDown(sync.dispose);
        await tester.runAsync(sync.start);

        await tester.pumpWidget(
            circleWithHealth(sync, initialTab: CircleTab.privacy));
        expect(find.text('Health Connect'), findsOneWidget);
        expect(find.text('Not connected · your watch syncs through it'),
            findsOneWidget);

        await tester.runAsync(() async {
          await tester.tap(find.text('Connect'));
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pump();
        expect(find.text('Connected · last sync just now'), findsOneWidget);
        expect(find.text('Sync'), findsOneWidget);

        await tester.ensureVisible(find.text('Disconnect'));
        await tester.runAsync(() async {
          await tester.tap(find.text('Disconnect'));
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pump();
        expect(sync.isConnected, isFalse);
        expect(find.text('Disconnected from Health Connect'), findsOneWidget);
      });

  testWidgets('Privacy card offers to install Health Connect',
          (WidgetTester tester) async {
        useTallPhone(tester);
        final source = MockHealthSource(
          name: 'Health Connect',
          initial: HealthConnection.needsInstall,
        );
        final sync = HealthSync(source, userId: 'u_me');
        addTearDown(sync.dispose);
        await tester.runAsync(sync.start);

        await tester.pumpWidget(
            circleWithHealth(sync, initialTab: CircleTab.privacy));
        expect(find.text('Install Health Connect to sync your watch'),
            findsOneWidget);

        await tester.tap(find.text('Install'));
        await tester.pump();
        expect(source.installCalls, 1);
      });
}
