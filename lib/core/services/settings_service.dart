import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'voice_activation_service.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  static const String _hardwareTriggerKey = 'hardware_trigger_enabled';
  static const String _autoLocationKey = 'auto_send_location';
  static const String _voiceActivationKey = 'voice_activation_enabled';

  final _storage = FlutterSecureStorage();

  Future<bool> isHardwareTriggerEnabled() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_hardwareTriggerKey) ?? true;
    }
    final value = await _storage.read(key: _hardwareTriggerKey);
    return value == null || value == 'true';
  }

  Future<void> setHardwareTriggerEnabled(bool value) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_hardwareTriggerKey, value);
    } else {
      await _storage.write(key: _hardwareTriggerKey, value: value.toString());
    }
  }

  Future<bool> isAutoLocationEnabled() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_autoLocationKey) ?? true;
    }
    final value = await _storage.read(key: _autoLocationKey);
    return value == null || value == 'true';
  }

  Future<void> setAutoLocationEnabled(bool value) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_autoLocationKey, value);
    } else {
      await _storage.write(key: _autoLocationKey, value: value.toString());
    }
  }

  Future<bool> isVoiceActivationEnabled() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_voiceActivationKey) ?? false;
    }
    final value = await _storage.read(key: _voiceActivationKey);
    return value == null || value == 'false';
  }

  Future<void> setVoiceActivationEnabled(bool value) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_voiceActivationKey, value);
    } else {
      await _storage.write(key: _voiceActivationKey, value: value.toString());
    }
    
    // Update voice activation service
    if (value) {
      await VoiceActivationService().enable();
    } else {
      await VoiceActivationService().disable();
    }
  }
}
