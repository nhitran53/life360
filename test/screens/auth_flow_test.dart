import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life360/data/account_session.dart';
import 'package:life360/data/mock_auth_repository.dart';
import 'package:life360/data/mock_profile_repository.dart';
import 'package:life360/main.dart';
import 'package:life360/models/models.dart';
import 'package:life360/screens/account_screen.dart';
import 'package:life360/screens/circle_screen.dart';
import 'package:life360/screens/onboarding_screen.dart';
import 'package:life360/screens/sign_in_screen.dart';

/// Saving fails like a server or network error would (not "username taken").
class _FailingProfiles extends MockProfileRepository {
  @override
  Future<UserProfile> createProfile({
    required String uid,
    required String displayName,
    required String username,
    required String avatarEmoji,
    DailyGoals goals = const DailyGoals(),
  }) => Future.error(Exception('permission-denied'));
}

/// Profile reads fail like an offline Firestore would, while [failing].
class _OfflineProfiles extends MockProfileRepository {
  var failing = true;

  @override
  Future<UserProfile?> profileFor(String uid) =>
      failing ? Future.error(Exception('unavailable')) : super.profileFor(uid);
}

/// Username checks and profile deletes fail like an offline Firestore
/// would, while the flags are on.
class _FlakyProfiles extends MockProfileRepository {
  var failChecks = false;
  var failDeletes = false;

  static final _offline = FirebaseException(
    plugin: 'cloud_firestore',
    code: 'unavailable',
  );

  @override
  Future<bool> isUsernameAvailable(String username) => failChecks
      ? Future.error(_offline)
      : super.isUsernameAvailable(username);

  @override
  Future<void> deleteProfile(String uid) =>
      failDeletes ? Future.error(_offline) : super.deleteProfile(uid);
}

void main() {
  late MockAuthRepository auth;
  late MockProfileRepository profiles;
  late AccountSession session;

  // Made inside each test (not setUp) so the session's stream listener runs
  // in the test's fake-async zone and reacts while the test pumps.
  void makeSession() {
    auth = MockAuthRepository();
    profiles = MockProfileRepository();
    session = AccountSession(auth: auth, profiles: profiles);
    addTearDown(() {
      session.dispose();
      auth.dispose();
    });
  }

  void useTallPhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 2900);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  Future<void> startApp(WidgetTester tester) async {
    useTallPhone(tester);
    await tester.pumpWidget(Friend360App(session: session));
    await tester.pump(const Duration(seconds: 2));
  }

  Future<void> signUp(
    WidgetTester tester, {
    String email = 'nhi@example.com',
  }) async {
    await tester.tap(find.text("Let's go"));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('email-field')), email);
    await tester.enterText(
      find.byKey(const ValueKey('password-field')),
      'password1',
    );
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
  }

  Future<void> onboard(WidgetTester tester) async {
    await tester.enterText(find.byKey(const ValueKey('name-field')), 'Nhi');
    await tester.enterText(
      find.byKey(const ValueKey('username-field')),
      '@Nhi',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Avatar 🦊'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More steps'));
    await tester.pump();
    await tester.tap(find.text("Let's go! 🎉"));
    await tester.pumpAndSettle();
  }

  testWidgets('Sign up, onboard and land on the Circle home', (tester) async {
    makeSession();
    await startApp(tester);
    await signUp(tester);

    expect(find.byType(SignInScreen), findsNothing);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('What should friends call you?'), findsOneWidget);

    await onboard(tester);

    expect(find.byType(CircleScreen), findsOneWidget);
    expect(session.profile!.username, 'nhi');
    expect(session.profile!.avatarEmoji, '🦊');
    expect(session.goals.steps, 9000);
  });

  testWidgets('Sign-up form checks the email and password', (tester) async {
    makeSession();
    await startApp(tester);
    await tester.tap(find.text("Let's go"));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('email-field')), 'nope');
    await tester.enterText(
      find.byKey(const ValueKey('password-field')),
      'short',
    );
    await tester.tap(find.text('Create account'));
    await tester.pump();

    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(find.text('Use at least 8 characters'), findsOneWidget);
    expect(find.byType(SignInScreen), findsOneWidget);
  });

  testWidgets('Wrong password shows a friendly error', (tester) async {
    makeSession();
    await auth.signUpWithEmail('nhi@example.com', 'password1');
    await auth.signOut();
    await startApp(tester);

    await tester.tap(find.text('I already have an account'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back 👋'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('email-field')),
      'nhi@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('password-field')),
      'wrongpass',
    );
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();

    expect(find.text("That email and password don't match"), findsOneWidget);
  });

  testWidgets('A failed save shows a message instead of doing nothing', (
    tester,
  ) async {
    auth = MockAuthRepository();
    session = AccountSession(auth: auth, profiles: _FailingProfiles());
    addTearDown(() {
      session.dispose();
      auth.dispose();
    });
    await startApp(tester);
    await signUp(tester);

    await tester.enterText(find.byKey(const ValueKey('name-field')), 'Nhi');
    await tester.enterText(
      find.byKey(const ValueKey('username-field')),
      'nhi',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Let's go! 🎉"));
    await tester.pumpAndSettle();

    expect(
      find.text(
        "Couldn't save your profile. Check your connection and try again.",
      ),
      findsOneWidget,
    );
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text("Let's go! 🎉"), findsOneWidget);
  });

  testWidgets('Taken usernames are rejected during onboarding', (tester) async {
    makeSession();
    await startApp(tester);
    await signUp(tester);

    await tester.enterText(find.byKey(const ValueKey('name-field')), 'Alex');
    // "alex.runs" belongs to a mock friend.
    await tester.enterText(
      find.byKey(const ValueKey('username-field')),
      'Alex.Runs',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('@alex.runs is taken. Try another one.'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('username-field')), 'a b');
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.text('Only letters, numbers, _ and .'), findsOneWidget);
  });

  testWidgets('Google sign-in, Apple shown only when asked', (tester) async {
    makeSession();
    useTallPhone(tester);
    await tester.pumpWidget(
      AccountScope(
        session: session,
        child: const MaterialApp(home: SignInScreen(showApple: false)),
      ),
    );
    expect(find.text('Continue with Apple'), findsNothing);

    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();
    expect(session.user?.email, 'you@gmail.com');

    await tester.pumpWidget(
      AccountScope(
        session: session,
        child: const MaterialApp(home: SignInScreen(showApple: true)),
      ),
    );
    expect(find.text('Continue with Apple'), findsOneWidget);
  });

  testWidgets('Cancelling Google sign-in shows no error', (tester) async {
    makeSession();
    auth.socialSignInCancelled = true;
    useTallPhone(tester);
    await tester.pumpWidget(
      AccountScope(
        session: session,
        child: const MaterialApp(home: SignInScreen()),
      ),
    );
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('auth-error')), findsNothing);
    expect(session.user, isNull);
  });

  /// Like [makeSession], with profile reads that fail until [failing] is
  /// switched off.
  _OfflineProfiles makeOfflineSession() {
    auth = MockAuthRepository();
    final offline = _OfflineProfiles();
    profiles = offline;
    session = AccountSession(auth: auth, profiles: profiles);
    addTearDown(() {
      session.dispose();
      auth.dispose();
    });
    return offline;
  }

  testWidgets('A failed profile load offers Try again instead of spinning', (
    tester,
  ) async {
    final offline = makeOfflineSession();
    await startApp(tester);
    await signUp(tester);

    expect(find.text("Couldn't load your profile"), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // Still offline: stays on the message.
    await tester.tap(find.byKey(const ValueKey('retry-profile')));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't load your profile"), findsOneWidget);

    // Back online: carries on to onboarding (no profile yet).
    offline.failing = false;
    await tester.tap(find.byKey(const ValueKey('retry-profile')));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  testWidgets('Logging out from a failed profile load goes back to welcome', (
    tester,
  ) async {
    makeOfflineSession();
    await startApp(tester);
    await signUp(tester);
    expect(find.text("Couldn't load your profile"), findsOneWidget);

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(find.text("Let's go"), findsOneWidget);
    expect(session.status, AccountStatus.signedOut);
  });

  testWidgets('Account page logs out back to the welcome screen', (
    tester,
  ) async {
    makeSession();
    await startApp(tester);
    await signUp(tester);
    await onboard(tester);

    await tester.tap(find.text('Privacy'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Account'));
    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();

    expect(find.byType(AccountScreen), findsOneWidget);
    expect(find.text('@nhi'), findsOneWidget);
    expect(find.text(session.profile!.friendCode), findsOneWidget);
    expect(find.text('Signed in with Email'), findsOneWidget);

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(find.byType(AccountScreen), findsNothing);
    expect(find.text('I already have an account'), findsOneWidget);
  });

  testWidgets('Deleting the account asks first, then signs out', (
    tester,
  ) async {
    makeSession();
    await startApp(tester);
    await signUp(tester);
    await onboard(tester);

    await tester.tap(find.text('Privacy'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Account'));
    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    expect(find.text('Delete your account?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AccountScreen), findsOneWidget);

    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('I already have an account'), findsOneWidget);
    expect(await profiles.isUsernameAvailable('nhi'), isTrue);
  });

  /// Like [makeSession], with profiles whose network calls can fail.
  _FlakyProfiles makeFlakySession() {
    auth = MockAuthRepository();
    final flaky = _FlakyProfiles();
    profiles = flaky;
    session = AccountSession(auth: auth, profiles: profiles);
    addTearDown(() {
      session.dispose();
      auth.dispose();
    });
    return flaky;
  }

  testWidgets('An offline username check stops spinning and says so', (
    tester,
  ) async {
    final flaky = makeFlakySession();
    await startApp(tester);
    await signUp(tester);

    flaky.failChecks = true;
    await tester.enterText(find.byKey(const ValueKey('name-field')), 'Nhi');
    await tester.enterText(
      find.byKey(const ValueKey('username-field')),
      'nhi',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        "Couldn't check that username. Check your connection and try again.",
      ),
      findsOneWidget,
    );
    expect(find.text('One sec…'), findsNothing);

    flaky.failChecks = false;
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Pick your look'), findsOneWidget);
  });

  testWidgets('An offline account delete frees the screen and says so', (
    tester,
  ) async {
    final flaky = makeFlakySession();
    await startApp(tester);
    await signUp(tester);
    await onboard(tester);

    await tester.tap(find.text('Privacy'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Account'));
    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();

    flaky.failDeletes = true;
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        "Couldn't delete your account. Check your connection and try again.",
      ),
      findsOneWidget,
    );
    expect(find.byType(AccountScreen), findsOneWidget);

    // Not stuck: logging out still works.
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(find.text('I already have an account'), findsOneWidget);
  });
}
