import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'core/services/supabase_client.dart';

class AstraBackend {
  static final AstraBackend _instance = AstraBackend._internal();
  factory AstraBackend() => _instance;
  AstraBackend._internal();
  static bool _isCurrentlyProcessingSOS = false;

  Future<void> triggerEmergencySOS(Position position, List<String> contacts) async {
    if (_isCurrentlyProcessingSOS) {
      print('⚠️ Emergency already in progress, skipping duplicate trigger');
      return;
    }

    _isCurrentlyProcessingSOS = true;
    try {
      final userId = supabase.auth.currentUser?.id ?? 'anonymous_user';

      final incidentId = await supabase.rpc('create_incident_with_location', params: {
        'p_latitude': position.latitude,
        'p_longitude': position.longitude,
        'p_incident_type': 'sos',
        'p_severity': 'high',
        'p_description': 'Emergency SOS triggered from mobile app',
        'p_status': 'active',
        'p_emergency_contacts': contacts,
      });

      print('Emergency incident created: $incidentId at ${position.latitude}, ${position.longitude}');
    } catch (e) {
      print('Error creating emergency incident: $e');
      rethrow;
    } finally {
      _isCurrentlyProcessingSOS = false;
    }
  }

  Future<List<dynamic>> getNearbyIncidents(Position myPosition, {int radiusMeters = 1000}) async {
    try {
      final result = await supabase.rpc('get_nearby_incidents', params: {
        'p_lat': myPosition.latitude,
        'p_lng': myPosition.longitude,
        'p_radius_meters': radiusMeters,
        'p_limit': 50,
      });
      return result as List<dynamic>;
    } catch (e) {
      print('Error fetching nearby incidents: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getIncidentStats() async {
    try {
      final response = await supabase.rpc('get_incident_stats');
      if (response is List && response.isNotEmpty) {
        return response[0] as Map<String, dynamic>;
      }
      return {'total_active': 0, 'total_resolved': 0, 'recent_24h': 0};
    } catch (e) {
      print('Error fetching stats: $e');
      return {'total_active': 0, 'total_resolved': 0, 'recent_24h': 0};
    }
  }

  Future<void> updateIncidentStatus(String incidentId, String status) async {
    try {
      await supabase.from('incidents').update({'status': status}).eq('id', incidentId);
    } catch (e) {
      print('Error updating incident: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getUserStats() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return {};

      final result = await supabase.from('incidents').select().eq('user_id', userId);
      return {'total_incidents': (result as List).length};
    } catch (e) {
      print('Error fetching user stats: $e');
      return {};
    }
  }
}
