// Widget tests for the Friend 360 home screen.
//
// Note: the home screen has animations that loop forever (background,
// floating emojis, button pulse), so we use tester.pump(duration) instead of
// tester.pumpAndSettle() — pumpAndSettle would wait forever and time out.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:life360/hub_screen.dart';
import 'package:life360/main.dart';
import 'package:life360/screens/circle_screen.dart';

void main() {
  testWidgets('Home screen shows title, tagline, and button',
          (WidgetTester tester) async {
        await tester.pumpWidget(const Friend360App());

        // Let the intro animations (title bounce, fade-ins) finish.
        await tester.pump(const Duration(seconds: 2));

        expect(find.text('Friend'), findsOneWidget);
        expect(find.text('360'), findsOneWidget);
        expect(find.text('Sleep. Sweat. Compete. 🏆'), findsOneWidget);
        expect(find.text('ENTER THE ARENA 🚀'), findsOneWidget);
      });

  testWidgets('Tapping the button goes to the circle home',
          (WidgetTester tester) async {
        await tester.pumpWidget(const Friend360App());
        await tester.pump(const Duration(seconds: 2));

        // Circle home shouldn't be showing yet.
        expect(find.text('Together today'), findsNothing);

        // Tap the button, then let the transition play.
        await tester.tap(find.text('ENTER THE ARENA 🚀'));
        await tester.pump(); // start the navigation
        await tester.pump(const Duration(seconds: 2));

        expect(find.text('Tran family'), findsOneWidget);
        expect(find.text('Together today'), findsOneWidget);
        expect(find.text('Circle'), findsOneWidget);
      });

  testWidgets('Circle home shows totals and members',
          (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.reset);

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

  testWidgets('Nudging Dad shows a confirmation',
          (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(const MaterialApp(home: CircleScreen()));
        await tester.pump();

        await tester.tap(find.text('Nudge'));
        await tester.pump();

        expect(find.text('Nudge sent to Dad 👋'), findsOneWidget);
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
}