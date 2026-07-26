package com.vybe.driver

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    /**
     * Create the FCM notification channels at startup.
     *
     * Android drops a notification outright if its channel is created while
     * the app is in the background, which is what happens when the Firebase
     * SDK lazily creates the default channel on the first push. Creating them
     * here guarantees the channel exists first.
     *
     * Ride requests get their own high-importance channel so a driver is
     * actually alerted when a booking arrives.
     */
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)

            val general = NotificationChannel(
                "vybe_driver_channel",
                "Ride updates",
                NotificationManager.IMPORTANCE_HIGH
            )
            general.description = "Ride status and earnings updates"
            general.enableVibration(true)
            manager?.createNotificationChannel(general)

            val requests = NotificationChannel(
                "vybe_ride_requests",
                "New ride requests",
                NotificationManager.IMPORTANCE_HIGH
            )
            requests.description = "Alerts when a customer books a ride nearby"
            requests.enableVibration(true)
            requests.vibrationPattern = longArrayOf(0, 400, 200, 400)
            manager?.createNotificationChannel(requests)
        }
    }
}
