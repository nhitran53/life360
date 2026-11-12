package com.nhitran.life360

import android.content.Intent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Health Connect permission requests use registerForActivityResult, which
// needs a FragmentActivity.
class MainActivity : FlutterFragmentActivity() {
    // Screen time from UsageStatsManager (lib/data/device_screen_time.dart).
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ScreenTimeChannel.NAME)
            .setMethodCallHandler(ScreenTimeChannel(this))
    }

    // Health Connect's "privacy policy" links open the in-app policy screen.
    private fun isPolicyIntent(intent: Intent?) =
        intent?.action == "androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE" ||
            intent?.action == "android.intent.action.VIEW_PERMISSION_USAGE"

    // Cold start.
    override fun getInitialRoute(): String? =
        if (isPolicyIntent(intent)) "/privacy-policy" else super.getInitialRoute()

    // App already running (launchMode is singleTop).
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (isPolicyIntent(intent)) {
            flutterEngine?.navigationChannel?.pushRoute("/privacy-policy")
        }
    }
}
