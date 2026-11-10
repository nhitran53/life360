import 'package:shared_preferences/shared_preferences.dart';

/// Remembers across app restarts whether the user connected their health
/// platform. Stores one flag only, never any health values.
abstract interface class HealthConnectionStore {
  Future<bool> loadConnected();

  Future<void> saveConnected(bool connected);
}

/// Keeps the flag in memory only. Used by tests and when nothing is injected.
class InMemoryHealthConnectionStore implements HealthConnectionStore {
  InMemoryHealthConnectionStore({this._connected = false});

  bool _connected;

  @override
  Future<bool> loadConnected() async => _connected;

  @override
  Future<void> saveConnected(bool connected) async => _connected = connected;
}

/// Stores the flag in `shared_preferences` (on device, app-private).
class SharedPreferencesHealthConnectionStore implements HealthConnectionStore {
  static const _key = 'health_connected';

  @override
  Future<bool> loadConnected() async =>
      (await SharedPreferences.getInstance()).getBool(_key) ?? false;

  @override
  Future<void> saveConnected(bool connected) async {
    final prefs = await SharedPreferences.getInstance();
    if (connected) {
      await prefs.setBool(_key, true);
    } else {
      await prefs.remove(_key);
    }
  }
}
