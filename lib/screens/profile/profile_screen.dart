import 'package:flutter/material.dart';
import '../../data/mock_data.dart';
import '../../models/app_models.dart';
import '../../services/api_client.dart';
import '../../services/api_config.dart';
import '../../services/backend_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  void _openChangePassword() {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Change password', style: Theme.of(sheetContext).textTheme.headlineSmall),
                const SizedBox(height: 16),
                TextField(
                  controller: currentController,
                  obscureText: obscureCurrent,
                  decoration: InputDecoration(
                    labelText: 'Current password',
                    suffixIcon: IconButton(
                      icon: Icon(obscureCurrent ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setSheet(() => obscureCurrent = !obscureCurrent),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newController,
                  obscureText: obscureNew,
                  decoration: InputDecoration(
                    labelText: 'New password (min 8 characters)',
                    suffixIcon: IconButton(
                      icon: Icon(obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setSheet(() => obscureNew = !obscureNew),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirm new password'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final current = currentController.text;
                      final newPass = newController.text;
                      final confirm = confirmController.text;
                      if (current.isEmpty || newPass.isEmpty) {
                        showActionSnackBar(sheetContext, 'Please fill in all fields');
                        return;
                      }
                      if (newPass.length < 8) {
                        showActionSnackBar(sheetContext, 'New password must be at least 8 characters');
                        return;
                      }
                      if (newPass != confirm) {
                        showActionSnackBar(sheetContext, 'Passwords do not match');
                        return;
                      }
                      try {
                        await runWithLoadingOverlay(
                          sheetContext,
                          () => BackendRepository.changePassword(
                            currentPassword: current,
                            newPassword: newPass,
                          ),
                          message: 'Saving new password…',
                        );
                        if (!sheetContext.mounted) return;
                        Navigator.pop(sheetContext);
                        if (!context.mounted) return;
                        showActionSnackBar(context, 'Password changed successfully');
                      } on ApiException catch (e) {
                        if (!sheetContext.mounted) return;
                        showActionSnackBar(sheetContext, e.message);
                      } on ApiUnreachableException {
                        if (!sheetContext.mounted) return;
                        Navigator.pop(sheetContext);
                        if (!context.mounted) return;
                        showActionSnackBar(context, 'Could not reach server — password not changed');
                      }
                    },
                    child: const Text('Save new password'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openEditor() {
    final user = MockData.currentUser;
    final nameController = TextEditingController(text: user.fullName);
    final phoneController = TextEditingController(text: user.phone);
    final addressController = TextEditingController(text: user.address);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Edit profile', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 14),
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Full name')),
              const SizedBox(height: 10),
              TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone')),
              const SizedBox(height: 10),
              TextField(controller: addressController, decoration: const InputDecoration(labelText: 'Address')),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final fullName = nameController.text.trim();
                    final phone = phoneController.text.trim();
                    final address = addressController.text.trim();
                    if (fullName.isEmpty || phone.isEmpty) {
                      showActionSnackBar(context, 'Name and phone are required');
                      return;
                    }
                    try {
                      final updated = await runWithLoadingOverlay(
                        context,
                        () => BackendRepository.updateProfile(
                          fullName: fullName,
                          phone: phone,
                          address: address,
                        ),
                        message: 'Saving changes…',
                      );
                      setState(() => MockData.currentUser = updated);
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      showActionSnackBar(this.context, 'Profile updated');
                    } on ApiException catch (e) {
                      if (!context.mounted) return;
                      showActionSnackBar(context, e.message);
                    } on ApiUnreachableException {
                      setState(() {
                        MockData.currentUser = AppUser(
                          fullName: fullName,
                          email: user.email,
                          phone: phone,
                          role: user.role,
                          address: address.isEmpty ? user.address : address,
                        );
                      });
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      showActionSnackBar(this.context, 'Profile updated locally (offline)');
                    }
                  },
                  child: const Text('Save changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = MockData.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile & Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: AppColors.parade,
                  child: Text(user.initials,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 12),
                Text(user.fullName,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                StatusPill(label: user.role.label, color: AppColors.brass),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Card(
            child: Column(
              children: [
                _InfoTile(
                    icon: Icons.mail_outline,
                    label: 'Email',
                    value: user.email),
                const Divider(height: 1),
                _InfoTile(
                    icon: Icons.phone_outlined,
                    label: 'Phone',
                    value: user.phone),
                const Divider(height: 1),
                _InfoTile(
                    icon: Icons.place_outlined,
                    label: 'Address',
                    value: user.address),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader(eyebrow: 'Manage', title: 'Settings'),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                _ActionTile(
                    icon: Icons.edit_outlined,
                    label: 'Edit profile',
                    onTap: _openEditor),
                const Divider(height: 1),
                _ActionTile(
                    icon: Icons.lock_reset_outlined,
                    label: 'Change password',
                    onTap: _openChangePassword),
                const Divider(height: 1),
                _ActionTile(
                    icon: Icons.notifications_outlined,
                    label: 'Notification preferences',
                    onTap: () => showActionSnackBar(
                        context, 'Opening notification settings…')),
                const Divider(height: 1),
                _ActionTile(
                    icon: Icons.language_outlined,
                    label: 'Language',
                    onTap: () => showActionSnackBar(context, 'English (US)')),
                const Divider(height: 1),
                _ActionTile(
                    icon: Icons.help_outline,
                    label: 'Help & support',
                    onTap: () =>
                        showActionSnackBar(context, 'Opening help center…')),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brick,
                  side: const BorderSide(color: AppColors.brick)),
              icon: const Icon(Icons.logout),
              label: const Text('Log out'),
              onPressed: () async {
                // Was missing entirely — the button navigated to
                // LoginScreen but never cleared the saved JWT/role, so the
                // splash screen's AuthSession.load() would find a still
                // logged-in session and route straight back into the app,
                // making "Log out" a no-op after any restart (and every
                // authenticated call in this session kept using the old
                // token until then).
                await AuthSession.clear();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.parade),
      title: Text(label, style: Theme.of(context).textTheme.labelSmall),
      subtitle: Text(value,
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(color: AppColors.ink)),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionTile(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.ink),
      title: Text(label,
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(color: AppColors.ink)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.inkFaint),
      onTap: onTap,
    );
  }
}
