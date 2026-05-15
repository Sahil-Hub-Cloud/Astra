import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class EmergencyHardwareTrigger {
  static const MethodChannel _channel = MethodChannel('astra/emergency_trigger');
  
  final Function() _onEmergencyTriggered;
  bool _isActive = false;

  EmergencyHardwareTrigger({
    required Function() onEmergencyTriggered,
  }) : _onEmergencyTriggered = onEmergencyTriggered {
    _setupMethodChannel();
  }

  void _setupMethodChannel() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'emergencyTriggered') {
        _onEmergencyTriggered();
      }
    });
  }

  Future<bool> enableTrigger() async {
    try {
      final notificationStatus = await Permission.notification.request();
      final ignoreBatteryStatus = await Permission.ignoreBatteryOptimizations.request();
      
      if (notificationStatus != PermissionStatus.granted) {
        if (kDebugMode) {
          print('Notification permission denied');
        }
        return false;
      }

      final result = await _channel.invokeMethod('enableEmergencyTrigger');
      _isActive = result as bool;
      
      if (kDebugMode) {
        print('Emergency hardware trigger enabled: $_isActive');
      }
      
      return _isActive;
    } catch (e) {
      if (kDebugMode) {
        print('Failed to enable emergency trigger: $e');
      }
      return false;
    }
  }

  Future<bool> disableTrigger() async {
    try {
      final result = await _channel.invokeMethod('disableEmergencyTrigger');
      _isActive = false;
      
      if (kDebugMode) {
        print('Emergency hardware trigger disabled');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Failed to disable emergency trigger: $e');
      }
      return false;
    }
  }

  Future<int> getCurrentTriggerStatus() async {
    try {
      final status = await _channel.invokeMethod('getCurrentTriggerStatus');
      return status as int;
    } catch (e) {
      if (kDebugMode) {
        print('Failed to get trigger status: $e');
      }
      return 0;
    }
  }

  bool get isActive => _isActive;

  void dispose() {
    disableTrigger();
  }
}
