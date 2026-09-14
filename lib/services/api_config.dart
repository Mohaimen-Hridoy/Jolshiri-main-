import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_models.dart';

/// Central place that knows how to reach the Jolshiri backend
/// (see `jolshiri-backend/src/index.js`) and holds the signed-in
/// session (JWT) in memory for the lifetime of the app.
class ApiConfig {
  ApiConfig._();

  /// If you've deployed the backend (Render, Railway, etc.), paste its
  /// full URL here — e.g. 'https://jolshiri-backend.onrender.com'. This
  /// takes priority over everything below, and works for every platform
  /// (Android, iOS, web, desktop).
  ///
  /// Left null for local development — set back to your Railway/Render URL
  /// once you've deployed the LATEST backend code there. While this was
  /// pointed at the old Railway deployment, every request (including
  /// "Flat View Requests") was hitting that stale server instead of your
  /// local one, which is why newer routes like
  /// /viewing-requests/for-my-listings 404'd with "No route for GET ..."
  /// even though the route exists in this codebase — the deployed server
  /// just hadn't been updated with it yet.
  static const String deployedBaseUrl = 'https://jolshiri-backend-production.up.railway.app';

  /// Only used for LOCAL development (deployedBaseUrl above is null).
  /// Change this if your local backend runs somewhere other than
  /// localhost:4000 (matches PORT in jolshiri-backend/.env.example).
  /// A few common local dev setups are handled automatically:
  ///  - Android emulator can't reach the host machine via "localhost", it
  ///    needs the special alias 10.0.2.2.
  ///  - iOS simulator / desktop / web can use localhost directly.
  ///  - A real phone on the same Wi-Fi needs your computer's LAN IP —
  ///    set [overrideHost] below if that's your setup.
  static const String? overrideHost = null; // e.g. '192.168.0.12'
  static const int port = 4000;

  static String get baseUrl {
    // Strip a trailing slash so we don't end up with a double "//api".
    final trimmed = deployedBaseUrl!.endsWith('/')
        ? deployedBaseUrl!.substring(0, deployedBaseUrl!.length - 1)
        : deployedBaseUrl!;
    return '$trimmed/api';
    if (overrideHost != null) return 'http://$overrideHost:$port/api';
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:$port/api';
    }
    return 'http://localhost:$port/api';
  }

  static const Duration timeout = Duration(seconds: 20);
}

/// Session holder backed by shared_preferences so the user stays logged in
/// across app restarts.
///
/// Usage:
///   - Call [load] once at startup (in SplashScreen) before routing.
///   - Call [set] after a successful login/signup.
///   - Call [clear] on logout.
///   - Check [isLoggedIn] before deciding which screen to show.
class AuthSession {
  AuthSession._();

  static const _keyToken  = 'auth_token';
  static const _keyUserId = 'auth_userId';
  static const _keyRole   = 'auth_role';

  // In-memory cache — avoids async reads after the initial load.
  static String? token;
  static String? userId;
  static String? role; // e.g. 'RESIDENT_OWNER', 'ADMIN', ...

  static bool get isLoggedIn => token != null;

  /// Load a previously saved session from disk.
  /// Call once at startup (SplashScreen) before checking [isLoggedIn].
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    token  = prefs.getString(_keyToken);
    userId = prefs.getString(_keyUserId);
    role   = prefs.getString(_keyRole);
  }

  /// Save session to memory and disk. Called after login / signup.
  static Future<void> set({
    required String token,
    required String userId,
    required String role,
  }) async {
    AuthSession.token  = token;
    AuthSession.userId = userId;
    AuthSession.role   = role;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken,  token);
    await prefs.setString(_keyUserId, userId);
    await prefs.setString(_keyRole,   role);
  }

  /// Update only the role in memory and on disk (role switch).
  static Future<void> setRole(UserRole role) async {
    final backendRole = switch (role) {
      UserRole.residentOwner  => 'RESIDENT_OWNER',
      UserRole.serviceProvider => 'SERVICE_PROVIDER',
      UserRole.developer      => 'DEVELOPER',
      UserRole.admin          => 'ADMIN',
    };
    AuthSession.role = backendRole;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRole, backendRole);
  }

  /// Clear session from memory and disk (logout).
  static Future<void> clear() async {
    token  = null;
    userId = null;
    role   = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyRole);
  }
}
