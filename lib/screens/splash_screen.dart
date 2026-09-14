import 'dart:async';

import 'package:flutter/material.dart';
import '../services/api_config.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';
import 'auth/login_screen.dart';
import '../models/app_models.dart';
import 'role_home.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

/// Maps the role string stored in AuthSession (e.g. 'RESIDENT_OWNER') to the
/// correct dashboard widget, for use when restoring a persisted session.
Widget _homeForRoleString(String roleStr) {
  final role = _parseRole(roleStr);
  return homeForRole(role);
}

UserRole _parseRole(String roleStr) {
  switch (roleStr) {
    case 'DEVELOPER':      return UserRole.developer;
    case 'SERVICE_PROVIDER': return UserRole.serviceProvider;
    case 'ADMIN':          return UserRole.admin;
    case 'RESIDENT_OWNER':
    default:               return UserRole.residentOwner;
  }
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..forward();
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    // Pull live data from the backend (plots, rentals, notices, community
    // posts, directory) so screens show real data the moment they open. If
    // the backend isn't reachable this silently keeps the built-in mock
    // data — see lib/services/sync_service.dart. Waited alongside the
    // splash's minimum display time so Home never briefly shows stale
    // mock data before the real lists land.
    final minDisplay = Future.delayed(const Duration(milliseconds: 1800));
    Future.wait([
      AuthSession.load(),           // restore saved JWT from disk
      BackendSync.syncPublicData(),
      minDisplay,
    ]).then((_) {
      if (!mounted) return;
      // If a valid session was found on disk, go straight to the dashboard.
      final Widget destination = AuthSession.isLoggedIn
          ? _homeForRoleString(AuthSession.role ?? '')
          : const LoginScreen();
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, __, ___) => destination,
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );
    });
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parade,
      body: Center(
        child: FadeTransition(
          opacity: _controller,
          child: ScaleTransition(
            scale: Tween(begin: 0.92, end: 1.0).animate(CurvedAnimation(
                parent: _controller, curve: Curves.easeOutCubic)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.brass, width: 1.4),
                  ),
                  child: const Icon(Icons.location_city_rounded,
                      color: AppColors.brass, size: 42),
                ),
                const SizedBox(height: 22),
                const Text(
                  'JOLSHIRI',
                  style: TextStyle(
                    fontFamily: 'serif',
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'SMART CITY',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 5,
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.brass.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
