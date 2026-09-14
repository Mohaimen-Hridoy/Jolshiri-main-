import 'package:flutter/material.dart';
import '../../data/mock_data.dart';
import '../../models/app_models.dart';
import '../../services/api_client.dart';
import '../../services/backend_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class SystemModeratorDashboard extends StatelessWidget {
  const SystemModeratorDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tabBodyHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight - 48
            : MediaQuery.of(context).size.height * 0.62;
        return DefaultTabController(
          length: 5,
          child: Column(
            children: [
              const TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppColors.parade,
                unselectedLabelColor: AppColors.inkFaint,
                indicatorColor: AppColors.brass,
                tabs: [
                  Tab(text: 'Users'),
                  Tab(text: 'Community'),
                  Tab(text: 'Marketplace'),
                  Tab(text: 'AI Monitoring'),
                  Tab(text: 'Analytics'),
                ],
              ),
              SizedBox(
                height: tabBodyHeight.clamp(400, 900),
                child: const TabBarView(children: [
                  _UserManagementTab(),
                  _CommunityModerationTab(),
                  _MarketplaceModerationTab(),
                  _AiMonitoringTab(),
                  _AnalyticsTab(),
                ]),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── User Management ──────────────────────────────────────────────────────────

class _UserManagementTab extends StatefulWidget {
  const _UserManagementTab();

  @override
  State<_UserManagementTab> createState() => _UserManagementTabState();
}

class _UserManagementTabState extends State<_UserManagementTab> {
  static const _demoUsers = [
    _UserRow(name: 'Ahmed Al Imran', role: 'Resident', status: 'Active'),
    _UserRow(name: 'Taslimul Alam', role: 'Resident', status: 'Active'),
    _UserRow(name: 'Karim Uddin', role: 'Service Provider', status: 'Active'),
  ];

  List<AdminUserSummary>? _users;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final users = await BackendRepository.fetchAdminUsers();
      if (!mounted) return;
      setState(() { _users = users; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _handleAction(String action, AdminUserSummary? user) async {
    if (user == null) {
      showActionSnackBar(context, '$action action (demo mode)');
      return;
    }
    final backendAction = action == 'Suspend' ? 'suspend'
        : action == 'Unsuspend' ? 'unsuspend'
        : action == 'Ban' ? 'ban' : null;

    if (backendAction != null) {
      try {
        await BackendRepository.updateAdminUserStatus(user.id, backendAction);
        _load();
        if (!mounted) return;
        showActionSnackBar(context, '$action: ${user.fullName}');
        return;
      } on ApiException catch (e) {
        if (!mounted) return;
        showActionSnackBar(context, e.message);
        return;
      } on ApiUnreachableException {
        if (!mounted) return;
        showActionSnackBar(context, '$action: ${user.fullName} (offline — not saved)');
        return;
      }
    }

    if (action == 'Delete') {
      try {
        await BackendRepository.deleteAdminUser(user.id);
        setState(() => _users?.removeWhere((u) => u.id == user.id));
        if (!mounted) return;
        showActionSnackBar(context, 'Deleted: ${user.fullName}');
        return;
      } on ApiException catch (e) {
        if (!mounted) return;
        showActionSnackBar(context, e.message);
        return;
      } on ApiUnreachableException { /* fall through */ }
    }

    if (action == 'Reset password') {
      try {
        final message = await BackendRepository.adminResetUserPassword(user.id);
        if (!mounted) return;
        showActionSnackBar(context, message);
        return;
      } on ApiException catch (e) {
        if (!mounted) return;
        showActionSnackBar(context, e.message);
        return;
      } on ApiUnreachableException {
        if (!mounted) return;
        showActionSnackBar(context, 'Reset password: ${user.fullName} (offline — not sent)');
        return;
      }
    }

    if (action == 'Verify') {
      try {
        final message = await BackendRepository.adminVerifyUser(user.id);
        _load();
        if (!mounted) return;
        showActionSnackBar(context, message);
        return;
      } on ApiException catch (e) {
        if (!mounted) return;
        showActionSnackBar(context, e.message);
        return;
      } on ApiUnreachableException {
        if (!mounted) return;
        showActionSnackBar(context, 'Verify: ${user.fullName} (offline — not saved)');
        return;
      }
    }

    if (!mounted) return;
    showActionSnackBar(context, '$action: ${user.fullName}');
  }

  @override
  Widget build(BuildContext context) {
    final users = _users;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionHeader(eyebrow: 'Manage', title: 'User Accounts'),
        const SizedBox(height: 12),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (users != null && users.isNotEmpty)
          ...users.map((u) {
            final isSuspended = u.accountStatus == 'SUSPENDED';
            final isBanned = u.accountStatus == 'BANNED';
            final statusColor = isBanned ? AppColors.brick
                : isSuspended ? AppColors.brass : AppColors.lake;
            final statusLabel = isBanned ? 'Banned'
                : isSuspended ? 'Suspended' : 'Active';
            return Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.parade.withValues(alpha: 0.12),
                      child: Text(
                        u.fullName.isEmpty ? '?' : u.fullName.substring(0, 1),
                        style: const TextStyle(color: AppColors.parade, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(u.fullName, style: Theme.of(context).textTheme.titleMedium),
                          Text(u.role, style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                    StatusPill(label: statusLabel, color: statusColor),
                    PopupMenuButton<String>(
                      onSelected: (action) => _handleAction(action, u),
                      itemBuilder: (_) => [
                        if (!isSuspended && !isBanned)
                          const PopupMenuItem(value: 'Suspend', child: Text('Suspend')),
                        if (isSuspended)
                          const PopupMenuItem(value: 'Unsuspend', child: Text('Unsuspend')),
                        if (!isBanned)
                          const PopupMenuItem(value: 'Ban', child: Text('Ban')),
                        const PopupMenuItem(value: 'Delete', child: Text('Delete')),
                        const PopupMenuItem(value: 'Reset password', child: Text('Reset password')),
                        if (!u.isEmailVerified)
                          const PopupMenuItem(value: 'Verify', child: Text('Verify account')),
                      ],
                    ),
                  ],
                ),
              ),
            );
          })
        else
          ..._demoUsers.map((u) => Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.parade.withValues(alpha: 0.12),
                    child: Text(u.name.substring(0, 1),
                        style: const TextStyle(color: AppColors.parade, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(u.name, style: Theme.of(context).textTheme.titleMedium),
                        Text(u.role, style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  StatusPill(
                    label: u.status,
                    color: u.status == 'Active' ? AppColors.lake
                        : u.status == 'Suspended' ? AppColors.brass : AppColors.brick,
                  ),
                  PopupMenuButton<String>(
                    onSelected: (action) => _handleAction(action, null),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'Suspend', child: Text('Suspend')),
                      PopupMenuItem(value: 'Ban', child: Text('Ban')),
                      PopupMenuItem(value: 'Delete', child: Text('Delete')),
                      PopupMenuItem(value: 'Reset password', child: Text('Reset password')),
                      PopupMenuItem(value: 'Verify', child: Text('Verify account')),
                    ],
                  ),
                ],
              ),
            ),
          )),
      ],
    );
  }
}

class _UserRow {
  final String name;
  final String role;
  final String status;
  const _UserRow({required this.name, required this.role, required this.status});
}

// ── Community Moderation ─────────────────────────────────────────────────────

enum _PostModStatus { none, spam, fake }

class _CommunityModerationTab extends StatefulWidget {
  const _CommunityModerationTab();

  @override
  State<_CommunityModerationTab> createState() => _CommunityModerationTabState();
}

class _CommunityModerationTabState extends State<_CommunityModerationTab> {
  late List<CommunityPost> _posts;
  // Tracks local moderation label per post id (or index for mock posts)
  final Map<String, _PostModStatus> _modStatus = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _posts = List.of(MockData.communityPosts);
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final posts = await BackendRepository.fetchCommunityPosts();
      if (mounted && posts.isNotEmpty) {
        setState(() {
          MockData.communityPosts..clear()..addAll(posts);
          _posts = List.of(posts);
        });
      }
    } on ApiException catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _postKey(CommunityPost p, int index) => p.id ?? 'mock_$index';

  void _markAs(CommunityPost post, int index, _PostModStatus status) {
    final key = _postKey(post, index);
    final current = _modStatus[key] ?? _PostModStatus.none;
    // Toggle: tapping same label clears it
    final next = current == status ? _PostModStatus.none : status;
    setState(() => _modStatus[key] = next);
    final label = next == _PostModStatus.none
        ? 'Label cleared for ${post.author}'
        : next == _PostModStatus.spam
            ? 'Marked as Spam: ${post.author}'
            : 'Marked as Fake: ${post.author}';
    showActionSnackBar(context, label);
  }

  Future<void> _remove(CommunityPost post, int index) async {
    // Confirm before delete
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove post?'),
        content: Text('Remove "${post.content.length > 60 ? '${post.content.substring(0, 60)}…' : post.content}" by ${post.author}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.brick),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    if (post.id != null) {
      try {
        await ApiClient.delete('/community-posts/${post.id}', auth: true);
      } on ApiException catch (e) {
        if (!mounted) return;
        showActionSnackBar(context, e.message);
        return;
      } on ApiUnreachableException {
        // remove locally anyway
      }
    }
    setState(() {
      _posts.removeAt(index);
      MockData.communityPosts.remove(post);
    });
    if (!mounted) return;
    showActionSnackBar(context, 'Post removed');
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(child: SectionHeader(
                eyebrow: 'Moderate',
                title: 'Community Posts',
                trailing: Text('${_posts.length} posts',
                    style: Theme.of(context).textTheme.labelSmall),
              )),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (_posts.isEmpty && !_loading)
            const EmptyState(
              icon: Icons.groups_outlined,
              title: 'No posts',
              message: 'Community posts will appear here for moderation.',
            )
          else
            ...List.generate(_posts.length, (index) {
              final p = _posts[index];
              final key = _postKey(p, index);
              final mod = _modStatus[key] ?? _PostModStatus.none;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(child: Text(p.author,
                            style: Theme.of(context).textTheme.titleMedium)),
                        StatusPill(
                          label: mod == _PostModStatus.spam ? 'Spam'
                              : mod == _PostModStatus.fake ? 'Fake'
                              : p.category,
                          color: mod == _PostModStatus.spam ? AppColors.brick
                              : mod == _PostModStatus.fake ? AppColors.brass
                              : AppColors.lake,
                        ),
                      ]),
                      const SizedBox(height: 4),
                      Text(
                        p.content,
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (p.price != null && p.price!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text('Price: ${p.price}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.brass)),
                      ],
                      Text(
                        '${p.postedAt.day}/${p.postedAt.month}/${p.postedAt.year} · ${p.comments.length} comment(s)',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: AppColors.inkFaint),
                      ),
                      const SizedBox(height: 10),
                      Row(children: [
                        _ModChip(
                          label: 'Spam',
                          active: mod == _PostModStatus.spam,
                          activeColor: AppColors.brick,
                          onTap: () => _markAs(p, index, _PostModStatus.spam),
                        ),
                        const SizedBox(width: 8),
                        _ModChip(
                          label: 'Fake',
                          active: mod == _PostModStatus.fake,
                          activeColor: AppColors.brass,
                          onTap: () => _markAs(p, index, _PostModStatus.fake),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          style: TextButton.styleFrom(foregroundColor: AppColors.brick),
                          icon: const Icon(Icons.delete_outline, size: 16),
                          label: const Text('Remove'),
                          onPressed: () => _remove(p, index),
                        ),
                      ]),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _ModChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  const _ModChip({
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? activeColor.withValues(alpha: 0.12) : Colors.transparent,
          border: Border.all(
            color: active ? activeColor : AppColors.inkFaint.withValues(alpha: 0.4),
            width: active ? 1.6 : 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.normal,
            color: active ? activeColor : AppColors.inkFaint,
          ),
        ),
      ),
    );
  }
}

// ── Marketplace Moderation ───────────────────────────────────────────────────

enum _ListingModStatus { none, flagged }

class _MarketplaceModerationTab extends StatefulWidget {
  const _MarketplaceModerationTab();

  @override
  State<_MarketplaceModerationTab> createState() => _MarketplaceModerationTabState();
}

class _MarketplaceModerationTabState extends State<_MarketplaceModerationTab> {
  bool _loading = false;
  final Map<String, _ListingModStatus> _flagged = {};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final rentals = await BackendRepository.fetchRentals();
      if (mounted && rentals.isNotEmpty) {
        setState(() { MockData.rentals..clear()..addAll(rentals); });
      }
    } on ApiException catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _listingKey(RentalListing r, int index) => r.id ?? 'mock_$index';

  void _toggleFlag(RentalListing rental, int index) {
    final key = _listingKey(rental, index);
    final current = _flagged[key] ?? _ListingModStatus.none;
    final next = current == _ListingModStatus.flagged
        ? _ListingModStatus.none
        : _ListingModStatus.flagged;
    setState(() => _flagged[key] = next);
    showActionSnackBar(
      context,
      next == _ListingModStatus.flagged
          ? 'Flagged for review: ${rental.title}'
          : 'Flag removed: ${rental.title}',
    );
  }

  Future<void> _deleteRental(RentalListing rental, int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove listing?'),
        content: Text('Remove "${rental.title}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.brick),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    if (rental.id != null) {
      try {
        await ApiClient.delete('/rentals/${rental.id}', auth: true);
      } on ApiException catch (e) {
        if (!mounted) return;
        showActionSnackBar(context, e.message);
        return;
      } on ApiUnreachableException { /* remove locally */ }
    }
    setState(() {
      MockData.rentals.removeAt(index);
      _flagged.remove(_listingKey(rental, index));
    });
    if (!mounted) return;
    showActionSnackBar(context, 'Listing removed: ${rental.title}');
  }

  @override
  Widget build(BuildContext context) {
    final rentals = MockData.rentals;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionHeader(
            eyebrow: 'Review',
            title: 'Rental Listings',
            trailing: Text('${rentals.length} total',
                style: Theme.of(context).textTheme.labelSmall),
          ),
          const SizedBox(height: 12),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (!_loading && rentals.isEmpty)
            const EmptyState(
              icon: Icons.home_work_outlined,
              title: 'No listings',
              message: 'Active rental listings will appear here for review.',
            )
          else
            ...List.generate(rentals.length, (index) {
              final item = rentals[index];
              final key = _listingKey(item, index);
              final isFlagged = (_flagged[key] ?? _ListingModStatus.none) == _ListingModStatus.flagged;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(child: Text(item.title,
                            style: Theme.of(context).textTheme.titleMedium)),
                        StatusPill(
                          label: isFlagged ? 'Flagged' : 'Active',
                          color: isFlagged ? AppColors.brick : AppColors.lake,
                        ),
                      ]),
                      const SizedBox(height: 4),
                      Text(
                        '${item.location} · ${item.bedrooms} bed · ${item.rentAmount}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (item.availability.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text('Available: ${item.availability}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.inkFaint)),
                      ],
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: Icon(
                              isFlagged ? Icons.flag : Icons.flag_outlined,
                              size: 16,
                              color: isFlagged ? AppColors.brick : null,
                            ),
                            style: isFlagged
                                ? OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.brick,
                                    side: const BorderSide(color: AppColors.brick),
                                  )
                                : null,
                            onPressed: () => _toggleFlag(item, index),
                            label: Text(isFlagged ? 'Unflag' : 'Flag'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.brick,
                                side: const BorderSide(color: AppColors.brick)),
                            icon: const Icon(Icons.delete_outline, size: 16),
                            onPressed: () => _deleteRental(item, index),
                            label: const Text('Remove'),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ── AI Monitoring ─────────────────────────────────────────────────────────────

class _AiMonitoringTab extends StatefulWidget {
  const _AiMonitoringTab();

  @override
  State<_AiMonitoringTab> createState() => _AiMonitoringTabState();
}

class _AiMonitoringTabState extends State<_AiMonitoringTab> {
  // Mutable list so Clear/Escalate update in-place
  late final List<_AiFlag> _flags = [
    const _AiFlag(
      query: '"Is Plot 7-142 legally disputed?"',
      response: 'AI stated the plot has no disputes without checking records.',
      reason: 'Unverified claim',
      status: 'Needs review',
    ),
    const _AiFlag(
      query: '"Can you share Karim Uddin\'s phone number?"',
      response: 'AI shared a service provider\'s contact info directly.',
      reason: 'Privacy concern',
      status: 'Needs review',
    ),
    const _AiFlag(
      query: '"What\'s the average rent in Sector 3?"',
      response: 'AI gave an estimate based on current rental listings.',
      reason: 'Low confidence answer',
      status: 'Cleared',
    ),
    const _AiFlag(
      query: '"Best developer for a duplex build?"',
      response: 'AI recommended a single developer by name.',
      reason: 'Possible bias',
      status: 'Escalated',
    ),
  ];

  void _setStatus(int index, String newStatus) {
    // Toggle: pressing same button clears back to 'Needs review'
    final current = _flags[index].status;
    setState(() {
      _flags[index] = _AiFlag(
        query: _flags[index].query,
        response: _flags[index].response,
        reason: _flags[index].reason,
        status: current == newStatus ? 'Needs review' : newStatus,
      );
    });
    final label = current == newStatus
        ? 'Reverted to "Needs review"'
        : newStatus == 'Cleared'
            ? 'Cleared: ${_flags[index].query}'
            : 'Escalated: ${_flags[index].query}';
    showActionSnackBar(context, label);
  }

  @override
  Widget build(BuildContext context) {
    final needsReview = _flags.where((f) => f.status == 'Needs review').length;
    final escalated = _flags.where((f) => f.status == 'Escalated').length;
    final cleared = _flags.where((f) => f.status == 'Cleared').length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionHeader(eyebrow: 'Oversee', title: 'AI Assistant Monitoring'),
        const SizedBox(height: 12),
        Row(
          children: [
            const Expanded(
              child: _StatCard(
                label: 'Queries Today',
                value: '186',
                icon: Icons.forum_outlined,
                color: AppColors.parade,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                label: 'Flagged Responses',
                value: '${_flags.length}',
                icon: Icons.flag_outlined,
                color: AppColors.brick,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Needs Review',
                value: '$needsReview',
                icon: Icons.pending_outlined,
                color: AppColors.brass,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                label: 'Escalated',
                value: '$escalated',
                icon: Icons.warning_amber_outlined,
                color: AppColors.brick,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                label: 'Cleared',
                value: '$cleared',
                icon: Icons.check_circle_outline,
                color: AppColors.lake,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const SectionHeader(eyebrow: 'Review', title: 'Flagged Conversations'),
        const SizedBox(height: 12),
        ...List.generate(_flags.length, (index) {
          final f = _flags[index];
          final isCleared = f.status == 'Cleared';
          final isEscalated = f.status == 'Escalated';
          final isNeedsReview = f.status == 'Needs review';
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text(f.query,
                        style: Theme.of(context).textTheme.titleMedium)),
                    StatusPill(
                      label: f.status,
                      color: isCleared ? AppColors.lake
                          : isEscalated ? AppColors.brick
                          : AppColors.brass,
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Text(f.response,
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Text('Reason: ${f.reason}',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: AppColors.inkFaint)),
                  const SizedBox(height: 10),
                  Row(children: [
                    OutlinedButton.icon(
                      icon: Icon(
                        Icons.check_circle_outline,
                        size: 15,
                        color: isCleared ? AppColors.lake : null,
                      ),
                      style: isCleared
                          ? OutlinedButton.styleFrom(
                              foregroundColor: AppColors.lake,
                              side: const BorderSide(color: AppColors.lake),
                            )
                          : null,
                      onPressed: isNeedsReview || isCleared
                          ? () => _setStatus(index, 'Cleared')
                          : null,
                      label: Text(isCleared ? 'Cleared ✓' : 'Clear'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: Icon(
                        Icons.warning_amber_outlined,
                        size: 15,
                        color: isEscalated ? AppColors.brick : null,
                      ),
                      style: isEscalated
                          ? OutlinedButton.styleFrom(
                              foregroundColor: AppColors.brick,
                              side: const BorderSide(color: AppColors.brick),
                            )
                          : OutlinedButton.styleFrom(
                              foregroundColor: AppColors.brick,
                            ),
                      onPressed: isNeedsReview || isEscalated
                          ? () => _setStatus(index, 'Escalated')
                          : null,
                      label: Text(isEscalated ? 'Escalated !' : 'Escalate'),
                    ),
                  ]),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _AiFlag {
  final String query;
  final String response;
  final String reason;
  final String status;
  const _AiFlag({
    required this.query,
    required this.response,
    required this.reason,
    required this.status,
  });
}

// ── Analytics ────────────────────────────────────────────────────────────────

class _AnalyticsTab extends StatefulWidget {
  const _AnalyticsTab();

  @override
  State<_AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<_AnalyticsTab> {
  AdminKpis? _kpis;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final kpis = await BackendRepository.fetchAdminKpis();
      if (mounted) setState(() { _kpis = kpis; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = _kpis;
    final totalUsers = k == null ? '—'
        : '${k.residentCount + k.developerCount + k.providerCount}';
    final residents = k == null ? '—' : '${k.residentCount}';
    final providers = k == null ? '—' : '${k.providerCount}';
    final developers = k == null ? '—' : '${k.developerCount}';
    final rentals = k == null ? '—' : '${k.rentalCount}';
    final projects = k == null ? '—' : '${k.activeProjects}';
    final security = k == null ? '—' : '${k.openSecurityReports}';

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionHeader(eyebrow: 'Usage', title: 'Platform Analytics'),
          if (_loading) const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(minHeight: 2),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _StatCard(label: 'Total Users', value: totalUsers, icon: Icons.people_outline, color: AppColors.parade)),
            const SizedBox(width: 10),
            Expanded(child: _StatCard(label: 'Residents', value: residents, icon: Icons.home_outlined, color: AppColors.lake)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _StatCard(label: 'Service Providers', value: providers, icon: Icons.build_outlined, color: AppColors.brass)),
            const SizedBox(width: 10),
            Expanded(child: _StatCard(label: 'Developers', value: developers, icon: Icons.engineering_outlined, color: AppColors.parade)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _StatCard(label: 'Rental Listings', value: rentals, icon: Icons.house_outlined, color: AppColors.lake)),
            const SizedBox(width: 10),
            Expanded(child: _StatCard(label: 'Active Projects', value: projects, icon: Icons.construction_outlined, color: AppColors.brass)),
          ]),
          const SizedBox(height: 10),
          _StatCard(label: 'Open Security Reports', value: security, icon: Icons.security_outlined, color: AppColors.brick),
          const SizedBox(height: 20),
          const SectionHeader(eyebrow: 'Trend', title: 'Daily Logins (Last 7 Days)'),
          const SizedBox(height: 12),
          const _MiniBarChart(data: [
            _Bar('Mon', 0.6),
            _Bar('Tue', 0.75),
            _Bar('Wed', 0.9),
            _Bar('Thu', 0.7),
            _Bar('Fri', 0.85),
            _Bar('Sat', 0.5),
            _Bar('Sun', 0.4),
          ]),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
                  Text(label,
                      style: const TextStyle(fontSize: 12, color: AppColors.inkFaint),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bar {
  final String label;
  final double ratio;
  const _Bar(this.label, this.ratio);
}

class _MiniBarChart extends StatelessWidget {
  final List<_Bar> data;
  const _MiniBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 100,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: data.map((b) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Container(
                      height: b.ratio * 90,
                      decoration: BoxDecoration(
                        color: AppColors.lake.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                )).toList(),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: data.map((b) => Expanded(
                child: Text(b.label, textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, color: AppColors.inkFaint)),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
