import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_client.dart';
import '../../services/backend_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/validators.dart';

/// Forgot password — 3-step flow:
///  1. Enter email → POST /api/auth/forgot-password → receive 6-digit OTP
///  2. Enter OTP  (demo: shown in snackbar since no email service is wired)
///  3. Enter new password → POST /api/auth/reset-password
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  _Step _step = _Step.email;
  bool _loading = false;

  // step 1
  final _emailKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  // step 2 — OTP fields
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes =
      List.generate(6, (_) => FocusNode());
  String? _demOtp; // only non-null in demo mode (no email server)

  // step 3
  final _pwKey = GlobalKey<FormState>();
  final _newPwController = TextEditingController();
  final _confirmPwController = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  String get _enteredOtp =>
      _otpControllers.map((c) => c.text).join();

  @override
  void dispose() {
    _emailController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final n in _otpFocusNodes) {
      n.dispose();
    }
    _newPwController.dispose();
    _confirmPwController.dispose();
    super.dispose();
  }

  // ── Step 1: request OTP ────────────────────────────────────────────
  Future<void> _requestOtp() async {
    if (!_emailKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final demoToken = await BackendRepository.forgotPassword(
          _emailController.text.trim());
      if (!mounted) return;
      setState(() {
        _loading = false;
        _step = _Step.otp;
        _demOtp = demoToken; // null when Gmail is configured (production)
      });
      if (!mounted) return;
      if (demoToken != null) {
        // Gmail not configured — OTP returned in response for dev/testing
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Dev mode — OTP: $demoToken (configure GMAIL_USER in .env to send real emails)'),
          duration: const Duration(seconds: 10),
        ));
      } else {
        // Real email sent via Gmail
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Reset code sent! Check your email inbox (and spam folder).'),
          duration: Duration(seconds: 5),
        ));
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)));
    } on ApiUnreachableException {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Can't reach the server — check your connection")));
    }
  }

  // ── Step 2: verify OTP locally (just move to step 3) ──────────────
  void _verifyOtp() {
    final otp = _enteredOtp;
    if (otp.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter all 6 digits')));
      return;
    }
    setState(() => _step = _Step.newPassword);
  }

  // ── Step 3: reset password ─────────────────────────────────────────
  Future<void> _resetPassword() async {
    if (!_pwKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await BackendRepository.resetPassword(
        email: _emailController.text.trim(),
        token: _enteredOtp,
        newPassword: _newPwController.text,
      );
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset successfully — please sign in')));
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } on ApiUnreachableException {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Can't reach the server")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Forgot Password'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_step == _Step.otp) {
              setState(() => _step = _Step.email);
            } else if (_step == _Step.newPassword) {
              setState(() => _step = _Step.otp);
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: switch (_step) {
            _Step.email => _EmailStep(
                formKey: _emailKey,
                controller: _emailController,
                loading: _loading,
                onSubmit: _requestOtp,
              ),
            _Step.otp => _OtpStep(
                email: _emailController.text.trim(),
                controllers: _otpControllers,
                focusNodes: _otpFocusNodes,
                onSubmit: _verifyOtp,
                onResend: () {
                  for (final c in _otpControllers) {
                    c.clear();
                  }
                  setState(() => _step = _Step.email);
                },
              ),
            _Step.newPassword => _NewPasswordStep(
                formKey: _pwKey,
                newController: _newPwController,
                confirmController: _confirmPwController,
                obscureNew: _obscureNew,
                obscureConfirm: _obscureConfirm,
                loading: _loading,
                onToggleNew: () => setState(() => _obscureNew = !_obscureNew),
                onToggleConfirm: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
                onSubmit: _resetPassword,
              ),
          },
        ),
      ),
    );
  }
}

enum _Step { email, otp, newPassword }

// ── Step 1: Email ─────────────────────────────────────────────────────────────

class _EmailStep extends StatelessWidget {
  const _EmailStep({
    required this.formKey,
    required this.controller,
    required this.loading,
    required this.onSubmit,
  });
  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final bool loading;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: AppColors.parade.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_reset_rounded, size: 36, color: AppColors.parade),
            ),
          ),
          const SizedBox(height: 24),
          Text('Reset your password',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'Enter the email address linked to your Jolshiri account. '
            'We will send you a 6-digit code to reset your password.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.inkFaint),
          ),
          const SizedBox(height: 32),
          Text('Email address', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.email_outlined),
              hintText: 'your@email.com',
            ),
            validator: Validators.email,
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: loading ? null : onSubmit,
              child: loading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Send reset code'),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back to Login'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 2: OTP ───────────────────────────────────────────────────────────────

class _OtpStep extends StatelessWidget {
  const _OtpStep({
    required this.email,
    required this.controllers,
    required this.focusNodes,
    required this.onSubmit,
    required this.onResend,
  });
  final String email;
  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final VoidCallback onSubmit;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    return Column(
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
          'We sent a 6-digit code to\n$email',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.inkFaint),
        ),
        const SizedBox(height: 32),
        // 6 OTP boxes
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (i) {
            return SizedBox(
              width: 48, height: 56,
              child: TextField(
                controller: controllers[i],
                focusNode: focusNodes[i],
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
                    focusNodes[i + 1].requestFocus();
                  }
                  if (v.isEmpty && i > 0) {
                    focusNodes[i - 1].requestFocus();
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
            onPressed: onSubmit,
            child: const Text('Verify code'),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: onResend,
            child: const Text('Resend code'),
          ),
        ),
      ],
    );
  }
}

// ── Step 3: New Password ──────────────────────────────────────────────────────

class _NewPasswordStep extends StatelessWidget {
  const _NewPasswordStep({
    required this.formKey,
    required this.newController,
    required this.confirmController,
    required this.obscureNew,
    required this.obscureConfirm,
    required this.loading,
    required this.onToggleNew,
    required this.onToggleConfirm,
    required this.onSubmit,
  });
  final GlobalKey<FormState> formKey;
  final TextEditingController newController;
  final TextEditingController confirmController;
  final bool obscureNew;
  final bool obscureConfirm;
  final bool loading;
  final VoidCallback onToggleNew;
  final VoidCallback onToggleConfirm;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: AppColors.parade.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline_rounded, size: 36, color: AppColors.parade),
            ),
          ),
          const SizedBox(height: 24),
          Text('Set new password',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Choose a strong password for your account.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.inkFaint)),
          const SizedBox(height: 32),
          Text('New password', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextFormField(
            controller: newController,
            obscureText: obscureNew,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.lock_outline),
              hintText: 'Min 8 characters',
              suffixIcon: IconButton(
                icon: Icon(obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: onToggleNew,
              ),
            ),
            validator: Validators.password,
          ),
          const SizedBox(height: 18),
          Text('Confirm password', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextFormField(
            controller: confirmController,
            obscureText: obscureConfirm,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.lock_outline),
              hintText: 'Repeat your new password',
              suffixIcon: IconButton(
                icon: Icon(obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: onToggleConfirm,
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please confirm your password';
              if (v != newController.text) return 'Passwords do not match';
              return null;
            },
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: loading ? null : onSubmit,
              child: loading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Reset password'),
            ),
          ),
        ],
      ),
    );
  }
}
