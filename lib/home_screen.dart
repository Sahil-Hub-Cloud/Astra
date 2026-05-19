import "package:go_router/go_router.dart";
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

import 'sos_service.dart';
import 'astra_backend.dart';
import 'core/services/emergency_hardware_trigger.dart';
import 'core/services/offline_queue_manager.dart';
import 'core/utils/secure_storage.dart';
import 'core/services/supabase_client.dart';
import 'core/services/fake_call_service.dart';
import 'core/services/danger_zone_service.dart';
import 'core/constants/app_constants.dart';
import 'features/dashboard/safety_dashboard_screen.dart';
import 'features/feed/community_feed_screen.dart';
import 'profile_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

@pragma('vm:entry-point')
void backgroundSmsEntryPoint() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final supabaseUrl = const String.fromEnvironment('SUPABASE_URL');
  final supabaseAnonKey = const String.fromEnvironment('SUPABASE_ANON_KEY');
  
  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }
  
  await _handleBackgroundEmergency();
}

Future<void> _handleBackgroundEmergency() async {
  final sosService = SosService();
  final astraBackend = AstraBackend();
  
  final contacts = await SecureStorage.loadEmergencyContacts();
  
  await sosService.activateEmergencySOS(contacts);
  
  try {
    Position? position = await _getRobustPositionGlobal();
    if (position != null) {
      await astraBackend.triggerEmergencySOS(position, contacts);
    } else {
      debugPrint('❌ Background SOS: No location available after waterfall');
    }
  } catch (e) {
    debugPrint('Background SOS backend update failed: $e');
  }
}

Future<Position?> _getRobustPositionGlobal() async {
  try {
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 5),
    );
  } catch (e) {
    debugPrint('⚠️ High-accuracy fix failed, falling back to LastKnown: $e');
    return await Geolocator.getLastKnownPosition();
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeContent(),
    const SafetyDashboardScreen(),
    const CommunityFeedScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1419),
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppConstants.surfaceDark,
        selectedItemColor: AppConstants.primaryPurple,
        unselectedItemColor: Colors.white54,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.shield), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.location_on), label: 'Feed'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> with TickerProviderStateMixin, WidgetsBindingObserver {
  GoogleMapController? _mapController;
  final Set<Circle> _circles = {};
  LatLng _currentMapPos = const LatLng(28.6139, 77.2090); // Default Delhi

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  String _networkStatus = 'Checking...';
  String _gpsStatus = 'Checking...';
  List<String> _emergencyContacts = [];
  bool _isSosActive = false;

  final SosService _sosService = SosService();
  final AstraBackend _astraBackend = AstraBackend();
  final OfflineQueueManager _offlineQueue = OfflineQueueManager();
  late EmergencyHardwareTrigger _emergencyTrigger;

  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  RealtimeChannel? _incidentSubscription;
  Timer? _statusUpdateTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _emergencyTrigger = EmergencyHardwareTrigger(
      onEmergencyTriggered: _activateSOS,
    );
    _setupAnimations();
    _loadContacts();
    _setupHardwareTrigger();
    FakeCallService().initialize(context);
    _startNearbyMonitoring();
    _monitorConnectivity();
    _startStatusUpdates();
    _initDangerZones();
  }

  Future<void> _initDangerZones() async {
    await DangerZoneService().updateDangerZones('New Delhi');
    _updateMapZones();
  }

  void _updateMapZones() {
    final zones = DangerZoneService().getZones();
    setState(() {
      _circles.clear();
      for (final zone in zones) {
        _circles.add(Circle(
          circleId: CircleId(zone.reason),
          center: LatLng(zone.lat, zone.lng),
          radius: zone.radius,
          fillColor: zone.riskLevel >= 7
              ? Colors.red.withAlpha(77)
              : Colors.orange.withAlpha(77),
          strokeWidth: 1,
          strokeColor: zone.riskLevel >= 7 ? Colors.red : Colors.orange,
        ));
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    _pulseController.dispose();
    _mapController?.dispose();
    _emergencyTrigger.dispose();
    _incidentSubscription?.unsubscribe();
    _statusUpdateTimer?.cancel();
    super.dispose();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _setupHardwareTrigger() async {
    await _emergencyTrigger.enableTrigger();
  }

  void _startStatusUpdates() {
    _refreshNetworkStatus();
    _refreshGpsStatus();
    _statusUpdateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        _refreshNetworkStatus();
        _refreshGpsStatus();
      }
    });
  }

  void _refreshNetworkStatus() {
    Connectivity().checkConnectivity().then((result) {
      if (!mounted) return;
      setState(() {
        _networkStatus = result == ConnectivityResult.none ? 'Offline' : 'Connected';
      });
    });
  }

  void _refreshGpsStatus() {
    Geolocator.isLocationServiceEnabled().then((enabled) {
      if (!mounted) return;
      setState(() {
        _gpsStatus = enabled ? 'Active' : 'Disabled';
      });
    });
  }

  Future<void> _loadContacts() async {
    final contacts = await SecureStorage.loadEmergencyContacts();
    if (mounted) setState(() => _emergencyContacts = contacts);
  }

  void _monitorConnectivity() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (result != ConnectivityResult.none) _processOfflineQueue();
      if (mounted) {
        setState(() {
          _networkStatus = result == ConnectivityResult.none ? 'Offline' : 'Connected';
        });
      }
    });
  }

  Future<void> _processOfflineQueue() async {
    await _offlineQueue.processOfflineQueue();
    final queueSize = await _offlineQueue.getQueueSize();
    if (queueSize == 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ All queued emergency alerts sent!'), backgroundColor: Colors.green),
      );
    }
  }

  void _startNearbyMonitoring() {
    _incidentSubscription = supabase.channel('nearby_incidents').onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'incidents',
      callback: (payload) => _handleNewIncident(payload.newRecord),
    ).subscribe();
  }

  Future<void> _handleNewIncident(Map<String, dynamic> incident) async {
    try {
      final lat = incident['latitude'] as double;
      final lng = incident['longitude'] as double;
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
      final distance = Geolocator.distanceBetween(position.latitude, position.longitude, lat, lng);

      if (distance <= 1000 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🚨 SOS: Nearby ${incident['incident_type']} detected!'),
            backgroundColor: Colors.deepOrange,
            duration: const Duration(seconds: 10),
            action: SnackBarAction(label: 'Details', textColor: Colors.white, onPressed: () {}),
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _activateSOS() async {
    if (_isSosActive) return;
    setState(() => _isSosActive = true);
    try {
      await _sosService.activateEmergencySOS(_emergencyContacts);
      final position = await _getRobustPosition();
      if (position != null) await _astraBackend.triggerEmergencySOS(position, _emergencyContacts);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🚀 Emergency alert activated! Help is on the way.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSosActive = false);
    }
  }

  Future<Position?> _getRobustPosition() async {
    try {
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 5));
      _checkLocationForCaution(pos);
      return pos;
    } catch (_) {
      return await Geolocator.getLastKnownPosition();
    }
  }

  void _showFakeCallSheet() {
    final nameController = TextEditingController(text: 'Mom');
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a1a2e),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Fake Call Options', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Caller Name',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _fakeCallOption('Now', 0, nameController),
                _fakeCallOption('2 min', 2, nameController),
                _fakeCallOption('5 min', 5, nameController),
                _fakeCallOption('10 min', 10, nameController),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _fakeCallOption(String label, int minutes, TextEditingController controller) {
    return ElevatedButton(
      onPressed: () {
        if (minutes == 0) {
          FakeCallService().triggerFakeCall(callerName: controller.text);
        } else {
          FakeCallService().scheduleFakeCall(callerName: controller.text, minutes: minutes);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fake call scheduled in $minutes minutes'), backgroundColor: Colors.indigo));
        }
        context.pop();
      },
      style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryPurple),
      child: Text(label),
    );
  }

  void _checkLocationForCaution(Position pos) {
    final risk = DangerZoneService().isLocationDangerous(pos.latitude, pos.longitude);
    if (risk >= 4 && mounted) {
      showModalBottomSheet(
        context: context,
        backgroundColor: AppConstants.surfaceDark,
        builder: (context) => Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⚠️ Caution: High Incident Area', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text('Recent incidents reported nearby. Stay alert and keep your phone accessible.', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.pop(),
                style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryPurple),
                child: const Text('Got it, I\'ll be careful'),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundDark,
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/ai-companion'),
        backgroundColor: AppConstants.primaryPurple,
        child: const Icon(Icons.security_update_good, color: Colors.white),
      ),
      body: Stack(
        children: [
          _buildMapBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  _buildHeader(context),
                  _buildStatusPanel(),
                  Expanded(child: _buildSosButtonArea()),
                  _buildQuickStats(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapBackground() {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: _currentMapPos, zoom: 13),
          onMapCreated: (controller) => _mapController = controller,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          circles: _circles,
          style: '[{"elementType":"geometry","stylers":[{"color":"#212121"}]},{"elementType":"labels.icon","stylers":[{"visibility":"off"}]},{"elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},{"elementType":"labels.text.stroke","stylers":[{"color":"#212121"}]},{"featureType":"administrative","elementType":"geometry","stylers":[{"color":"#757575"}]},{"featureType":"administrative.country","elementType":"labels.text.fill","stylers":[{"color":"#9e9e9e"}]},{"featureType":"administrative.land_parcel","stylers":[{"visibility":"off"}]},{"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#bdbdbd"}]},{"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},{"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#181818"}]},{"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#616161"}]},{"featureType":"poi.park","elementType":"labels.text.stroke","stylers":[{"color":"#1b1b1b"}]},{"featureType":"road","elementType":"geometry.fill","stylers":[{"color":"#2c2c2c"}]},{"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#8a8a8a"}]},{"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#373737"}]},{"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#3c3c3c"}]},{"featureType":"road.highway.controlled_access","elementType":"geometry","stylers":[{"color":"#4e4e4e"}]},{"featureType":"road.local","elementType":"labels.text.fill","stylers":[{"color":"#616161"}]},{"featureType":"transit","elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},{"featureType":"water","elementType":"geometry","stylers":[{"color":"#000000"}]},{"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#3d3d3d"}]}]',
        ),
        Positioned(
          top: 140,
          right: 16,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppConstants.surfaceDark.withAlpha(204), borderRadius: BorderRadius.circular(12)),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [CircleAvatar(radius: 6, backgroundColor: Colors.red), SizedBox(width: 8), Text('High Risk', style: TextStyle(color: Colors.white, fontSize: 12))]),
                SizedBox(height: 4),
                Row(children: [CircleAvatar(radius: 6, backgroundColor: Colors.orange), SizedBox(width: 8), Text('Moderate Risk', style: TextStyle(color: Colors.white, fontSize: 12))]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ASTRA', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
            Text('Your safety, always on.', style: TextStyle(fontSize: 14, color: Colors.white70)),
          ],
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.history_outlined, color: Colors.white70, size: 30),
              onPressed: () => context.push('/history'),
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: Colors.white70, size: 28),
              onPressed: () => context.push('/settings'),
            ),
            IconButton(
              icon: const Icon(Icons.contacts_outlined, color: Colors.white70, size: 30),
              onPressed: () async {
                await context.push('/contacts');
                _loadContacts();
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusPanel() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.deepPurple.withAlpha(77), Colors.indigo.withAlpha(77)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.deepPurple.withAlpha(128), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatusItem('📡', 'Network', _networkStatus),
          _buildStatusItem('📍', 'GPS', _gpsStatus),
          _buildStatusItem('👥', 'Contacts', '${_emergencyContacts.length}'),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String icon, String label, String value) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildSosButtonArea() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: _isSosActive ? null : _activateSOS,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Container(
                  width: 220, height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: _isSosActive ? [Colors.red.withAlpha(204), Colors.deepOrange.withAlpha(153)] : [Colors.deepPurple.withAlpha(230), Colors.indigo.withAlpha(179)],
                      center: Alignment.center,
                      radius: 0.8,
                    ),
                    boxShadow: [BoxShadow(color: _isSosActive ? Colors.red.withAlpha(128) : Colors.deepPurple.withAlpha(102), blurRadius: _isSosActive ? 40 : 30, spreadRadius: _isSosActive ? 15 : 5)],
                  ),
                  child: Center(
                    child: _isSosActive ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white), strokeWidth: 4) : const Text('SOS', style: TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold, letterSpacing: 3)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 30),
          Text(_isSosActive ? '🚀 Activating Emergency Protocol...' : 'Tap to Activate Emergency', style: const TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          if (!_isSosActive)
            OutlinedButton.icon(
              onPressed: _showFakeCallSheet,
              icon: const Icon(Icons.phone_callback, color: Colors.white70),
              label: const Text('Fake Call', style: TextStyle(color: Colors.white70)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white24), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withAlpha(26), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withAlpha(51), width: 1)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatCard('Local Network', '${_emergencyContacts.length} contacts'),
          _buildStatCard('Global Network', _networkStatus),
          _buildStatCard('Monitoring', _gpsStatus),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12), textAlign: TextAlign.center),
      ],
    );
  }
}
