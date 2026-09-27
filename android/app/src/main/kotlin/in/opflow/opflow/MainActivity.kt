package `in`.opflow.opflow

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // The channel the server's pushes use ("opflow"). Android 8+ needs it before a notification can show.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel("opflow", "Bookings and your line", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Booking updates, reminders and when your turn is near"
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Some phones (Vivo, Oppo, Xiaomi…) switch notifications off for apps installed outside the Play Store.
        // The app checks this and can open OPflow's own notification settings.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "opflow/notifications").setMethodCallHandler { call, result ->
            when (call.method) {
                "enabled" -> result.success(notificationsEnabled())
                "openSettings" -> {
                    openNotificationSettings()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    /** Notifications allowed for the app AND the "opflow" channel not turned off. */
    private fun notificationsEnabled(): Boolean {
        val nm = getSystemService(NotificationManager::class.java)
        if (!nm.areNotificationsEnabled()) return false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = nm.getNotificationChannel("opflow")
            if (ch != null && ch.importance == NotificationManager.IMPORTANCE_NONE) return false
        }
        return true
    }

    private fun openNotificationSettings() {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
        } else {
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
        }
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            startActivity(intent)
        } catch (e: Exception) {
            startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }
    }
}
