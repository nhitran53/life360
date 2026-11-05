import '../models/models.dart';
import 'circle_repository.dart';
import 'mock_data.dart';

/// In-memory [CircleRepository] with a couple of circles for the demo.
class MockCircleRepository implements CircleRepository {
  MockCircleRepository({String? userId, List<Circle>? seed})
    : _me = userId ?? mockMe.id {
    _circles.addAll((seed ?? _defaultSeed()).map(_frozen));
  }

  final String _me;
  final _circles = <Circle>[];
  var _nextId = 0;

  /// A fresh list each time, so one repository can't change another's seed.
  static List<Circle> _defaultSeed() => [
    Circle(
      id: 'c_gym',
      name: 'Gym crew',
      type: CircleType.friends,
      ownerId: mockMe.id,
      memberIds: [mockMe.id, 'u_alex', 'u_bree', 'u_chris'],
      inviteCode: 'GYM360',
      rewardText: 'Winner picks the restaurant',
    ),
    Circle(
      id: 'c_dorm',
      name: 'Dorm floor',
      type: CircleType.team,
      ownerId: 'u_dana',
      memberIds: [mockMe.id, 'u_dana', 'u_eli'],
      inviteCode: 'DORM12',
    ),
    // Someone else's circle, so join-by-code has something to find.
    const Circle(
      id: 'c_fam',
      name: 'Family',
      type: CircleType.family,
      ownerId: 'u_dana',
      memberIds: ['u_dana', 'u_eli'],
      inviteCode: 'FAM777',
    ),
  ];

  /// Member lists can't be edited through a returned [Circle].
  static Circle _frozen(Circle c) =>
      c.copyWith(memberIds: List.unmodifiable(c.memberIds));

  int _indexOf(String id) {
    final i = _circles.indexWhere((c) => c.id == id);
    if (i < 0) throw const CircleException('No such circle.');
    return i;
  }

  @override
  Future<List<Circle>> circles() async => [
    for (final c in _circles)
      if (c.hasMember(_me)) c,
  ];

  @override
  Future<Circle> create(String name, CircleType type) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw const CircleException('Give the circle a name.');
    final n = _nextId++;
    final circle = Circle(
      id: 'c_new$n',
      name: trimmed,
      type: type,
      ownerId: _me,
      memberIds: [_me],
      inviteCode: 'NEW${(100 + n).toString().padLeft(3, '0')}',
    );
    _circles.add(_frozen(circle));
    return circle;
  }

  @override
  Future<Circle> joinByCode(String code) async {
    final wanted = code.trim().toUpperCase();
    final i = _circles.indexWhere((c) => c.inviteCode == wanted);
    if (i < 0) throw const CircleException('No circle has that code.');
    final circle = _circles[i];
    if (circle.hasMember(_me)) return circle;
    return _circles[i] = circle.copyWith(memberIds: [...circle.memberIds, _me]);
  }

  @override
  Future<void> leave(String circleId) async {
    final i = _indexOf(circleId);
    final circle = _circles[i];
    if (!circle.hasMember(_me)) return;
    final rest = [...circle.memberIds]..remove(_me);
    if (rest.isEmpty) {
      _circles.removeAt(i);
    } else if (circle.ownerId == _me) {
      throw const CircleException('Hand the circle to someone else first.');
    } else {
      _circles[i] = _frozen(circle.copyWith(memberIds: rest));
    }
  }

  @override
  Future<Circle> setReward(String circleId, String? text) async {
    final i = _indexOf(circleId);
    final circle = _circles[i];
    if (circle.ownerId != _me) {
      throw const CircleException('Only the owner can change the reward.');
    }
    final trimmed = text?.trim();
    if (trimmed != null && trimmed.length > maxRewardLength) {
      throw const CircleException(
        'Keep the reward under $maxRewardLength characters.',
      );
    }
    return _circles[i] = trimmed == null || trimmed.isEmpty
        ? circle.copyWith(clearReward: true)
        : circle.copyWith(rewardText: trimmed);
  }
}
