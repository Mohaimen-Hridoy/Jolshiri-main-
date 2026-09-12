
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
import '../../widgets/common.dart';
import '../role_home.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _specialtyController = TextEditingController();
  final _serviceTypeController = TextEditingController();

  UserRole _selectedRole = UserRole.residentOwner;
  final AdminType _selectedAdminType = AdminType.jolshiriManagement;
  String _selectedServiceType = 'Electrician';

  static const List<String> _serviceTypeOptions = [
    'Electrician',
    'Plumber',
    'Cleaner',
    'Painter',
    'Carpenter',
    'AC Technician',
    'Security Guard',
    'Gardener',
    'Mason / Construction',
    'Internet / CCTV Technician',
    'Other',
  ];

  bool _loading = false;
  bool _googleLoading = false;

  bool get _isDeveloper => _selectedRole == UserRole.developer;
  bool get _isServiceProvider => _selectedRole == UserRole.serviceProvider;

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isDeveloper && (_companyNameController.text.trim().isEmpty || _specialtyController.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your company name and specialty')),
      );
      return;
    }
    if (_isServiceProvider && _selectedServiceType.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your service type')),
      );
      return;
    }
    final isAdmin = _selectedRole == UserRole.admin;
    final enteredName = _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : null;

    setState(() => _loading = true);

    // Every role now signs up against the real backend — see
    // jolshiri-backend/src/utils/validation.js:signupSchema for the
    // extra fields each role requires.
    const canUseBackend = true;

    if (canUseBackend) {
      try {
        final result = await BackendRepository.signup({
          'fullName': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'password': _passwordController.text,
          'role': _backendRole(_selectedRole),
          if (isAdmin) 'adminType': _backendAdminType(_selectedAdminType),
          if (_isDeveloper) 'companyName': _companyNameController.text.trim(),
          if (_isDeveloper) 'specialty': _specialtyController.text.trim(),
          if (_isServiceProvider) 'serviceType': _selectedServiceType,
        });
        if (!mounted) return;
        // No more email-OTP gate — the account is verified immediately and
        // the backend already returned a login token, so log the user
        // straight in (mirrors login_screen.dart's success path).
        await AuthSession.set(token: result.token, userId: result.userId, role: result.role);
        MockData.currentUser = result.user;
        final adminType = adminTypeFromBackend(result.adminType);
        await BackendSync.syncUserData(result.user.role, adminType: adminType);
        FcmService.init();
        if (!mounted) return;
        setState(() => _loading = false);
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => homeForRole(result.user.role, adminType: adminType, userName: enteredName),
          ),
          (route) => false,
        );
        return;
      } on ApiException catch (e) {
        if (!mounted) return;
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
        return;
      } on ApiUnreachableException {
        // Bug fix: this used to silently fall through to an "offline demo"
        // flow that created a fake local account and skipped straight to
        // homeForRole() — completely bypassing signup-OTP email
        // verification. That's the root cause of "signup goes directly to
        // the dashboard with no 2-step verification". Signup must always
        // go through the real backend so the account is created as
        // unverified and the OTP email step can't be skipped. If the
        // server can't be reached, surface a real error instead of
        // silently granting access.
        if (!mounted) return;
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                "Couldn't reach the server — please check your connection and try again."),
          ),
        );
        return;
      }
    }
  }

  static String _backendRole(UserRole r) => switch (r) {
        UserRole.residentOwner => 'RESIDENT_OWNER',
        UserRole.serviceProvider => 'SERVICE_PROVIDER',
        UserRole.developer => 'DEVELOPER',
        UserRole.admin => 'ADMIN',
      };

  static String _backendAdminType(AdminType t) => switch (t) {
        AdminType.jolshiriManagement => 'JOLSHIRI_MANAGEMENT',
        AdminType.armyOversight => 'ARMY_OVERSIGHT',
        AdminType.systemModerator => 'SYSTEM_MODERATOR',
      };

  /// Signs up (or logs in) with Google via Firebase, sends the ID token to
  /// the backend (POST /api/auth/sso/google), and navigates to the dashboard.
  /// The role selected on this screen is passed so the backend creates the
  /// correct account type on first sign-in.
  void _handleGoogleSignUp() async {
    setState(() => _googleLoading = true);
    try {
      final idToken = await GoogleAuthService.signInAndGetFirebaseIdToken();
      if (idToken == null) {
        // User cancelled
        setState(() => _googleLoading = false);
        return;
      }

      // Send to backend with the selected role so it creates the right account
      final result = await BackendRepository.googleSignIn(
        idToken: idToken,
        role: _backendRole(_selectedRole),
      );

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
      showActionSnackBar(context, 'Signed up with Google as ${_selectedRole.label}');
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => homeForRole(result.user.role,
            adminType: adminType, userName: result.user.fullName),
      ));
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
        SnackBar(content: Text('Google Sign-Up failed: ${e.toString()}')),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _companyNameController.dispose();
    _specialtyController.dispose();
    _serviceTypeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Join Jolshiri Smart City',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 6),
                Text('Choose the role that best describes you.',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 20),

                // ── Role chips ───────────────────────────────────────
                // Admin/Authority accounts (Jolshiri Management, Army
                // Oversight, System Moderator) hold security- and
                // authority-critical privileges — Security Reports,
                // Complaint register, Authority Portal appointments,
                // permit approval, user deletion, and resident personal
                // data. They must never be self-service: the backend's
                // public signup endpoint rejects role=ADMIN outright (see
                // PUBLIC_SIGNUP_ROLES in the backend), so that option is
                // intentionally not offered here either. Admin accounts
                // are provisioned out-of-band by Jolshiri IT.
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: UserRole.values.where((role) => role != UserRole.admin).map((role) {
                    final selected = role == _selectedRole;
                    return ChoiceChip(
                      label: Text(role.label),
                      selected: selected,
                      onSelected: (_) => setState(() => _selectedRole = role),
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : AppColors.ink,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    );
                  }).toList(),
                ),

                // ── Developer info (Developer only) ───────────────────
                if (_isDeveloper) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.parade.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      border: Border.all(color: AppColors.parade.withValues(alpha: 0.18)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.engineering_outlined, size: 18, color: AppColors.parade),
                            const SizedBox(width: 8),
                            Text('Company information',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.parade)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text('Company name', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _companyNameController,
                          decoration: const InputDecoration(hintText: 'e.g. Ashraf Builders Ltd.'),
                        ),
                        const SizedBox(height: 12),
                        Text('Specialty', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _specialtyController,
                          decoration: const InputDecoration(hintText: 'e.g. Residential construction'),
                        ),
                      ],
                    ),
                  ),
                ],

                // ── Service type (Service Provider only) ──────────────
                if (_isServiceProvider) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.parade.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      border: Border.all(color: AppColors.parade.withValues(alpha: 0.18)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.build_outlined, size: 18, color: AppColors.parade),
                            const SizedBox(width: 8),
                            Text('Service information',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.parade)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text('Service type', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedServiceType,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.build_circle_outlined),
                          ),
                          items: _serviceTypeOptions
                              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                              .toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _selectedServiceType = v);
                          },
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // ── Email / password fields ──────────────────────────
                Text('Full name', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: Validators.nameInputFormatters,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Fatima Ashraf',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: Validators.name,
                ),
                const SizedBox(height: 18),
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
                Text('Phone number', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: Validators.phoneInputFormatters,
                  decoration: const InputDecoration(
                    hintText: '+880 1XXX-XXXXXX',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: Validators.phone,
                ),
                const SizedBox(height: 18),
                Text('Password', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    hintText: 'Min 8 chars, letters and numbers',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: Validators.password,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading || _googleLoading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.4, color: Colors.white))
                        : const Text('Create account'),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('or sign up with Google',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey.shade500)),
                    ),
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Google Sign-Up button ────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: _googleLoading || _loading ? null : _handleGoogleSignUp,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.sm)),
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.ink,
                    ),
                    child: _googleLoading
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.4))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CustomPaint(
                                      painter: _GoogleLogoPainter())),
                              const SizedBox(width: 12),
                              const Text('Sign up with Google',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.18;
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius * 0.82),
        -0.52, 1.05, false, paint);
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius * 0.82),
        -2.62, 1.05, false, paint);
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius * 0.82),
        2.09, 1.05, false, paint);
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius * 0.82),
        0.52, 0.52, false, paint);
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = size.width * 0.18
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(center.dx, center.dy),
        Offset(center.dx + radius * 0.72, center.dy), barPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
