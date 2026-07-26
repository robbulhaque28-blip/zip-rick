package com.vybe.customer

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    /**
     * Create the FCM notification channel as soon as the app starts.
     *
     * Android drops a notification outright if its channel is created while
     * the app is in the background - which is exactly what happens when the
     * Firebase SDK lazily creates the default channel on the first incoming
     * push. Creating it here means the channel always exists first, so the
     * very first notification is delivered instead of being silently lost.
     */
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "vybe_customer_channel",
                "Ride updates",
                NotificationManager.IMPORTANCE_HIGH
            )
            channel.description = "Driver assigned, arrival, ride start and completion alerts"
            channel.enableVibration(true)
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }
}
