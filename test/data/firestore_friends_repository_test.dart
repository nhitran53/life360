import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life360/data/firestore_friends_repository.dart';
import 'package:life360/data/firestore_profile_repository.dart';
import 'package:life360/data/friends_repository.dart';
import 'package:life360/models/models.dart';

// Repository logic only: the rules are tested against the emulator in
// firestore-tests/.
void main() {
  late FakeFirebaseFirestore db;

  UserProfile person(String uid, String name, String username, String code) =>
      UserProfile(
        id: uid,
        displayName: name,
        username: username,
        avatarEmoji: '🦊',
        friendCode: code,
      );

  final alice = person('alice', 'Alice', 'alice.runs', 'AAAAA2');
  final bob = person('bob', 'Bob', 'bob', 'BBBBB2');
  final carol = person('carol', 'Carol', 'carol', 'CCCCC2');

  FirestoreFriendsRepository as(UserProfile me) =>
      FirestoreFriendsRepository(db, me: me);

  setUp(() async {
    db = FakeFirebaseFirestore();
    for (final p in [alice, bob, carol]) {
      await db.doc('users/${p.id}').set(p.toJson()..remove('id'));
      await db.doc('usernames/${p.username}').set({'uid': p.id});
      await db.doc('friendCodes/${p.friendCode}').set({'uid': p.id});
    }
  });

  Future<Object?> errorOf(Future<Object?> f) async {
    try {
      await f;
    } on FriendRequestException catch (e) {
      return e.message;
    }
    return null;
  }

  test('pair ids are sorted, so both people get the same one', () {
    expect(friendshipId('bob', 'alice'), 'alice_bob');
    expect(friendshipId('alice', 'bob'), 'alice_bob');
  });

  test('request → accept makes friends on both sides', () async {
    final request = await as(alice).sendRequest(bob.id);
    expect(request.id, 'alice_bob');

    final doc = (await db.doc('friendships/alice_bob').get()).data()!;
    expect(doc['users'], ['alice', 'bob']);
    expect(doc['status'], 'pending');

    expect((await as(alice).outgoingRequests()).single.addresseeId, 'bob');
    expect((await as(bob).incomingRequests()).single.requesterId, 'alice');
    expect(await as(alice).friends(), isEmpty);

    await as(bob).respondToRequest('alice_bob', accept: true);

    expect((await as(alice).friends()).map((p) => p.id), ['bob']);
    expect((await as(bob).friends()).map((p) => p.id), ['alice']);
    expect(await as(bob).incomingRequests(), isEmpty);
    expect(await as(alice).outgoingRequests(), isEmpty);
    expect((await as(carol).friends()), isEmpty);
  });

  test('declining deletes the request, so they can ask again', () async {
    await as(alice).sendRequest(bob.id);
    await as(bob).respondToRequest('alice_bob', accept: false);

    expect((await db.doc('friendships/alice_bob').get()).exists, isFalse);
    expect(await as(alice).outgoingRequests(), isEmpty);
    await as(alice).sendRequest(bob.id);
    expect(await as(bob).incomingRequests(), hasLength(1));
  });

  test('only the right person can accept or cancel', () async {
    await as(alice).sendRequest(bob.id);
    expect(
      await errorOf(as(alice).respondToRequest('alice_bob', accept: true)),
      'Request not found',
    );
    expect(
      await errorOf(as(bob).cancelRequest('alice_bob')),
      'Request not found',
    );

    await as(alice).cancelRequest('alice_bob');
    expect(await as(bob).incomingRequests(), isEmpty);
  });

  test('duplicate, reverse and self requests are refused', () async {
    expect(
      await errorOf(as(alice).sendRequest(alice.id)),
      "You can't add yourself 😅",
    );
    expect(await errorOf(as(alice).sendRequest('nobody')), 'User not found');

    await as(alice).sendRequest(bob.id);
    expect(
      await errorOf(as(alice).sendRequest(bob.id)),
      'A request is already pending',
    );
    expect(
      await errorOf(as(bob).sendRequest(alice.id)),
      'They already sent you a request. Check your requests!',
    );

    await as(bob).respondToRequest('alice_bob', accept: true);
    expect(
      await errorOf(as(alice).sendRequest(bob.id)),
      "You're already friends",
    );
  });

  test('either friend can unfriend', () async {
    await as(alice).sendRequest(bob.id);
    expect(await errorOf(as(alice).removeFriend(bob.id)), "You're not friends");
    await as(bob).respondToRequest('alice_bob', accept: true);

    await as(bob).removeFriend(alice.id);
    expect(await as(alice).friends(), isEmpty);
    expect(await as(bob).friends(), isEmpty);
  });

  test('friends are sorted by name', () async {
    for (final p in [carol, bob]) {
      await as(alice).sendRequest(p.id);
      await as(p).respondToRequest(friendshipId(alice.id, p.id), accept: true);
    }
    expect((await as(alice).friends()).map((p) => p.displayName), [
      'Bob',
      'Carol',
    ]);
  });

  test('find by friend code, any case', () async {
    expect((await as(alice).findByFriendCode('bbbbb2'))?.id, 'bob');
    expect(await as(alice).findByFriendCode('ZZZZZ9'), isNull);
    expect(await as(alice).findByFriendCode('short'), isNull);
  });

  test('search is a username prefix and never includes you', () async {
    expect((await as(alice).searchUsers('@Ca')).map((p) => p.id), ['carol']);
    expect((await as(alice).searchUsers('alice')), isEmpty);
    expect((await as(bob).searchUsers('alice')).map((p) => p.id), ['alice']);
    expect(await as(alice).searchUsers('b'), isEmpty); // too short
  });

  test('currentUser and userById', () async {
    expect(await as(alice).currentUser(), alice);
    expect((await as(alice).userById('carol'))?.displayName, 'Carol');
    expect(await as(alice).userById('nobody'), isNull);
  });

  test('deleting a profile removes its friendships too', () async {
    await as(alice).sendRequest(bob.id);
    await as(bob).respondToRequest('alice_bob', accept: true);
    await as(carol).sendRequest(alice.id);

    await FirestoreProfileRepository(db).deleteProfile(alice.id);

    expect((await db.collection('friendships').get()).docs, isEmpty);
    expect(await as(bob).friends(), isEmpty);
  });
}
