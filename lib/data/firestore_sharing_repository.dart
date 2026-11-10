import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'sharing_repository.dart';

/// [SharingRepository] that saves the signed-in user's settings in
/// `users/{uid}/private/settings` (owner-only, see firestore.rules).
///
/// Reads are synchronous, so the settings are cached: call [load] once after
/// creating it. Until it finishes, or if it fails, you get the private
/// defaults. Friends' settings are private to them and can't be read, so
/// everyone but [uid] also gets the defaults (sleep and screen time hidden).
class FirestoreSharingRepository extends ChangeNotifier
    implements SharingRepository {
  FirestoreSharingRepository(this._db, {required this.uid});

  final FirebaseFirestore _db;
  final String uid;

  SharingSettings _mine = const SharingSettings();

  /// Set once the user changes something, so a slow [load] can't overwrite it.
  var _changed = false;

  var _loaded = false;

  /// True after [load] read the document (or found none), or once the user
  /// saved a change. A failed [load] leaves it false.
  @override
  bool get isLoaded => _loaded;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _db.collection('users').doc(uid).collection('private').doc('settings');

  /// Reads the saved settings. A missing or unreadable document keeps the
  /// private defaults.
  Future<void> load() async {
    final Map<String, dynamic>? data;
    try {
      data = (await _doc.get()).data();
    } on FirebaseException {
      return;
    }
    if (_changed) return;
    final saved = data == null ? _mine : SharingSettings.fromJson(data);
    _loaded = true;
    // Always announce the first load, so listeners can act on the settings
    // that are now known to be real.
    _mine = saved;
    notifyListeners();
  }

  @override
  SharingSettings settingsFor(String userId) =>
      userId == uid ? _mine : const SharingSettings();

  /// Shows the change right away, then saves it. If saving fails the
  /// previous settings come back and the error is rethrown.
  @override
  Future<void> update(String userId, SharingSettings settings) async {
    if (userId != uid) {
      throw ArgumentError.value(userId, 'userId', 'Not the signed-in user');
    }
    final previous = _mine;
    final wasLoaded = _loaded;
    if (previous == settings && wasLoaded) return;
    _changed = true;
    _loaded = true;
    _mine = settings;
    notifyListeners();
    try {
      await _doc.set(settings.toJson());
    } catch (_) {
      if (_mine == settings) {
        _mine = previous;
        _loaded = wasLoaded;
        notifyListeners();
      }
      rethrow;
    }
  }
}
