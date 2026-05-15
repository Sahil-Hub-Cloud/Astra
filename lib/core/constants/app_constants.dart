class AppConstants {
  // App Information
  static const String appName = 'Disha';
  static const String appVersion = '2.0.0';
  static const String appDescription = 'Your lifeline, anytime, anywhere';
  
  // Colors
  static const String primaryColor = '#4F46E5'; // Deep Indigo
  static const String secondaryColor = '#8B5CF6'; // Soft Purple
  static const String emergencyColor = '#FF6B6B'; // Vibrant Coral
  static const String backgroundColor = '#FAFAFA'; // Off-white
  static const String textColor = '#1F2937'; // Charcoal
  static const String secondaryTextColor = '#6B7280'; // Gray
  static const String successColor = '#10B981'; // Emerald
  static const String whiteColor = '#FFFFFF'; // Pure white
  
  // SOS Settings
  static const int defaultCountdownDuration = 3; // seconds
  static const int maxSOSActivationsPerMinute = 1;
  static const int bluetoothRangeMeters = 100;
  static const int locationCacheExpiryMinutes = 30;
  
  // Storage Keys
  static const String contactsBox = 'emergency_contacts';
  static const String settingsBox = 'app_settings';
  static const String historyBox = 'incident_history';
  static const String locationBox = 'location_cache';
  
  // Permission Keys
  static const String locationPermission = 'location_permission';
  static const String smsPermission = 'sms_permission';
  static const String callPermission = 'call_permission';
  static const String bluetoothPermission = 'bluetooth_permission';
  
  // Feature Flags
  static const bool enableVoiceActivation = true;
  static const bool enableBluetoothMesh = true;
  static const bool enableAudioRecording = true;
  static const bool enableCommunityMap = false; // Disabled by default for privacy
  static const bool enableHardwareButtonTrigger = true; // Power + Volume button trigger
}