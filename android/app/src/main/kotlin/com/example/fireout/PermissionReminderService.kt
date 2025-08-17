package com.example.fireout

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.location.LocationManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

class PermissionReminderService : Service() {

    companion object {
        private const val ONGOING_NOTIFICATION_ID = 1001
        private const val REMINDER_NOTIFICATION_ID = 1002
        private const val CHANNEL_ID = "permission_reminder"
        private const val CHANNEL_NAME = "Permission Reminder"
    }

    private val handler = Handler(Looper.getMainLooper())
    private val checkIntervalMs: Long = 6 * 60 * 60 * 1000 // every 6 hours

    private val periodicCheck = object : Runnable {
        override fun run() {
            try {
                showReminderIfNeeded()
            } catch (_: Throwable) { }
            handler.postDelayed(this, checkIntervalMs)
        }
    }

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // If notifications are completely blocked we can't run as a foreground service on Android 13+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val nm = NotificationManagerCompat.from(this)
            if (!nm.areNotificationsEnabled()) {
                // Attempt to open settings to prompt user when service starts
                val settingsIntent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                    putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                try { startActivity(settingsIntent) } catch (_: Throwable) { }
                stopSelf()
                return START_NOT_STICKY
            }
        }

        startForeground(ONGOING_NOTIFICATION_ID, buildOngoingNotification())
        handler.post(periodicCheck)
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        handler.removeCallbacks(periodicCheck)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val importance = NotificationManager.IMPORTANCE_LOW
            val channel = NotificationChannel(CHANNEL_ID, CHANNEL_NAME, importance).apply {
                description = "Reminds users to enable notifications and location"
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildOngoingNotification(): Notification {
        val openSettingsIntent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            }
        }
        val pending = PendingIntent.getActivity(
            this, 0, openSettingsIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("Fireout permissions monitor")
            .setContentText("Tap to review notification and location settings")
            .setContentIntent(pending)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun showReminderIfNeeded() {
        val notificationsEnabled = NotificationManagerCompat.from(this).areNotificationsEnabled()
        val locationEnabled = isLocationEnabled()

        if (!notificationsEnabled || !locationEnabled) {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = android.net.Uri.parse("package:$packageName")
            }
            val pending = PendingIntent.getActivity(
                this, 1, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
            )

            val text = when {
                !notificationsEnabled && !locationEnabled -> "Enable notifications and location for full functionality"
                !notificationsEnabled -> "Enable notifications to receive incident alerts"
                else -> "Enable location to improve incident accuracy"
            }

            val builder = NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_dialog_alert)
                .setContentTitle("Action required")
                .setContentText(text)
                .setStyle(NotificationCompat.BigTextStyle().bigText(text))
                .setAutoCancel(true)
                .setContentIntent(pending)
                .setPriority(NotificationCompat.PRIORITY_HIGH)

            with(NotificationManagerCompat.from(this)) {
                try { notify(REMINDER_NOTIFICATION_ID, builder.build()) } catch (_: Throwable) { }
            }
        }
    }

    private fun isLocationEnabled(): Boolean {
        return try {
            val lm = getSystemService(Context.LOCATION_SERVICE) as LocationManager
            val gps = lm.isProviderEnabled(LocationManager.GPS_PROVIDER)
            val network = lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
            gps || network
        } catch (_: Throwable) {
            false
        }
    }
}


