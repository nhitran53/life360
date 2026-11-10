import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life360/data/account_session.dart';
import 'package:life360/data/mock_auth_repository.dart';
import 'package:life360/data/mock_profile_repository.dart';
import 'package:life360/data/sharing_repository.dart';
import 'package:life360/main.dart';
import 'package:life360/models/models.dart';
import 'package:life360/screens/circle_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Settings that never load, so StatsSync keeps retrying; counts the retries.
class _NeverLoadedSharing extends ChangeNotifier implements SharingRepository {
  var refreshes = 0;

  @override
  bool get isLoaded => false;

  @override
  Future<void> refresh() async => refreshes++;

  @override
  SharingSettings settingsFor(String userId) => const SharingSettings();

  @override
  Future<void> update(String userId, SharingSettings settings) async {}
}

// The signed-in services (and StatsSync's retry timer) live only as long as
// the session that made them, even when AuthGate stays mounted.
void main() {
  testWidgets('signing out stops the retries; signing back in starts fresh', (
    tester,
  ) async {
    // Tests default to Android, which would use the real Health Connect
    // plugin. Reset before the end: the framework checks it unset then.
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1170, 2900);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final auth = MockAuthRepository();
    final sharings = <_NeverLoadedSharing>[];
    final session = AccountSession(
      auth: auth,
      profiles: MockProfileRepository(),
      sharingFor: (_) {
        final sharing = _NeverLoadedSharing();
        sharings.add(sharing);
        return sharing;
      },
      statsDb: FakeFirebaseFirestore(),
    );
    addTearDown(() {
      session.dispose();
      auth.dispose();
    });

    await tester.pumpWidget(Friend360App(session: session));
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

    CircleScreen circleScreen() => tester.widget(find.byType(CircleScreen));
    final first = circleScreen().services;
    expect(sharings, hasLength(1));

    // The unloaded settings leave a retry pending.
    await tester.pump(const Duration(seconds: 6));
    expect(sharings.first.refreshes, greaterThan(0));

    await session.signOut();
    await tester.pump();
    await tester.pump();
    expect(find.byType(CircleScreen), findsNothing);
    final atSignOut = sharings.first.refreshes;
    await tester.pump(const Duration(minutes: 10));
    expect(sharings.first.refreshes, atSignOut);

    await auth.signInWithEmail('nhi@example.com', 'password1');
    await tester.pump();
    await tester.pump();

    expect(sharings, hasLength(2));
    expect(circleScreen().services, isNot(same(first)));
    // The old session's repository is left alone; the new one is retried.
    await tester.pump(const Duration(seconds: 6));
    expect(sharings.first.refreshes, atSignOut);
    expect(sharings.last.refreshes, greaterThan(0));
    debugDefaultTargetPlatformOverride = null;
  });
}
