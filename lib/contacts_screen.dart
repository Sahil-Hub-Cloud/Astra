import "package:go_router/go_router.dart";
import 'package:flutter/material.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'core/utils/secure_storage.dart';
import 'sos_service.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<String> _contacts = [];
  final TextEditingController _controller = TextEditingController();
  final SosService _sosService = SosService();

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final secureContacts = await SecureStorage.loadEmergencyContacts();
    if (mounted) {
      setState(() {
        _contacts = secureContacts;
      });
    }
  }

  bool _isValidPhoneNumber(String number) {
    // Indian numbers: 10 digits starting 6-9, or international with + prefix
    final indianRegex = RegExp(r'^[6-9]\d{9}$');
    final internationalRegex = RegExp(r'^\+\d{1,15}$');

    String cleanNumber = number.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanNumber.startsWith('+')) {
      return internationalRegex.hasMatch(cleanNumber);
    } else {
      return indianRegex.hasMatch(cleanNumber);
    }
  }

  Future<void> _saveContact(String number) async {
    if (number.isEmpty) return;
    
    String cleanNumber = number.replaceAll(RegExp(r'[^0-9+]'), '');
    
    if (!_isValidPhoneNumber(cleanNumber)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid number. Use 10 digits (6-9) or +prefix'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_contacts.contains(cleanNumber)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contact already exists'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_contacts.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 5 contacts allowed'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await SecureStorage.addEmergencyContact(cleanNumber);
    await _loadContacts();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Contact added securely'),
        backgroundColor: Colors.green,
      ),
    );
    
    _controller.clear();
  }

  Future<void> _deleteContact(int index) async {
    final contactToDelete = _contacts[index];
    await SecureStorage.removeEmergencyContact(contactToDelete);
    await _loadContacts();
  }

  Future<void> _testSms(String number) async {
    try {
      await _sosService.sendSmsToSingleContact(
        number,
        'Astra test alert — your contact is testing the emergency system'
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Test SMS sent successfully'), backgroundColor: Colors.blue),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send test SMS: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _importFromPhonebook() async {
    if (await Permission.contacts.request().isGranted) {
      try {
        final Contact? contact = await ContactsService.openDeviceContactPicker();
        if (contact != null && contact.phones != null && contact.phones!.isNotEmpty) {
          final String? phone = contact.phones!.first.value;
          if (phone != null) {
            await _saveContact(phone);
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error picking contact: $e'), backgroundColor: Colors.red),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contacts permission denied'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1419),
      appBar: AppBar(
        title: const Text('Astra Network', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.contact_phone, color: Colors.white),
            onPressed: _importFromPhonebook,
            tooltip: 'Import from phonebook',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple.withAlpha(77), Colors.indigo.withAlpha(77)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.deepPurple.withAlpha(128), width: 1),
            ),
            child: Column(
              children: [
                const Text('📡 Add Emergency Contact', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(26),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withAlpha(77)),
                        ),
                        child: TextField(
                          controller: _controller,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Enter phone number',
                            hintStyle: TextStyle(color: Colors.white70),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(15),
                            prefixIcon: Icon(Icons.phone, color: Colors.white70),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Colors.deepPurple, Colors.indigo]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.add, color: Colors.white, size: 28),
                        onPressed: () => _saveContact(_controller.text),
                      ),
                    ),
                  ],
                ),
                if (_contacts.length >= 5)
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text('Maximum contacts reached (5/5)', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _contacts.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(15),
                    itemCount: _contacts.length,
                    itemBuilder: (context, index) => _buildContactCard(index),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.group_outlined, size: 80, color: Colors.white38),
          const SizedBox(height: 20),
          const Text('No Emergency Contacts', style: TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text('Add up to 5 trusted contacts', style: TextStyle(fontSize: 16, color: Colors.white.withAlpha(179)), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildContactCard(int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white.withAlpha(26), Colors.white.withAlpha(13)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(51), width: 1),
      ),
      child: ListTile(
        leading: Container(
          width: 40, height: 40,
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.deepPurple, Colors.indigo]), shape: BoxShape.circle),
          child: const Icon(Icons.person, color: Colors.white, size: 20),
        ),
        title: Text(_contacts[index], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: const Text('Emergency Network', style: TextStyle(color: Colors.white70, fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.send_outlined, color: Colors.blue, size: 24),
              onPressed: () => _testSms(_contacts[index]),
              tooltip: 'Test SMS',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 24),
              onPressed: () => _deleteContact(index),
            ),
          ],
        ),
      ),
    );
  }
}
