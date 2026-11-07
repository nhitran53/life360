import 'package:flutter_test/flutter_test.dart';
import 'package:life360/data/friends_repository.dart';
import 'package:life360/data/mock_data.dart';
import 'package:life360/data/mock_friends_repository.dart';
import 'package:life360/models/models.dart';

void main() {
  late MockFriendsRepository friends;

  setUp(
    () =>
        friends = MockFriendsRepository(clock: () => DateTime(2026, 3, 11, 12)),
  );

  group('searchUsers', () {
    test('matches usernames and names, with or without @', () async {
      expect(await friends.searchUsers('@gia'), [mockStranger]);
      expect(await friends.searchUsers('YOGA'), [mockStranger]);
      expect(
        (await friends.searchUsers('al')).map((u) => u.id),
        contains('u_alex'),
      );
    });

    test('never returns you and ignores very short queries', () async {
      expect(await friends.searchUsers('me'), isNot(contains(mockMe)));
      expect(await friends.searchUsers('a'), isEmpty);
      expect(await friends.searchUsers('@'), isEmpty);
    });
  });

  group('requests', () {
    test('sent requests show up until canceled', () async {
      final req = await friends.sendRequest(mockStranger.id);
      expect((await friends.outgoingRequests()).single.id, req.id);

      await friends.cancelRequest(req.id);
      expect(await friends.outgoingRequests(), isEmpty);
      // Can ask again after canceling.
      await friends.sendRequest(mockStranger.id);
    });

    test("you can't cancel a request someone sent you", () async {
      final incoming = (await friends.incomingRequests()).single;
      expect(
        friends.cancelRequest(incoming.id),
        throwsA(isA<FriendRequestException>()),
      );
    });

    test('accepting adds a friend; removing takes them away', () async {
      final incoming = (await friends.incomingRequests()).single;
      await friends.respondToRequest(incoming.id, accept: true);
      expect(
        (await friends.friends()).map((u) => u.id),
        contains(mockRequester.id),
      );

      await friends.removeFriend(mockRequester.id);
      expect(
        (await friends.friends()).map((u) => u.id),
        isNot(contains(mockRequester.id)),
      );
      expect(await friends.friends(), hasLength(5));
    });

    test('removing someone who is not a friend fails', () async {
      expect(
        friends.removeFriend(mockStranger.id),
        throwsA(isA<FriendRequestException>()),
      );
    });

    test('after removing, you can send a new request', () async {
      final alex = mockFriends.first;
      await friends.removeFriend(alex.id);
      final req = await friends.sendRequest(alex.id);
      expect(req.status, FriendshipStatus.pending);
    });
  });
}
