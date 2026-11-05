import 'package:flutter/material.dart';

import '../data/circle_repository.dart';
import '../data/friends_repository.dart';
import '../data/stats_repository.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/chunky.dart';
import '../widgets/circle_type_label.dart';
import 'circle_detail_screen.dart';

// ---------------------------------------------------------------------------
// CIRCLES — the groups you're in, plus create and join
// ---------------------------------------------------------------------------

class CirclesScreen extends StatefulWidget {
  const CirclesScreen({
    super.key,
    required this.circles,
    required this.friends,
    required this.stats,
    this.clock,
  });

  final CircleRepository circles;
  final FriendsRepository friends;
  final StatsRepository stats;
  final DateTime Function()? clock;

  @override
  State<CirclesScreen> createState() => _CirclesScreenState();
}

class _CirclesScreenState extends State<CirclesScreen> {
  late Future<List<Circle>> _circles = widget.circles.circles();
  final _codeController = TextEditingController();
  String? _joinError;
  var _joining = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _reload() {
    final next = widget.circles.circles();
    setState(() {
      _circles = next;
    });
  }

  Future<void> _join() async {
    setState(() {
      _joining = true;
      _joinError = null;
    });
    try {
      await widget.circles.joinByCode(_codeController.text);
      if (!mounted) return;
      _codeController.clear();
      setState(() => _joining = false);
      _reload();
    } on CircleException catch (e) {
      if (!mounted) return;
      setState(() {
        _joining = false;
        _joinError = e.message;
      });
    }
  }

  Future<void> _create() async {
    final created = await showModalBottomSheet<Circle>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => _CreateCircleSheet(repository: widget.circles),
    );
    if (created != null && mounted) _reload();
  }

  Future<void> _open(Circle circle) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CircleDetailScreen(
          circle: circle,
          circles: widget.circles,
          friends: widget.friends,
          stats: widget.stats,
          clock: widget.clock,
        ),
      ),
    );
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Circles')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            Text("Who's in your circle?", style: text.headlineMedium),
            const SizedBox(height: 4),
            Text(
              'Couples, families, friends and teams all race in circles.',
              style: text.bodyMedium?.copyWith(color: AppColors.inkSoft),
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<Circle>>(
              future: _circles,
              builder: (context, snapshot) {
                final list = snapshot.data;
                if (list == null) {
                  if (snapshot.hasError) {
                    return Text(
                      "Couldn't load your circles. Try again in a sec.",
                      style: text.bodyMedium,
                    );
                  }
                  return const Center(child: CircularProgressIndicator());
                }
                if (list.isEmpty) {
                  return Text(
                    'No circles yet. Make one or join with a code.',
                    key: const ValueKey('circles-empty'),
                    style: text.bodyMedium?.copyWith(color: AppColors.inkSoft),
                  );
                }
                return Column(
                  children: [
                    for (final circle in list) ...[
                      _CircleCard(circle: circle, onTap: () => _open(circle)),
                      const SizedBox(height: 12),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            ChunkyButton(
              key: const ValueKey('create-circle-button'),
              label: 'Create a circle',
              icon: Icons.add_rounded,
              onPressed: _create,
            ),
            const SizedBox(height: 24),
            Text('Have a code?', style: text.titleMedium),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('join-code-field'),
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(hintText: 'Circle code'),
              onSubmitted: (_) => _join(),
            ),
            if (_joinError != null) ...[
              const SizedBox(height: 8),
              Text(
                _joinError!,
                key: const ValueKey('join-error'),
                style: text.bodyMedium?.copyWith(color: AppColors.redText),
              ),
            ],
            const SizedBox(height: 12),
            ChunkyButton.secondary(
              key: const ValueKey('join-button'),
              label: _joining ? 'Joining…' : 'Join circle',
              onPressed: _joining ? null : _join,
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleCard extends StatelessWidget {
  const _CircleCard({required this.circle, required this.onTap});

  final Circle circle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final subtitle =
        '${circle.type.label} · ${memberCountLabel(circle.memberIds.length)}';
    return ChunkyCard(
      key: ValueKey('circle-${circle.id}'),
      onTap: onTap,
      semanticLabel: '${circle.name}. $subtitle',
      child: Row(
        children: [
          Text(circle.type.emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Expanded(
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(circle.name, style: text.titleLarge),
                  const SizedBox(height: 2),
                  Text(subtitle, style: text.bodySmall),
                ],
              ),
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.muted,
            size: 28,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CREATE SHEET — name + type
// ---------------------------------------------------------------------------

class _CreateCircleSheet extends StatefulWidget {
  const _CreateCircleSheet({required this.repository});

  final CircleRepository repository;

  @override
  State<_CreateCircleSheet> createState() => _CreateCircleSheetState();
}

class _CreateCircleSheetState extends State<_CreateCircleSheet> {
  final _nameController = TextEditingController();
  var _type = CircleType.friends;
  String? _error;
  var _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final circle = await widget.repository.create(
        _nameController.text,
        _type,
      );
      if (!mounted) return;
      Navigator.of(context).pop(circle);
    } on CircleException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('New circle', style: text.headlineMedium),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('circle-name-field'),
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Circle name'),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final type in CircleType.values)
                _TypeChip(
                  type: type,
                  selected: type == _type,
                  onTap: () => setState(() => _type = type),
                ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              key: const ValueKey('create-error'),
              style: text.bodyMedium?.copyWith(color: AppColors.redText),
            ),
          ],
          const SizedBox(height: 16),
          ChunkyButton(
            key: const ValueKey('create-save-button'),
            label: _saving ? 'Creating…' : 'Create',
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final CircleType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChunkySurface(
      key: ValueKey('type-${type.name}'),
      color: selected ? AppColors.primary : AppColors.surface,
      edgeColor: selected ? AppColors.primaryDark : AppColors.border,
      borderColor: selected ? null : AppColors.border,
      radius: AppRadius.chip,
      depth: AppDepth.chip,
      selected: selected,
      semanticLabel: type.label,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: ExcludeSemantics(
        child: Text(
          '${type.emoji} ${type.label}',
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(color: selected ? Colors.white : AppColors.inkSoft),
        ),
      ),
    );
  }
}
