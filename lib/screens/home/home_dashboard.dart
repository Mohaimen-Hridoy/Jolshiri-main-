import 'dart:async';

import 'package:flutter/material.dart';
import '../../data/mock_data.dart';
import '../../models/app_models.dart';
import '../../services/api_config.dart';
import '../../services/backend_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/review_prompt.dart';
import '../authority/authority_screen.dart';
import '../chatbot/chatbot_screen.dart';
import '../notifications/notifications_screen.dart';
import '../property/property_screen.dart';
import '../property/tolet_screen.dart';
import '../property/flat_view_requests_screen.dart';
import '../resident/complaints_screen.dart';
import '../resident/construction_lifecycle_screen.dart';
import '../resident/meetings_screen.dart';
import '../resident/payments_screen.dart';
import '../resident/reviews_screen.dart';
import '../security/security_screen.dart';

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  Timer? _pollTimer;
  final Set<String> _promptedBookingIds = {};
  bool _reviewPromptShowing = false;

  @override
  void initState() {
    super.initState();
    // Fixed notification button: pull the live feed as soon as the
    // dashboard opens instead of only relying on the one-time sync done at
    // login, and keep polling quietly in the background so the bell badge
    // (and the "mark completed" review prompt below) reflect the backend
    // in near real time rather than only after a full app restart.
    _refreshNotifications();
    if (AuthSession.isLoggedIn) {
      _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) => _poll());
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshNotifications() async {
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

  Future<void> _poll() async {
    await _refreshNotifications();
    try {
      final bookings = await BackendRepository.fetchMyBookings();
      if (!mounted) return;
      setState(() {
        MockData.serviceBookings
          ..removeWhere((b) => b.customerName == MockData.currentUser.fullName)
          ..insertAll(0, bookings);
      });
    } catch (_) {
      // Backend unreachable — keep whatever bookings are already cached.
    }
    _maybePromptForReview();
  }

  // Part 6: as soon as a service provider marks a booking "completed", the
  // resident should be asked to rate & review it. Shows the prompt at most
  // once per booking (tracked by id) and never stacks two prompts.
  void _maybePromptForReview() {
    if (_reviewPromptShowing || !mounted) return;
    final pending = MockData.serviceBookings.where((b) =>
        b.customerName == MockData.currentUser.fullName &&
        b.status == RequestStatus.completed &&
        !b.reviewed &&
        (b.id == null || !_promptedBookingIds.contains(b.id)));
    if (pending.isEmpty) return;

    final booking = pending.first;
    if (booking.id != null) _promptedBookingIds.add(booking.id!);
    _reviewPromptShowing = true;
    showServiceRatingPrompt(context, booking).whenComplete(() {
      _reviewPromptShowing = false;
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = MockData.currentUser;
    final unread = MockData.notifications.where((n) => !n.isRead).length;

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.parade,
                    child: Text(user.initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Welcome back,', style: Theme.of(context).textTheme.bodyMedium),
                        Text(user.fullName, style: Theme.of(context).textTheme.titleLarge),
                      ],
                    ),
                  ),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined),
                        onPressed: () async {
                          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                          _refreshNotifications();
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
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.parade, AppColors.paradeDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('YOUR ROLE', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.brass)),
                          const SizedBox(height: 6),
                          Text(
                            user.role.label,
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'serif'),
                          ),
                          const SizedBox(height: 4),
                          Text(user.address, style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12.5)),
                        ],
                      ),
                    ),
                    const Icon(Icons.shield_moon_outlined, color: AppColors.brass, size: 36),
                  ],
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 26, 20, 12),
              child: SectionHeader(eyebrow: 'Get things done', title: 'Quick access'),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.92,
              ),
              delegate: SliverChildListDelegate([
                QuickAccessTile(
                  icon: Icons.home_work_outlined,
                  label: 'Property',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PropertyScreen())),
                ),
                QuickAccessTile(
                  icon: Icons.key_outlined,
                  label: 'To-Let',
                  color: AppColors.lake,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ToLetScreen())),
                ),
                QuickAccessTile(
                  icon: Icons.forum_outlined,
                  label: 'Flat View Requests',
                  color: AppColors.brass,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FlatViewRequestsScreen())),
                ),
                QuickAccessTile(
                  icon: Icons.shield_outlined,
                  label: 'Security',
                  color: AppColors.brick,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SecurityScreen())),
                ),
                QuickAccessTile(
                  icon: Icons.account_balance_outlined,
                  label: 'Authority',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthorityScreen())),
                ),
                QuickAccessTile(
                  icon: Icons.smart_toy_outlined,
                  label: 'AI Chatbot',
                  color: AppColors.brass,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChatbotScreen())),
                ),
                QuickAccessTile(
                  icon: Icons.notifications_none_rounded,
                  label: 'Notifications',
                  color: AppColors.lake,
                  onTap: () async {
                    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                    _refreshNotifications();
                  },
                ),
                QuickAccessTile(
                  icon: Icons.star_rate_outlined,
                  label: 'Reviews',
                  color: AppColors.brass,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReviewsScreen())),
                ),
                QuickAccessTile(
                  icon: Icons.video_call_outlined,
                  label: 'Meetings',
                  color: AppColors.lake,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MeetingsScreen())),
                ),
                QuickAccessTile(
                  icon: Icons.payments_outlined,
                  label: 'Payments',
                  color: AppColors.parade,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PaymentsScreen())),
                ),
                QuickAccessTile(
                  icon: Icons.construction_outlined,
                  label: 'Build Track',
                  color: AppColors.brick,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConstructionLifecycleScreen())),
                ),
                QuickAccessTile(
                  icon: Icons.report_problem_outlined,
                  label: 'Complaints',
                  color: AppColors.brass,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ComplaintsScreen())),
                ),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
              child: SectionHeader(
                eyebrow: 'Stay informed',
                title: 'Latest notices',
                trailing: TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthorityScreen())),
                  child: const Text('See all'),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final n = MockData.notices[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _NoticePreviewCard(notice: n),
                  );
                },
                childCount: MockData.notices.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticePreviewCard extends StatelessWidget {
  final Notice notice;
  const _NoticePreviewCard({required this.notice});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: AppColors.paperDim, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.campaign_outlined, size: 18, color: AppColors.parade),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notice.title, style: Theme.of(context).textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(notice.description, style: Theme.of(context).textTheme.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
