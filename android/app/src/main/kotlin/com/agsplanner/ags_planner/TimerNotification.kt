package com.agsplanner.ags_planner

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews

/**
 * The pomodoro/stopwatch entry in the status bar. The system renders the
 * ticking [android.widget.Chronometer], so it keeps counting while the app
 * is in the background. Drawn with custom layouts so the clock is large (on
 * the left when collapsed, full width when expanded), which the notifications
 * plugin can't do.
 */
object TimerNotification {
    const val ID = 3
    const val ACTION_OPEN = "com.agsplanner.ags_planner.OPEN_POMODORO"
    private const val CHANNEL = "pomodoro_timer"

    /**
     * [valueMs] is the time left ([countDown]) or elapsed. A paused timer
     * ([running] false) shows it frozen and can be swiped away.
     */
    fun show(
        context: Context,
        title: String,
        subject: String,
        valueMs: Long,
        countDown: Boolean,
        running: Boolean,
    ) {
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        val now = SystemClock.elapsedRealtime()
        // Both layouts share view ids: a large clock collapsed, a very large one expanded.
        fun views(layout: Int) = RemoteViews(context.packageName, layout).apply {
            setChronometer(R.id.timer_clock, if (countDown) now + valueMs else now - valueMs, null, running)
            setChronometerCountDown(R.id.timer_clock, countDown)
            setTextViewText(R.id.timer_title, title)
            setTextViewText(R.id.timer_subject, subject)
            setViewVisibility(R.id.timer_subject, if (subject.isEmpty()) View.GONE else View.VISIBLE)
        }
        val open = PendingIntent.getActivity(
            context,
            ID,
            Intent(context, MainActivity::class.java)
                .setAction(ACTION_OPEN)
                .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL, "Çalışan Sayaç", NotificationManager.IMPORTANCE_LOW).apply {
                    description = "Pomodoro ve kronometre süresini bildirim çubuğunda gösterir"
                    setSound(null, null)
                    enableVibration(false)
                },
            )
            Notification.Builder(context, CHANNEL).apply {
                // Disappear at zero; the end alarm takes over from there.
                if (countDown && running) setTimeoutAfter(valueMs.coerceAtLeast(1))
            }
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context).setPriority(Notification.PRIORITY_LOW)
        }
        builder
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(subject)
            .setCustomContentView(views(R.layout.notification_timer))
            .setCustomBigContentView(views(R.layout.notification_timer_big))
            .setStyle(Notification.DecoratedCustomViewStyle())
            .setContentIntent(open)
            .setOngoing(running)
            .setAutoCancel(false)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setCategory("stopwatch")
            .setVisibility(Notification.VISIBILITY_PUBLIC)
        try {
            manager.notify(ID, builder.build())
        } catch (e: SecurityException) {
            // Notification permission denied: the in-app timer still works.
        }
    }

    fun cancel(context: Context) {
        context.getSystemService(NotificationManager::class.java)?.cancel(ID)
    }
}
