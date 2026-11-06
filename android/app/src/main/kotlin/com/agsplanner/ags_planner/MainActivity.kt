package com.agsplanner.ags_planner

import android.app.AppOpsManager
import android.app.KeyguardManager
import android.app.NotificationManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Process
import android.provider.Settings
import android.util.Log
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * When the pomodoro end alarm (notification id 1) launches the app while the
 * phone is locked, the activity is shown over the lock screen only for that
 * moment; Flutter then covers everything with a minimal "time's up" screen.
 * Confirming (or the screen turning off) puts the lock screen back on top.
 *
 * Also hosts the status-bar timer ([TimerNotification]) and reports what
 * keeps the alarm from waking the screen.
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var timerChannel: MethodChannel? = null
    private var pendingAlarm: String? = null
    private var launchedFromTimer = false
    private var overLock = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        channel = MethodChannel(messenger, "ags/lock_alarm").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "takePending" -> {
                        result.success(pendingAlarm)
                        pendingAlarm = null
                    }
                    "dismiss" -> {
                        setOverLock(false)
                        result.success(null)
                    }
                    "wakeBlocker" -> result.success(wakeBlocker())
                    "confirmXiaomiPermissions" -> {
                        prefs().edit().putBoolean(KEY_XIAOMI_CONFIRMED, true).apply()
                        result.success(null)
                    }
                    "openXiaomiPermissions" -> {
                        openXiaomiPermissions()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
        timerChannel = MethodChannel(messenger, "ags/timer_notification").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "show" -> {
                        TimerNotification.show(
                            this@MainActivity,
                            title = call.argument<String>("title") ?: "",
                            subject = call.argument<String>("subject") ?: "",
                            valueMs = call.argument<Number>("valueMs")?.toLong() ?: 0L,
                            countDown = call.argument<Boolean>("countDown") ?: false,
                            running = call.argument<Boolean>("running") ?: false,
                        )
                        result.success(null)
                    }
                    "cancel" -> {
                        TimerNotification.cancel(this@MainActivity)
                        result.success(null)
                    }
                    "takeLaunch" -> {
                        result.success(launchedFromTimer)
                        launchedFromTimer = false
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent, coldStart = true)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent, coldStart = false)
    }

    override fun onStop() {
        super.onStop()
        // Screen turned off or the user left: never stay above the lock screen.
        if (overLock) {
            setOverLock(false)
            channel?.invokeMethod("hide", null)
        }
    }

    private fun handleIntent(intent: Intent?, coldStart: Boolean) {
        if (intent?.action == TimerNotification.ACTION_OPEN) {
            // Pulled by Dart on cold start; pushed when the engine is already running.
            if (coldStart) launchedFromTimer = true else timerChannel?.invokeMethod("tap", null)
            return
        }
        handleAlarm(intent)
    }

    private fun handleAlarm(intent: Intent?) {
        if (intent?.action != "SELECT_NOTIFICATION" || intent.getIntExtra("notificationId", -1) != 1) return
        val keyguard = getSystemService(KeyguardManager::class.java)
        if (keyguard == null || !keyguard.isKeyguardLocked) return
        setOverLock(true)
        // Pulled by Dart on cold start; pushed when the engine is already running.
        pendingAlarm = intent.getStringExtra("payload") ?: "pomodoro:work"
        channel?.invokeMethod("show", pendingAlarm)
    }

    /**
     * Why the end alarm can't wake the screen: "fullScreenIntent" (Android 14+
     * permission), "xiaomi" (MIUI/HyperOS "show on lock screen" or "open new
     * windows while running in the background" is off), "xiaomiUnverified"
     * (those can't be read on this MIUI/HyperOS version and the user hasn't
     * confirmed turning them on), or null.
     */
    private fun wakeBlocker(): String? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE &&
            getSystemService(NotificationManager::class.java)?.canUseFullScreenIntent() == false
        ) return "fullScreenIntent"
        if (!isXiaomi()) return null
        val ops = listOf(miuiOpAllowed(OP_SHOW_WHEN_LOCKED), miuiOpAllowed(OP_BACKGROUND_START_ACTIVITY))
        return when {
            false in ops -> "xiaomi"
            null in ops && !prefs().getBoolean(KEY_XIAOMI_CONFIRMED, false) -> "xiaomiUnverified"
            else -> null
        }
    }

    /** Xiaomi, Redmi and POCO phones all run MIUI/HyperOS. */
    private fun isXiaomi() = listOf(Build.MANUFACTURER, Build.BRAND).any {
        it.lowercase() in setOf("xiaomi", "redmi", "poco")
    }

    private fun prefs() = getSharedPreferences("ags_lock_alarm", MODE_PRIVATE)

    /**
     * MIUI keeps these permissions as private app-ops: allowed, denied
     * (ignored/errored), or null when unreadable on this system version.
     */
    private fun miuiOpAllowed(op: Int): Boolean? = try {
        val ops = getSystemService(AppOpsManager::class.java)
        val check = AppOpsManager::class.java.getMethod(
            "checkOpNoThrow", Int::class.javaPrimitiveType, Int::class.javaPrimitiveType, String::class.java,
        )
        when (check.invoke(ops, op, Process.myUid(), packageName) as Int) {
            AppOpsManager.MODE_ALLOWED -> true
            AppOpsManager.MODE_IGNORED, AppOpsManager.MODE_ERRORED -> false
            else -> null
        }
    } catch (e: Exception) {
        Log.w("AgsLockAlarm", "MIUI permission $op unreadable", e)
        null
    }

    /** MIUI's per-app "Other permissions" page, else the app's settings page. */
    private fun openXiaomiPermissions() {
        val miui = Intent("miui.intent.action.APP_PERM_EDITOR").putExtra("extra_pkgname", packageName)
        val attempts = listOf(
            Intent(miui).setClassName("com.miui.securitycenter", "com.miui.permcenter.permissions.PermissionsEditorActivity"),
            Intent(miui).setClassName("com.miui.securitycenter", "com.miui.permcenter.permissions.AppPermissionsEditorActivity"),
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", packageName, null)),
        )
        for (intent in attempts) {
            try {
                startActivity(intent)
                return
            } catch (e: Exception) {
                Log.w("AgsLockAlarm", "Cannot open ${intent.component ?: intent.action}", e)
            }
        }
    }

    private fun setOverLock(on: Boolean) {
        overLock = on
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(on)
            setTurnScreenOn(on)
        } else {
            @Suppress("DEPRECATION")
            val flags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            if (on) window.addFlags(flags) else window.clearFlags(flags)
        }
    }

    private companion object {
        // MIUI-specific app-op codes.
        const val OP_SHOW_WHEN_LOCKED = 10020
        const val OP_BACKGROUND_START_ACTIVITY = 10021
        const val KEY_XIAOMI_CONFIRMED = "xiaomi_permissions_confirmed"
    }
}
