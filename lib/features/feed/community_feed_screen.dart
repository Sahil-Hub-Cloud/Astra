import "package:go_router/go_router.dart";
/*
Supabase Table Schema:
incidents_feed (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references auth.users(id),
  type text not null, -- harassment/theft/accident/suspicious/other
  description text,
  latitude double precision not null,
  longitude double precision not null,
  created_at timestamptz default now(),
  confirmations_count int default 0
)
*/

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/supabase_client.dart';

class CommunityFeedScreen extends StatefulWidget {
  const CommunityFeedScreen({super.key});

  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen> {
  final List<Map<String, dynamic>> _alerts = [];
  bool _isLoading = true;
  Position? _currentPosition;
  RealtimeChannel? _feedSubscription;

  @override
  void initState() {
    super.initState();
    _initFeed();
  }

  @override
  void dispose() {
    _feedSubscription?.unsubscribe();
    super.dispose();
  }

  Future<void> _initFeed() async {
    try {
      _currentPosition = await Geolocator.getCurrentPosition();
      await _fetchInitialAlerts();
      _subscribeToFeed();
    } catch (e) {
      debugPrint('Feed init error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchInitialAlerts() async {
    final twoHoursAgo = DateTime.now().subtract(const Duration(hours: 2)).toIso8601String();
    final response = await supabase
        .from('incidents_feed')
        .select()
        .gt('created_at', twoHoursAgo)
        .order('created_at', ascending: false);

    if (mounted) {
      setState(() {
        _alerts.clear();
        _alerts.addAll(List<Map<String, dynamic>>.from(response as List));
      });
    }
  }

  void _subscribeToFeed() {
    _feedSubscription = supabase
        .channel('public:incidents_feed')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'incidents_feed',
          callback: (payload) {
            _fetchInitialAlerts(); // Refresh for simplicity
          },
        )
        .subscribe();
  }

  Future<void> _postAlert(String type, String description) async {
    if (_currentPosition == null) return;

    try {
      await supabase.from('incidents_feed').insert({
        'user_id': supabase.auth.currentUser?.id,
        'type': type,
        'description': description,
        'latitude': _currentPosition!.latitude,
        'longitude': _currentPosition!.longitude,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alert posted anonymously'), backgroundColor: Colors.green));
      }
    } catch (e) {
      debugPrint('Post alert error: $e');
    }
  }

  Future<void> _confirmAlert(String id, int currentCount) async {
    try {
      await supabase
          .from('incidents_feed')
          .update({'confirmations_count': currentCount + 1})
          .eq('id', id);
    } catch (e) {
      debugPrint('Confirm alert error: $e');
    }
  }

  void _showAddAlertSheet() {
    String selectedType = 'suspicious';
    final descController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1a1a2e),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Post Anonymous Alert', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: selectedType,
              dropdownColor: const Color(0xFF1a1a2e),
              items: ['harassment', 'theft', 'accident', 'suspicious', 'other']
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase(), style: const TextStyle(color: Colors.white))))
                  .toList(),
              onChanged: (val) => selectedType = val!,
              decoration: const InputDecoration(labelText: 'Alert Type', labelStyle: TextStyle(color: Colors.white70)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Description (optional)', labelStyle: TextStyle(color: Colors.white70)),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                _postAlert(selectedType, descController.text);
                context.pop();
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED), minimumSize: const Size(double.infinity, 50)),
              child: const Text('Post Alert'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1419),
      appBar: AppBar(
        title: const Text('Community Safety Feed', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_alert, color: Color(0xFF7C3AED)),
            onPressed: _showAddAlertSheet,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _alerts.isEmpty
              ? _buildEmptyFeed()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _alerts.length,
                  itemBuilder: (context, index) => _buildAlertCard(_alerts[index]),
                ),
    );
  }

  Widget _buildEmptyFeed() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.rss_feed, size: 80, color: Colors.white24),
          SizedBox(height: 16),
          Text('No alerts in your area right now.', style: TextStyle(color: Colors.white70, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert) {
    final type = alert['type'] as String;
    final dist = _currentPosition != null
        ? Geolocator.distanceBetween(_currentPosition!.latitude, _currentPosition!.longitude, alert['latitude'], alert['longitude'])
        : 0.0;

    final timeAgo = DateTime.now().difference(DateTime.parse(alert['created_at'])).inMinutes;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(13),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: _getTypeColor(type).withAlpha(51), borderRadius: BorderRadius.circular(20)),
                child: Text(type.toUpperCase(), style: TextStyle(color: _getTypeColor(type), fontWeight: FontWeight.bold, fontSize: 10)),
              ),
              Text('${dist < 1000 ? dist.toInt() : (dist/1000).toStringAsFixed(1)} ${dist < 1000 ? 'm' : 'km'} away', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          if (alert['description'] != null && alert['description'].isNotEmpty)
            Text(alert['description'], style: const TextStyle(color: Colors.white, fontSize: 14)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$timeAgo min ago', style: const TextStyle(color: Colors.white38, fontSize: 12)),
              Row(
                children: [
                  Text('${alert['confirmations_count']} confirmed', style: const TextStyle(color: Colors.green, fontSize: 12)),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _confirmAlert(alert['id'], alert['confirmations_count']),
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Confirm'),
                    style: TextButton.styleFrom(foregroundColor: Colors.green, padding: EdgeInsets.zero, minimumSize: Size.zero),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'harassment': return Colors.red;
      case 'theft': return Colors.orange;
      case 'accident': return Colors.blue;
      case 'suspicious': return Colors.yellow;
      default: return Colors.purple;
    }
  }
}
