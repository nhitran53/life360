part of '../my_stats_screen.dart';

// ---------------------------------------------------------------------------
// HEALTH SOURCE — connect and sync status
// ---------------------------------------------------------------------------

/// Connect / sync status for the health source, with the action that fits
/// the current state.
class _ConnectCard extends StatelessWidget {
  const _ConnectCard({
    required this.stats,
    required this.busy,
    required this.failed,
    required this.onConnect,
    required this.onSelectSource,
    required this.onInstall,
  });

  final ConnectableStatsRepository stats;
  final bool busy;
  final bool failed;
  final VoidCallback onConnect;

  /// Called with the option id when the user picks a data source.
  final ValueChanged<String> onSelectSource;
  final VoidCallback onInstall;

  @override
  Widget build(BuildContext context) {
    final source = stats.sourceName;
    final theme = Theme.of(context).textTheme;
    final denied = stats.deniedMetrics;
    final deniedNames = [
      for (final m in StatMetric.values)
        if (denied.contains(m)) m.label,
    ];

    final String title;
    final String message;
    final IconData icon;
    final Color iconColor;
    String? installLabel;

    if (failed) {
      title = "Couldn't reach $source";
      message = 'Something went wrong. Try again.';
      icon = Icons.error_outline;
      iconColor = AppColors.red;
    } else if (stats.isConnected) {
      title = '$source connected';
      final at = stats.lastSyncedAt;
      final synced = at == null
          ? 'Synced'
          : 'Synced at ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(at))}';
      message = deniedNames.isEmpty
          ? synced
          : '$synced. ${deniedNames.join(', ')} not allowed: turn '
                '${deniedNames.length == 1 ? 'it' : 'them'} on in $source, '
                'then sync again.';
      icon = deniedNames.isEmpty ? Icons.check_circle : Icons.info_outline;
      iconColor = deniedNames.isEmpty ? AppColors.primary : AppColors.orange;
    } else {
      switch (stats.availability) {
        case HealthAvailability.notInstalled:
          title = '$source is not installed';
          message = 'Install $source, then come back to sync your stats.';
          installLabel = 'Install $source';
        case HealthAvailability.updateRequired:
          title = '$source needs an update';
          message = 'Update $source, then come back to sync your stats.';
          installLabel = 'Update $source';
        case HealthAvailability.unsupported:
          title = '$source is not available';
          message = "This device can't sync health stats. Showing demo data.";
        case HealthAvailability.blockedInBuild:
          title = "$source isn't available in this build";
          message = stats.sourceOptions.any((o) => o.id == takeoutOptionId)
              ? "Sideloaded builds can't read $source. Use Google Health "
                    '(Takeout) instead.'
              : '$source needs a signed build with HealthKit.';
        case HealthAvailability.available:
          title = 'No access to $source';
          message = 'Allow reading your stats in $source, then try again.';
        case null:
          title = 'Showing demo data';
          message = 'Connect $source to sync your real stats.';
      }
      icon = stats.availability == null ? Icons.sync : Icons.warning_amber;
      iconColor = stats.availability == null
          ? AppColors.blue
          : AppColors.orange;
    }

    final selectedNote = stats.sourceOptions
        .where((o) => o.id == stats.selectedSourceId)
        .firstOrNull
        ?.note;
    final unsupported =
        stats.availability == HealthAvailability.unsupported ||
        stats.availability == HealthAvailability.blockedInBuild;
    return ChunkyCard(
      key: const ValueKey('connect-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: theme.titleMedium)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            selectedNote == null ? message : '$message $selectedNote.',
            style: theme.bodyMedium?.copyWith(color: AppColors.inkSoft),
          ),
          if (stats.sourceOptions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Data source', style: theme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in stats.sourceOptions)
                  _SourceOptionButton(
                    option: option,
                    selected: option.id == stats.selectedSourceId,
                    onPressed: busy ? null : () => onSelectSource(option.id),
                  ),
              ],
            ),
          ],
          if (!unsupported) ...[
            const SizedBox(height: 12),
            if (installLabel != null) ...[
              ChunkyButton(
                key: const ValueKey('install-button'),
                label: installLabel,
                icon: Icons.download,
                onPressed: busy ? null : onInstall,
              ),
              const SizedBox(height: 8),
            ],
            installLabel != null
                ? ChunkyButton.secondary(
                    key: const ValueKey('connect-button'),
                    label: 'Try again',
                    onPressed: busy ? null : onConnect,
                  )
                : ChunkyButton(
                    key: const ValueKey('connect-button'),
                    label: busy
                        ? 'Syncing…'
                        : stats.isConnected
                        ? 'Sync now'
                        : 'Connect $source',
                    icon: stats.isConnected ? Icons.sync : Icons.favorite,
                    onPressed: busy ? null : onConnect,
                  ),
          ],
        ],
      ),
    );
  }
}

/// One "Data source" choice. A source for another platform is disabled and
/// says which platform it needs.
class _SourceOptionButton extends StatelessWidget {
  const _SourceOptionButton({
    required this.option,
    required this.selected,
    required this.onPressed,
  });

  final HealthSourceOption option;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final note = option.unavailableNote;
    final onTap = option.isAvailable ? onPressed : null;
    return SizedBox(
      width: 160,
      child: Column(
        children: [
          selected && option.isAvailable
              ? ChunkyButton(
                  key: ValueKey('source-${option.id}'),
                  label: option.label,
                  onPressed: onTap,
                )
              : ChunkyButton.secondary(
                  key: ValueKey('source-${option.id}'),
                  label: option.label,
                  onPressed: onTap,
                ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                note,
                key: ValueKey('source-note-${option.id}'),
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.muted),
              ),
            ),
        ],
      ),
    );
  }
}
