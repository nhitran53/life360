part of '../leaderboard_screen.dart';

// ---------------------------------------------------------------------------
// FAMILY PICKER — whose leaderboard: all friends or one of your families
// ---------------------------------------------------------------------------

class _ScopeButton extends StatelessWidget {
  const _ScopeButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ChunkySurface(
        key: const ValueKey('scope-button'),
        color: AppColors.surface,
        edgeColor: AppColors.border,
        borderColor: AppColors.border,
        radius: AppRadius.chip,
        depth: AppDepth.chip,
        semanticLabel: 'Showing $label. Switch leaderboard',
        padding: const EdgeInsets.symmetric(horizontal: 14),
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.groups_rounded, size: 20, color: AppColors.ink),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: AppColors.ink, letterSpacing: 0),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more_rounded,
                  size: 22, color: AppColors.inkSoft),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the sheet closes with. [family] null = all friends.
class _ScopeChoice {
  const _ScopeChoice(this.family);
  final CircleFamily? family;
}

class _ScopeSheet extends StatelessWidget {
  const _ScopeSheet({required this.families, required this.selected});

  final List<CircleFamily> families;

  /// Null = all friends.
  final CircleFamily? selected;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Whose leaderboard?', style: text.titleLarge),
            const SizedBox(height: 2),
            Text('Compare with all your friends or one family',
                style: text.bodySmall),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ScopeOption(
                      icon: Icons.public_rounded,
                      title: 'All friends',
                      subtitle: 'Everyone you’ve added',
                      selected: selected == null,
                      onTap: () =>
                          Navigator.of(context).pop(const _ScopeChoice(null)),
                    ),
                    for (final family in families) ...[
                      const SizedBox(height: 10),
                      _ScopeOption(
                        icon: Icons.groups_rounded,
                        title: family.name,
                        subtitle: family.memberCount == 1
                            ? 'Just you so far'
                            : '${family.memberCount} members',
                        selected: family.id == selected?.id,
                        onTap: () =>
                            Navigator.of(context).pop(_ScopeChoice(family)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScopeOption extends StatelessWidget {
  const _ScopeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return ChunkySurface(
      color: selected ? AppColors.primaryTint : AppColors.surface,
      edgeColor: selected ? AppColors.primaryDark : AppColors.border,
      borderColor: selected ? AppColors.primary : AppColors.border,
      radius: AppRadius.card,
      depth: AppDepth.card,
      selected: selected,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.surfaceSunken,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22, color: AppColors.ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall),
                Text(subtitle, style: text.bodySmall),
              ],
            ),
          ),
          if (selected)
            const Icon(Icons.check_circle_rounded,
                color: AppColors.primary, size: 24),
        ],
      ),
    );
  }
}
