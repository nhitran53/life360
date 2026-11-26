import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life360/data/account_session.dart';
import 'package:life360/data/mock_auth_repository.dart';
import 'package:life360/data/mock_profile_repository.dart';
import 'package:life360/main.dart';
import 'package:life360/screens/sign_in_screen.dart';
import 'package:life360/widgets/practice_mode_note.dart';

// #76: when Firebase isn't set up for the platform, accounts are only saved
// on the device. Say so, and don't offer a Google button that makes a fake
// account.
void main() {
  late MockAuthRepository auth;

  AccountSession makeSession({required bool practice}) {
    auth = MockAuthRepository();
    final session = AccountSession(
      auth: auth,
      profiles: MockProfileRepository(),
      practiceMode: practice,
    );
    addTearDown(() {
      session.dispose();
      auth.dispose();
    });
    return session;
  }

  void useTallPhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 2900);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpSignIn(WidgetTester tester, AccountSession session) async {
    useTallPhone(tester);
    await tester.pumpWidget(
      AccountScope(
        session: session,
        child: const MaterialApp(home: SignInScreen(showApple: true)),
      ),
    );
  }

  test('sessions are real unless marked as practice', () {
    final real = AccountSession(
      auth: MockAuthRepository(),
      profiles: MockProfileRepository(),
    );
    addTearDown(real.dispose);
    expect(real.practiceMode, isFalse);
  });

  testWidgets('welcome screen shows the note in practice mode', (tester) async {
    useTallPhone(tester);
    await tester.pumpWidget(Friend360App(session: makeSession(practice: true)));
    await tester.pumpAndSettle();

    expect(find.byType(PracticeModeNote), findsOneWidget);
    expect(find.textContaining('only saved on this device'), findsOneWidget);
    expect(
      find.textContaining('Android emulator or iPhone simulator'),
      findsOneWidget,
    );
  });

  testWidgets('welcome screen has no note with real accounts', (tester) async {
    useTallPhone(tester);
    await tester.pumpWidget(
      Friend360App(session: makeSession(practice: false)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PracticeModeNote), findsNothing);
  });

  testWidgets('the default in-memory app is practice mode', (tester) async {
    useTallPhone(tester);
    await tester.pumpWidget(const Friend360App());
    await tester.pumpAndSettle();

    expect(find.byType(PracticeModeNote), findsOneWidget);
  });

  testWidgets('sign-in in practice mode shows the note, hides Google and '
      'Apple', (tester) async {
    await pumpSignIn(tester, makeSession(practice: true));

    expect(find.byType(PracticeModeNote), findsOneWidget);
    expect(find.text('Continue with Google'), findsNothing);
    expect(find.text('Continue with Apple'), findsNothing);
    expect(find.text('OR'), findsNothing);
    // Email sign-up still works.
    expect(find.text('Create account'), findsOneWidget);
  });

  testWidgets('sign-in with real accounts keeps Google and has no note', (
    tester,
  ) async {
    await pumpSignIn(tester, makeSession(practice: false));

    expect(find.byType(PracticeModeNote), findsNothing);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsOneWidget);
  });

  testWidgets('the note is announced as one sentence', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpSignIn(tester, makeSession(practice: true));

    expect(
      find.bySemanticsLabel(RegExp('^Practice mode: this account is only')),
      findsOneWidget,
    );
    handle.dispose();
  });
}
