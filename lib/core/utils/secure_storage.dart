import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage();
  static const String _contactsKey = 'secure_emergency_contacts';

  static Future<void> saveEmergencyContacts(List<String> contacts) async {
    final jsonContacts = jsonEncode(contacts);
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_contactsKey, jsonContacts);
    } else {
      await _storage.write(key: _contactsKey, value: jsonContacts);
    }
  }

  static Future<List<String>> loadEmergencyContacts() async {
    String? jsonContacts;
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      jsonContacts = prefs.getString(_contactsKey);
    } else {
      jsonContacts = await _storage.read(key: _contactsKey);
    }

    if (jsonContacts != null) {
      try {
        return List<String>.from(jsonDecode(jsonContacts));
      } catch (e) {
        return [];
      }
    }
    return [];
  }

  static Future<void> addEmergencyContact(String phoneNumber) async {
    final contacts = await loadEmergencyContacts();
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');

    if (cleanNumber.isNotEmpty && !contacts.contains(cleanNumber)) {
      contacts.add(cleanNumber);
      await saveEmergencyContacts(contacts);
    }
  }

  static Future<void> removeEmergencyContact(String phoneNumber) async {
    final contacts = await loadEmergencyContacts();
    contacts.remove(phoneNumber);
    await saveEmergencyContacts(contacts);
  }

  static Future<void> clearEmergencyContacts() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_contactsKey);
    } else {
      await _storage.delete(key: _contactsKey);
    }
  }
}
