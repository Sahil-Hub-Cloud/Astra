import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/services/supabase_client.dart';
import '../../core/utils/secure_storage.dart';

class SafetyDashboardScreen extends StatefulWidget {
  const SafetyDashboardScreen({super.key});

  @override
  State<SafetyDashboardScreen> createState() => _SafetyDashboardScreenState();
}

class _SafetyDashboardScreenState extends State<SafetyDashboardScreen> {
  bool _isLoading = true;
  int _sosThisMonth = 0;
  int _sosLastMonth = 0;
  int _safeDaysStreak = 0;
  int _contactsCount = 0;
  int _nearbyAlerts = 0;
  List<BarChartGroupData> _weeklyData = [];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    if (mounted) setState(() => _isLoading = true);
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      // 1. SOS This Month vs Last Month
      final now = DateTime.now();
      final firstDayMonth = DateTime(now.year, now.month, 1).toIso8601String();
      final firstDayLastMonth = DateTime(now.year, now.month - 1, 1).toIso8601String();

      final currentMonthResponse = await supabase
          .from('incidents')
          .select('id')
          .eq('user_id', user.id)
          .gte('created_at', firstDayMonth);

      final lastMonthResponse = await supabase
          .from('incidents')
          .select('id')
          .eq('user_id', user.id)
          .gte('created_at', firstDayLastMonth)
          .lt('created_at', firstDayMonth);

      _sosThisMonth = (currentMonthResponse as List).length;
      _sosLastMonth = (lastMonthResponse as List).length;

      // 2. Safe Days Streak
      final lastIncident = await supabase
          .from('incidents')
          .select('created_at')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(1);

      if ((lastIncident as List).isEmpty) {
        _safeDaysStreak = now.difference(DateTime.parse(user.createdAt)).inDays;
      } else {
        final lastDate = DateTime.parse(lastIncident[0]['created_at']);
        _safeDaysStreak = now.difference(lastDate).inDays;
      }

      // 3. Weekly Bar Chart
      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final startOfDay = DateTime(date.year, date.month, date.day).toIso8601String();
        final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59).toIso8601String();

        final dayResponse = await supabase
            .from('incidents')
            .select('id')
            .eq('user_id', user.id)
            .gte('created_at', startOfDay)
            .lte('created_at', endOfDay);

        _weeklyData.add(BarChartGroupData(
          x: 6 - i,
          barRods: [BarChartRodData(toY: (dayResponse as List).length.toDouble(), color: const Color(0xFF7C3AED))],
        ));
      }

      // 4. Contacts Status
      final contacts = await SecureStorage.loadEmergencyContacts();
      _contactsCount = contacts.length;

      // 5. Nearby Alerts (Placeholder/Mock logic for now as PostGIS query is complex)
      _nearbyAlerts = 5;

    } catch (e) {
      debugPrint('Dashboard data error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1419),
      appBar: AppBar(
        title: const Text('Safety Dashboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSOSOverviewCard(),
                const SizedBox(height: 16),
                _buildSafeDaysCard(),
                const SizedBox(height: 16),
                _buildIncidentChart(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildStatusCard('Contacts', '$_contactsCount', _contactsCount >= 3 ? Colors.green : Colors.red)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildStatusCard('Nearby Alerts', '$_nearbyAlerts', Colors.orange)),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildSOSOverviewCard() {
    final trend = _sosThisMonth - _sosLastMonth;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(13),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SOS Triggers (Month)', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$_sosThisMonth', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Icon(trend > 0 ? Icons.trending_up : Icons.trending_down, color: trend > 0 ? Colors.red : Colors.green),
                  const SizedBox(width: 4),
                  Text('${trend.abs()} vs last month', style: TextStyle(color: trend > 0 ? Colors.red : Colors.green)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSafeDaysCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF4C1D95)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text('Safe Days Streak', style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 8),
          Text('$_safeDaysStreak Days', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
          const Text('Keep staying safe!', style: TextStyle(color: Colors.white70, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildIncidentChart() {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(13),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Incidents (Last 7 Days)', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 20),
          Expanded(
            child: BarChart(
              BarChartData(
                barGroups: _weeklyData,
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(13),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
