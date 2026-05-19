import "package:flutter/foundation.dart";
import 'package:geolocator/geolocator.dart';
import 'package:sms_advanced/sms_advanced.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import 'core/services/offline_queue_manager.dart';
import 'core/services/supabase_client.dart';

class SosService {
  final OfflineQueueManager _offlineQueue = OfflineQueueManager();

  Future<void> activateEmergencySOS(List<String> contacts) async {
    try {
      await _makeEmergencyCall();
    } catch (e) {
      debugPrint('Warning: Emergency call failed: $e — continuing');
    }

    Position? position;
    String message;

    try {
      position = await _getLocationWithTimeout(const Duration(seconds: 10));
      position ??= await Geolocator.getLastKnownPosition();

      if (position != null) {
        message = _buildMessage(position);
      } else {
        message = _buildMessageNoLocation();
      }
    } catch (e) {
      debugPrint('Location error: $e');
      message = _buildMessageNoLocation();
    }

    try {
      final connectivity = await Connectivity().checkConnectivity();

      if (connectivity == ConnectivityResult.none) {
        await _offlineQueue.addToOfflineQueue(
          message: message,
          recipients: contacts,
          latitude: position?.latitude ?? 0.0,
          longitude: position?.longitude ?? 0.0,
          timestamp: DateTime.now().toIso8601String(),
        );
      } else {
        await _sendSmsToContacts(contacts, message);
        if (position != null) {
          await _createSupabaseIncident(position, contacts);
        }
      }
    } catch (e) {
      debugPrint('Error in SOS flow: $e');
      try {
        await _sendSmsToContacts(contacts, _buildMessageNoLocation());
      } catch (_) {}
    }
  }

  Future<Position?> _getLocationWithTimeout(Duration timeout) async {
    final completer = Completer<Position?>();

    Timer(timeout, () {
      if (!completer.isCompleted) completer.complete(null);
    });

    try {
      Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high)
          .then((pos) {
        if (!completer.isCompleted) completer.complete(pos);
      }).catchError((e) {
        if (!completer.isCompleted) completer.complete(null);
      });
    } catch (_) {
      if (!completer.isCompleted) completer.complete(null);
    }

    return completer.future;
  }

  String _buildMessage(Position position) {
    return '🚨 EMERGENCY ALERT 🚨\n\n'
        'Help needed!\n'
        'Time: ${DateTime.now()}\n'
        'Location: https://www.google.com/maps?q='
        '${position.latitude},${position.longitude}\n'
        'Accuracy: ${position.accuracy.toInt()} meters';
  }

  String _buildMessageNoLocation() {
    return '🚨 EMERGENCY ALERT 🚨\n\n'
        'Help needed!\n'
        'Time: ${DateTime.now()}\n'
        'Location: Unable to determine';
  }

  Future<void> _sendSmsToContacts(List<String> contacts, String message) async {
    if (contacts.isEmpty) {
      throw Exception('No emergency contacts saved');
    }

    for (final number in contacts) {
      try {
        final clean = number.replaceAll(RegExp(r'[^0-9+]'), '');
        if (clean.isNotEmpty) {
          final sender = SmsSender();
          await sender.sendSms(SmsMessage(clean, message));
        }
      } catch (e) {
        debugPrint('Failed to send SMS to $number: $e');
      }
    }
  }

  Future<void> sendSmsToSingleContact(String number, String message) async {
    final clean = number.replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.isNotEmpty) {
      final sender = SmsSender();
      await sender.sendSms(SmsMessage(clean, message));
    }
  }

  Future<void> _createSupabaseIncident(Position position, List<String> contacts) async {
    try {
      final result = await supabase.rpc('create_incident_with_location', params: {
        'p_latitude': position.latitude,
        'p_longitude': position.longitude,
        'p_incident_type': 'sos',
        'p_severity': 'high',
        'p_description': 'Emergency SOS triggered from mobile app',
        'p_status': 'active',
        'p_emergency_contacts': contacts,
      });
      debugPrint('Supabase incident created');
      
      // Fire-and-forget notification to contacts via edge function
      if (result is Map<String, dynamic> && result['id'] != null) {
        _notifyContactsEdgeFunction(result['id'] as String);
      }
    } catch (e) {
      debugPrint('Failed to create Supabase incident: $e');
    }
  }

  Future<void> _notifyContactsEdgeFunction(String incidentId) async {
    try {
      await supabase.functions.invoke('notify-contacts', body: {
        'incident_id': incidentId,
        'timestamp': DateTime.now().toIso8601String(),
      });
      debugPrint('notify-contacts edge function invoked for incident: $incidentId');
    } catch (e) {
      // Never block SOS on notification failure
      debugPrint('Failed to invoke notify-contacts: $e');
    }
  }

  Future<void> _makeEmergencyCall() async {
    final uri = Uri(scheme: 'tel', path: '112');
    if (!await launchUrl(uri)) {
      await Clipboard.setData(const ClipboardData(text: '112'));
      debugPrint('Emergency number copied to clipboard: 112');
    }
  }
}
