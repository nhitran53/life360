import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'theme/app_colors.dart';

/// Catches errors nothing else handled, app-wide.
///
/// Errors are logged by type and stack only: their messages can carry health
/// values. In release builds a widget that fails to build shows
/// [FriendlyErrorBox] instead of Flutter's red error screen. Call once, before
/// `runApp`.
void installErrorHandlers({
  bool releaseMode = kReleaseMode,
  void Function(String message) log = _debugLog,
}) {
  final presentInDebug = FlutterError.presentError;
  FlutterError.onError = (details) {
    if (!releaseMode) {
      presentInDebug(details);
      return;
    }
    log('Uncaught Flutter error: ${details.exception.runtimeType}');
    final stack = details.stack;
    if (stack != null) log(stack.toString());
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    log('Uncaught async error: ${error.runtimeType}');
    if (releaseMode) log(stack.toString());
    return true;
  };
  if (releaseMode) {
    ErrorWidget.builder = (_) => const FriendlyErrorBox();
  }
}

void _debugLog(String message) => debugPrint(message);

/// Shown in place of a widget that failed to build (release builds only).
/// Works without a MaterialApp or theme above it.
class FriendlyErrorBox extends StatelessWidget {
  const FriendlyErrorBox({super.key});

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: AppColors.surface,
    child: Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Something went wrong here. Try going back and opening it again.',
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          style: TextStyle(
            color: AppColors.inkSoft,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
  );
}
