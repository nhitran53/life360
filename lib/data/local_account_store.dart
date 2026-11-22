import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Saves the mock accounts and profiles on the device, so signing up on a
/// platform without Firebase (Linux, web, desktop) survives an app restart.
///
/// Each repository keeps one JSON document under its own key.
abstract interface class LocalAccountStore {
  Future<Map<String, dynamic>?> load(String key);

  Future<void> save(String key, Map<String, dynamic> data);
}

/// Keeps the documents in memory only. Handy for tests.
class InMemoryLocalAccountStore implements LocalAccountStore {
  final _docs = <String, String>{};

  @override
  Future<Map<String, dynamic>?> load(String key) async {
    final raw = _docs[key];
    return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
  }

  @override
  Future<void> save(String key, Map<String, dynamic> data) async =>
      _docs[key] = jsonEncode(data);
}

/// Stores the documents in `shared_preferences` (on device, app-private).
class SharedPreferencesLocalAccountStore implements LocalAccountStore {
  static const _prefix = 'local_accounts.';

  @override
  Future<Map<String, dynamic>?> load(String key) async {
    final raw = (await SharedPreferences.getInstance()).getString(
      '$_prefix$key',
    );
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } on FormatException {
      // A broken save shouldn't stop the app from starting.
      return null;
    }
  }

  @override
  Future<void> save(String key, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$key', jsonEncode(data));
  }
}
