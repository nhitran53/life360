import 'package:flutter/foundation.dart';

import 'mock_circle.dart';

/// The families you belong to, shared by the Circle and Leaderboard screens
/// so a family created on one shows up on the other.
///
/// In memory only for now: new families last until the app restarts.
class FamilyStore extends ChangeNotifier {
  FamilyStore([List<CircleFamily> initial = circleFamilies])
      : _families = [...initial];

  /// The one the app uses. Tests can pass their own store instead.
  static final instance = FamilyStore();

  final List<CircleFamily> _families;

  List<CircleFamily> get families => List.unmodifiable(_families);

  bool contains(CircleFamily family) => _families.any((f) => f.id == family.id);

  void add(CircleFamily family) {
    if (contains(family)) return;
    _families.add(family);
    notifyListeners();
  }
}