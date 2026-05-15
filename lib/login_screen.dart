import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/services/supabase_client.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _showOtpField = false;
  bool _isLoading = false;
  String? _phoneError;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1419),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                const Icon(Icons.shield, color: Colors.deepPurple, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'ASTRA',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 4,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  'Emergency Network',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withAlpha(179),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    labelStyle: TextStyle(color: Colors.white.withAlpha(179)),
                    hintText: '+91 9876543210',
                    hintStyle: TextStyle(color: Colors.white.withAlpha(77)),
                    prefixIcon: Icon(Icons.phone, color: Colors.white.withAlpha(179)),
                    errorText: _phoneError,
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: _phoneError != null
                            ? Colors.red
                            : Colors.deepPurple.withAlpha(128),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: _phoneError != null
                            ? Colors.red
                            : Colors.deepPurple,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.red),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.red),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white.withAlpha(13),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      _phoneError = 'Please enter your phone number';
                      return 'Please enter your phone number';
                    }

                    final trimmed = value.trim();
                    final phoneRegex = RegExp(
                      r'^(?:\+\d{1,3}[\s]?\d{10}|[6-9]\d{9})$',
                    );

                    if (!phoneRegex.hasMatch(trimmed)) {
                      _phoneError = 'Enter valid number (Indian: 6-9xxx or +country code)';
                      return 'Enter valid number (Indian: 6-9xxx or +country code)';
                    }

                    _phoneError = null;
                    return null;
                  },
                  enabled: !_showOtpField && !_isLoading,
                  onChanged: (value) {
                    if (_phoneError != null) {
                      setState(() {
                        _phoneError = null;
                      });
                    }
                  },
                ),

                const SizedBox(height: 20),

                if (_showOtpField) ...[
                  TextFormField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Verification Code',
                      labelStyle: TextStyle(color: Colors.white.withAlpha(179)),
                      hintText: '6-digit code',
                      hintStyle: TextStyle(color: Colors.white.withAlpha(77)),
                      prefixIcon: Icon(Icons.lock, color: Colors.white.withAlpha(179)),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.deepPurple.withAlpha(128),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.deepPurple),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white.withAlpha(13),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the verification code';
                      }
                      if (value.length != 6) return 'Code must be 6 digits';
                      return null;
                    },
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 20),
                ],

                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _showOtpField ? 'Verifying...' : 'Sending...',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        )
                      : Text(
                          _showOtpField ? 'Verify Code' : 'Send Verification Code',
                          style: const TextStyle(fontSize: 16),
                        ),
                ),

                if (_showOtpField) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _isLoading ? null : _resendCode,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isLoading) ...[
                          const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white70,
                              strokeWidth: 1.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          _isLoading ? 'Resending...' : 'Resend Code',
                          style: TextStyle(color: Colors.white.withAlpha(179)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      if (!_showOtpField) {
        await _requestOtp(_phoneController.text.trim());
      } else {
        await _verifyOtp(_otpController.text.trim());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _requestOtp(String phone) async {
    await supabase.auth.signInWithOtp(phone: phone);
    setState(() => _showOtpField = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification code sent to $phone')),
      );
    }
  }

  Future<void> _verifyOtp(String token) async {
    await supabase.auth.verifyOTP(
      phone: _phoneController.text.trim(),
      token: token,
      type: OtpType.sms,
    );
    context.go('/home');
  }

  Future<void> _resendCode() async {
    setState(() => _isLoading = true);
    try {
      await _requestOtp(_phoneController.text.trim());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
