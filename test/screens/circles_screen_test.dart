import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life360/data/mock_circle_repository.dart';
import 'package:life360/data/mock_friends_repository.dart';
import 'package:life360/data/mock_stats_repository.dart';
import 'package:life360/screens/circles_screen.dart';
import 'package:life360/theme/app_theme.dart';

void main() {
  // A Wednesday afternoon.
  final now = DateTime(2026, 11, 4, 15);
  DateTime clock() => now;

  late MockFriendsRepository friends;
  late MockStatsRepository stats;
  late MockCircleRepository circles;

  setUp(() {
    friends = MockFriendsRepository(clock: clock);
    stats = MockStatsRepository(friends: friends, clock: clock);
    circles = MockCircleRepository();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: CirclesScreen(
          circles: circles,
          friends: friends,
          stats: stats,
          clock: clock,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists my circles with type and member count', (tester) async {
    await pumpScreen(tester);

    final gym = find.byKey(const ValueKey('circle-c_gym'));
    expect(find.descendant(of: gym, matching: find.text('Gym crew')), findsOne);
    expect(
      find.descendant(of: gym, matching: find.text('Friends · 4 members')),
      findsOneWidget,
    );
    final dorm = find.byKey(const ValueKey('circle-c_dorm'));
    expect(
      find.descendant(of: dorm, matching: find.text('Team · 3 members')),
      findsOneWidget,
    );
    // Someone else's circle isn't listed until I join it.
    expect(find.byKey(const ValueKey('circle-c_fam')), findsNothing);
  });

  testWidgets('create sheet needs a name, then adds the circle', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('create-circle-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('create-save-button')));
    await tester.pumpAndSettle();
    expect(find.text('Give the circle a name.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('circle-name-field')),
      'Study buddies',
    );
    await tester.tap(find.byKey(const ValueKey('type-couple')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('create-save-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('create-save-button')), findsNothing);
    expect(find.text('Study buddies'), findsOneWidget);
    expect(find.text('Couple · 1 member'), findsOneWidget);
  });

  testWidgets('join by code shows the error inline, then joins', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.enterText(
      find.byKey(const ValueKey('join-code-field')),
      'nope00',
    );
    await tester.tap(find.byKey(const ValueKey('join-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('join-error')), findsOneWidget);
    expect(find.text('No circle has that code.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('join-code-field')),
      'fam777',
    );
    await tester.tap(find.byKey(const ValueKey('join-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('join-error')), findsNothing);
    expect(find.byKey(const ValueKey('circle-c_fam')), findsOneWidget);
  });

  testWidgets('tapping a circle opens its detail page', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('circle-c_dorm')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reward-banner')), findsOneWidget);
    expect(find.text('Leave circle'), findsOneWidget);
  });

  testWidgets('empty list nudges to create or join', (tester) async {
    circles = MockCircleRepository(seed: const []);
    await pumpScreen(tester);
    expect(find.byKey(const ValueKey('circles-empty')), findsOneWidget);
  });
}
