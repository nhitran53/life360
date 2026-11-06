import 'package:flutter/material.dart';

import 'app_services.dart';
import 'screens/circles_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/my_stats_screen.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'widgets/chunky.dart';

// ---------------------------------------------------------------------------
// HUB SCREEN — the main menu: My Stats / Friends' Stats / Leaderboard
// ---------------------------------------------------------------------------

class _HubItem {
  const _HubItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.edgeColor,
    this.screen,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color edgeColor;

  /// Null shows a "coming soon" page.
  final Widget Function(AppServices)? screen;
}

Widget _myStats(AppServices s) =>
    MyStatsScreen(friends: s.friends, stats: s.stats);

Widget _leaderboard(AppServices s) =>
    LeaderboardScreen(friends: s.friends, stats: s.stats);

Widget _circles(AppServices s) =>
    CirclesScreen(circles: s.circles, friends: s.friends, stats: s.stats);

const _hubItems = [
  _HubItem(
    icon: Icons.insights_rounded,
    title: 'My Stats',
    subtitle: 'Steps, sleep, workouts and more',
    color: AppColors.primary,
    edgeColor: AppColors.primaryDark,
    screen: _myStats,
  ),
  _HubItem(
    icon: Icons.group_rounded,
    title: "Friends' Stats",
    subtitle: 'See how your friends are doing',
    color: AppColors.blue,
    edgeColor: AppColors.blueDark,
  ),
  _HubItem(
    icon: Icons.emoji_events_rounded,
    title: 'Leaderboard',
    subtitle: "Who's on top this week?",
    color: AppColors.gold,
    edgeColor: AppColors.goldDark,
    screen: _leaderboard,
  ),
  _HubItem(
    icon: Icons.groups_rounded,
    title: 'Circles',
    subtitle: 'Your groups and weekly rewards',
    color: AppColors.orange,
    edgeColor: AppColors.orangeDark,
    screen: _circles,
  ),
];

class HubScreen extends StatefulWidget {
  const HubScreen({super.key, this.services});

  /// Defaults to [AppServices.defaults] when omitted.
  final AppServices? services;

  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen> {
  late final AppServices _services = widget.services ?? AppServices.defaults();

  void _open(BuildContext context, _HubItem item) {
    final screen = item.screen;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => screen != null
            ? screen(_services)
            : ComingSoonPage(title: item.title, icon: item.icon),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Friend 360')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text('Where to?', style: text.headlineLarge),
            const SizedBox(height: 4),
            Text('Pick a spot and get moving.',
                style: text.bodyMedium?.copyWith(color: AppColors.inkSoft)),
            const SizedBox(height: 24),
            for (final item in _hubItems) ...[
              _HubCard(item: item, onTap: () => _open(context, item)),
              const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  const _HubCard({required this.item, required this.onTap});

  final _HubItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return ChunkyCard(
      onTap: onTap,
      semanticLabel: '${item.title}. ${item.subtitle}',
      child: Row(
        children: [
          _IconTile(icon: item.icon, color: item.color, edge: item.edgeColor),
          const SizedBox(width: 16),
          Expanded(
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: text.titleLarge),
                  const SizedBox(height: 2),
                  Text(item.subtitle, style: text.bodySmall),
                ],
              ),
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.muted, size: 28),
        ],
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon, required this.color, required this.edge});

  final IconData icon;
  final Color color;
  final Color edge;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      child: ChunkySurface(
        color: color,
        edgeColor: edge,
        radius: AppRadius.chip,
        depth: AppDepth.chip,
        child: SizedBox(
          height: 53,
          child: Icon(icon, color: Colors.white, size: 30),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PLACEHOLDER — replace with the real My Stats / Friends / Leaderboard pages
// ---------------------------------------------------------------------------

class ComingSoonPage extends StatelessWidget {
  const ComingSoonPage({super.key, required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 72, color: AppColors.border),
              const SizedBox(height: 16),
              Text('Coming soon 👀', style: text.headlineMedium),
              const SizedBox(height: 8),
              Text(
                "We're still building this one. Check back soon!",
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: AppColors.inkSoft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
