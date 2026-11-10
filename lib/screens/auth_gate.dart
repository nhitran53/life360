import 'package:flutter/material.dart';

import '../app_services.dart';
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

  /// Made once per signed-in profile, so screens keep one set of
  /// repositories (and one health connection) while you're signed in.
  AppServices? _services;
  String? _servicesFor;

  AppServices _servicesOf(AccountSession session) {
    final id = session.profile?.id;
    if (_services == null || _servicesFor != id) {
      _servicesFor = id;
      _services = AppServices.defaults(
        friends: session.friends,
        sharing: session.sharing,
      );
    }
    return _services!;
  }

  @override
  Widget build(BuildContext context) {
    final session = AccountScope.of(context);
    final status = session.status;

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
        widget.signedIn?.call(context) ??
            CircleScreen(services: _servicesOf(session)),
    };
  }
}
