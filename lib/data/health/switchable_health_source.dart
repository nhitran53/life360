import 'package:flutter/foundation.dart';

import '../../models/models.dart';
import 'health_source.dart';

/// One choice in the "Data source" row of My Stats.
@immutable
class HealthSourceOption {
  const HealthSourceOption({
    required this.id,
    required this.label,
    required this.source,
    this.unavailableNote,
    this.note,
  });

  /// Stable key, e.g. `apple-health`.
  final String id;

  /// Button text, e.g. "Apple Health".
  final String label;

  final HealthSource source;

  /// Set when this option can't be used on this device ("iOS only"). The
  /// button is shown disabled with this text under it.
  final String? unavailableNote;

  /// Extra line shown on the connect card while this option is selected.
  final String? note;

  bool get isAvailable => unavailableNote == null;
}

/// [HealthSource] that forwards to whichever of its [options] is selected, so
/// the user can pick the data source at runtime.
class SwitchableHealthSource implements HealthSource {
  SwitchableHealthSource({
    required List<HealthSourceOption> options,
    String? selectedId,
  }) : options = List.unmodifiable(options),
       assert(options.isNotEmpty),
       _selected = options.firstWhere(
         (o) => o.id == selectedId,
         orElse: () => options.first,
       );

  final List<HealthSourceOption> options;
  HealthSourceOption _selected;

  HealthSourceOption get selected => _selected;

  /// Makes the option with [id] the active source. Throws [ArgumentError] for
  /// an unknown id or an option that [HealthSourceOption.isAvailable] rules out.
  void select(String id) {
    final option = options.where((o) => o.id == id).firstOrNull;
    if (option == null || !option.isAvailable) {
      throw ArgumentError.value(id, 'id', 'Not a usable source option');
    }
    _selected = option;
  }

  HealthSource get _source => _selected.source;

  @override
  String get displayName => _source.displayName;

  @override
  Set<StatMetric> get readableMetrics => _source.readableMetrics;

  @override
  Future<HealthAvailability> availability() => _source.availability();

  @override
  Future<void> openInstallPage() => _source.openInstallPage();

  @override
  Future<HealthPermissionResult> requestPermissions() =>
      _source.requestPermissions();

  @override
  Future<HealthPermissionResult> checkPermissions() =>
      _source.checkPermissions();

  @override
  Future<List<DailyStats>> fetchDailyStats(
    String userId, {
    required DateTime from,
    required DateTime to,
  }) => _source.fetchDailyStats(userId, from: from, to: to);
}

/// The My Stats source choices for this device.
///
/// Apple Health and Health Connect are both always listed; the one that
/// belongs to the other platform is disabled. Both use [platformSource]
/// (the health package picks the store by platform). Off a phone neither can
/// be used, so [demoSource] stands in. [takeout] adds the dev-only Google
/// Health (Takeout) option and, when given, is selected first.
SwitchableHealthSource buildHealthSourceOptions({
  required TargetPlatform platform,
  required bool isWeb,
  required HealthSource platformSource,
  required HealthSource demoSource,
  HealthSource? takeout,
  String? takeoutNote,
}) {
  final onIos = !isWeb && platform == TargetPlatform.iOS;
  final onAndroid = !isWeb && platform == TargetPlatform.android;
  final real = onIos || onAndroid ? platformSource : demoSource;
  return SwitchableHealthSource(
    options: [
      HealthSourceOption(
        id: appleHealthOptionId,
        label: 'Apple Health',
        source: real,
        unavailableNote: onIos ? null : 'iOS only',
      ),
      HealthSourceOption(
        id: healthConnectOptionId,
        label: onIos ? 'Google Health Connect' : 'Health Connect',
        source: real,
        unavailableNote: onAndroid
            ? null
            : onIos && takeout != null
            ? 'Android only; on iPhone use Google Health (Takeout)'
            : 'Android only',
      ),
      if (takeout != null)
        HealthSourceOption(
          id: takeoutOptionId,
          label: 'Google Health (Takeout)',
          source: takeout,
          note: takeoutNote,
        ),
    ],
    selectedId: takeout != null
        ? takeoutOptionId
        : onIos
        ? appleHealthOptionId
        : healthConnectOptionId,
  );
}

const appleHealthOptionId = 'apple-health';
const healthConnectOptionId = 'health-connect';
const takeoutOptionId = 'takeout';
