import 'package:flutter/material.dart';

import '../data/account_session.dart';
import '../data/mock_data.dart';
import '../data/sharing_repository.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
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
  const _Audience(this.emoji, this.name, this.size, this.access);

  final String emoji;
  final String name;
  final String size;
  final String access;
}

const _audiences = [
  _Audience('👪', 'Tran family', '5 members', 'Everything shared'),
  _Audience('🚶', 'Morning walkers', '8 friends', 'Steps only'),
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
    final sharedCount = StatMetric.values
        .where((m) => !settings.hidden.contains(m))
        .length;
    final signedIn = AccountScope.maybeOf(context) != null;

    void push(Widget page) => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CircleTitle(
            title: 'Sharing & privacy',
            subtitle: 'You decide who sees what. Change it anytime.',
          ),
          const SizedBox(height: 20),

          // 1. Where your stats come from
          const CircleGroupLabel('Connected device'),
          _FitbitCard(
            paused: paused,
            onManage: () =>
                showCircleSnack(context, 'Managing Fitbit is coming soon 👀'),
          ),
          const SizedBox(height: 22),

          // 2. Which stats leave your phone
          CircleGroupLabel(
            'What you share',
            trailing: '$sharedCount of ${StatMetric.values.length} on',
          ),
          CircleGroup(
            rows: [
              for (final metric in StatMetric.values)
                _SettingRow(
                  leading: CircleEmojiBubble(metric.emoji),
                  title: metric.label,
                  subtitle: _shareSubtitle(metric),
                  trailing: CircleSwitch(value: !settings.hidden.contains(metric)),
                  toggled: !settings.hidden.contains(metric),
                  onTap: () => _toggle(metric),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              paused
                  ? 'Paused: friends see none of your stats for now 🔒'
                  : "Private stats stay off friends' screens and leaderboards 🔒",
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: CircleColors.secondary,
              ),
            ),
          ),
          const SizedBox(height: 22),

          // 3. Which circles see them
          const CircleGroupLabel('Who can see it'),
          CircleGroup(
            rows: [
              for (final audience in _audiences)
                _SettingRow(
                  leading: CircleEmojiBubble(audience.emoji),
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
          const SizedBox(height: 22),

          // 4. Take a break
          const CircleGroupLabel('Take a break'),
          CircleGroup(
            rows: [
              _SettingRow(
                leading: CircleEmojiBubble(paused ? '⏸️' : '🌙'),
                title: paused ? 'Sharing is paused' : 'Pause sharing',
                subtitle: paused
                    ? 'Back on automatically in 24 h'
                    : 'Hide all your stats for a day',
                trailing: CirclePillButton(
                  label: paused ? 'Resume sharing' : 'Pause for 24 h',
                  filled: paused,
                  horizontalPadding: 12,
                  onPressed: _togglePause,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // 5. Account and legal
          const CircleGroupLabel('Account & legal'),
          CircleGroup(
            rows: [
              if (signedIn)
                _NavRow(
                  icon: Icons.person_rounded,
                  label: 'Account',
                  onTap: () => push(const AccountScreen()),
                ),
              _NavRow(
                icon: Icons.description_rounded,
                label: 'Privacy policy',
                onTap: () => push(const PrivacyPolicyScreen()),
              ),
              _NavRow(
                icon: Icons.link_off_rounded,
                label: 'Disconnect Fitbit',
                danger: true,
                onTap: () => showCircleSnack(
                  context,
                  'Disconnecting Fitbit is coming soon 👀',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PIECES
// ---------------------------------------------------------------------------

class _FitbitCard extends StatelessWidget {
  const _FitbitCard({required this.paused, required this.onManage});

  final bool paused;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return CircleGroup(
      rows: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: CircleColors.okBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const CircleSvg('icon_link', size: 20),
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
                    const SizedBox(height: 4),
                    _StatusChip(paused: paused),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              CirclePillButton(label: 'Manage', onPressed: onManage),
            ],
          ),
        ),
      ],
    );
  }
}

/// "● Connected · synced 2 min ago" or "● Paused · back in 24 h".
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.paused});

  final bool paused;

  @override
  Widget build(BuildContext context) {
    final color = paused ? CircleColors.secondary : CircleColors.okTextDark;
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: paused ? CircleColors.muted : AppColors.primary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            paused
                ? 'Paused · sharing resumes in 24 h'
                : 'Connected · last sync 2 min ago',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.toggled,
    this.onTap,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final Widget trailing;

  /// Set for switch rows so screen readers announce on/off.
  final bool? toggled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 14),
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
                const SizedBox(height: 1),
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

/// A row that opens something: icon, label, chevron.
class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Red, for things like disconnecting.
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? CircleColors.heart : CircleColors.ink;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: danger
                      ? CircleColors.dangerOutline.withValues(alpha: 0.35)
                      : AppColors.primaryTint,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 19, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: danger ? CircleColors.heart : CircleColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}