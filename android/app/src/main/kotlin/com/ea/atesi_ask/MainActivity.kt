package com.ea.atesi_ask

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.ryanheise.audioservice.AudioServiceActivity

class MainActivity : AudioServiceActivity() {

    private val CHANNEL = "com.ea.atesi_ask/audio_control"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "forceStopNotification" -> {
                    try {
                        // 1. HAMLE: audio_service'in native Android servisini kökünden durdurur
                        val audioServiceIntent = Intent(applicationContext, com.ryanheise.audioservice.AudioService::class.java)
                        applicationContext.stopService(audioServiceIntent)
                        
                        // 2. HAMLE: Servis durdurulduktan sonra kalan bildirim kalıntılarını temizler
                        val notificationManager =
                            getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                        notificationManager.cancelAll()
                        
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("NOTIFICATION_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
