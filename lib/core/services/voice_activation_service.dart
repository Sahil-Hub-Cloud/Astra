import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../sos_service.dart';
import '../utils/secure_storage.dart';

class VoiceActivationService {
  static final VoiceActivationService _instance = VoiceActivationService._internal();
  factory VoiceActivationService() => _instance;
  VoiceActivationService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _enabled = false;
  Timer? _countdownTimer;
  int _countdownSeconds = 0;

  bool get isListening => _isListening;
  bool get isEnabled => _enabled;

  Future<bool> enable() async {
    final available = await _speech.initialize(
      onStatus: (status) {
        debugPrint('Speech status: $status');
      },
      onError: (error) {
        debugPrint('Speech error: $error');
      },
    );

    if (!available) {
      debugPrint('Speech recognition not available');
      return false;
    }

    _enabled = true;
    _startListening();
    return true;
  }

  Future<void> disable() async {
    _enabled = false;
    _stopListening();
    _cancelCountdown();
  }

  Future<void> _startListening() async {
    if (!_enabled || _isListening) return;

    try {
      await _speech.listen(
        onResult: (result) => _onSpeechResult(result),
        listenMode: stt.ListenMode.confirmation,
        pauseFor: const Duration(seconds: 2),
        partialResults: true,
      );
      _isListening = true;
      debugPrint('Voice activation listening started');
    } catch (e) {
      debugPrint('Error starting speech recognition: $e');
      _isListening = false;
    }
  }

  Future<void> _stopListening() async {
    if (!_isListening) return;

    try {
      await _speech.stop();
      _isListening = false;
      debugPrint('Voice activation listening stopped');
    } catch (e) {
      debugPrint('Error stopping speech recognition: $e');
    }
  }

  void _onSpeechResult(dynamic result) {
    if (!_enabled || _countdownSeconds > 0) return;

    final lowerResult = result.recognizedWords.toLowerCase();
    final keywords = ['help', 'bachao', 'save me', 'emergency', 'madad'];

    for (final keyword in keywords) {
      if (lowerResult.contains(keyword)) {
        debugPrint('Keyword detected: $keyword');
        _startCountdown(keyword);
        break;
      }
    }
  }

  void _startCountdown(String keyword) {
    _cancelCountdown();
    _countdownSeconds = 3;

    // Show notification using Flutter's native notification system
    ScaffoldMessenger.of(WidgetsBinding.instance.focusManager.primaryFocus!.context!).showSnackBar(
      SnackBar(
        content: Text('Voice SOS: Triggering in $_countdownSeconds seconds...'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 1),
      ),
    );

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _countdownSeconds--;
      
      ScaffoldMessenger.of(WidgetsBinding.instance.focusManager.primaryFocus!.context!).showSnackBar(
        SnackBar(
          content: Text('Voice SOS: $_countdownSeconds...'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 1),
        ),
      );

      if (_countdownSeconds <= 0) {
        _triggerSOS(keyword);
        timer.cancel();
      }
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _countdownSeconds = 0;
  }

  Future<void> _triggerSOS(String keyword) async {
    debugPrint('Voice SOS triggered via keyword: $keyword');
    
    final sosService = SosService();
    final contacts = await SecureStorage.loadEmergencyContacts();
    
    await sosService.activateEmergencySOS(contacts);
  }
}
