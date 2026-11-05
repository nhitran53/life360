import 'package:flutter/material.dart';

import '../data/health_source.dart';
import '../data/health_sync.dart';
import '../theme/circle_colors.dart';
import '../widgets/circle_widgets.dart';

// ---------------------------------------------------------------------------
// SHARING & PRIVACY — connected device, what you share and who sees it
// ---------------------------------------------------------------------------

class _ShareOption {
  const _ShareOption(this.title, this.subtitle);

  final String title;
  final String subtitle;
}

const _shareOptions = [
  _ShareOption('Heart rate', 'Live bpm and resting average'),
  _ShareOption('Steps & distance', 'Counts toward leaderboards'),
  _ShareOption('Active minutes', 'Workouts and activity status'),
  _ShareOption('Sleep', 'Duration only, never stages'),
];

class _Audience {
  const _Audience(this.name, this.size, this.access);

  final String name;
  final String size;
  final String access;
}

const _audiences = [
  _Audience('Tran family', '5 members', 'Everything shared'),
  _Audience('Morning walkers', '8 friends', 'Steps only'),
];

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  /// One per [_shareOptions]. Sleep is private until the user opts in.
  final _sharing = [true, true, true, false];

  bool _paused = false;

  void _togglePause() {
    setState(() => _paused = !_paused);
    showCircleSnack(
      context,
      _paused ? 'Sharing paused for 24 h' : 'Sharing is back on',
    );
  }

  Future<void> _disconnect() async {
    final health = HealthScope.of(context);
    if (!health.isConnected) {
      showCircleSnack(context, 'Nothing is connected yet');
      return;
    }
    await health.disconnect();
    if (!mounted) return;
    showCircleSnack(
      context,
      health.source.name == 'Apple Health'
          ? 'Disconnected. To remove access fully: Health app → Sharing → Apps'
          : 'Disconnected from ${health.source.name}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CircleTitle(
            title: 'Sharing & privacy',
            subtitle: 'You decide who sees what. Change it anytime.',
          ),
          const SizedBox(height: 14),
          _HealthCard(paused: _paused),
          const SizedBox(height: 14),
          _Section(
            label: 'What you share',
            rowHeight: 54,
            rows: [
              for (var i = 0; i < _shareOptions.length; i++)
                _SettingRow(
                  title: _shareOptions[i].title,
                  subtitle: _shareOptions[i].subtitle,
                  trailing: _Switch(value: _sharing[i]),
                  toggled: _sharing[i],
                  onTap: () => setState(() => _sharing[i] = !_sharing[i]),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            label: 'Who can see it',
            rowHeight: 58,
            rows: [
              for (final audience in _audiences)
                _SettingRow(
                  title: audience.name,
                  subtitle: audience.size,
                  trailing: CirclePillButton(
                    label: audience.access,
                    horizontalPadding: 12,
                    onPressed: () => showCircleSnack(
                      context,
                      'Choosing what ${audience.name} sees is coming soon 👀',
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: CirclePillButton(
                  label: _paused ? 'Resume sharing' : 'Pause for 24 h',
                  height: 48,
                  fontSize: 14,
                  horizontalPadding: 16,
                  onPressed: _togglePause,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CirclePillButton(
                  label: 'Disconnect',
                  height: 48,
                  fontSize: 14,
                  horizontalPadding: 16,
                  borderColor: CircleColors.dangerOutline,
                  textColor: CircleColors.heart,
                  onPressed: _disconnect,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The phone's health hub (Apple Health / Health Connect): connect, sync,
/// or install Health Connect on Android.
class _HealthCard extends StatelessWidget {
  const _HealthCard({required this.paused});

  final bool paused;

  @override
  Widget build(BuildContext context) {
    final health = HealthScope.of(context);
    final connected = health.isConnected;

    final (String status, Color statusColor) = switch (health.connection) {
      _ when paused => ('Paused · sharing resumes in 24 h', CircleColors.secondary),
      _ when health.busy => ('Syncing…', CircleColors.secondary),
      HealthConnection.connected when health.syncFailed =>
        ("Couldn't sync · tap Sync to retry", CircleColors.heart),
      HealthConnection.connected => (
          'Connected · last sync ${syncedAgo(health.lastSynced)}',
          CircleColors.okTextDark,
        ),
      HealthConnection.notConnected =>
        ('Not connected · your watch syncs through it', CircleColors.secondary),
      HealthConnection.needsInstall =>
        ('Install Health Connect to sync your watch', CircleColors.secondary),
      HealthConnection.unsupported =>
        ('Open Friend 360 on your phone to sync', CircleColors.secondary),
    };

    final String? action = switch (health.connection) {
      HealthConnection.connected => 'Sync',
      HealthConnection.notConnected => 'Connect',
      HealthConnection.needsInstall => 'Install',
      HealthConnection.unsupported => null,
    };

    Future<void> onAction() async {
      switch (health.connection) {
        case HealthConnection.connected:
          await health.refresh();
        case HealthConnection.notConnected:
          final ok = await health.connect();
          if (!ok && context.mounted) {
            showCircleSnack(context, 'No access yet. You can allow it anytime 🙂');
          }
        case HealthConnection.needsInstall:
          await health.installProvider();
        case HealthConnection.unsupported:
          break;
      }
    }

    return CircleCard(
      radius: 18,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: connected
                  ? CircleColors.okBackground
                  : CircleColors.divider,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const CircleSvg('icon_link', size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  health.source.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: CircleColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: 12),
            CirclePillButton(
              label: action,
              filled: !connected,
              onPressed: health.busy ? () {} : onAction,
            ),
          ],
        ],
      ),
    );
  }
}

/// White card with a small label and divided rows.
class _Section extends StatelessWidget {
  const _Section({
    required this.label,
    required this.rowHeight,
    required this.rows,
  });

  final String label;
  final double rowHeight;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return CircleCard(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CircleSectionLabel(label),
          for (var i = 0; i < rows.length; i++)
            Container(
              constraints: BoxConstraints(minHeight: rowHeight),
              decoration: i == rows.length - 1
                  ? null
                  : const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: CircleColors.divider),
                      ),
                    ),
              child: rows[i],
            ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.toggled,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final Widget trailing;

  /// Set for switch rows so screen readers announce on/off.
  final bool? toggled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: CircleColors.ink,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: CircleColors.secondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing,
        ],
      ),
    );

    final onTap = this.onTap;
    if (onTap == null) return row;
    return Semantics(
      toggled: toggled,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch({required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    return CircleSvg(value ? 'switch_on' : 'switch_off', size: 46, height: 28);
  }
}
