package com.astra.emergency

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build

class AstraApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        
        // Create notification channel for Android 8.0+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "emergency_channel",
                "Emergency Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Critical emergency notifications from Astra"
                enableVibration(true)
                enableLights(true)
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }
}