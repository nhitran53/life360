import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'published_sharing_repository.dart';
import 'sharing_repository.dart';

/// [SharingRepository] that saves the signed-in user's settings in
/// `users/{uid}/private/settings` (owner-only, see firestore.rules).
///
/// Reads are synchronous, so the settings are cached: call [load] once after
/// creating it. Until it finishes, or if it fails, you get the private
/// defaults. Friends' settings are private to them and can't be read, so
/// everyone but [uid] also gets the defaults (sleep and screen time hidden).
/// What a friend shares is read from their published stats instead
/// (see [PublishedSharingRepository]).
///
/// `pausedUntil` is stored as a Firestore timestamp so firestore.rules can
/// compare it with the request time when it checks published stats against
/// these settings. Older documents hold it as an ISO string; [load] converts
/// those.
class FirestoreSharingRepository extends ChangeNotifier
    implements SharingRepository {
  FirestoreSharingRepository(this._db, {required this.uid});

  final FirebaseFirestore _db;
  final String uid;

  SharingSettings _mine = const SharingSettings();

  /// Set once the user changes something, so a slow [load] can't overwrite it.
  var _changed = false;

  var _loaded = false;

  /// True after [load] read the document (or saved the defaults), or once the user
  /// saved a change. A failed [load] leaves it false.
  @override
  bool get isLoaded => _loaded;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _db.collection('users').doc(uid).collection('private').doc('settings');

  /// How many saves are in flight, and how many were started, so [refresh]
  /// never overwrites a change that hasn't reached the server yet.
  var _saving = 0;
  var _saves = 0;

  static Map<String, dynamic> _toDoc(SharingSettings settings) => {
    ...settings.toJson(),
    'pausedUntil': switch (settings.pausedUntil) {
      final DateTime until => Timestamp.fromDate(until),
      _ => null,
    },
  };

  static SharingSettings _fromDoc(Map<String, dynamic> data) =>
      SharingSettings.fromJson({
        ...data,
        'pausedUntil': switch (data['pausedUntil']) {
          final Timestamp t => t.toDate().toUtc().toIso8601String(),
          final other => other,
        },
      });

  /// An async function, so the write is issued right away and a failure to
  /// start it comes back as a failed future.
  Future<void> _save(SharingSettings settings) async =>
      _doc.set(_toDoc(settings));

  /// Reads the saved settings. A failed read keeps the private defaults and
  /// leaves [isLoaded] false (a later [refresh] tries again).
  ///
  /// When there is no document yet, the default settings are saved, because
  /// firestore.rules rejects published stats for a user with no settings
  /// document. The create happens in a transaction that only writes if the
  /// document is still absent, so settings another device saved meanwhile
  /// are used instead of overwritten. If the create fails the load counts as
  /// failed, so nothing is published until it works.
  Future<void> load() async {
    final Map<String, dynamic>? data;
    try {
      data = await _readOrCreate();
    } on FirebaseException {
      return;
    }
    if (_changed) return;
    final saved = data == null ? _mine : _fromDoc(data);
    _loaded = true;
    // Always announce the first load, so listeners can act on the settings
    // that are now known to be real.
    _mine = saved;
    notifyListeners();
    if (data != null && data['pausedUntil'] is String) {
      // Old format: rewrite it so the rules can read the pause.
      try {
        await _doc.set(_toDoc(saved));
      } on FirebaseException {
        // Tried again on the next change.
      }
    }
  }

  /// The saved settings, or null after saving the defaults because there
  /// were none.
  Future<Map<String, dynamic>?> _readOrCreate() async {
    final existing = (await _doc.get()).data();
    if (existing != null) return existing;
    return _db.runTransaction((transaction) async {
      final current = (await transaction.get(_doc)).data();
      if (current != null) return current;
      transaction.set(_doc, _toDoc(const SharingSettings()));
      return null;
    });
  }

  /// Picks up settings saved from another device. Skipped until the first
  /// [load] succeeded, and discarded if this device saved a change meanwhile.
  /// Listeners are only told when something changed.
  @override
  Future<void> refresh() async {
    if (!_loaded) return load();
    if (_saving > 0) return;
    final savesBefore = _saves;
    final Map<String, dynamic>? data;
    try {
      data = (await _doc.get()).data();
    } on FirebaseException {
      return;
    }
    if (data == null || _saving > 0 || _saves != savesBefore) return;
    final saved = _fromDoc(data);
    if (saved == _mine) return;
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
    _saves++;
    _saving++;
    try {
      // Start saving before announcing the change, so what listeners do in
      // response (publishing stats) is checked against these settings.
      final saving = _save(settings);
      notifyListeners();
      await saving;
    } catch (_) {
      if (_mine == settings) {
        _mine = previous;
        _loaded = wasLoaded;
        notifyListeners();
      }
      rethrow;
    } finally {
      _saving--;
    }
  }
}
