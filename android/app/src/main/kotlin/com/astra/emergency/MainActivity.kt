package com.astra.emergency

import android.app.ActivityManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val EMERGENCY_CHANNEL = "astra/emergency_trigger"
    private val OFFLINE_QUEUE_CHANNEL = "astra/offline_queue"
    private var emergencyMethodChannel: MethodChannel? = null
    private var offlineQueueMethodChannel: MethodChannel? = null
    
    // Static broadcast receiver for emergency triggers from service
    companion object {
        private val emergencyBroadcastReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                when (intent?.action) {
                    "com.astra.emergency.TRIGGER" -> {
                        // Forward to Flutter - this will only work if Flutter is running
                        // We'll handle this through a static method instead
                        Log.d("MainActivity", "Emergency broadcast received")
                    }
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Emergency trigger channel
        emergencyMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, EMERGENCY_CHANNEL)
        emergencyMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "enableEmergencyTrigger" -> {
                    enableEmergencyTrigger()
                    result.success(true)
                }
                "disableEmergencyTrigger" -> {
                    disableEmergencyTrigger()
                    result.success(true)
                }
                "getCurrentTriggerStatus" -> {
                    result.success(0) // Status is handled by service
                }
                else -> result.notImplemented()
            }
        }
        
        // Offline queue channel
        offlineQueueMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OFFLINE_QUEUE_CHANNEL)
        offlineQueueMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleOfflineProcessing" -> {
                    scheduleOfflineQueueProcessing()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Register broadcast receiver when activity is created
        registerEmergencyReceiver()
    }
    
    override fun onDestroy() {
        super.onDestroy()
        // Unregister broadcast receiver when activity is destroyed
        unregisterEmergencyReceiver()
        // Clean up method channel
        emergencyMethodChannel?.setMethodCallHandler(null)
        offlineQueueMethodChannel?.setMethodCallHandler(null)
    }
    
    private fun registerEmergencyReceiver() {
        try {
            val filter = IntentFilter("com.astra.emergency.TRIGGER")
            registerReceiver(emergencyBroadcastReceiver, filter)
            Log.d("MainActivity", "Emergency broadcast receiver registered")
        } catch (e: Exception) {
            Log.e("MainActivity", "Failed to register emergency broadcast receiver", e)
        }
    }
    
    private fun unregisterEmergencyReceiver() {
        try {
            unregisterReceiver(emergencyBroadcastReceiver)
            Log.d("MainActivity", "Emergency broadcast receiver unregistered")
        } catch (e: Exception) {
            Log.e("MainActivity", "Failed to unregister emergency broadcast receiver", e)
        }
    }
    
    private fun enableEmergencyTrigger() {
        // Check if service is already running
        if (!isServiceForegrounded(EmergencyForegroundService::class.java)) {
            // Start foreground service to handle emergency trigger
            val serviceIntent = Intent(this, EmergencyForegroundService::class.java)
            serviceIntent.action = "START_FOREGROUND_SERVICE"
            
            try {
                startForegroundService(serviceIntent)
                Log.d("AstraHardware", "Emergency trigger service started")
            } catch (e: Exception) {
                Log.e("AstraHardware", "Failed to start foreground service", e)
            }
        } else {
            Log.d("AstraHardware", "Emergency trigger service already running")
        }
    }
    
    private fun isServiceForegrounded(serviceClass: Class<*>): Boolean {
        val manager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        for (service in manager.getRunningServices(Int.MAX_VALUE)) {
            if (serviceClass.name == service.service.className) {
                return service.foreground
            }
        }
        return false
    }

    private fun disableEmergencyTrigger() {
        // Stop foreground service
        val serviceIntent = Intent(this, EmergencyForegroundService::class.java)
        serviceIntent.action = "STOP_FOREGROUND_SERVICE"
        
        try {
            startService(serviceIntent) // Use startService to send command
            Log.d("AstraHardware", "Emergency trigger service stopping")
        } catch (e: Exception) {
            Log.e("AstraHardware", "Failed to stop foreground service", e)
        }
    }
    
    private fun scheduleOfflineQueueProcessing() {
        try {
            OfflineQueueWorker.scheduleQueueProcessing(this)
            Log.d("AstraOffline", "Offline queue processing scheduled via WorkManager")
        } catch (e: Exception) {
            Log.e("AstraOffline", "Failed to schedule offline queue processing", e)
        }
    }
}