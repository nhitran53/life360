import 'package:flutter_test/flutter_test.dart';
import 'package:life360/data/friends_repository.dart';
import 'package:life360/data/mock_data.dart';
import 'package:life360/data/mock_friends_repository.dart';
import 'package:life360/data/mock_stats_repository.dart';
import 'package:life360/models/models.dart';

void main() {
  // A Wednesday, so "this week" has Mon–Wed of data.
  final now = DateTime(2026, 11, 4, 12);
  DateTime clock() => now;

  late MockFriendsRepository friends;
  late MockStatsRepository stats;

  setUp(() {
    friends = MockFriendsRepository(clock: clock);
    stats = MockStatsRepository(friends: friends, clock: clock);
  });

  group('generateMockStats', () {
    test('is deterministic and covers 14 days per user', () {
      final a = generateMockStats(today: now);
      final b = generateMockStats(today: now);
      expect(a, b);
      expect(a.length, mockAllUsers.length * 14);
    });

    test('produces realistic ranges', () {
      for (final s in generateMockStats(today: now)) {
        expect(s.steps, inInclusiveRange(0, 30000));
        expect(s.sleepMinutes, inInclusiveRange(180, 720));
        expect(s.screenTimeMinutes, inInclusiveRange(0, 900));
      }
    });
  });

  group('MockStatsRepository', () {
    test('dailyStats returns an inclusive, sorted range', () async {
      final days = await stats.dailyStats(mockMe.id,
          from: DateTime(2026, 10, 30), to: DateTime(2026, 11, 2, 8));
      expect(days.map((d) => d.date), [
        DateTime(2026, 10, 30),
        DateTime(2026, 10, 31),
        DateTime(2026, 11, 1),
        DateTime(2026, 11, 2),
      ]);
    });

    test('weeklySummary covers this week so far', () async {
      final w = await stats.weeklySummary(mockMe.id);
      expect(w.weekStart, DateTime(2026, 11, 2));
      expect(w.daysTracked, 3);
    });

    test('last week has all 7 days', () async {
      final w = await stats.weeklySummary(mockMe.id,
          weekOf: DateTime(2026, 10, 28));
      expect(w.daysTracked, 7);
    });

    test('leaderboard includes me and my 5 friends, best first', () async {
      final board = await stats.leaderboard(StatMetric.steps);
      expect(board.length, 6);
      expect(board.map((e) => e.user), contains(mockMe));
      expect(board.map((e) => e.user), isNot(contains(mockStranger)));
      for (var i = 1; i < board.length; i++) {
        expect(board[i].value, lessThanOrEqualTo(board[i - 1].value));
      }
    });

    test('accepting a request adds them to the leaderboard', () async {
      final req = (await friends.incomingRequests()).single;
      await friends.respondToRequest(req.id, accept: true);
      final board = await stats.leaderboard(StatMetric.sleep);
      expect(board.map((e) => e.user), contains(mockRequester));
    });
  });

  group('MockFriendsRepository', () {
    test('starts with 5 friends and 1 incoming request', () async {
      expect(await friends.friends(), hasLength(5));
      final reqs = await friends.incomingRequests();
      expect(reqs.single.requesterId, mockRequester.id);
    });

    test('findByFriendCode is case-insensitive', () async {
      expect(await friends.findByFriendCode(' gia999 '), mockStranger);
      expect(await friends.findByFriendCode('NOPE00'), isNull);
    });

    test('sendRequest creates a pending request', () async {
      final f = await friends.sendRequest(mockStranger.id);
      expect(f.status, FriendshipStatus.pending);
      expect(f.addresseeId, mockStranger.id);
    });

    test('sendRequest rejects self, existing friends and duplicates', () async {
      expect(friends.sendRequest(mockMe.id),
          throwsA(isA<FriendRequestException>()));
      expect(friends.sendRequest(mockFriends.first.id),
          throwsA(isA<FriendRequestException>()));
      await friends.sendRequest(mockStranger.id);
      expect(friends.sendRequest(mockStranger.id),
          throwsA(isA<FriendRequestException>()));
    });

    test('declining removes the request without adding a friend', () async {
      final req = (await friends.incomingRequests()).single;
      await friends.respondToRequest(req.id, accept: false);
      expect(await friends.incomingRequests(), isEmpty);
      expect(await friends.friends(), hasLength(5));
    });
  });
}
