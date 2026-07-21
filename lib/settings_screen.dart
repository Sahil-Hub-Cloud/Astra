import "package:go_router/go_router.dart";
import 'package:flutter/material.dart';
import 'astra_auth.dart';
import 'core/services/emergency_hardware_trigger.dart';
import 'core/services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _hardwareTriggerEnabled = true;
  bool _autoSendLocation = true;
  bool _voiceActivationEnabled = false;
  bool _aiDangerZonesEnabled = true;
  bool _suggestSaferRoutes = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final hardwareEnabled = await SettingsService().isHardwareTriggerEnabled();
    final autoLocationEnabled = await SettingsService().isAutoLocationEnabled();
    final voiceEnabled = await SettingsService().isVoiceActivationEnabled();
    setState(() {
      _hardwareTriggerEnabled = hardwareEnabled;
      _autoSendLocation = autoLocationEnabled;
      _voiceActivationEnabled = voiceEnabled;
    });
  }

  Future<void> _toggleHardwareTrigger(bool value) async {
    await SettingsService().setHardwareTriggerEnabled(value);
    if (value) {
      final trigger = EmergencyHardwareTrigger(
        onEmergencyTriggered: () {
          // Trigger will be handled by the callback in main.dart
        },
      );
      await trigger.enableTrigger();
    }
    setState(() => _hardwareTriggerEnabled = value);
  }

  Future<void> _toggleAutoLocation(bool value) async {
    await SettingsService().setAutoLocationEnabled(value);
    setState(() => _autoSendLocation = value);
  }

  Future<void> _toggleVoiceActivation(bool value) async {
    await SettingsService().setVoiceActivationEnabled(value);
    setState(() => _voiceActivationEnabled = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFF1a1a2e),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        children: [
          Card(
            margin: const EdgeInsets.all(10),
            child: ExpansionTile(
              title: const Row(
                children: [
                  Icon(Icons.account_circle, color: Color(0xFF0f3460)),
                  SizedBox(width: 10),
                  Text('Account Settings'),
                ],
              ),
              children: [
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('Profile'),
                  onTap: () => context.go('/profile'),
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Sign Out'),
                  onTap: () async {
                    await AstraAuth().signOut();
                    context.go('/login');
                  },
                ),
              ],
            ),
          ),

          Card(
            margin: const EdgeInsets.all(10),
            child: ExpansionTile(
              title: const Row(
                children: [
                  Icon(Icons.security, color: Color(0xFF0f3460)),
                  SizedBox(width: 10),
                  Text('Emergency Settings'),
                ],
              ),
              children: [
                SwitchListTile(
                  title: const Text('Enable Hardware Trigger'),
                  subtitle: const Text('Use Volume Up+Down to trigger SOS'),
                  value: _hardwareTriggerEnabled,
                  onChanged: _toggleHardwareTrigger,
                ),
                SwitchListTile(
                  title: const Text('Auto-send Location'),
                  subtitle: const Text('Include GPS coordinates in alerts'),
                  value: _autoSendLocation,
                  onChanged: _toggleAutoLocation,
                ),
                SwitchListTile(
                  title: const Text('Voice Activation SOS'),
                  subtitle: const Text('Say "help", "bachao", "emergency" to trigger SOS'),
                  value: _voiceActivationEnabled,
                  onChanged: _toggleVoiceActivation,
                ),
                SwitchListTile(
                  title: const Text('AI Danger Zone Alerts'),
                  subtitle: const Text('Predictive alerts when entering risky areas'),
                  value: _aiDangerZonesEnabled,
                  onChanged: (v) => setState(() => _aiDangerZonesEnabled = v),
                ),
                SwitchListTile(
                  title: const Text('Suggest Safer Routes'),
                  subtitle: const Text('AI analysis of route safety scores'),
                  value: _suggestSaferRoutes,
                  onChanged: (v) => setState(() => _suggestSaferRoutes = v),
                ),
              ],
            ),
          ),

          Card(
            margin: const EdgeInsets.all(10),
            child: ExpansionTile(
              title: const Row(
                children: [
                  Icon(Icons.contacts, color: Color(0xFF0f3460)),
                  SizedBox(width: 10),
                  Text('Contact Settings'),
                ],
              ),
              children: [
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Manage Emergency Contacts'),
                  onTap: () => context.go('/contacts'),
                ),
              ],
            ),
          ),

          Card(
            margin: const EdgeInsets.all(10),
            child: ExpansionTile(
              title: const Row(
                children: [
                  Icon(Icons.info, color: Color(0xFF0f3460)),
                  SizedBox(width: 10),
                  Text('About'),
                ],
              ),
              children: const [
                ListTile(
                  title: Text('Version'),
                  subtitle: Text('1.0.0'),
                ),
                ListTile(
                  title: Text('Astra Emergency Network'),
                  subtitle: Text('Built for your safety'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
