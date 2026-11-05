import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life360/models/stat_metric.dart';
import 'package:life360/theme/app_colors.dart';
import 'package:life360/theme/stat_colors.dart';
import 'package:life360/widgets/chunky.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: SizedBox(width: 300, child: child))),
    );

void main() {
  testWidgets('ChunkyButton calls onPressed when tapped', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
        _wrap(ChunkyButton(label: 'Go', onPressed: () => taps++)));

    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();

    expect(taps, 1);
  });

  testWidgets('ChunkyButton keeps its height while pressed', (tester) async {
    await tester.pumpWidget(_wrap(ChunkyButton(label: 'Go', onPressed: () {})));
    final before = tester.getSize(find.byType(ChunkyButton));

    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Go')));
    await tester.pumpAndSettle();
    final textWhilePressed = tester.getCenter(find.text('Go'));
    expect(tester.getSize(find.byType(ChunkyButton)), before);

    await gesture.up();
    await tester.pumpAndSettle();
    // The face slid down while pressed and comes back up after release.
    expect(tester.getCenter(find.text('Go')).dy, lessThan(textWhilePressed.dy));
    expect(tester.getSize(find.byType(ChunkyButton)), before);
  });

  testWidgets('A disabled ChunkyButton does nothing', (tester) async {
    await tester.pumpWidget(_wrap(const ChunkyButton(label: 'Nope', onPressed: null)));
    await tester.tap(find.text('Nope'));
    await tester.pump();
    // No exception and no press state to settle.
    expect(find.text('Nope'), findsOneWidget);
  });

  testWidgets('ChunkyCard with onTap is announced as a button', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(ChunkyCard(
      onTap: () {},
      semanticLabel: 'Open stats',
      child: const Text('Stats'),
    )));

    expect(
      tester.getSemantics(find.bySemanticsLabel('Open stats')),
      matchesSemantics(
        isButton: true,
        hasTapAction: true,
        label: 'Open stats',
      ),
    );
    handle.dispose();
  });

  test('every stat has its own color', () {
    final colors = StatMetric.values.map((m) => m.color).toSet();
    expect(colors.length, StatMetric.values.length);
    expect(StatMetric.sleep.color, AppColors.blue);
    expect(StatMetric.screenTime.color, AppColors.purple);
    expect(StatMetric.workout.color, AppColors.orange);
    expect(StatMetric.steps.color, AppColors.primary);
  });
}
