import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'supabase_client.dart';

class PoliceIntegrationService {

  Future<bool> sendAlertToPolice({
    required Position location,
    required String userId,
    required String incidentDescription,
    String urgencyLevel = 'high',
  }) async {
    try {
      final auth = supabase.auth.currentUser;
      if (auth == null) {
        throw Exception('User not authenticated');
      }

      final userRole = auth.userMetadata?['role'] as String?;
      if (userRole != 'verified_responder' && userRole != 'admin') {
        throw Exception('Insufficient permissions for police integration');
      }

      final response = await supabase.from('police_alerts').insert({
        'incident_id': null,
        'latitude': location.latitude,
        'longitude': location.longitude,
        'message': incidentDescription,
        'alert_type': 'police_dispatch',
        'priority': urgencyLevel,
        'status': 'pending', 
      }).select();

      final alertId = response[0]['id'];
      print('Police alert created: $alertId at ${location.latitude}, ${location.longitude}');
      
      return true;
    } catch (e) {
      print('Error sending alert to police: $e');
      return false;
    }
  }

  bool hasPoliceIntegrationAccess() {
    final auth = supabase.auth.currentUser;
    if (auth == null) return false;
    final role = auth.userMetadata?['role'] as String?;
    return role == 'verified_responder' || role == 'admin';
  }

  Future<Map<String, dynamic>> getPoliceAvailability(double lat, double lng) async {
    try {
      return {
        'department_available': true,
        'estimated_response_time': '8-12 minutes',
        'officers_available': 3,
        'area_coverage': 'Full coverage in your area',
      };
    } catch (e) {
      print('Error getting police availability: $e');
      return {
        'department_available': false,
        'estimated_response_time': 'Unknown',
        'officers_available': 0,
        'area_coverage': 'No coverage available',
      };
    }
  }

  Future<List<String>> getPoliceContactsForArea(double lat, double lng) async {
    try {
      return ['112', '100'];
    } catch (e) {
      print('Error getting police contacts: $e');
      return ['112'];
    }
  }

  Future<String?> submitIncidentReport({
    required String userId,
    required Position location,
    required String incidentType,
    required String description,
    List<String> evidenceUrls = const [],
  }) async {
    try {
      final response = await supabase.from('incident_reports').insert({
        'reporter_id': userId,
        'incident_id': null,
        'report_title': incidentType,
        'report_details': description,
        'media_urls': evidenceUrls,
      }).select();

      return response[0]['id'];
    } catch (e) {
      print('Error submitting incident report: $e');
      return null;
    }
  }
}
