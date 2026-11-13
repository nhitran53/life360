package com.nhitran.life360

import android.Manifest
import android.app.Activity
import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Daily screen time from UsageStatsManager (issue #10), for
 * `lib/data/device_screen_time.dart`.
 *
 * Screen time is the time any app other than the home screen is in the
 * foreground. Apps open side by side count once. Only daily totals leave this
 * class, and no values are ever logged.
 */
class ScreenTimeChannel(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        const val NAME = "friend360/screen_time"

        // UsageEvents.Event types, as numbers so they compile on every API level.
        private const val ACTIVITY_RESUMED = 1
        private const val ACTIVITY_PAUSED = 2
        private const val SCREEN_NON_INTERACTIVE = 16
        private const val ACTIVITY_STOPPED = 23
        private const val DEVICE_SHUTDOWN = 26

        private const val MILLIS_PER_MINUTE = 60_000L

        // Two months of days is far more than Android keeps events for.
        private const val MAX_DAYS = 62
    }

    private val mainThread = Handler(Looper.getMainLooper())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasUsageAccess" -> result.success(hasUsageAccess())
            "openUsageAccessSettings" -> {
                openUsageAccessSettings()
                result.success(null)
            }
            "dailyScreenTime" -> dailyScreenTime(call, result)
            else -> result.notImplemented()
        }
    }

    private fun hasUsageAccess(): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName,
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName,
            )
        }
        return if (mode == AppOpsManager.MODE_DEFAULT) {
            context.checkCallingOrSelfPermission(Manifest.permission.PACKAGE_USAGE_STATS) ==
                PackageManager.PERMISSION_GRANTED
        } else {
            mode == AppOpsManager.MODE_ALLOWED
        }
    }

    private fun openUsageAccessSettings() {
        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
        if (context !is Activity) intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    }

    private fun dailyScreenTime(call: MethodCall, result: MethodChannel.Result) {
        if (!hasUsageAccess()) {
            result.error("NO_ACCESS", "Usage access is off", null)
            return
        }
        val raw = call.argument<List<Any>>("boundaries")
        val boundaries = raw?.mapNotNull { (it as? Number)?.toLong() }
        if (raw == null || boundaries == null || boundaries.size != raw.size ||
            boundaries.size < 2 || boundaries.size > MAX_DAYS + 1 ||
            boundaries.zipWithNext().any { (a, b) -> b <= a }
        ) {
            result.error("BAD_ARGS", "Expected 2 to ${MAX_DAYS + 1} increasing day boundaries", null)
            return
        }
        // Reading events can take a moment: keep it off the UI thread.
        Thread {
            try {
                val minutes = minutesPerDay(boundaries)
                mainThread.post { result.success(minutes) }
            } catch (e: SecurityException) {
                mainThread.post { result.error("NO_ACCESS", "Usage access is off", null) }
            } catch (e: RuntimeException) {
                mainThread.post { result.error("FAILED", e.javaClass.simpleName, null) }
            }
        }.start()
    }

    /** Foreground minutes for each day between consecutive [boundaries]. */
    private fun minutesPerDay(boundaries: List<Long>): List<Int> {
        val totals = LongArray(boundaries.size - 1)
        val start = boundaries.first()
        val end = minOf(boundaries.last(), System.currentTimeMillis())
        if (end > start) {
            forEachForegroundSpan(start, end) { from, to -> addSpan(totals, boundaries, from, to) }
        }
        return totals.map { (it / MILLIS_PER_MINUTE).toInt() }
    }

    /** Calls [onSpan] for each stretch when at least one app was in front. */
    private fun forEachForegroundSpan(start: Long, end: Long, onSpan: (Long, Long) -> Unit) {
        val usage = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val events = usage.queryEvents(start, end) ?: return
        val homeScreens = homePackages()
        val event = UsageEvents.Event()
        val open = HashSet<String>()
        var since = start
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val key = "${event.packageName}/${event.className}"
            when (event.eventType) {
                ACTIVITY_RESUMED -> if (event.packageName !in homeScreens) {
                    if (open.isEmpty()) since = event.timeStamp
                    open.add(key)
                }
                ACTIVITY_PAUSED, ACTIVITY_STOPPED -> {
                    if (open.remove(key) && open.isEmpty()) onSpan(since, event.timeStamp)
                }
                SCREEN_NON_INTERACTIVE, DEVICE_SHUTDOWN -> {
                    if (open.isNotEmpty()) onSpan(since, event.timeStamp)
                    open.clear()
                }
            }
        }
        if (open.isNotEmpty()) onSpan(since, end)
    }

    private fun addSpan(totals: LongArray, boundaries: List<Long>, from: Long, to: Long) {
        for (i in totals.indices) {
            val overlap = minOf(to, boundaries[i + 1]) - maxOf(from, boundaries[i])
            if (overlap > 0) totals[i] += overlap
        }
    }

    /** The launcher apps; time on the home screen isn't screen time. */
    private fun homePackages(): Set<String> {
        val home = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        @Suppress("DEPRECATION")
        return context.packageManager
            .queryIntentActivities(home, PackageManager.MATCH_DEFAULT_ONLY)
            .map { it.activityInfo.packageName }
            .toSet()
    }
}
