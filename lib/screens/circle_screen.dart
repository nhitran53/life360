import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../app_services.dart';
import '../data/account_session.dart';
import '../data/family_store.dart';
import '../data/mock_circle.dart';
import '../data/mock_notifications.dart';
import '../models/daily_goals.dart';
import '../theme/app_colors.dart';
import '../theme/circle_colors.dart';
import '../widgets/circle_widgets.dart';
import '../widgets/family_switcher.dart';
import 'friends_stats_screen.dart';
import 'invite_people_sheet.dart';
import 'leaderboard_screen.dart';
import 'member_detail_screen.dart';
import 'my_stats_screen.dart';
import 'notifications_screen.dart';
import 'nudge_screen.dart';
import 'privacy_screen.dart';

part 'circle/pulse_map.dart';

// ---------------------------------------------------------------------------
// CIRCLE — tab shell (Circle / Ranks / Nudges / Privacy) + the Circle home:
// live pulse map of your circle and today's totals
// ---------------------------------------------------------------------------

/// Thickness of the green outlines around the boxes on the Circle home.
const _outline = 2.5;

class CircleScreen extends StatefulWidget {
  const CircleScreen({
    super.key,
    this.initialTab = CircleTab.circle,
    this.services,
    this.familyStore,
  });

  final CircleTab initialTab;

  /// Defaults to [AppServices.defaults] when My Stats is opened.
  final AppServices? services;

  /// Defaults to [FamilyStore.instance].
  final FamilyStore? familyStore;

  @override
  State<CircleScreen> createState() => _CircleScreenState();
}

class _CircleScreenState extends State<CircleScreen> {
  late CircleTab _tab = widget.initialTab;

  CircleMember _nudgeRecipient = circleNudgeMembers.first;

  /// Changes whenever a nudge is started from elsewhere, so the Nudges tab
  /// starts fresh for the new recipient.
  Key _nudgeKey = UniqueKey();

  /// Every family you belong to, plus any you create this session.
  late final FamilyStore _store = widget.familyStore ?? FamilyStore.instance;

  /// Created on first use so My Stats keeps one connection per Circle visit.
  late final AppServices _services = widget.services ?? AppServices.defaults();

  /// The one the Circle home is showing.
  late CircleFamily _family = _store.families.first;

  /// Notifications you haven't seen yet (drives the dot on the bell).
  final Set<String> _unread = {
    for (final n in mockNotifications)
      if (n.unread) n.id,
  };

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            NotificationsScreen(unreadIds: {..._unread}, onNudgeBack: _nudge),
      ),
    );
    // Seen them all now.
    if (mounted) setState(_unread.clear);
  }

  Future<void> _switchFamily() async {
    final next = await showFamilySwitcher(
      context,
      families: _store.families,
      current: _family,
    );
    if (next == null || !mounted) return;

    final isNew = !_store.contains(next);
    setState(() {
      if (isNew) _store.add(next);
      _family = next;
    });
    if (isNew) showCircleSnack(context, 'Created ${next.name} 🎉');
  }

  void _selectTab(CircleTab tab) {
    if (tab == CircleTab.ranks) {
      Navigator.of(context).push(
        // Opens on the family you're looking at; switch from the top of it.
        MaterialPageRoute<void>(
          builder: (_) => LeaderboardScreen(
            friends: _services.friends,
            stats: _services.stats,
            sharing: _services.sharing,
            initialFamily: _family,
            familyStore: _store,
          ),
        ),
      );
      return;
    }
    setState(() => _tab = tab);
  }

  void _openMyStats() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MyStatsScreen(
          friends: _services.friends,
          stats: _services.stats,
          screenTimeLog: _services.screenTime,
          // Your own goals once you're signed in.
          goals: AccountScope.maybeOf(context)?.goals ?? const DailyGoals(),
        ),
      ),
    );
  }

  void _openFriendsStats() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FriendsStatsScreen(
          friends: _services.friends,
          stats: _services.stats,
          sharing: _services.sharing,
        ),
      ),
    );
  }

  void _invitePeople() {
    showInvitePeopleSheet(
      context,
      friends: _services.friends,
      familyName: _family.name,
    );
  }

  void _nudge(CircleMember member) {
    setState(() {
      _nudgeRecipient = member;
      _nudgeKey = UniqueKey();
      _tab = CircleTab.nudges;
    });
  }

  void _openMember(CircleMember member) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MemberDetailScreen(
          member: member,
          onSelectTab: _selectTab,
          onSendNote: _nudge,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Same green family as the home screen.
      backgroundColor: AppColors.primaryTint,
      bottomNavigationBar: CircleTabBar(active: _tab, onSelect: _selectTab),
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          // Ranks never becomes active: it pushes the leaderboard as its own page.
          index: switch (_tab) {
            CircleTab.circle || CircleTab.ranks => 0,
            CircleTab.nudges => 1,
            CircleTab.privacy => 2,
          },
          children: [
            _CircleHome(
              family: _family,
              onSwitchFamily: _switchFamily,
              onOpenMember: _openMember,
              onNudge: _nudge,
              onOpenMyStats: _openMyStats,
              onOpenFriendsStats: _openFriendsStats,
              onInvite: _invitePeople,
              hasUnread: _unread.isNotEmpty,
              onOpenNotifications: _openNotifications,
            ),
            NudgeScreen(key: _nudgeKey, initialRecipient: _nudgeRecipient),
            PrivacyScreen(
              sharing: _services.sharing,
              // Your own settings once signed in (mock "You" otherwise).
              userId: AccountScope.maybeOf(context)?.profile?.id,
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleHome extends StatelessWidget {
  const _CircleHome({
    required this.family,
    required this.onSwitchFamily,
    required this.onOpenMember,
    required this.onNudge,
    required this.onOpenMyStats,
    required this.onOpenFriendsStats,
    required this.onInvite,
    required this.hasUnread,
    required this.onOpenNotifications,
  });

  final CircleFamily family;
  final bool hasUnread;
  final VoidCallback onOpenNotifications;
  final VoidCallback onSwitchFamily;
  final VoidCallback onOpenMyStats;
  final VoidCallback onOpenFriendsStats;
  final VoidCallback onInvite;
  final ValueChanged<CircleMember> onOpenMember;
  final ValueChanged<CircleMember> onNudge;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            familyName: family.name,
            onTap: onSwitchFamily,
            hasUnread: hasUnread,
            onOpenNotifications: onOpenNotifications,
          ),
          const SizedBox(height: 14),
          _PulseMap(members: family.mapMembers),
          const SizedBox(height: 14),
          _TogetherToday(steps: family.stepsToday, goal: family.stepsGoal),
          const SizedBox(height: 14),
          _CircleLink(
            icon: Icons.sync_rounded,
            label: 'My stats and health sync',
            onTap: onOpenMyStats,
          ),
          const SizedBox(height: 8),
          _CircleLink(
            icon: Icons.group_rounded,
            label: "Friends' stats",
            onTap: onOpenFriendsStats,
          ),
          const SizedBox(height: 8),
          _CircleLink(
            key: const ValueKey('invite-people-button'),
            icon: Icons.person_add_alt_1_rounded,
            label: 'Invite people',
            onTap: onInvite,
          ),
          if (family.listMembers.isEmpty) ...[
            const SizedBox(height: 14),
            _EmptyFamily(name: family.name, onInvite: onInvite),
          ],
          for (final member in family.listMembers) ...[
            SizedBox(height: member == family.listMembers.first ? 14 : 8),
            _MemberRow(
              member: member,
              onTap: () => onOpenMember(member),
              onNudge: member.idle ? () => onNudge(member) : null,
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// HEADER — circle switcher + notifications
// ---------------------------------------------------------------------------

class _CircleLink extends StatelessWidget {
  const _CircleLink({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CircleColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.primarySoft, width: _outline),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 19, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: CircleColors.ink,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.primaryText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.familyName,
    required this.onTap,
    required this.hasUnread,
    required this.onOpenNotifications,
  });

  final String familyName;

  /// Opens the family switcher.
  final VoidCallback onTap;

  /// Shows the dot on the bell.
  final bool hasUnread;
  final VoidCallback onOpenNotifications;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              button: true,
              hint: 'Switch or create a family',
              child: Material(
                color: CircleColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                  side: const BorderSide(color: CircleColors.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onTap,
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SvgPicture.asset(
                          '$circleAssets/icon_users.svg',
                          width: 16,
                          height: 16,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            familyName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: CircleColors.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SvgPicture.asset(
                          '$circleAssets/icon_chevron_down.svg',
                          width: 14,
                          height: 14,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Tooltip(
          message: 'Notifications',
          child: Semantics(
            button: true,
            label: hasUnread ? 'Notifications, new' : 'Notifications',
            excludeSemantics: true,
            child: InkResponse(
              key: const ValueKey('notifications-button'),
              onTap: onOpenNotifications,
              radius: 26,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  children: [
                    SvgPicture.asset(
                      '$circleAssets/notifications.svg',
                      width: 44,
                      height: 44,
                    ),
                    if (hasUnread)
                      Positioned(
                        left: 25,
                        top: 9,
                        child: SvgPicture.asset(
                          '$circleAssets/notification_dot.svg',
                          key: const ValueKey('notification-dot'),
                          width: 10,
                          height: 10,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// TOGETHER TODAY — combined steps vs. goal
// ---------------------------------------------------------------------------

class _TogetherToday extends StatelessWidget {
  const _TogetherToday({required this.steps, required this.goal});

  final int steps;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final progress = (steps / goal).clamp(0.0, 1.0);
    const label = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: CircleColors.secondary,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: CircleColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primarySoft, width: _outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Text(
                  'Together today',
                  style: label,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text('Goal ${formatNumber(goal)}', style: label),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                formatNumber(steps),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: CircleColors.ink,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'steps · ${(progress * 100).round()}%',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 12,
            decoration: BoxDecoration(
              color: AppColors.primaryTint,
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// EMPTY FAMILY — shown for a new family with nobody in it yet
// ---------------------------------------------------------------------------

class _EmptyFamily extends StatelessWidget {
  const _EmptyFamily({required this.name, required this.onInvite});

  final String name;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CircleColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.primarySoft, width: _outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('empty-family-invite'),
        onTap: onInvite,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: const CircleSvg('icon_users', size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Just you so far',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: CircleColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Invite people to $name to start comparing stats',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: CircleColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.person_add_alt_1_rounded,
                color: AppColors.primaryText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// MEMBER ROW — avatar, status, and heart rate or a Nudge button
// ---------------------------------------------------------------------------

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member, required this.onTap, this.onNudge});

  final CircleMember member;
  final VoidCallback onTap;

  /// When set, shows a Nudge button instead of heart rate + steps.
  final VoidCallback? onNudge;

  @override
  Widget build(BuildContext context) {
    final onNudge = this.onNudge;

    return Material(
      color: CircleColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.primarySoft, width: _outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              MemberAvatar(initial: member.initial, color: member.color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: CircleColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      member.status,
                      overflow: TextOverflow.ellipsis,
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
              if (onNudge != null)
                CirclePillButton(
                  label: 'Nudge',
                  icon: 'icon_send',
                  filled: true,
                  onPressed: onNudge,
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${member.bpm} bpm',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: CircleColors.heart,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${formatNumber(member.steps)} steps',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: CircleColors.secondary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
