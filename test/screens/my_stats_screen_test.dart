import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life360/app_services.dart';
import 'package:life360/data/health/fake_health_source.dart';
import 'package:life360/data/health/health_source.dart';
import 'package:life360/data/health_stats_repository.dart';
import 'package:life360/data/mock_friends_repository.dart';
import 'package:life360/data/mock_stats_repository.dart';
import 'package:life360/models/models.dart';
import 'package:life360/screens/my_stats_screen.dart';
import 'package:life360/theme/app_theme.dart';

void main() {
  late MockFriendsRepository friends;
  late String me;

  setUp(() async {
    friends = MockFriendsRepository();
    me = (await friends.currentUser()).id;
  });

  FakeHealthSource sourceWith({
    String displayName = 'Health Connect',
    HealthAvailability availability = HealthAvailability.available,
    Map<StatMetric, HealthPermissionStatus>? permissions,
  }) => FakeHealthSource(
    displayName: displayName,
    availabilityResult: availability,
    permissionOutcome: permissions,
    stats: [
      DailyStats(
        userId: me,
        date: DateTime.now(),
        steps: 4321,
        sleepMinutes: 450,
        workoutMinutes: 40,
        activeCalories: 300,
        screenTimeMinutes: 0,
      ),
    ],
  );

  Future<void> pumpScreen(WidgetTester tester, FakeHealthSource source) async {
    tester.view.physicalSize = const Size(1170, 2900);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final services = AppServices(
      friends: friends,
      stats: HealthStatsRepository(
        source: source,
        fallback: MockStatsRepository(friends: friends),
        friends: friends,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MyStatsScreen(services: services),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('offers to connect the platform source by name', (tester) async {
    await pumpScreen(tester, sourceWith(displayName: 'Apple Health'));
    expect(find.text('Connect Apple Health'), findsOneWidget);
    expect(find.text('Showing demo data'), findsOneWidget);
  });

  testWidgets('connecting syncs real stats and offers Sync now', (
    tester,
  ) async {
    final source = sourceWith();
    await pumpScreen(tester, source);
    await tap(tester, 'connect-button');

    expect(source.requestPermissionsCalls, 1);
    expect(find.text('Health Connect connected'), findsOneWidget);
    expect(find.textContaining('Synced at'), findsOneWidget);
    // Today and This week show the same single day.
    expect(find.text('4321 steps'), findsNWidgets(2));
    expect(find.text('Sync now'), findsOneWidget);

    await tap(tester, 'connect-button');
    expect(source.requestPermissionsCalls, 2);
  });

  testWidgets('denied metrics show No access instead of 0', (tester) async {
    await pumpScreen(
      tester,
      sourceWith(
        permissions: {
          StatMetric.steps: HealthPermissionStatus.granted,
          StatMetric.sleep: HealthPermissionStatus.denied,
          StatMetric.workout: HealthPermissionStatus.granted,
          StatMetric.calories: HealthPermissionStatus.granted,
        },
      ),
    );
    await tap(tester, 'connect-button');

    expect(find.textContaining('Sleep not allowed'), findsOneWidget);
    // Sleep appears in both Today and This week.
    expect(find.text('No access'), findsNWidgets(2));
    // Today and This week show the same single day.
    expect(find.text('4321 steps'), findsNWidgets(2));
    expect(find.text('0h 0m'), findsNothing);
  });

  testWidgets('all permissions denied explains how to retry', (tester) async {
    await pumpScreen(
      tester,
      sourceWith(
        permissions: {
          for (final m in StatMetric.values) m: HealthPermissionStatus.denied,
        },
      ),
    );
    await tap(tester, 'connect-button');

    expect(find.text('No access to Health Connect'), findsOneWidget);
    expect(find.text('Connect Health Connect'), findsOneWidget);
    expect(find.text('Showing demo data'), findsNothing);
  });

  testWidgets('missing Health Connect offers install and retry', (
    tester,
  ) async {
    final source = sourceWith(availability: HealthAvailability.notInstalled);
    await pumpScreen(tester, source);
    await tap(tester, 'connect-button');

    expect(find.text('Health Connect is not installed'), findsOneWidget);
    expect(source.requestPermissionsCalls, 0);

    await tap(tester, 'install-button');
    expect(source.openInstallPageCalls, 1);

    // Installed now: Try again connects.
    source.availabilityResult = HealthAvailability.available;
    await tap(tester, 'connect-button');
    expect(find.text('Health Connect connected'), findsOneWidget);
  });

  testWidgets('outdated Health Connect offers an update', (tester) async {
    await pumpScreen(
      tester,
      sourceWith(availability: HealthAvailability.updateRequired),
    );
    await tap(tester, 'connect-button');
    expect(find.text('Health Connect needs an update'), findsOneWidget);
    expect(find.text('Update Health Connect'), findsOneWidget);
  });

  testWidgets('unsupported platform shows no connect button', (tester) async {
    await pumpScreen(
      tester,
      sourceWith(availability: HealthAvailability.unsupported),
    );
    await tap(tester, 'connect-button');
    expect(find.text('Health Connect is not available'), findsOneWidget);
    expect(find.byKey(const ValueKey('connect-button')), findsNothing);
  });
}
