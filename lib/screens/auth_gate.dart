import 'package:flutter/material.dart';

import '../data/account_session.dart';
import '../theme/app_colors.dart';
import 'circle_screen.dart';
import 'onboarding_screen.dart';

// ---------------------------------------------------------------------------
// AUTH GATE — picks the root screen from the account status: welcome when
// signed out, onboarding until there's a profile, then the app.
// ---------------------------------------------------------------------------

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.welcome, this.signedIn});

  /// Shown when nobody is signed in.
  final Widget welcome;

  /// Shown once signed in with a profile. Defaults to the Circle home.
  final WidgetBuilder? signedIn;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  AccountStatus? _shown;

  @override
  Widget build(BuildContext context) {
    final status = AccountScope.of(context).status;

    // Signing in, finishing onboarding or logging out swaps the root
    // screen, so close whatever was pushed on top (sign-in, account page).
    if (_shown != null && _shown != status) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      });
    }
    _shown = status;

    return switch (status) {
      AccountStatus.loading => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      AccountStatus.signedOut => widget.welcome,
      AccountStatus.needsProfile => const OnboardingScreen(),
      AccountStatus.ready =>
        widget.signedIn?.call(context) ?? const CircleScreen(),
    };
  }
}
