import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life360/hub_screen.dart';
import 'package:life360/screens/circles_screen.dart';

void main() {
  testWidgets('Circles hub card opens the circles screen', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: HubScreen()));

    await tester.tap(find.text('Circles'));
    await tester.pumpAndSettle();

    expect(find.byType(CirclesScreen), findsOneWidget);
    expect(find.text('Gym crew'), findsOneWidget);
  });
}
