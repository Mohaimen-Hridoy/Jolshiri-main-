import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'backend_repository.dart';

/// Handles Firebase Cloud Messaging setup and token registration.
/// Call [init] once after login — it requests permission, gets the FCM token,
/// and sends it to the backend so the server can push notifications to this device.
class FcmService {
  FcmService._();

  static Future<void> init() async {
    // Skip on web — FCM works differently there (needs a service worker)
    if (kIsWeb) return;

    final messaging = FirebaseMessaging.instance;

    // Request permission (shows native dialog on iOS; Android 13+ also needs this)
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[FCM] Permission denied');
      return;
    }

    // Get the token and send to backend
    final token = await messaging.getToken();
    if (token != null) {
      await _sendTokenToBackend(token);
    }

    // Listen for token refreshes (token can change after app restore / reinstall)
    messaging.onTokenRefresh.listen(_sendTokenToBackend);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[FCM] Foreground message: ${message.notification?.title}');
    });
  }

  static Future<void> _sendTokenToBackend(String token) async {
    try {
      await BackendRepository.updateFcmToken(token);
      debugPrint('[FCM] Token sent to backend');
    } catch (e) {
      debugPrint('[FCM] Failed to send token: $e');
    }
  }
}
