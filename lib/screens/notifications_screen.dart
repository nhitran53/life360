import 'package:flutter/material.dart';

import '../data/mock_circle.dart';
import '../data/mock_notifications.dart';
import '../theme/app_colors.dart';
import '../theme/circle_colors.dart';
import '../widgets/circle_widgets.dart';

// ---------------------------------------------------------------------------
// NOTIFICATIONS — opened from the bell on the Circle home
// ---------------------------------------------------------------------------

enum _Filter { all, goals, nudges }

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    this.notifications = mockNotifications,
    this.unreadIds = const {},
    this.onNudgeBack,
  });

  final List<CircleNotification> notifications;

  /// Highlighted as new.
  final Set<String> unreadIds;

  /// "Nudge back" on a nudge. The screen closes itself first.
  final ValueChanged<CircleMember>? onNudgeBack;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  var _filter = _Filter.all;

  List<CircleNotification> get _visible => [
    for (final n in widget.notifications)
      if (_filter == _Filter.all ||
          (_filter == _Filter.goals && !n.isNudge) ||
          (_filter == _Filter.nudges && n.isNudge))
        n,
  ];

  void _nudgeBack(CircleMember member) {
    Navigator.of(context).maybePop();
    widget.onNudgeBack?.call(member);
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final today = [for (final n in visible) if (n.today) n];
    final earlier = [for (final n in visible) if (!n.today) n];
    final newCount = widget.unreadIds.length;

    return Scaffold(
      backgroundColor: AppColors.primaryTint,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
                style: IconButton.styleFrom(
                  backgroundColor: CircleColors.surface,
                  side: const BorderSide(color: CircleColors.border),
                ),
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: CircleColors.ink,
                ),
              ),
            ),
            const SizedBox(height: 12),
            CircleTitle(
              title: 'Notifications',
              subtitle: newCount == 0
                  ? 'Goals hit and nudges from your circle'
                  : '$newCount new · goals hit and nudges from your circle',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                for (final f in _Filter.values) ...[
                  _FilterChip(
                    label: switch (f) {
                      _Filter.all => 'All',
                      _Filter.goals => 'Goals',
                      _Filter.nudges => 'Nudges',
                    },
                    selected: f == _filter,
                    onTap: () => setState(() => _filter = f),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
            if (visible.isEmpty) ...[
              const SizedBox(height: 32),
              const Center(
                child: Text(
                  'Nothing here yet 👀',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: CircleColors.secondary,
                  ),
                ),
              ),
            ],
            for (final (label, group) in [('Today', today), ('Earlier', earlier)])
              if (group.isNotEmpty) ...[
                const SizedBox(height: 20),
                CircleSectionLabel(label),
                for (final n in group) ...[
                  const SizedBox(height: 8),
                  _NotificationRow(
                    notification: n,
                    unread: widget.unreadIds.contains(n.id),
                    onNudgeBack: n.isNudge && n.from != null
                        ? () => _nudgeBack(n.from!)
                        : null,
                  ),
                ],
              ],
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.primary : CircleColors.surface,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? AppColors.primary : CircleColors.border,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : CircleColors.secondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.notification,
    required this.unread,
    this.onNudgeBack,
  });

  final CircleNotification notification;
  final bool unread;
  final VoidCallback? onNudgeBack;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final from = n.from;
    final onNudgeBack = this.onNudgeBack;

    return Container(
      key: ValueKey('notification-${n.id}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CircleColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: unread ? AppColors.primary : AppColors.primarySoft,
          width: 2.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (from != null)
            MemberAvatar(initial: from.initial, color: from.color)
          else
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Text(n.emoji, style: const TextStyle(fontSize: 22)),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        n.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: CircleColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      n.timeAgo,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: CircleColors.muted,
                      ),
                    ),
                    if (unread) ...[
                      const SizedBox(width: 6),
                      Semantics(
                        label: 'New',
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  n.body,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: CircleColors.secondary,
                  ),
                ),
                if (onNudgeBack != null) ...[
                  const SizedBox(height: 10),
                  CirclePillButton(
                    label: 'Nudge back',
                    icon: 'icon_send',
                    filled: true,
                    onPressed: onNudgeBack,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}