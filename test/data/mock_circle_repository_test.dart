import 'package:flutter_test/flutter_test.dart';
import 'package:life360/data/circle_repository.dart';
import 'package:life360/data/mock_circle_repository.dart';
import 'package:life360/models/models.dart';

void main() {
  test('lists only circles the user is in', () async {
    final names = (await MockCircleRepository().circles()).map((c) => c.name);
    expect(names, ['Gym crew', 'Dorm floor']);
  });

  test('create adds the user as owner and only member', () async {
    final repo = MockCircleRepository();
    final c = await repo.create('  Couple  ', CircleType.couple);
    expect(c.name, 'Couple');
    expect(c.memberIds, ['u_me']);
    expect(c.ownerId, 'u_me');
    expect(
      await repo.circles(),
      contains(predicate<Circle>((x) => x.id == c.id)),
    );
    expect(
      () => repo.create(' ', CircleType.friends),
      throwsA(isA<CircleException>()),
    );
  });

  test('join by code is case-insensitive; unknown code fails', () async {
    final repo = MockCircleRepository();
    final c = await repo.joinByCode(' fam777 ');
    expect(c.hasMember('u_me'), isTrue);
    expect((await repo.circles()).length, 3);
    expect(() => repo.joinByCode('nope'), throwsA(isA<CircleException>()));
  });

  test(
    'leave: member leaves, owner with others cannot, last one deletes',
    () async {
      final repo = MockCircleRepository();
      await repo.leave('c_dorm');
      expect((await repo.circles()).map((c) => c.id), ['c_gym']);
      expect(() => repo.leave('c_gym'), throwsA(isA<CircleException>()));
      final solo = await repo.create('Solo', CircleType.friends);
      await repo.leave(solo.id);
      expect((await repo.circles()).any((c) => c.id == solo.id), isFalse);
    },
  );

  test('setReward: owner only, trims, clears, length limit', () async {
    final repo = MockCircleRepository();
    expect(
      (await repo.setReward('c_gym', '  Free coffee ')).rewardText,
      'Free coffee',
    );
    expect((await repo.setReward('c_gym', '  ')).rewardText, isNull);
    expect(
      () => repo.setReward('c_gym', 'x' * 81),
      throwsA(isA<CircleException>()),
    );
    expect(
      () => repo.setReward('c_dorm', 'Hi'),
      throwsA(isA<CircleException>()),
    );
  });

  test('returned circles cannot be edited or leak into other repos', () async {
    final repo = MockCircleRepository();
    final gym = (await repo.circles()).first;
    expect(() => gym.memberIds.clear(), throwsUnsupportedError);
    expect((await MockCircleRepository().circles()).first.memberIds.length, 4);
  });
}
