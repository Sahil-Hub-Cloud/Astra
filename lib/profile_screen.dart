import "package:go_router/go_router.dart";
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'core/services/supabase_client.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  String _displayName = '';
  String? _photoUrl;
  int _sosCount = 0;
  String _emergencyId = '';
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    if (mounted) setState(() => _isLoading = true);
    final user = supabase.auth.currentUser;
    if (user == null) return;

    _displayName = user.userMetadata?['display_name'] ?? 'User';
    _photoUrl = user.userMetadata?['avatar_url'];
    _emergencyId = user.userMetadata?['emergency_id'] ?? '';
    _nameController.text = _displayName;

    if (_emergencyId.isEmpty) {
      _emergencyId = const Uuid().v4();
      await supabase.auth.updateUser(UserAttributes(
        data: {'emergency_id': _emergencyId},
      ));
    }

    try {
      final response = await supabase
          .from('incidents')
          .select('id')
          .eq('user_id', user.id);

      if (mounted) {
        setState(() {
          _sosCount = (response as List).length;
        });
      }
    } catch (e) {
      debugPrint('Error loading SOS count: $e');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _updateDisplayName() async {
    try {
      await supabase.auth.updateUser(UserAttributes(
        data: {'display_name': _nameController.text},
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name updated successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update name: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    if (mounted) setState(() => _isLoading = true);

    try {
      final user = supabase.auth.currentUser!;
      final fileBytes = await image.readAsBytes();
      final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'avatars/$fileName';

      await supabase.storage.from('avatars').uploadBinary(path, fileBytes);
      final String publicUrl = supabase.storage.from('avatars').getPublicUrl(path);

      await supabase.auth.updateUser(UserAttributes(
        data: {'avatar_url': publicUrl},
      ));

      await _loadProfileData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1419),
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : user == null
              ? const Center(child: Text('No user found', style: TextStyle(color: Colors.white)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.deepPurple,
                            backgroundImage: _photoUrl != null ? NetworkImage(_photoUrl!) : null,
                            child: _photoUrl == null
                                ? Text(
                                    _displayName.isNotEmpty ? _displayName[0].toUpperCase() : 'U',
                                    style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white),
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              backgroundColor: Colors.indigo,
                              child: IconButton(
                                icon: const Icon(Icons.camera_alt, color: Colors.white),
                                onPressed: _pickAndUploadImage,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildSectionTitle('Personal Info'),
                    _buildEditableField('Display Name', _nameController, _updateDisplayName),
                    _buildInfoRow('Phone', user.phone ?? 'N/A'),
                    _buildInfoRow('Account Created', user.createdAt.substring(0, 10)),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Astra Security'),
                    _buildInfoRow('Emergency ID', _emergencyId),
                    _buildInfoRow('Total SOS Triggers', '$_sosCount'),
                    const SizedBox(height: 40),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await supabase.auth.signOut();
                        if (mounted) context.go('/login');
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text('Sign Out'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(color: Colors.deepPurpleAccent, fontWeight: FontWeight.bold, fontSize: 18),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(13),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildEditableField(String label, TextEditingController controller, VoidCallback onSave) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(13),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.save, color: Colors.green, size: 20),
                onPressed: onSave,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
