package com.agsplanner.ags_planner

import android.app.KeyguardManager
import android.app.NotificationManager
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * When the pomodoro end alarm (notification id 1) launches the app while the
 * phone is locked, the activity is shown over the lock screen only for that
 * moment; Flutter then covers everything with a minimal "time's up" screen.
 * Confirming (or the screen turning off) puts the lock screen back on top.
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var pendingAlarm: String? = null
    private var overLock = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ags/lock_alarm").apply {
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
                    // Android 14+ may deny full-screen intents; then the alarm can't wake the screen.
                    "canUseFullScreenIntent" -> result.success(
                        Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE ||
                            getSystemService(NotificationManager::class.java)?.canUseFullScreenIntent() != false
                    )
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleAlarm(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleAlarm(intent)
    }

    override fun onStop() {
        super.onStop()
        // Screen turned off or the user left: never stay above the lock screen.
        if (overLock) {
            setOverLock(false)
            channel?.invokeMethod("hide", null)
        }
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
}
