import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/services/supabase_client.dart';

class AstraAuth {

  Future<void> signInWithPhone(String phoneNumber) async {
    try {
      await supabase.auth.signInWithOtp(phone: phoneNumber);
    } catch (e) {
      throw Exception('Authentication failed: ${e.toString()}');
    }
  }

  Future<AuthResponse> verifyOTP(String phoneNumber, String token) async {
    try {
      final response = await supabase.auth.verifyOTP(
        phone: phoneNumber,
        token: token,
        type: OtpType.sms,
      );
      return response;
    } catch (e) {
      throw Exception('OTP verification failed: ${e.toString()}');
    }
  }

  bool isVerifiedResponder() {
    final user = supabase.auth.currentUser;
    if (user == null) return false;
    final role = user.userMetadata?['role'] as String?;
    return role == 'responder' || role == 'admin';
  }

  String? getUserRole() {
    final user = supabase.auth.currentUser;
    return user?.userMetadata?['role'] as String?;
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  User? getCurrentUser() {
    return supabase.auth.currentUser;
  }

  Future<void> requestRoleUpgrade(String reason) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    try {
      await supabase.functions.invoke('request-role-upgrade', body: {
        'user_id': user.id,
        'reason': reason,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to request role upgrade: ${e.toString()}');
    }
  }
}
