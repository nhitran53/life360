import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life360/app_services.dart';
import 'package:life360/data/account_session.dart';
import 'package:life360/data/mock_auth_repository.dart';
import 'package:life360/data/mock_profile_repository.dart';
import 'package:life360/data/sharing_repository.dart';
import 'package:life360/models/models.dart';
import 'package:life360/screens/auth_gate.dart';
import 'package:life360/screens/circle_screen.dart';
import 'package:life360/screens/privacy_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Settings that never load, so StatsSync keeps retrying; counts the retries.
class _NeverLoadedSharing extends ChangeNotifier implements SharingRepository {
  var refreshes = 0;

  bool get listened => hasListeners;

  var settingsReads = 0;

  @override
  bool get isLoaded => false;

  @override
  Future<void> refresh() async => refreshes++;

  @override
  SharingSettings settingsFor(String userId) {
    settingsReads++;
    return const SharingSettings();
  }

  @override
  Future<void> update(String userId, SharingSettings settings) async {}
}

void main() {
  late MockAuthRepository auth;
  late AccountSession session;
  late List<_NeverLoadedSharing> sharings;
  late List<AppServices> made;

  AppServices makeServices(AccountSession s) {
    final services = AppServices.defaults(
      friends: s.friends,
      sharing: s.sharing,
      statsDb: s.statsDb,
      userId: s.profile?.id,
    );
    made.add(services);
    return services;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// Called inside the test body so the session's auth subscription runs in
  /// the test's fake-async zone.
  void createSession() {
    auth = MockAuthRepository();
    sharings = [];
    made = [];
    session = AccountSession(
      auth: auth,
      profiles: MockProfileRepository(),
      sharingFor: (_) {
        final sharing = _NeverLoadedSharing();
        sharings.add(sharing);
        return sharing;
      },
      statsDb: FakeFirebaseFirestore(),
    );
  }

  /// Tests default to Android, which would use the real Health Connect
  /// plugin; the override must be reset before the test ends.
  void testOnLinux(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      tester.view.physicalSize = const Size(1170, 2900);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      try {
        await body(tester);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  Widget app() => MaterialApp(
    home: AccountScope(
      session: session,
      child: AuthGate(
        welcome: const Text('welcome'),
        createServices: makeServices,
      ),
    ),
  );

  Future<void> signIn(WidgetTester tester) async {
    createSession();
    await tester.pumpWidget(app());
    await tester.pump(const Duration(seconds: 2));
    await auth.signUpWithEmail('nhi@example.com', 'password1');
    await tester.pump();
    await session.completeOnboarding(
      displayName: 'Nhi',
      username: 'nhi',
      avatarEmoji: '🦊',
      goals: const DailyGoals(),
    );
    await tester.pump();
  }

  testOnLinux('rebuilding without a status change makes services once', (
    tester,
  ) async {
    await signIn(tester);
    expect(made, hasLength(1));

    for (var i = 0; i < 3; i++) {
      tester.element(find.byType(AuthGate)).markNeedsBuild();
      await tester.pump();
      await tester.pumpWidget(app());
    }

    expect(made, hasLength(1));
    expect(made.single.isDisposed, isFalse);
    final screen = tester.widget<CircleScreen>(find.byType(CircleScreen));
    expect(screen.services, same(made.single));

    await tester.pumpWidget(const SizedBox());
    expect(made.single.isDisposed, isTrue);
    addTearDown(() {
      session.dispose();
      auth.dispose();
    });
  });

  testOnLinux('signing out disposes services and detaches from sharing', (
    tester,
  ) async {
    await signIn(tester);
    addTearDown(() {
      session.dispose();
      auth.dispose();
    });

    expect(sharings.single.listened, isTrue);
    await tester.pump(const Duration(seconds: 6));
    expect(sharings.single.refreshes, greaterThan(0));

    await session.signOut();
    await tester.pump();
    await tester.pump();

    expect(made.single.isDisposed, isTrue);
    expect(sharings.single.listened, isFalse);
    final atSignOut = sharings.single.refreshes;
    await tester.pump(const Duration(minutes: 10));
    expect(sharings.single.refreshes, atSignOut);

    await auth.signInWithEmail('nhi@example.com', 'password1');
    await tester.pump();
    await tester.pump();
    expect(made, hasLength(2));
    expect(made.last.isDisposed, isFalse);
  });

  testOnLinux('signing out and back in before a frame rebuilds the screen', (
    tester,
  ) async {
    await signIn(tester);
    addTearDown(() {
      session.dispose();
      auth.dispose();
    });
    expect(find.byType(PrivacyScreen, skipOffstage: false), findsOneWidget);
    final first = sharings.single;
    expect(first.settingsReads, greaterThan(0));

    // Out and in as the same user without a frame in between.
    await session.signOut();
    await auth.signInWithEmail('nhi@example.com', 'password1');
    await tester.idle();
    await tester.pump();

    expect(made, hasLength(2));
    expect(made.first.isDisposed, isTrue);
    expect(sharings, hasLength(2));
    final readsBefore = first.settingsReads;
    expect(sharings.last.settingsReads, greaterThan(0));
    // Rebuilds only ever read from the new sharing repository.
    tester
        .element(find.byType(PrivacyScreen, skipOffstage: false))
        .markNeedsBuild();
    await tester.pump();
    expect(first.settingsReads, readsBefore);
    final privacy = tester.widget<PrivacyScreen>(
      find.byType(PrivacyScreen, skipOffstage: false),
    );
    expect(privacy.sharing, same(made.last.sharing));
  });

  group('CircleScreen', () {
    testOnLinux('swaps between made and passed-in services', (tester) async {
      final own = <AppServices>[];
      final passed = AppServices.defaults();
      addTearDown(passed.dispose);
      Widget screen(AppServices? services) => MaterialApp(
        home: CircleScreen(
          services: services,
          createServices: () {
            final made = AppServices.defaults();
            own.add(made);
            return made;
          },
        ),
      );

      await tester.pumpWidget(screen(null));
      await tester.pump();
      expect(own, hasLength(1));

      await tester.pumpWidget(screen(passed));
      await tester.pump();
      expect(own.single.isDisposed, isTrue);
      expect(passed.isDisposed, isFalse);

      await tester.pumpWidget(screen(null));
      await tester.pump();
      // Open Ranks to use the services again: a fresh set, not the old one.
      await tester.tap(find.text('Ranks'));
      await tester.pumpAndSettle();
      expect(own, hasLength(2));
      expect(own.last.isDisposed, isFalse);

      await tester.pumpWidget(const SizedBox());
      expect(own.last.isDisposed, isTrue);
      expect(passed.isDisposed, isFalse);
    });

    testOnLinux('disposes the services it made itself', (tester) async {
      final own = <AppServices>[];
      await tester.pumpWidget(
        MaterialApp(
          home: CircleScreen(
            createServices: () {
              final services = AppServices.defaults();
              own.add(services);
              return services;
            },
          ),
        ),
      );
      await tester.pump();
      expect(own, hasLength(1));
      expect(own.single.isDisposed, isFalse);

      await tester.pumpWidget(const SizedBox());
      expect(own.single.isDisposed, isTrue);
    });

    testOnLinux('leaves services passed in alone', (tester) async {
      final passed = AppServices.defaults();
      addTearDown(passed.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: CircleScreen(
            services: passed,
            createServices: () => fail('should not make its own'),
          ),
        ),
      );
      await tester.pump();

      await tester.pumpWidget(const SizedBox());
      expect(passed.isDisposed, isFalse);
    });
  });

  test('AppServices.dispose twice is safe and keeps the shared sharing', () {
    final sharing = _NeverLoadedSharing();
    final services = AppServices.defaults(
      sharing: sharing,
      statsDb: FakeFirebaseFirestore(),
      userId: 'u1',
    );
    expect(sharing.listened, isTrue);

    services.dispose();
    services.dispose();

    expect(services.isDisposed, isTrue);
    expect(sharing.listened, isFalse);
    // The caller still owns it: using it after is fine.
    sharing.addListener(() {});
    expect(sharing.listened, isTrue);
  });
}
