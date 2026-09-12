import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/mock_data.dart';
import '../../services/api_client.dart';
import '../../services/api_config.dart';
import '../../services/backend_repository.dart';
import '../../services/fcm_service.dart';
import '../../services/sync_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../role_home.dart';

/// Shown right after signup (or after a login attempt on an unverified
/// account) to collect the 6-digit code emailed by
/// POST /api/auth/signup, then calls POST /api/auth/verify-signup-otp to
/// finish creating the session.
class VerifySignupOtpScreen extends StatefulWidget {
  const VerifySignupOtpScreen({
    super.key,
    required this.email,
    this.devOtp,
    this.userName,
  });

  final String email;
  /// Only set when Gmail isn't configured on the backend — lets the OTP
  /// be shown directly so the flow is still testable without a mail server.
  final String? devOtp;
  final String? userName;

  @override
  State<VerifySignupOtpScreen> createState() => _VerifySignupOtpScreenState();
}

class _VerifySignupOtpScreenState extends State<VerifySignupOtpScreen> {
  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  bool _verifying = false;
  bool _resending = false;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  String get _enteredOtp => _otpControllers.map((c) => c.text).join();

  @override
  void initState() {
    super.initState();
    if (widget.devOtp != null) {
      // Dev convenience — surface the mock-mailed OTP so testers aren't stuck.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Dev mode — OTP: ${widget.devOtp} (configure GMAIL_USER in .env to send real emails)'),
          duration: const Duration(seconds: 10),
        ));
      });
    }
    _startCooldown();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _resendCooldown = 30);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCooldown <= 1) {
        timer.cancel();
        setState(() => _resendCooldown = 0);
      } else {
        setState(() => _resendCooldown -= 1);
      }
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final n in _otpFocusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  Future<void> _verify() async {
    final otp = _enteredOtp;
    if (otp.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter all 6 digits')));
      return;
    }
    setState(() => _verifying = true);
    try {
      final result = await BackendRepository.verifySignupOtp(email: widget.email, otp: otp);
      if (!mounted) return;
      await AuthSession.set(token: result.token, userId: result.userId, role: result.role);
      MockData.currentUser = result.user;
      final adminType = adminTypeFromBackend(result.adminType);
      await BackendSync.syncUserData(result.user.role, adminType: adminType);
      FcmService.init();
      if (!mounted) return;
      setState(() => _verifying = false);
      showActionSnackBar(context, 'Email verified — welcome to Jolshiri!');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => homeForRole(result.user.role, adminType: adminType, userName: widget.userName),
        ),
        (route) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _verifying = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } on ApiUnreachableException {
      if (!mounted) return;
      setState(() => _verifying = false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Can't reach the server — check your connection")));
    }
  }

  Future<void> _resend() async {
    if (_resendCooldown > 0 || _resending) return;
    setState(() => _resending = true);
    try {
      final devOtp = await BackendRepository.resendSignupOtp(widget.email);
      if (!mounted) return;
      setState(() => _resending = false);
      _startCooldown();
      for (final c in _otpControllers) {
        c.clear();
      }
      _otpFocusNodes.first.requestFocus();
      if (devOtp != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Dev mode — new OTP: $devOtp'),
          duration: const Duration(seconds: 10),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('A new code has been sent to your email')));
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _resending = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } on ApiUnreachableException {
      if (!mounted) return;
      setState(() => _resending = false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Can't reach the server — check your connection")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify your email')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.lake.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mark_email_read_outlined, size: 36, color: AppColors.lake),
                ),
              ),
              const SizedBox(height: 24),
              Text('Enter your code',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                'We sent a 6-digit verification code to\n${widget.email}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.inkFaint),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) {
                  return SizedBox(
                    width: 48, height: 56,
                    child: TextField(
                      controller: _otpControllers[i],
                      focusNode: _otpFocusNodes[i],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                        ),
                      ),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
                      onChanged: (v) {
                        if (v.isNotEmpty && i < 5) {
                          _otpFocusNodes[i + 1].requestFocus();
                        }
                        if (v.isEmpty && i > 0) {
                          _otpFocusNodes[i - 1].requestFocus();
                        }
                        if (v.isNotEmpty && i == 5 && _enteredOtp.length == 6) {
                          _verify();
                        }
                      },
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _verifying ? null : _verify,
                  child: _verifying
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Verify & continue'),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: _resendCooldown > 0 || _resending ? null : _resend,
                  child: _resending
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_resendCooldown > 0 ? 'Resend code (${_resendCooldown}s)' : 'Resend code'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
