import 'package:flutter/material.dart';

import '../data/account_session.dart';
import '../data/auth_repository.dart';
import '../theme/app_colors.dart';

/// Asks "Delete your account?", then deletes it through the
/// [AccountSession]. Shows a snack bar if it fails. Used by the account page
/// and by onboarding (a login without a profile can be deleted too).
///
/// [onBusy] is called with true while deleting and false when done.
Future<void> confirmAndDeleteAccount(
  BuildContext context, {
  ValueChanged<bool>? onBusy,
}) async {
  final session = AccountScope.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete your account?'),
      content: const Text(
        'Your profile, friends, goals and shared stats will be removed. '
        "This can't be undone.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: AppColors.redText),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  void showError(String message) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  onBusy?.call(true);
  try {
    await session.deleteAccount();
  } on AuthException catch (e) {
    showError(
      e.code == AuthException.requiresRecentLogin
          ? 'For safety, log out and back in, then try again.'
          : e.message,
    );
  } on Exception catch (e) {
    // e.g. a FirebaseException from deleting the profile while offline.
    debugPrint('Deleting the account failed: ${e.runtimeType}');
    showError(
      "Couldn't delete your account. Check your connection and try again.",
    );
  } finally {
    if (context.mounted) onBusy?.call(false);
  }
}
