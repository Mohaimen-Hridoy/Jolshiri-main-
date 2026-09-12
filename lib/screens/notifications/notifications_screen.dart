import 'package:flutter/material.dart';
import '../../data/mock_data.dart';
import '../../services/api_config.dart';
import '../../services/backend_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Fixed: the bell used to just show whatever was cached at login, so
    // anything that arrived afterwards (a request accepted, a booking
    // completed, etc.) never showed up until the app was restarted. Now
    // every time this screen opens it pulls the live list from the backend.
    _refresh();
  }

  Future<void> _refresh() async {
    if (!AuthSession.isLoggedIn) return;
    setState(() => _loading = true);
    try {
      final notifications = await BackendRepository.fetchMyNotifications();
      if (!mounted) return;
      setState(() {
        MockData.notifications
          ..clear()
          ..addAll(notifications);
      });
    } catch (_) {
      // Backend unreachable — keep whatever notifications are already cached.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _markAllRead() {
    setState(() {
      for (final n in MockData.notifications) {
        n.isRead = true;
      }
    });
    // Fire-and-forget: the list already reflects the read state locally;
    // if the backend is unreachable the next sync will just re-fetch as-is.
    BackendRepository.markAllNotificationsRead().catchError((_) {});
  }

  void _markRead(dynamic n) {
    setState(() => n.isRead = true);
    if (n.id != null) {
      BackendRepository.markNotificationRead(n.id!).catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = MockData.notifications;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _refresh,
          ),
          TextButton(
            onPressed: items.isEmpty ? null : _markAllRead,
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: items.isEmpty
                  ? ListView(
                      // Wrapped in a ListView so pull-to-refresh still works
                      // on an empty list.
                      children: const [
                        EmptyState(
                          icon: Icons.notifications_none_rounded,
                          title: 'All caught up',
                          message: 'New alerts and updates will appear here.',
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final n = items[i];
                        return Card(
                          color: n.isRead ? Colors.white : AppColors.paperDim,
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(14),
                            onTap: () => _markRead(n),
                            leading: Container(
                              width: 10,
                              height: 10,
                              margin: const EdgeInsets.only(top: 4),
                              decoration: BoxDecoration(color: n.isRead ? Colors.transparent : AppColors.brick, shape: BoxShape.circle),
                            ),
                            title: Text(n.title, style: Theme.of(context).textTheme.titleMedium),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(n.message, style: Theme.of(context).textTheme.bodyMedium),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
