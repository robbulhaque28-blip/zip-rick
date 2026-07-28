package com.vybe.driver

import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.AudioAttributes
import android.media.Ringtone
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channelName = "com.vybe.driver/alert"
    private var ringtone: Ringtone? = null

    /**
     * Create the FCM notification channels at startup.
     *
     * Android drops a notification outright if its channel is created while
     * the app is in the background, which is what happens when the Firebase
     * SDK lazily creates the default channel on the first push. Creating them
     * here guarantees the channel exists first.
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

    /**
     * Native alert for an incoming ride request.
     *
     * Uses Android's built-in notification ringtone plus a vibration pattern,
     * so no audio package and no bundled sound file are required - nothing
     * new is added to the build. Routed through the ALARM stream so the
     * driver still hears it when the phone is on silent, which matters when
     * a booking is the thing they are waiting for.
     */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "rideRequestAlert" -> {
                        playAlert()
                        result.success(true)
                    }
                    "stopAlert" -> {
                        stopAlert()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun playAlert() {
        try {
            stopAlert()
            var uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            if (uri == null) uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            if (uri != null) {
                val r = RingtoneManager.getRingtone(applicationContext, uri)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    r.audioAttributes = AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                }
                r.play()
                ringtone = r
            }
        } catch (e: Exception) {
            // Sound is best-effort; never let it break the ride request.
        }

        try {
            val pattern = longArrayOf(0, 400, 200, 400, 200, 600)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vm = getSystemService(VibratorManager::class.java)
                vm?.defaultVibrator?.vibrate(VibrationEffect.createWaveform(pattern, -1))
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val v = getSystemService(Vibrator::class.java)
                v?.vibrate(VibrationEffect.createWaveform(pattern, -1))
            } else {
                @Suppress("DEPRECATION")
                val v = getSystemService(Vibrator::class.java)
                @Suppress("DEPRECATION")
                v?.vibrate(pattern, -1)
            }
        } catch (e: Exception) {
            // Vibration is optional too.
        }
    }

    private fun stopAlert() {
        try {
            ringtone?.let { if (it.isPlaying) it.stop() }
            ringtone = null
        } catch (e: Exception) {
        }
    }

    override fun onDestroy() {
        stopAlert()
        super.onDestroy()
    }
}
