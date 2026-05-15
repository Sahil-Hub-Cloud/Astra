package com.astra.emergency

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioManager
import android.os.Binder
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.math.abs

class EmergencyForegroundService : Service() {
    private val channelId = "EmergencyServiceChannel"
    private val notificationId = 1000
    private val volumePressNotificationId = 1001
    private val emergencyNotificationId = 1002
    
    private var isMonitoring = false
    private var backgroundFlutterEngine: FlutterEngine? = null
    
    // Volume button detection variables
    private var triggerSequenceCount = 0 // Track pattern completion
    private var lastVolumeDirection = 0 // 1 for up, -1 for down
    private var lastVolumeLevel = 0
    private var lastPressTime: Long = 0
    private val triggerSequence = mutableListOf<Int>()
    private var consecutivePresses = 0
    private var resetRunnable: Runnable? = null
    
    private val handler = Handler(Looper.getMainLooper())
    
    private val volumeButtonReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                "android.media.VOLUME_CHANGED_ACTION" -> {
                    handleVolumeChange()
                }
                Intent.ACTION_SCREEN_ON -> {
                    resetTrigger()
                }
            }
        }
    }
    
    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        Log.d("EmergencyService", "Service created")
    }
    
    private fun ensureFlutterEngineInitialized() {
        if (backgroundFlutterEngine != null) return
        
        Log.d("EmergencyService", "Initializing background Flutter Engine...")
        backgroundFlutterEngine = FlutterEngine(this)
        
        // Find the Dart entrypoint for background processing
        val loader = io.flutter.embedding.engine.loader.FlutterLoader()
        loader.startInitialization(this)
        loader.ensureInitializationComplete(this, null)
        
        val bundlePath = loader.findAppBundlePath()
        val entrypoint = io.flutter.embedding.engine.dart.DartExecutor.DartEntrypoint(
            bundlePath,
            "backgroundSmsEntryPoint"
        )
        
        backgroundFlutterEngine?.dartExecutor?.executeDartEntrypoint(entrypoint)
        Log.d("EmergencyService", "Background Dart entrypoint execution requested")
    }
    
    private fun sendEmergencyBroadcast() {
        // First, trigger via background isolate (reliable when app is killed)
        ensureFlutterEngineInitialized()
        
        // Also send broadcast for active UI listeners
        val intent = Intent("com.astra.emergency.TRIGGER")
        intent.putExtra("event", "emergency_triggered")
        try {
            sendBroadcast(intent)
            Log.d("EmergencyService", "Emergency broadcast sent to system")
        } catch (e: Exception) {
            Log.e("EmergencyService", "Failed to send emergency broadcast", e)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "START_FOREGROUND_SERVICE" -> startForegroundService()
            "STOP_FOREGROUND_SERVICE" -> stopForegroundService()
            "CANCEL_EMERGENCY_TRIGGER" -> {
                cancelEmergencyTrigger()
                return START_NOT_STICKY
            }
        }
        return START_STICKY
    }
    
    private fun cancelEmergencyTrigger() {
        Log.d("EmergencyService", "Emergency trigger cancelled by user")
        resetTrigger()
        
        // Show cancellation confirmation
        val cancelNotification = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("Emergency Trigger Cancelled")
            .setContentText("False trigger prevented")
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setAutoCancel(true)
            .build()
            
        with(getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager) {
            notify(volumePressNotificationId, cancelNotification)
        }
    }

    private fun startForegroundService() {
        if (isMonitoring) return
        
        isMonitoring = true
        
        // Register volume button receiver
        registerVolumeButtonReceiver()
        
        val notification = createNotification("Astra Emergency Monitoring Active")
        startForeground(notificationId, notification)
        
        Log.d("EmergencyService", "Foreground service started")
    }

    private fun stopForegroundService() {
        if (!isMonitoring) return
        
        isMonitoring = false
        unregisterVolumeButtonReceiver()
        stopForeground(true)
        stopSelf()
        
        Log.d("EmergencyService", "Foreground service stopped")
    }

    private fun registerVolumeButtonReceiver() {
        val filter = IntentFilter().apply {
            addAction("android.media.VOLUME_CHANGED_ACTION")
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
        }
        registerReceiver(volumeButtonReceiver, filter)
        Log.d("EmergencyService", "Volume button receiver registered")
    }

    private fun unregisterVolumeButtonReceiver() {
        try {
            unregisterReceiver(volumeButtonReceiver)
            Log.d("EmergencyService", "Volume button receiver unregistered")
        } catch (e: IllegalArgumentException) {
            Log.d("EmergencyService", "Volume button receiver not registered")
        }
    }

    private fun handleVolumeChange(): Boolean {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val currentMusicVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
        val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        
        Log.d("EmergencyService", "Current volume: $currentMusicVolume, Max volume: $maxVolume, Last direction: $lastVolumeDirection")
        
        // Determine direction based on volume change
        val currentDirection = when {
            currentMusicVolume > lastVolumeLevel -> 1  // Volume up
            currentMusicVolume < lastVolumeLevel -> -1 // Volume down  
            else -> 0  // No change
        }
        
        // Only process if there was an actual volume change (direction != 0)
        if (currentDirection != 0) {
            // Check if this creates the required sequence: Up -> Down -> Up -> Down
            if (lastVolumeDirection == -1 && currentDirection == 1) { // Up after Down
                triggerSequenceCount++
                Log.d("EmergencyService", "Up detected after Down, sequence count: $triggerSequenceCount")
            } else if (lastVolumeDirection == 1 && currentDirection == -1) { // Down after Up
                // This is part of the sequence but doesn't increment until the next up
                Log.d("EmergencyService", "Down detected after Up")
            } else if (lastVolumeDirection == 0) { // First press in sequence
                if (currentDirection == 1) { // First press is Up
                    triggerSequenceCount = 1
                    Log.d("EmergencyService", "First press - Up detected, sequence count: $triggerSequenceCount")
                } else {
                    triggerSequenceCount = 0  // Reset if first press isn't Up
                    Log.d("EmergencyService", "First press not Up, resetting sequence")
                }
            } else {
                // Direction changed but not in the expected sequence, reset
                triggerSequenceCount = if (currentDirection == 1) 1 else 0
                Log.d("EmergencyService", "Unexpected direction change, resetting sequence. New count: $triggerSequenceCount")
            }
            
            // Update our tracking variables
            lastVolumeDirection = currentDirection
            lastVolumeLevel = currentMusicVolume
            
            // Check if we've reached the trigger sequence: Up-Down-Up-Down (count reaches 2)
            if (triggerSequenceCount >= 2) {
                Log.d("EmergencyService", "Volume sequence completed! Triggering emergency.")
                triggerEmergency()
                return true
            }
        }
        
        return false
    }

    // This method is no longer used after our refactoring, but keeping for compatibility

    private fun triggerEmergency() {
        Log.d("EmergencyService", "Emergency triggered!")
        
        // Send emergency broadcast to the main activity
        sendEmergencyBroadcast()
        
        // Show emergency notification
        showEmergencyNotification()
        
        // Reset trigger
        resetTrigger()
    }

    private fun resetTrigger() {
        consecutivePresses = 0
        triggerSequence.clear()
        lastVolumeDirection = 0
        resetRunnable?.let { handler.removeCallbacks(it) }
        Log.d("EmergencyService", "Trigger reset - sequence cleared")
    }


    private fun showEmergencyNotification() {
        val notification = NotificationCompat.Builder(this, "emergency_channel")
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("🚨 EMERGENCY ACTIVATED")
            .setContentText("Astra emergency alert has been triggered")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setOngoing(false)
            .build()
        
        with(getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager) {
            notify(emergencyNotificationId, notification)
        }
    }

    private fun createNotification(contentText: String): Notification {
        return NotificationCompat.Builder(this, channelId)
            .setContentTitle("Astra Emergency")
            .setContentText(contentText)
            .setSmallIcon(android.R.drawable.ic_secure) // Security icon
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setOngoing(true)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Emergency Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps emergency detection running"
                setShowBadge(false)
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        isMonitoring = false
        unregisterVolumeButtonReceiver()
        // Clean up Flutter engine safely on main thread
        handler.post {
            backgroundFlutterEngine?.destroy()
            backgroundFlutterEngine = null
        }
        super.onDestroy()
        Log.d("EmergencyService", "Service destroyed")
    }
}