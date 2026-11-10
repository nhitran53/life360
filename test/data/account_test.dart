import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:life360/data/account_session.dart';
import 'package:life360/data/auth_repository.dart';
import 'package:life360/data/mock_auth_repository.dart';
import 'package:life360/data/mock_profile_repository.dart';
import 'package:life360/data/profile_repository.dart';
import 'package:life360/models/models.dart';

/// Lets the session's auth-stream listener and profile load finish.
Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('usernames', () {
    test('normalize trims, lowercases and drops a leading @', () {
      expect(normalizeUsername('  @Alex.R '), 'alex.r');
    });

    test('rules', () {
      expect(usernameProblem('alex_r.9'), isNull);
      expect(usernameProblem(''), 'Pick a username');
      expect(usernameProblem('ab'), 'At least 3 characters');
      expect(usernameProblem('a' * 21), 'At most 20 characters');
      expect(usernameProblem('9lives'), 'Start with a letter');
      expect(usernameProblem('hey you'), 'Only letters, numbers, _ and .');
      expect(usernameProblem('a..b'), isNotNull);
      expect(usernameProblem('abc.'), isNotNull);
    });

    test('display names', () {
      expect(displayNameProblem(' Nhi '), isNull);
      expect(displayNameProblem('   '), isNotNull);
      expect(displayNameProblem('x' * 31), isNotNull);
    });
  });

  test('friend codes use 6 unambiguous characters', () {
    final r = Random(1);
    for (var i = 0; i < 200; i++) {
      final code = generateFriendCode(r);
      expect(code, matches(RegExp(r'^[A-HJKMNP-Z2-9]{6}$')));
    }
  });

  test('DailyGoals round-trips through JSON and withTarget', () {
    final goals = const DailyGoals().withTarget(StatMetric.steps, 12000);
    expect(goals.steps, 12000);
    expect(DailyGoals.fromJson(goals.toJson()), goals);
    expect(DailyGoals.fromJson(const {}), const DailyGoals());
  });

  group('MockAuthRepository', () {
    test('sign up, sign out, log in', () async {
      final auth = MockAuthRepository();
      final user = await auth.signUpWithEmail(' Nhi@Example.com ', 'password1');
      expect(user.email, 'nhi@example.com');
      expect(auth.currentUser, user);

      await auth.signOut();
      expect(auth.currentUser, isNull);

      final again = await auth.signInWithEmail('nhi@example.com', 'password1');
      expect(again.uid, user.uid);
    });

    test('rejects taken emails, weak passwords and wrong passwords', () async {
      final auth = MockAuthRepository();
      await auth.signUpWithEmail('nhi@example.com', 'password1');

      Future<String> codeOf(Future<Object?> f) async {
        try {
          await f;
        } on AuthException catch (e) {
          return e.code;
        }
        return 'no error';
      }

      expect(
        await codeOf(auth.signUpWithEmail('nhi@example.com', 'password2')),
        AuthException.emailInUse,
      );
      expect(
        await codeOf(auth.signUpWithEmail('x@example.com', 'short')),
        AuthException.weakPassword,
      );
      expect(
        await codeOf(auth.signUpWithEmail('not-an-email', 'password1')),
        AuthException.invalidEmail,
      );
      expect(
        await codeOf(auth.signInWithEmail('nhi@example.com', 'nope')),
        AuthException.wrongCredentials,
      );
      expect(
        await codeOf(auth.signInWithEmail('who@example.com', 'password1')),
        AuthException.wrongCredentials,
      );
    });

    test('Google returns the same account each time', () async {
      final auth = MockAuthRepository();
      final first = await auth.signInWithGoogle();
      await auth.signOut();
      final second = await auth.signInWithGoogle();
      expect(second.uid, first.uid);
      expect(second.method, SignInMethod.google);
    });
  });

  group('MockProfileRepository', () {
    test('mock users and new profiles take their usernames', () async {
      final profiles = MockProfileRepository(random: Random(2));
      expect(await profiles.isUsernameAvailable('me'), isFalse);
      expect(await profiles.isUsernameAvailable('nhi'), isTrue);

      final p = await profiles.createProfile(
        uid: 'u1',
        displayName: ' Nhi ',
        username: 'nhi',
        avatarEmoji: '🦊',
      );
      expect(p.displayName, 'Nhi');
      expect(p.friendCode, hasLength(6));
      expect(await profiles.isUsernameAvailable('nhi'), isFalse);
      expect(
        () => profiles.createProfile(
          uid: 'u2',
          displayName: 'Other',
          username: 'nhi',
          avatarEmoji: '🐼',
        ),
        throwsA(isA<ProfileException>()),
      );

      await profiles.deleteProfile('u1');
      expect(await profiles.profileFor('u1'), isNull);
      expect(await profiles.isUsernameAvailable('nhi'), isTrue);
    });
  });

  group('AccountSession', () {
    late MockAuthRepository auth;
    late MockProfileRepository profiles;
    late AccountSession session;

    setUp(() {
      auth = MockAuthRepository();
      profiles = MockProfileRepository();
      session = AccountSession(auth: auth, profiles: profiles);
    });

    tearDown(() {
      session.dispose();
      auth.dispose();
    });

    test('signed out → needs profile → ready → signed out', () async {
      await settle();
      expect(session.status, AccountStatus.signedOut);

      await auth.signUpWithEmail('nhi@example.com', 'password1');
      await settle();
      expect(session.status, AccountStatus.needsProfile);

      const goals = DailyGoals(steps: 10000);
      await session.completeOnboarding(
        displayName: 'Nhi',
        username: 'nhi',
        avatarEmoji: '🦊',
        goals: goals,
      );
      expect(session.status, AccountStatus.ready);
      expect(session.profile!.username, 'nhi');
      expect(session.goals, goals);

      await session.signOut();
      await settle();
      expect(session.status, AccountStatus.signedOut);
      expect(session.profile, isNull);

      // Logging back in finds the saved profile and goals.
      await auth.signInWithEmail('nhi@example.com', 'password1');
      await settle();
      expect(session.status, AccountStatus.ready);
      expect(session.goals.steps, 10000);
    });

    test('deleting needs a recent login and then touches nothing', () async {
      await auth.signUpWithEmail('nhi@example.com', 'password1');
      await settle();
      await session.completeOnboarding(
        displayName: 'Nhi',
        username: 'nhi',
        avatarEmoji: '🦊',
        goals: const DailyGoals(),
      );
      auth.recentLogin = false;

      await expectLater(
        session.deleteAccount(),
        throwsA(
          isA<AuthException>().having(
            (e) => e.code,
            'code',
            AuthException.requiresRecentLogin,
          ),
        ),
      );
      expect(session.status, AccountStatus.ready);
      expect(await profiles.profileFor(session.user!.uid), isNotNull);
    });

    test('deleting the account removes the profile and the login', () async {
      await auth.signUpWithEmail('nhi@example.com', 'password1');
      await settle();
      await session.completeOnboarding(
        displayName: 'Nhi',
        username: 'nhi',
        avatarEmoji: '🦊',
        goals: const DailyGoals(),
      );
      final uid = session.user!.uid;

      await session.deleteAccount();
      await settle();

      expect(session.status, AccountStatus.signedOut);
      expect(await profiles.profileFor(uid), isNull);
      expect(await profiles.isUsernameAvailable('nhi'), isTrue);
      expect(
        () => auth.signInWithEmail('nhi@example.com', 'password1'),
        throwsA(isA<AuthException>()),
      );
    });
  });
}
