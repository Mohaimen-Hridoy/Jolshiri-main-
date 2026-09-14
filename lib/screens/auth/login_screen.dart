import 'dart:async';

import 'package:flutter/material.dart';
import '../../data/mock_data.dart';
import '../../models/app_models.dart';
import '../../services/api_client.dart';
import '../../services/api_config.dart';
import '../../services/backend_repository.dart';
import '../../services/fcm_service.dart';
import '../../services/google_auth_service.dart';
import '../../services/sync_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/validators.dart';
import '../role_home.dart';
import 'signup_screen.dart';

/// SSO-ready login screen. Google Sign-In exchanges a Google account for a
/// Firebase ID token (see GoogleAuthService) and sends that to the backend.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _googleLoading = false;
  UserRole _role = UserRole.residentOwner;
  AdminType _adminType = AdminType.jolshiriManagement;

  // ── Email / password login ──────────────────────────────────────────
  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      // POST /api/auth/login — real backend call.
      final result = await BackendRepository.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      await AuthSession.set(token: result.token, userId: result.userId, role: result.role);
      MockData.currentUser = result.user;
      final adminType = adminTypeFromBackend(result.adminType);
      // Wait for the role's "mine"/incoming lists to land in MockData
      // *before* navigating, so the dashboard's first build already shows
      // live data instead of the mock seed (which would otherwise sit
      // there until something else triggers a rebuild).
      await BackendSync.syncUserData(result.user.role, adminType: adminType);
      // Register FCM token so backend can push notifications to this device
      FcmService.init();
      if (!mounted) return;
      setState(() => _loading = false);
      _navigateHome(result.user.role, adminType: adminType);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      // Login no longer has an email-OTP gate (see auth.controller.js), so
      // a 403 here only ever means a SUSPENDED/BANNED account — always show
      // the real backend message instead of routing to the old OTP screen.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } on ApiUnreachableException {
      // Backend not reachable — fall back to the offline demo flow so the
      // app is still usable without a running server.
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't reach the server — continuing in offline demo mode")),
      );
      // Bug 6 Fix: offline fallback must use the admin type the user
      // actually selected in the UI dropdown (_adminType), not a hardcoded
      // value.  Previously _adminType defaulted to jolshiriManagement and
      // was only applied when _role == UserRole.admin, which is correct —
      // but the role picker was hidden for non-admin roles, meaning a user
      // who typed an army-admin email and picked "Admin / Army Oversight"
      // in the UI still landed on the JolshiriManagement dashboard in
      // offline mode because _role could be residentOwner (the default)
      // if they never touched the role dropdown.
      //
      // Fix: always read _role from the dropdown (already done), and pass
      // _adminType only when the selected role is admin.  The dropdown is
      // now visible so the user can explicitly choose their role before
      // hitting Sign In — the offline path mirrors that choice faithfully.
      _navigateHome(_role, adminType: _role == UserRole.admin ? _adminType : null);
    }
  }

  // ── Google SSO ──────────────────────────────────────────────────────
  /// Signs in with Google via Firebase, gets an ID token, sends it to the
  /// backend (POST /api/auth/sso/google), and navigates to the dashboard.
  ///
  /// On first sign-in (new account) the backend creates a RESIDENT_OWNER
  /// account by default. If the user wants a different role, they should
  /// register via the regular signup screen instead.
  void _handleGoogleSignIn() async {
    setState(() => _googleLoading = true);
    try {
      final idToken = await GoogleAuthService.signInAndGetFirebaseIdToken();
      if (idToken == null) {
        // User cancelled
        setState(() => _googleLoading = false);
        return;
      }

      // Send to backend → verify with Firebase Admin → get Jolshiri JWT
      final result = await BackendRepository.googleSignIn(idToken: idToken);

      if (!mounted) return;
      await AuthSession.set(
        token: result.token,
        userId: result.userId,
        role: result.role,
      );
      MockData.currentUser = result.user;
      final adminType = adminTypeFromBackend(result.adminType);
      await BackendSync.syncUserData(result.user.role, adminType: adminType);
      FcmService.init();
      if (!mounted) return;
      setState(() => _googleLoading = false);
      _navigateHome(result.user.role, adminType: adminType, userName: result.user.fullName);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _googleLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } on ApiUnreachableException {
      if (!mounted) return;
      setState(() => _googleLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't reach the server — check your connection")),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _googleLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google Sign-In failed: ${e.toString()}')),
      );
    }
  }

  /// After Google OAuth, ask which role this account should act as
  /// (one Google account can have one role, but this picker lets testers
  /// try every flow without multiple accounts).
  void _showRolePickerAfterSSO() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
      ),
      builder: (ctx) {
        UserRole picked = UserRole.residentOwner;
        AdminType pickedAdminType = AdminType.jolshiriManagement;
        return StatefulBuilder(builder: (ctx, setSheet) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Select your role', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  'Signed in with Google. Which role do you want to continue as?',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: UserRole.values.map((r) {
                    final sel = r == picked;
                    return ChoiceChip(
                      label: Text(r.label),
                      selected: sel,
                      onSelected: (_) => setSheet(() => picked = r),
                      labelStyle: TextStyle(
                        color: sel ? Colors.white : AppColors.ink,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    );
                  }).toList(),
                ),
                if (picked == UserRole.admin) ...[
                  const SizedBox(height: 16),
                  Text('Admin type', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: AdminType.values.map((t) {
                      final sel = t == pickedAdminType;
                      return ChoiceChip(
                        label: Text(t.label),
                        selected: sel,
                        onSelected: (_) => setSheet(() => pickedAdminType = t),
                        labelStyle: TextStyle(
                          color: sel ? Colors.white : AppColors.ink,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _navigateHome(picked,
                          adminType: picked == UserRole.admin ? pickedAdminType : null);
                    },
                    child: const Text('Continue'),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  void _navigateHome(UserRole role, {AdminType? adminType, String? userName}) {
    final displayName = userName ?? (_emailController.text.isNotEmpty ? _emailController.text : null);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => homeForRole(role, adminType: adminType, userName: displayName)),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Brand mark ───────────────────────────────────────
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.parade,
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: const Icon(Icons.location_city_rounded, color: AppColors.brass, size: 28),
                ),
                const SizedBox(height: 24),
                Text('Welcome back', style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: 6),
                Text(
                  'Sign in to access plots, services, security, and community updates for Jolshiri.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 28),

                // ── Email field ──────────────────────────────────────
                Text('Email', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  inputFormatters: Validators.emailInputFormatters,
                  decoration: const InputDecoration(
                    hintText: 'you@example.com',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                  validator: Validators.email,
                ),
                const SizedBox(height: 18),

                // ── Password field ───────────────────────────────────
                Text('Password', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    hintText: 'Enter your password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: Validators.loginPassword,
                ),
                const SizedBox(height: 6),

                // ── Role picker ──────────────────────────────────────
                Text('Sign in as', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                DropdownButtonFormField<UserRole>(
                  initialValue: _role,
                  isExpanded: true,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.badge_outlined)),
                  items: UserRole.values
                      .map((r) => DropdownMenuItem(
                            value: r,
                            child: Text(r.label, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _role = v ?? UserRole.residentOwner),
                ),
                if (_role == UserRole.admin) ...[
                  const SizedBox(height: 18),
                  Text('Admin type', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<AdminType>(
                    initialValue: _adminType,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.admin_panel_settings_outlined)),
                    items: AdminType.values
                        .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(t.label, overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _adminType = v ?? AdminType.jolshiriManagement),
                  ),
                ],
                const SizedBox(height: 22),

                // ── Submit ───────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading || _googleLoading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.4, color: Colors.white),
                          )
                        : const Text('Sign in'),
                  ),
                ),
                const SizedBox(height: 16),
                _OrDivider(),
                const SizedBox(height: 16),

                // ── Google Sign-In button (SSO) ──────────────────────
                _GoogleSignInButton(
                  loading: _googleLoading,
                  onTap: _googleLoading || _loading ? null : _handleGoogleSignIn,
                ),
                const SizedBox(height: 20),

                // ── Sign-up link ─────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account?"),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const SignupScreen())),
                      child: const Text('Sign up'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Google Sign-In Button ─────────────────────────────────────────────────────

class _GoogleSignInButton extends StatelessWidget {
  final bool loading;
  final VoidCallback? onTap;

  const _GoogleSignInButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.grey.shade300, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          backgroundColor: Colors.white,
          foregroundColor: AppColors.ink,
        ),
        child: loading
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _GoogleLogo(),
                  const SizedBox(width: 12),
                  const Text(
                    'Continue with Google',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Drawn Google "G" logo — no asset needed.
class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22, height: 22,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw the four-colour G segments
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = size.width * 0.18;

    // Blue (right arc — 315° to 45° roughly)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius * 0.82),
        -0.52, 1.05, false, paint);

    // Red (upper arc)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius * 0.82),
        -2.62, 1.05, false, paint);

    // Yellow (lower-left arc)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius * 0.82),
        2.09, 1.05, false, paint);

    // Green (lower-right arc)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius * 0.82),
        0.52, 0.52, false, paint);

    // Horizontal bar of the G
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = size.width * 0.18
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(center.dx, center.dy),
      Offset(center.dx + radius * 0.72, center.dy),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Or Divider ────────────────────────────────────────────────────────────────

class _OrDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey.shade300)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or sign in with email',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade500,
                ),
          ),
        ),
        Expanded(child: Divider(color: Colors.grey.shade300)),
      ],
    );
  }
}
