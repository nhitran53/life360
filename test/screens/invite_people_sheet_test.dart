import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life360/data/mock_data.dart';
import 'package:life360/data/mock_friends_repository.dart';
import 'package:life360/screens/invite_people_sheet.dart';

void main() {
  late MockFriendsRepository friends;

  setUp(() => friends = MockFriendsRepository());

  Future<void> pumpSheet(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2900);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: InvitePeopleSheet(friends: friends)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('suggests people you are not connected with, and invites them', (
    tester,
  ) async {
    await pumpSheet(tester);

    expect(find.text('Suggested for you'), findsOneWidget);
    expect(find.text(mockStranger.displayName), findsOneWidget);
    // Friends and people with a pending request aren't suggested.
    expect(find.text(mockRequester.displayName), findsNothing);
    expect(find.text(mockFriends.first.displayName), findsNothing);

    await tester.tap(find.byKey(ValueKey('invite-${mockStranger.id}')));
    await tester.pumpAndSettle();

    expect(find.text('Invited ✓'), findsOneWidget);
    expect(
      (await friends.outgoingRequests()).single.addresseeId,
      mockStranger.id,
    );
  });

  testWidgets('typing a username searches and shows where you stand', (
    tester,
  ) async {
    await pumpSheet(tester);

    await tester.enterText(
      find.byKey(const ValueKey('invite-input')),
      '@${mockFriends.first.username}',
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    expect(find.text('Suggested for you'), findsNothing);
    expect(find.text(mockFriends.first.displayName), findsOneWidget);
    expect(find.text('Friends ✓'), findsOneWidget);
  });

  testWidgets('an email nobody uses suggests sending the invite link', (
    tester,
  ) async {
    await pumpSheet(tester);

    await tester.enterText(
      find.byKey(const ValueKey('invite-input')),
      'someone@example.com',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('invite-no-results')), findsOneWidget);
    expect(find.textContaining('that email'), findsOneWidget);
    expect(find.byKey(const ValueKey('copy-invite-link')), findsOneWidget);
  });

  testWidgets('a friend code finds that person', (tester) async {
    await pumpSheet(tester);

    await tester.enterText(
      find.byKey(const ValueKey('invite-input')),
      mockStranger.friendCode.toLowerCase(),
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.byKey(ValueKey('invite-${mockStranger.id}')), findsOneWidget);
  });
}
