import 'package:flutter/material.dart';
import '../models/app_models.dart';
import 'admin/admin_shell.dart';
import 'developer/developer_dashboard.dart';
import 'home/home_shell.dart';
import 'provider/provider_dashboard.dart';

/// Returns the correct landing screen for a given user role, so login and
/// sign up both route each stakeholder to their own experience instead of
/// always opening the resident dashboard.
///
/// [adminType] is required when [role] is [UserRole.admin]: an admin account
/// belongs to exactly one of the three admin types (set at sign up), so
/// logging in as admin takes that account straight to its own dashboard
/// instead of a picker that exposes all three admin roles.
Widget homeForRole(UserRole role, {AdminType? adminType, String? userName}) {
  switch (role) {
    case UserRole.serviceProvider:
      return ProviderDashboard(providerName: userName);
    case UserRole.developer:
      return DeveloperDashboard(developerName: userName);
    case UserRole.admin:
      return AdminShell(adminType: adminType ?? AdminType.jolshiriManagement);
    case UserRole.residentOwner:
      return const HomeShell();
  }
}
