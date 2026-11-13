import 'package:flutter/material.dart';

import '../data/account_session.dart';
import '../data/mock_data.dart';
import '../data/sharing_repository.dart';
import '../models/models.dart';
import '../theme/circle_colors.dart';
import 'account_screen.dart';
import 'privacy_policy_screen.dart';
import '../widgets/circle_widgets.dart';

// ---------------------------------------------------------------------------
// SHARING & PRIVACY — connected device, what you share and who sees it
// ---------------------------------------------------------------------------

/// One line under each stat's name, in the order of [StatMetric.values].
String _shareSubtitle(StatMetric metric) => switch (metric) {
  StatMetric.steps => 'Counts toward the Steps board',
  StatMetric.sleep => 'Duration only, never stages',
  StatMetric.workout => 'Workout minutes and streaks',
  StatMetric.calories => 'Active calories burned',
  StatMetric.screenTime => 'Daily total, if you track it',
};

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
  const PrivacyScreen({super.key, this.sharing, this.userId, this.clock});

  /// Where the choices are saved. Defaults to an in-memory mock.
  final SharingRepository? sharing;

  /// Whose settings these are. Defaults to the mock current user.
  final String? userId;

  final DateTime Function()? clock;

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  late final SharingRepository _repo =
      widget.sharing ?? (_ownRepo = MockSharingRepository());
  MockSharingRepository? _ownRepo;

  late final String _userId = widget.userId ?? mockMe.id;
  late final DateTime Function() _clock = widget.clock ?? DateTime.now;

  SharingSettings get _settings => _repo.settingsFor(_userId);

  @override
  void dispose() {
    _ownRepo?.dispose();
    super.dispose();
  }

  /// Saves [settings]; the repository shows them right away and puts the
  /// old ones back if saving fails.
  Future<void> _save(SharingSettings settings) async {
    try {
      await _repo.update(_userId, settings);
    } on Exception {
      if (mounted) showCircleSnack(context, "Couldn't save that. Try again.");
    }
  }

  void _toggle(StatMetric metric) {
    final shared = !_settings.hidden.contains(metric);
    _save(_settings.withShared(metric, !shared));
  }

  void _togglePause() {
    final now = _clock();
    final pausing = !_settings.isPaused(now);
    _save(
      _settings.withPause(pausing ? now.add(const Duration(hours: 24)) : null),
    );
    showCircleSnack(
      context,
      pausing ? 'Sharing paused for 24 h' : 'Sharing is back on',
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: _repo, builder: _build);
  }

  Widget _build(BuildContext context, Widget? _) {
    final settings = _settings;
    final paused = settings.isPaused(_clock());

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
          _FitbitCard(
            paused: paused,
            onManage: () =>
                showCircleSnack(context, 'Managing Fitbit is coming soon 👀'),
          ),
          const SizedBox(height: 14),
          _Section(
            label: 'What you share',
            rowHeight: 54,
            rows: [
              for (final metric in StatMetric.values)
                _SettingRow(
                  title: metric.label,
                  subtitle: _shareSubtitle(metric),
                  trailing: _Switch(value: !settings.hidden.contains(metric)),
                  toggled: !settings.hidden.contains(metric),
                  onTap: () => _toggle(metric),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            paused
                ? 'Paused: friends see none of your stats for now 🔒'
                : "Private stats stay off friends' screens and leaderboards 🔒",
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: CircleColors.secondary,
            ),
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
                  label: paused ? 'Resume sharing' : 'Pause for 24 h',
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
                  onPressed: () => showCircleSnack(
                    context,
                    'Disconnecting Fitbit is coming soon 👀',
                  ),
                ),
              ),
            ],
          ),
          if (AccountScope.maybeOf(context) != null) ...[
            const SizedBox(height: 10),
            CirclePillButton(
              label: 'Account',
              height: 48,
              fontSize: 14,
              horizontalPadding: 16,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AccountScreen()),
              ),
            ),
          ],
          const SizedBox(height: 10),
          CirclePillButton(
            label: 'Privacy policy',
            height: 48,
            fontSize: 14,
            horizontalPadding: 16,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PrivacyPolicyScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FitbitCard extends StatelessWidget {
  const _FitbitCard({required this.paused, required this.onManage});

  final bool paused;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
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
              color: CircleColors.okBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const CircleSvg('icon_link', size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Google Fitbit',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: CircleColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  paused
                      ? 'Paused · sharing resumes in 24 h'
                      : 'Connected · last sync 2 min ago',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: paused
                        ? CircleColors.secondary
                        : CircleColors.okTextDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          CirclePillButton(label: 'Manage', onPressed: onManage),
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
