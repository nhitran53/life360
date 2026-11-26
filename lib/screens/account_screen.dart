import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/account_session.dart';
import '../theme/app_colors.dart';
import '../widgets/chunky.dart';
import '../widgets/delete_account.dart';

// ---------------------------------------------------------------------------
// ACCOUNT — your profile, friend code, sign out and delete account.
// ---------------------------------------------------------------------------

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _busy = false;

  Future<void> _signOut() async {
    final session = AccountScope.of(context);
    setState(() => _busy = true);
    try {
      await session.signOut();
    } on Exception catch (e) {
      debugPrint('Signing out failed: ${e.runtimeType}');
      _showError("Couldn't log you out. Check your connection and try again.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _delete() => confirmAndDeleteAccount(
    context,
    onBusy: (busy) => setState(() => _busy = busy),
  );

  @override
  Widget build(BuildContext context) {
    final session = AccountScope.of(context);
    final profile = session.profile;
    final user = session.user;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: SafeArea(
        top: false,
        child: profile == null
            ? const Center(child: CircularProgressIndicator())
            : AbsorbPointer(
                absorbing: _busy,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                  children: [
                    Center(
                      child: Text(
                        profile.avatarEmoji,
                        style: const TextStyle(fontSize: 72),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      profile.displayName,
                      textAlign: TextAlign.center,
                      style: text.headlineMedium,
                    ),
                    Text(
                      '@${profile.username}',
                      textAlign: TextAlign.center,
                      style: text.bodyMedium?.copyWith(
                        color: AppColors.inkSoft,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ChunkyCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Your friend code', style: text.bodySmall),
                                Text(
                                  profile.friendCode,
                                  style: text.headlineMedium?.copyWith(
                                    color: AppColors.primaryText,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Copy friend code',
                            icon: const Icon(
                              Icons.copy_rounded,
                              color: AppColors.blue,
                            ),
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: profile.friendCode),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Code copied 📋')),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (user != null)
                      ChunkyCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Signed in with ${user.method.label}',
                              style: text.bodySmall,
                            ),
                            Text(
                              user.email ?? 'Email hidden',
                              style: text.titleMedium,
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 32),
                    ChunkyButton.secondary(
                      label: 'Log out',
                      icon: Icons.logout_rounded,
                      onPressed: _busy ? null : _signOut,
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: _busy ? null : _delete,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.redText,
                        ),
                        child: const Text('Delete account'),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
