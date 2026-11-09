import 'package:flutter/material.dart';

import '../data/account_session.dart';
import '../data/profile_repository.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/stat_colors.dart';
import '../utils/format.dart';
import '../widgets/chunky.dart';

// ---------------------------------------------------------------------------
// ONBOARDING — after signing up: name + @username, avatar, daily goals.
// ---------------------------------------------------------------------------

enum _Step { name, avatar, goals }

/// How each goal moves when you tap − / +, and its limits.
class _GoalRange {
  const _GoalRange(this.step, this.min, this.max);
  final int step;
  final int min;
  final int max;
}

const _goalRanges = {
  StatMetric.steps: _GoalRange(1000, 2000, 30000),
  StatMetric.sleep: _GoalRange(30, 5 * 60, 10 * 60),
  StatMetric.workout: _GoalRange(5, 10, 120),
  StatMetric.calories: _GoalRange(50, 100, 1500),
  StatMetric.screenTime: _GoalRange(30, 30, 8 * 60),
};

String _goalLabel(StatMetric metric, int value) => switch (metric) {
  StatMetric.steps => '${formatThousands(value)} steps',
  StatMetric.sleep => formatMinutes(value),
  StatMetric.workout => '$value min',
  StatMetric.calories => '$value kcal',
  StatMetric.screenTime => 'Under ${formatMinutes(value)}',
};

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  _Step _step = _Step.name;
  final _name = TextEditingController();
  final _username = TextEditingController();
  String? _nameError;
  String? _usernameError;
  String _avatar = avatarChoices.first;
  DailyGoals _goals = const DailyGoals();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    switch (_step) {
      case _Step.name:
        await _checkName();
      case _Step.avatar:
        setState(() => _step = _Step.goals);
      case _Step.goals:
        await _finish();
    }
  }

  void _back() => setState(() {
    _error = null;
    _step = _Step.values[_step.index - 1];
  });

  Future<void> _checkName() async {
    final username = normalizeUsername(_username.text);
    final nameError = displayNameProblem(_name.text);
    var usernameError = usernameProblem(username);
    setState(() {
      _nameError = nameError;
      _usernameError = usernameError;
    });
    if (nameError != null || usernameError != null) return;

    setState(() => _busy = true);
    final session = AccountScope.of(context);
    final free = await session.profiles.isUsernameAvailable(username);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (free) {
        _step = _Step.avatar;
      } else {
        _usernameError = '@$username is taken. Try another one.';
      }
    });
  }

  Future<void> _finish() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AccountScope.of(context).completeOnboarding(
        displayName: _name.text.trim(),
        username: normalizeUsername(_username.text),
        avatarEmoji: _avatar,
        goals: _goals,
      );
    } on ProfileException catch (e) {
      if (!mounted) return;
      // Most likely the username went in the meantime: go back to it.
      setState(() {
        _usernameError = e.message;
        _step = _Step.name;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final last = _step == _Step.goals;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: _step == _Step.name
            ? null
            : IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: _busy ? null : _back,
              ),
        title: _Progress(value: (_step.index + 1) / _Step.values.length),
        actions: [
          if (_step == _Step.name)
            TextButton(
              onPressed: () => AccountScope.of(context).signOut(),
              child: const Text('Cancel'),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                children: [
                  ...switch (_step) {
                    _Step.name => _nameStep(text),
                    _Step.avatar => _avatarStep(text),
                    _Step.goals => _goalsStep(text),
                  },
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: text.bodyMedium?.copyWith(
                        color: AppColors.redText,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: ChunkyButton(
                label: _busy
                    ? 'One sec…'
                    : last
                    ? "Let's go! 🎉"
                    : 'Continue',
                onPressed: _busy ? null : _next,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _nameStep(TextTheme text) => [
    Text("What should friends call you?", style: text.headlineMedium),
    const SizedBox(height: 6),
    Text(
      'Your @username is how friends find you. You can share your friend '
      'code later too.',
      style: text.bodyMedium?.copyWith(color: AppColors.inkSoft),
    ),
    const SizedBox(height: 24),
    TextField(
      key: const ValueKey('name-field'),
      controller: _name,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.givenName],
      decoration: InputDecoration(hintText: 'Your name', errorText: _nameError),
    ),
    const SizedBox(height: 12),
    TextField(
      key: const ValueKey('username-field'),
      controller: _username,
      autocorrect: false,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _next(),
      decoration: InputDecoration(
        hintText: 'username',
        // Always visible, unlike prefixText (only shows when focused).
        prefixIcon: const Padding(
          padding: EdgeInsets.only(left: 16, right: 2),
          child: Text(
            '@',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.inkSoft,
            ),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(),
        errorText: _usernameError,
        helperText: 'Letters, numbers, _ and .',
      ),
    ),
  ];

  List<Widget> _avatarStep(TextTheme text) => [
    Text('Pick your look', style: text.headlineMedium),
    const SizedBox(height: 6),
    Text(
      'This is you on leaderboards and in your friends\' lists.',
      style: text.bodyMedium?.copyWith(color: AppColors.inkSoft),
    ),
    const SizedBox(height: 24),
    Center(child: Text(_avatar, style: const TextStyle(fontSize: 72))),
    const SizedBox(height: 24),
    GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        for (final emoji in avatarChoices)
          ChunkySurface(
            color: emoji == _avatar ? AppColors.primaryTint : AppColors.surface,
            edgeColor: emoji == _avatar ? AppColors.primary : AppColors.border,
            borderColor: emoji == _avatar
                ? AppColors.primary
                : AppColors.border,
            radius: AppRadius.chip,
            depth: AppDepth.chip,
            selected: emoji == _avatar,
            semanticLabel: 'Avatar $emoji',
            onTap: () => setState(() => _avatar = emoji),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 32)),
            ),
          ),
      ],
    ),
  ];

  List<Widget> _goalsStep(TextTheme text) => [
    Text('Set your daily goals', style: text.headlineMedium),
    const SizedBox(height: 6),
    Text(
      "Start easy. You can change these anytime, and only you see them.",
      style: text.bodyMedium?.copyWith(color: AppColors.inkSoft),
    ),
    const SizedBox(height: 20),
    for (final metric in StatMetric.values) ...[
      _GoalRow(
        metric: metric,
        value: _goals.target(metric),
        range: _goalRanges[metric]!,
        onChanged: (v) => setState(() => _goals = _goals.withTarget(metric, v)),
      ),
      const SizedBox(height: 10),
    ],
  ];
}

class _Progress extends StatelessWidget {
  const _Progress({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Step ${(value * _Step.values.length).round()} of '
          '${_Step.values.length}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: value),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => LinearProgressIndicator(
            value: v,
            minHeight: 14,
            backgroundColor: AppColors.border,
          ),
        ),
      ),
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({
    required this.metric,
    required this.value,
    required this.range,
    required this.onChanged,
  });

  final StatMetric metric;
  final int value;
  final _GoalRange range;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final label = _goalLabel(metric, value);

    return ChunkyCard(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        children: [
          Text(metric.emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(metric.label, style: text.bodySmall),
                Text(
                  label,
                  style: text.titleMedium?.copyWith(color: metric.edgeColor),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Less ${metric.label.toLowerCase()}',
            icon: const Icon(Icons.remove_circle_rounded),
            color: metric.color,
            iconSize: 32,
            onPressed: value - range.step >= range.min
                ? () => onChanged(value - range.step)
                : null,
          ),
          IconButton(
            tooltip: 'More ${metric.label.toLowerCase()}',
            icon: const Icon(Icons.add_circle_rounded),
            color: metric.color,
            iconSize: 32,
            onPressed: value + range.step <= range.max
                ? () => onChanged(value + range.step)
                : null,
          ),
        ],
      ),
    );
  }
}
