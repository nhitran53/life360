/// Which platform features the app can use, in one place so screens don't
/// check the platform themselves.
library;

import 'package:flutter/foundation.dart';

/// Android or iOS: the phones with a health store.
bool get isPhone =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// Android, where apps can read screen time (with usage access).
bool get canReadDeviceScreenTime =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Apple's own platforms, where Sign in with Apple is offered.
bool get offersAppleSignIn =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);
