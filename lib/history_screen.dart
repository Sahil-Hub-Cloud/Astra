import 'package:flutter/material.dart';
import 'core/services/supabase_client.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _incidentHistory = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadIncidentHistory();
  }

  Future<void> _loadIncidentHistory() async {
    setState(() => _isLoading = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final response = await supabase
          .from('incidents')
          .select()
          .eq('user_id', userId)
          .order('reported_at', ascending: false);

      if (mounted) {
        setState(() {
          _incidentHistory =
              (response as List).cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading incident history: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Incident History'),
        backgroundColor: const Color(0xFF1a1a2e),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 20),
                      Text(
                        'Failed to load history',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _error!,
                        style: TextStyle(color: Colors.grey[500]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _loadIncidentHistory,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _incidentHistory.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history, size: 80, color: Colors.grey[400]),
                          const SizedBox(height: 20),
                          Text(
                            'No incident history yet',
                            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Your emergency alerts will appear here',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadIncidentHistory,
                      child: ListView.builder(
                        itemCount: _incidentHistory.length,
                        itemBuilder: (context, index) {
                          final incident = _incidentHistory[index];
                          return Card(
                            margin: const EdgeInsets.all(8),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: _getStatusColor(incident['severity']),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.warning,
                                    color: Colors.white, size: 20),
                              ),
                              title: Text(
                                incident['incident_type'] ??
                                    'Emergency Alert',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(incident['description'] ??
                                      'Emergency SOS triggered'),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Posted: ${_formatDateTime(incident['reported_at'])}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                              trailing: Text(
                                (incident['status'] as String?)?.toUpperCase() ??
                                    'ACTIVE',
                                style: TextStyle(
                                  color: _getStatusColor(
                                      incident['severity']),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  Color _getStatusColor(String? severity) {
    switch (severity?.toLowerCase()) {
      case 'high':
        return const Color(0xFFdc3545);
      case 'medium':
        return const Color(0xFFfd7e14);
      case 'low':
        return const Color(0xFFffc107);
      default:
        return const Color(0xFF0f3460);
    }
  }

  String _formatDateTime(String? dateTimeString) {
    if (dateTimeString == null) return '';
    try {
      final dt = DateTime.parse(dateTimeString);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return dateTimeString.length >= 10
          ? dateTimeString.substring(0, 10)
          : dateTimeString;
    }
  }
}
