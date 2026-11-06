import '../models/models.dart';

/// The circles the current user belongs to. Screens depend on this, not on a
/// backend; [MockCircleRepository] is the only implementation for now.
abstract interface class CircleRepository {
  /// Circles the current user is a member of.
  Future<List<Circle>> circles();

  /// Makes a new circle owned by the current user.
  Future<Circle> create(String name, CircleType type);

  /// Joins the circle with this invite code (case-insensitive).
  /// Throws [CircleException] for an unknown code.
  Future<Circle> joinByCode(String code);

  /// Leaves a circle. The owner can't leave while others remain.
  Future<void> leave(String circleId);

  /// Sets or, with null/blank text, clears the reward. Owner only.
  Future<Circle> setReward(String circleId, String? text);
}

class CircleException implements Exception {
  const CircleException(this.message);
  final String message;

  @override
  String toString() => 'CircleException: $message';
}
