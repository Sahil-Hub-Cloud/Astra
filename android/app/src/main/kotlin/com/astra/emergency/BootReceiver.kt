package com.astra.emergency

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        when (intent?.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                Log.d("AstraBoot", "Device booted or app updated")
                
                // Start foreground service to maintain emergency trigger
                val serviceIntent = Intent(context, EmergencyForegroundService::class.java)
                serviceIntent.action = "START_FOREGROUND_SERVICE"
                
                try {
                    context?.startForegroundService(serviceIntent)
                    Log.d("AstraBoot", "Foreground service started")
                } catch (e: Exception) {
                    Log.e("AstraBoot", "Failed to start foreground service", e)
                }
            }
        }
    }
}