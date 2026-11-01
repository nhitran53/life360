// Widget tests for the Friend 360 home screen.
//
// Note: the home screen has animations that loop forever (background,
// floating emojis, button pulse), so we use tester.pump(duration) instead of
// tester.pumpAndSettle() — pumpAndSettle would wait forever and time out.

import 'package:flutter_test/flutter_test.dart';

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

  testWidgets('Tapping the button goes to the next page',
          (WidgetTester tester) async {
        await tester.pumpWidget(const Friend360App());
        await tester.pump(const Duration(seconds: 2));

        // Next page shouldn't be showing yet.
        expect(find.text('Next page coming soon 👀'), findsNothing);

        // Tap the button, then let the page transition play.
        await tester.tap(find.text('ENTER THE ARENA 🚀'));
        await tester.pump(); // start the navigation
        await tester.pump(const Duration(seconds: 1)); // finish the transition

        expect(find.text('Next page coming soon 👀'), findsOneWidget);
      });
}