import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life360/data/mock_data.dart';
import 'package:life360/data/mock_friends_repository.dart';
import 'package:life360/models/models.dart';
import 'package:life360/screens/add_friends_screen.dart';
import 'package:life360/screens/friends_stats_screen.dart';
import 'package:life360/theme/app_theme.dart';

/// Fails like an offline Firestore would, while the flags are on.
class _OfflineFriends extends MockFriendsRepository {
  _OfflineFriends({super.clock});

  var failSend = false;
  var failSearch = false;

  static final _offline = FirebaseException(
    plugin: 'cloud_firestore',
    code: 'unavailable',
  );

  @override
  Future<Friendship> sendRequest(String userId) =>
      failSend ? Future.error(_offline) : super.sendRequest(userId);

  @override
  Future<List<UserProfile>> searchUsers(String query) =>
      failSearch ? Future.error(_offline) : super.searchUsers(query);

  @override
  Future<UserProfile?> findByFriendCode(String code) =>
      failSearch ? Future.error(_offline) : super.findByFriendCode(code);
}

void main() {
  DateTime clock() => DateTime(2026, 3, 11, 12);
  late MockFriendsRepository friends;

  setUp(() => friends = MockFriendsRepository(clock: clock));

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 5000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: AddFriendsScreen(friends: friends),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const ValueKey('friend-search')), text);
    await tester.pumpAndSettle();
  }

  Future<void> tapIn(WidgetTester tester, String rowKey, String label) async {
    final button = find.descendant(
      of: find.byKey(ValueKey(rowKey)),
      matching: find.text(label),
    );
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('shows your friend code and username', (tester) async {
    await pumpScreen(tester);
    expect(find.text(mockMe.friendCode), findsOneWidget);
    expect(find.text('or find me as @${mockMe.username}'), findsOneWidget);
    expect(find.text('Your friends (5)'), findsOneWidget);
  });

  testWidgets('add by code, then cancel the request', (tester) async {
    await pumpScreen(tester);

    await search(tester, 'gia999');
    expect(find.byKey(const ValueKey('result-u_gia')), findsOneWidget);
    await tapIn(tester, 'result-u_gia', 'Add');

    expect(find.text('Request sent to Gia 👋'), findsOneWidget);
    expect(find.byKey(const ValueKey('outgoing-u_gia')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('result-u_gia')),
        matching: find.text('Requested'),
      ),
      findsOneWidget,
    );

    await tapIn(tester, 'outgoing-u_gia', 'Cancel');
    expect(find.byKey(const ValueKey('outgoing-u_gia')), findsNothing);
    expect(await friends.outgoingRequests(), isEmpty);
  });

  testWidgets('an invite link or @username finds people', (tester) async {
    await pumpScreen(tester);

    await search(tester, inviteLink('GIA999'));
    expect(find.byKey(const ValueKey('result-u_gia')), findsOneWidget);

    await search(tester, '@alex');
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('result-u_alex')),
        matching: find.text('Friends ✓'),
      ),
      findsOneWidget,
    );

    await search(tester, 'zzzz');
    expect(
      find.text('No one found. Check the code and try again 🔍'),
      findsOneWidget,
    );
  });

  testWidgets('accept and decline incoming requests', (tester) async {
    await pumpScreen(tester);
    expect(find.byKey(const ValueKey('incoming-u_fin')), findsOneWidget);

    await tapIn(tester, 'incoming-u_fin', 'Accept');
    expect(find.text('You and Fin are friends now 🎉'), findsOneWidget);
    expect(find.byKey(const ValueKey('incoming-u_fin')), findsNothing);
    expect(find.byKey(const ValueKey('friend-row-u_fin')), findsOneWidget);
    expect(find.text('Your friends (6)'), findsOneWidget);
  });

  testWidgets('removing a friend asks first', (tester) async {
    await pumpScreen(tester);

    await tapIn(tester, 'friend-row-u_alex', 'Remove');
    expect(find.text('Remove Alex?'), findsOneWidget);
    await tester.tap(find.text('Keep'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('friend-row-u_alex')), findsOneWidget);

    await tapIn(tester, 'friend-row-u_alex', 'Remove');
    await tester.tap(find.widgetWithText(TextButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('friend-row-u_alex')), findsNothing);
    expect(find.text('Your friends (4)'), findsOneWidget);
  });

  testWidgets("Friends' Stats badges requests and opens Friends", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 4000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: FriendsStatsScreen(friends: friends, clock: clock),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Add friends, 1 new request'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('add-friends')));
    await tester.pumpAndSettle();
    expect(find.byType(AddFriendsScreen), findsOneWidget);

    // Accept Fin, go back: Fin is in the list and the badge is gone.
    await tapIn(tester, 'incoming-u_fin', 'Accept');
    await tester.pageBack();
    await tester.pumpAndSettle();
    // ignore: avoid_print
    expect(find.byTooltip('Add friends'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('friend-u_fin')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const ValueKey('friend-u_fin')), findsOneWidget);
  });

  testWidgets('a network error frees the button and says so', (tester) async {
    final offline = _OfflineFriends(clock: clock);
    friends = offline;
    await pumpScreen(tester);

    await search(tester, 'gia999');
    offline.failSend = true;
    await tapIn(tester, 'result-u_gia', 'Add');

    expect(
      find.text("That didn't go through. Check your connection and try again."),
      findsOneWidget,
    );
    expect(await friends.outgoingRequests(), isEmpty);

    // Back online: the same button works again.
    offline.failSend = false;
    await tapIn(tester, 'result-u_gia', 'Add');
    expect(find.text('Request sent to Gia 👋'), findsOneWidget);
  });

  testWidgets('a failed search shows a message instead of throwing', (
    tester,
  ) async {
    final offline = _OfflineFriends(clock: clock);
    friends = offline;
    await pumpScreen(tester);

    offline.failSearch = true;
    await search(tester, '@alex');

    expect(
      find.text("Couldn't search right now. Check your connection."),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('result-u_alex')), findsNothing);
  });
}
