import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'mock_data.dart';

/// Each user's [SharingSettings]. Will be backed by Firestore later
/// (`users/{uid}/private/settings`).
///
/// It's a [Listenable] so screens and stats can react when the current user
/// changes what they share.
abstract interface class SharingRepository implements Listenable {
  /// The settings for [userId]; defaults for anyone who never changed them.
  SharingSettings settingsFor(String userId);

  /// Saves the current user's settings.
  Future<void> update(String userId, SharingSettings settings);
}

/// In-memory [SharingRepository]. Changes last for the app session.
class MockSharingRepository extends ChangeNotifier
    implements SharingRepository {
  MockSharingRepository({Map<String, SharingSettings>? initial})
    : _settings = {...(initial ?? mockSharing)};

  final Map<String, SharingSettings> _settings;

  @override
  SharingSettings settingsFor(String userId) =>
      _settings[userId] ?? const SharingSettings();

  @override
  Future<void> update(String userId, SharingSettings settings) async {
    if (settingsFor(userId) == settings) return;
    _settings[userId] = settings;
    notifyListeners();
  }
}

/// A few friends who opted in to sharing sleep or screen time, so those
/// boards aren't empty. Everyone else keeps the private defaults.
final mockSharing = <String, SharingSettings>{
  'u_alex': const SharingSettings(hidden: {StatMetric.screenTime}),
  'u_bree': const SharingSettings(hidden: {}),
  'u_dana': const SharingSettings(hidden: {StatMetric.screenTime}),
  'u_eli': const SharingSettings(hidden: {StatMetric.sleep}),
  // Shares only steps.
  'u_chris': const SharingSettings(
    hidden: {
      StatMetric.sleep,
      StatMetric.workout,
      StatMetric.calories,
      StatMetric.screenTime,
    },
  ),
  mockMe.id: const SharingSettings(),
};
