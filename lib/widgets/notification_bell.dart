import 'dart:async';

import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../services/api_config.dart';
import '../services/backend_repository.dart';
import '../theme/app_theme.dart';
import '../screens/notifications/notifications_screen.dart';

/// Notification bell for AppBars — pulls the live unread count from the
/// backend as soon as it mounts, keeps polling quietly in the background,
/// and refreshes again the moment the person comes back from the full
/// Notifications screen. Previously only the resident Home dashboard had
/// this; Service Provider and Developer dashboards had no way at all to
/// see the booking/quote/verification/review notifications the backend
/// was already sending them (Part 2: notification button fix).
class NotificationBellButton extends StatefulWidget {
  const NotificationBellButton({super.key});

  @override
  State<NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<NotificationBellButton> {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _refresh();
    if (AuthSession.isLoggedIn) {
      _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) => _refresh());
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!AuthSession.isLoggedIn) return;
    try {
      final notifications = await BackendRepository.fetchMyNotifications();
      if (!mounted) return;
      setState(() {
        MockData.notifications
          ..clear()
          ..addAll(notifications);
      });
    } catch (_) {
      // Backend unreachable — keep whatever is already cached.
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = MockData.notifications.where((n) => !n.isRead).length;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Notifications',
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            );
            _refresh();
          },
        ),
        if (unread > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(color: AppColors.brick, shape: BoxShape.circle),
            ),
          ),
      ],
    );
  }
}
