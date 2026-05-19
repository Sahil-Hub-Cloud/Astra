import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import '../constants/app_constants.dart';
import 'supabase_client.dart';
import 'notification_service.dart';

class DangerZone {
  final double lat;
  final double lng;
  final double radius;
  final int riskLevel;
  final String reason;

  DangerZone({required this.lat, required this.lng, required this.radius, required this.riskLevel, required this.reason});

  factory DangerZone.fromJson(Map<String, dynamic> json) {
    return DangerZone(
      lat: json['center']['lat'].toDouble(),
      lng: json['center']['lng'].toDouble(),
      radius: json['radius_meters'].toDouble(),
      riskLevel: json['risk_level'],
      reason: json['reason'],
    );
  }
}

class DangerZoneService {
  static final DangerZoneService _instance = DangerZoneService._internal();
  factory DangerZoneService() => _instance;
  DangerZoneService._internal();

  List<DangerZone> _zones = [];
  bool _isMonitoring = false;

  Future<void> updateDangerZones(String city) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('danger_zones_cache');
      final lastUpdate = prefs.getInt('danger_zones_time') ?? 0;

      if (cached != null && DateTime.now().millisecondsSinceEpoch - lastUpdate < 6 * 60 * 60 * 1000) {
        final List decoded = jsonDecode(cached);
        _zones = decoded.map((z) => DangerZone.fromJson(z)).toList();
        return;
      }

      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
      final response = await supabase
          .from('incidents_feed')
          .select('latitude, longitude, type')
          .gt('created_at', thirtyDaysAgo);

      final incidentData = jsonEncode(response);

      final aiResponse = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${AppConstants.geminiApiKey}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'text': "Analyze these incident coordinates in $city. Identify 3-5 high-risk zones. Return ONLY valid JSON: {zones: [{center: {lat,lng}, radius_meters, risk_level: 1-10, reason}]}. Data: $incidentData"
                }
              ]
            }
          ]
        }),
      );

      if (aiResponse.statusCode == 200) {
        final data = jsonDecode(aiResponse.body);
        String text = data['candidates'][0]['content']['parts'][0]['text'];
        // Extract JSON if AI wrapped it in markdown
        if (text.contains('```json')) {
          text = text.split('```json')[1].split('```')[0];
        }
        final Map<String, dynamic> parsed = jsonDecode(text);
        final List zonesList = parsed['zones'];
        _zones = zonesList.map((z) => DangerZone.fromJson(z)).toList();

        await prefs.setString('danger_zones_cache', jsonEncode(zonesList));
        await prefs.setInt('danger_zones_time', DateTime.now().millisecondsSinceEpoch);
      }
    } catch (e) {
      debugPrint('DangerZoneService error: $e');
    }
  }

  int isLocationDangerous(double lat, double lng) {
    for (final zone in _zones) {
      final distance = Geolocator.distanceBetween(lat, lng, zone.lat, zone.lng);
      if (distance <= zone.radius) {
        return zone.riskLevel;
      }
    }
    return 0;
  }

  List<DangerZone> getZones() => _zones;

  void startProactiveMonitoring() {
    if (_isMonitoring) return;
    _isMonitoring = true;

    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 50),
    ).listen((Position position) {
      final risk = isLocationDangerous(position.latitude, position.longitude);
      if (risk >= 4 && position.speed * 3.6 > 2) {
        NotificationService.showLocalNotification(
          '⚠️ Entering Higher-Risk Area',
          'You are entering an area with higher recent incidents. Consider alternate routes or enable live sharing.'
        );
      }
    });
  }
}
