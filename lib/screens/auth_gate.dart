import 'package:flutter/material.dart';

import '../app_services.dart';
import '../data/account_session.dart';
import '../theme/app_colors.dart';
import '../widgets/chunky.dart';
import 'circle_screen.dart';
import 'onboarding_screen.dart';

// ---------------------------------------------------------------------------
// AUTH GATE — picks the root screen from the account status: welcome when
// signed out, onboarding until there's a profile, then the app.
// ---------------------------------------------------------------------------

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.welcome,
    this.signedIn,
    @visibleForTesting this.createServices = _defaultServices,
  });

  /// Shown when nobody is signed in.
  final Widget welcome;

  /// Shown once signed in with a profile. Defaults to the Circle home.
  final WidgetBuilder? signedIn;

  /// Makes the services for a signed-in session.
  final AppServices Function(AccountSession session) createServices;

  static AppServices _defaultServices(AccountSession session) =>
      AppServices.defaults(
        friends: session.friends,
        sharing: session.sharing,
        statsDb: session.statsDb,
        userId: session.profile?.id,
      );

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  AccountStatus? _shown;

  AccountSession? _session;

  /// Made once per signed-in profile, so screens keep one set of
  /// repositories (and one health connection) while you're signed in.
  /// Created and released only by [_syncServices], never by build.
  AppServices? _services;
  String? _servicesFor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = AccountScope.of(context);
    if (!identical(session, _session)) {
      _session?.removeListener(_syncServices);
      _session = session..addListener(_syncServices);
      _syncServices();
    }
  }

  @override
  void didUpdateWidget(AuthGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncServices();
  }

  /// Builds, replaces or releases the services to match the session. Runs on
  /// every session change, so leaving `ready` (even briefly) always releases
  /// them: signing in again, even as the same user, starts with fresh ones.
  void _syncServices() {
    final session = _session!;
    // A custom signed-in screen brings its own repositories.
    if (session.status != AccountStatus.ready || widget.signedIn != null) {
      _releaseServices();
      return;
    }
    final id = session.profile?.id;
    if (_services == null || _servicesFor != id) {
      _services?.dispose();
      _servicesFor = id;
      _services = widget.createServices(session);
    }
  }

  void _releaseServices() {
    _services?.dispose();
    _services = null;
    _servicesFor = null;
  }

  @override
  void dispose() {
    _session?.removeListener(_syncServices);
    _releaseServices();
    super.dispose();
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
      AccountStatus.loadFailed => _LoadFailedScreen(session: session),
      AccountStatus.ready =>
        widget.signedIn?.call(context) ??
            // Keyed by the services so a replacement rebuilds the whole
            // subtree; descendants cache repositories from their services.
            CircleScreen(
              key: ObjectKey(_services),
              services: _services!,
            ),
    };
  }
}

/// Signed in, but the profile couldn't be loaded (usually offline). Lets the
/// user try again or log out instead of waiting on a spinner forever.
class _LoadFailedScreen extends StatelessWidget {
  const _LoadFailedScreen({required this.session});

  final AccountSession session;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.wifi_off_rounded,
                  size: 56,
                  color: AppColors.inkSoft,
                ),
                const SizedBox(height: 16),
                Text(
                  "Couldn't load your profile",
                  textAlign: TextAlign.center,
                  style: text.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Check your connection and try again.',
                  textAlign: TextAlign.center,
                  style: text.bodyLarge?.copyWith(color: AppColors.inkSoft),
                ),
                const SizedBox(height: 32),
                ChunkyButton(
                  key: const ValueKey('retry-profile'),
                  label: 'Try again',
                  icon: Icons.refresh_rounded,
                  onPressed: session.retry,
                ),
                const SizedBox(height: 12),
                ChunkyButton.secondary(
                  label: 'Log out',
                  onPressed: session.signOut,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
