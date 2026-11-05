import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Route the Android Health Connect "privacy policy" intents open.
const privacyPolicyRoute = '/privacy-policy';

/// Keep in sync with PRIVACY.md (a test checks the headings).
const privacyPolicySections = <(String, String)>[
  (
    'What we read',
    'With your permission, Friend 360 reads these from Apple Health or '
        'Health Connect: steps, sleep, workouts and active calories. It asks '
        'only for these four. It never writes to Apple Health or Health '
        'Connect.',
  ),
  (
    'Where your data goes',
    'Today the health data stays on your phone. The app has no accounts and '
        'no server, and it does not send your health data anywhere. It is '
        'used only to draw your stats and your place on the weekly '
        'leaderboard.\n\nThe friends and circles you see in the app are '
        'sample data for a demo. They are not real people.',
  ),
  (
    "What we don't do",
    "We don't sell your data, use it for advertising, or share it with third "
        "parties. We don't use it for credit, insurance or employment "
        "decisions, and we never share it without your explicit consent. We "
        "don't write health values to logs or crash reports.",
  ),
  (
    'Retention and security',
    'No copy of your health data leaves your phone. The app keeps it only '
        "in memory while it runs, and your phone's app sandbox protects it. "
        'Uninstalling the app deletes anything it holds.',
  ),
  (
    'Sleep and other private data',
    'Sleep is private by default. Sharing any metric with other people will '
        'always be opt-in, per metric, and you can turn it off again.',
  ),
  (
    'Your choices',
    'You can change or revoke access at any time in the Health app on '
        'iPhone (Sharing > Apps > Friend 360), or in Health Connect on '
        'Android (App permissions > Friend 360). Uninstalling the app '
        'removes the data it holds on your phone.',
  ),
  (
    'Future changes',
    'If we add accounts or sharing with friends, health data you choose to '
        'share would be stored on a server and shown to the people you pick. '
        'This policy will be updated first, and you will be asked before '
        'anything is shared.',
  ),
  (
    'Children',
    'Friend 360 is not directed at children under 13.',
  ),
];

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy policy')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            Text(
              'Friend 360 is a class project (CSC 4330). This policy '
              'describes what the app does today.',
              style: text.bodyLarge,
            ),
            for (final (title, body) in privacyPolicySections) ...[
              const SizedBox(height: 20),
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: text.titleMedium
                      ?.copyWith(color: AppColors.primaryText),
                ),
              ),
              const SizedBox(height: 6),
              Text(body, style: text.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}
