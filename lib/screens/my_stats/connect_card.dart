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
    required this.onInstall,
  });

  final ConnectableStatsRepository stats;
  final bool busy;
  final bool failed;
  final VoidCallback onConnect;
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

    final unsupported = stats.availability == HealthAvailability.unsupported;
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
            message,
            style: theme.bodyMedium?.copyWith(color: AppColors.inkSoft),
          ),
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
