# Hardware Button Trigger Implementation Notes

## Android Implementation Required

To make the power button + volume button trigger work, you'll need to implement native Android code:

### 1. AndroidManifest.xml additions:
```xml
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
```

### 2. Create a Background Service (Kotlin/Java):
```kotlin
class EmergencyButtonService : Service() {
    private var powerButtonCount = 0
    private var volumeButtonCount = 0
    private var lastTriggerTime = 0L
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onCreate() {
        super.onCreate()
        registerButtonListeners()
    }
    
    private fun registerButtonListeners() {
        // Listen for power button presses
        // Listen for volume button presses
        // Implement 30-second timeout logic
        // Trigger emergency when both reach 3 presses
    }
    
    private fun triggerEmergency() {
        // Send broadcast to Flutter app
        // Or directly trigger emergency actions
    }
}
```

### 3. Method Channel Handler:
```kotlin
// In MainActivity.kt
private fun setupEmergencyTriggerChannel() {
    MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, "disha/emergency_trigger")
        .setMethodCallHandler { call, result ->
            when (call.method) {
                "enableEmergencyTrigger" -> {
                    startEmergencyButtonService()
                    result.success(true)
                }
                "disableEmergencyTrigger" -> {
                    stopEmergencyButtonService()
                    result.success(true)
                }
            }
        }
}
```

## iOS Implementation Notes

iOS has stricter background execution policies, so this feature would be more limited:
- Requires special entitlements
- May need to use Accessibility features
- Apple's review process for emergency apps is strict

## Security Considerations

1. **False Trigger Prevention**: 
   - Require both buttons to prevent accidental activation
   - 30-second timeout window
   - Visual/audio confirmation when activated

2. **Battery Optimization**: 
   - Request ignore battery optimizations permission
   - Use foreground services appropriately

3. **User Control**: 
   - Clear toggle in settings
   - Ability to disable completely
   - Test mode option

## Testing Approach

1. Create a debug mode that shows button press counts
2. Test with different timing intervals
3. Verify proper timeout behavior
4. Test edge cases (app in background, screen off, etc.)