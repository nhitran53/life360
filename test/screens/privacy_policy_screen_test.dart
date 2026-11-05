import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life360/main.dart';
import 'package:life360/screens/privacy_policy_screen.dart';

void main() {
  testWidgets('policy screen shows every section', (tester) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: PrivacyPolicyScreen()));
    for (final (title, _) in privacyPolicySections) {
      expect(find.text(title), findsOneWidget);
    }
  });

  testWidgets('the app registers the policy route', (tester) async {
    await tester.pumpWidget(const Friend360App());
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.routes!.containsKey(privacyPolicyRoute), isTrue);
  });

  test('PRIVACY.md has the same section headings as the screen', () {
    final md = File('PRIVACY.md').readAsStringSync();
    for (final (title, _) in privacyPolicySections) {
      expect(md, contains('## $title'));
    }
  });
}
