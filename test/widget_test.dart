// Widget tests for the Friend 360 home screen.
//
// Note: the home screen has animations that loop forever (background,
// floating emojis, button pulse), so we use tester.pump(duration) instead of
// tester.pumpAndSettle() — pumpAndSettle would wait forever and time out.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:life360/hub_screen.dart';
import 'package:life360/main.dart';

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

  testWidgets('Tapping the button goes to the hub',
          (WidgetTester tester) async {
        await tester.pumpWidget(const Friend360App());
        await tester.pump(const Duration(seconds: 2));

        // Hub shouldn't be showing yet.
        expect(find.text('THE HUB'), findsNothing);

        // Tap the button, then let the transition + hub intro play.
        await tester.tap(find.text('ENTER THE ARENA 🚀'));
        await tester.pump(); // start the navigation
        await tester.pump(const Duration(seconds: 2));

        expect(find.text('THE HUB'), findsOneWidget);
        expect(find.text('My Stats'), findsOneWidget);
        expect(find.text("Friends' Stats"), findsOneWidget);
        expect(find.text('Leaderboard'), findsOneWidget);
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