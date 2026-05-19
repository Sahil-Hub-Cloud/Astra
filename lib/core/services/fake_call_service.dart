import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shake/shake.dart';

class FakeCallService {
  static final FakeCallService _instance = FakeCallService._internal();
  factory FakeCallService() => _instance;
  FakeCallService._internal();

  ShakeDetector? _detector;
  Timer? _timer;
  BuildContext? _context;

  void initialize(BuildContext context) {
    _context = context;
    _detector = ShakeDetector.autoStart(
      onPhoneShake: () {
        triggerFakeCall(callerName: 'Mom');
      },
      shakeThresholdGravity: 2.7,
    );
  }

  void scheduleFakeCall({required String callerName, required int minutes}) {
    _timer?.cancel();
    _timer = Timer(Duration(minutes: minutes), () {
      triggerFakeCall(callerName: callerName);
    });
  }

  void triggerFakeCall({String callerName = 'Mom'}) {
    if (_context != null) {
      _context!.go('/fake-call?name=$callerName');
    }
  }

  void dispose() {
    _detector?.stopListening();
    _timer?.cancel();
  }
}
