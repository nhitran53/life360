import 'package:flutter_test/flutter_test.dart';
import 'package:life360/data/account_session.dart';
import 'package:life360/data/auth_repository.dart';
import 'package:life360/data/local_account_store.dart';
import 'package:life360/data/mock_auth_repository.dart';
import 'package:life360/data/mock_profile_repository.dart';
import 'package:life360/models/models.dart';

/// Builds the session the way main() does on platforms without Firebase.
Future<AccountSession> _launch(LocalAccountStore store) async => AccountSession(
  auth: await MockAuthRepository.persistent(store),
  profiles: await MockProfileRepository.persistent(store),
);

Future<void> _settle(AccountSession session) async {
  while (session.status == AccountStatus.loading) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('stays signed in with the same profile after a restart', () async {
    final store = InMemoryLocalAccountStore();
    final first = await _launch(store);
    await first.auth.signUpWithEmail('sam@example.com', 'hunter22');
    await _settle(first);
    await first.completeOnboarding(
      displayName: 'Sam',
      username: 'sam_runs',
      avatarEmoji: '🦊',
      goals: const DailyGoals(steps: 12000),
    );
    first.dispose();

    final second = await _launch(store);
    await _settle(second);
    expect(second.status, AccountStatus.ready);
    expect(second.profile?.username, 'sam_runs');
    expect(second.goals.steps, 12000);
    second.dispose();
  });

  test('after logging out, the account can log back in', () async {
    final store = InMemoryLocalAccountStore();
    final first = await _launch(store);
    await first.auth.signUpWithEmail('sam@example.com', 'hunter22');
    await first.signOut();
    await _settle(first);
    first.dispose();

    final second = await _launch(store);
    await _settle(second);
    expect(second.status, AccountStatus.signedOut);
    await expectLater(
      second.auth.signInWithEmail('sam@example.com', 'wrong-pass'),
      throwsA(isA<AuthException>()),
    );
    final user = await second.auth.signInWithEmail(
      'sam@example.com',
      'hunter22',
    );
    expect(user.email, 'sam@example.com');
    second.dispose();
  });

  test('passwords are not saved as plain text', () async {
    final store = InMemoryLocalAccountStore();
    final auth = await MockAuthRepository.persistent(store);
    await auth.signUpWithEmail('sam@example.com', 'hunter22');
    await Future<void>.delayed(Duration.zero);
    expect((await store.load('auth')).toString(), isNot(contains('hunter22')));
  });
}
