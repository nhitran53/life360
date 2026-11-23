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

/// Whether Sign in with Apple is set up: it needs a paid Apple Developer
/// account, the "Sign in with Apple" capability in Xcode and the Apple
/// provider enabled in Firebase. Until then the button stays hidden, since
/// tapping it would fail. Flip to `true` once that's done (App Review
/// requires it on iPhone because the app offers Google sign-in).
const appleSignInReady = false;

/// Apple's own platforms, where Sign in with Apple is offered (once
/// [appleSignInReady]).
bool get offersAppleSignIn =>
    appleSignInReady &&
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);
