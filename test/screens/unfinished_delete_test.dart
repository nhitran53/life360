import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life360/data/account_session.dart';
import 'package:life360/data/auth_repository.dart';
import 'package:life360/data/mock_auth_repository.dart';
import 'package:life360/data/mock_profile_repository.dart';
import 'package:life360/main.dart';
import 'package:life360/screens/onboarding_screen.dart';

/// Refuses to delete the login while [refuseDelete] is set, like Firebase
/// does when it disagrees that the sign-in was recent.
class _RefusingAuth extends MockAuthRepository {
  var refuseDelete = false;

  @override
  Future<void> deleteAccount() async {
    if (!refuseDelete) return super.deleteAccount();
    throw const AuthException(
      AuthException.requiresRecentLogin,
      'For safety, log out and back in, then try again.',
    );
  }
}

// #43: if the data is deleted but the login isn't, the user lands on
// onboarding. Explain what happened and let them finish deleting there.
void main() {
  late _RefusingAuth auth;
  late AccountSession session;

  Future<void> signUpWithUi(
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

  Future<void> startSignedIn(WidgetTester tester) async {
    auth = _RefusingAuth();
    session = AccountSession(auth: auth, profiles: MockProfileRepository());
    addTearDown(() {
      session.dispose();
      auth.dispose();
    });
    tester.view.physicalSize = const Size(1170, 2900);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(Friend360App(session: session));
    await tester.pumpAndSettle();
    await signUpWithUi(tester);
    await tester.enterText(find.byKey(const ValueKey('name-field')), 'Nhi');
    await tester.enterText(find.byKey(const ValueKey('username-field')), 'nhi');
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

  Future<void> deleteFromAccountPage(WidgetTester tester) async {
    await tester.tap(find.text('Privacy'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Account'));
    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
  }

  testWidgets('a half-finished delete is explained on onboarding and can be '
      'finished there', (tester) async {
    await startSignedIn(tester);
    auth.refuseDelete = true;
    await deleteFromAccountPage(tester);

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.textContaining("your login wasn't deleted"), findsOneWidget);

    auth.refuseDelete = false;
    await tester.tap(find.text('Finish deleting'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('I already have an account'), findsOneWidget);
    expect(auth.currentUser, isNull);
  });

  testWidgets('a login without a profile can be deleted from onboarding', (
    tester,
  ) async {
    auth = _RefusingAuth();
    session = AccountSession(auth: auth, profiles: MockProfileRepository());
    addTearDown(() {
      session.dispose();
      auth.dispose();
    });
    tester.view.physicalSize = const Size(1170, 2900);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(Friend360App(session: session));
    await tester.pumpAndSettle();
    await signUpWithUi(tester, email: 'new@example.com');

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.textContaining("your login wasn't deleted"), findsNothing);

    await tester.ensureVisible(find.text('Delete account'));
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('I already have an account'), findsOneWidget);
    expect(auth.currentUser, isNull);
  });
}
