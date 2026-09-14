import 'package:flutter/material.dart';
import '../../models/app_models.dart';
import '../../services/api_client.dart';
import '../../services/api_config.dart';
import '../../services/backend_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'chat_screen.dart';

/// "Flat View Requests" — sits next to the Property feature. Two tabs:
///  • Sent: viewing requests the current user sent for other people's
///    To-Let listings (GET /viewing-requests/mine). Message the owner and
///    track approve/decline here.
///  • Received: requests other residents sent for listings the current
///    user owns (GET /viewing-requests/for-my-listings). Approve/decline
///    and message the requester here.
class FlatViewRequestsScreen extends StatelessWidget {
  const FlatViewRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Flat View Requests'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Sent by me'),
              Tab(text: 'Received (my listings)'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _SentRequestsTab(),
            _ReceivedRequestsTab(),
          ],
        ),
      ),
    );
  }
}

Color _statusColor(RequestStatus status) => switch (status) {
      RequestStatus.pending => AppColors.brass,
      RequestStatus.accepted => AppColors.lake,
      RequestStatus.completed => AppColors.parade,
      RequestStatus.declined => AppColors.brick,
    };

void _openChat(BuildContext context, RentalViewingRequest r, {required bool iAmRequester}) {
  if (r.id == null) {
    showActionSnackBar(context, 'This request has no chat yet — try again after it syncs with the server.');
    return;
  }
  final otherPartyName = iAmRequester ? (r.ownerName ?? 'Owner') : r.requesterName;
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => ChatScreen(
      viewingRequestId: r.id!,
      otherPartyName: otherPartyName,
      listingTitle: r.listingTitle,
    ),
  ));
}

// ── Sent by me ────────────────────────────────────────────────────────────

class _SentRequestsTab extends StatefulWidget {
  const _SentRequestsTab();

  @override
  State<_SentRequestsTab> createState() => _SentRequestsTabState();
}

class _SentRequestsTabState extends State<_SentRequestsTab> {
  List<RentalViewingRequest> _requests = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (!AuthSession.isLoggedIn) {
      setState(() => _error = 'Sign in to see the viewing requests you\'ve sent.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final requests = await BackendRepository.fetchMyViewingRequests();
      if (mounted) setState(() => _requests = requests);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on ApiUnreachableException {
      if (mounted) setState(() => _error = 'Could not reach the server — pull to retry.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: _loading && _requests.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!, style: const TextStyle(color: AppColors.brick)),
                  ),
                if (_requests.isEmpty && _error == null)
                  const EmptyState(
                    icon: Icons.key_outlined,
                    title: 'No viewing requests sent',
                    message: 'Requests you send from the To-Let tab will show up here — the owner is notified instantly, and you\'ll be notified back once they respond.',
                  )
                else
                  ..._requests.map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if ((r.listingImageUrl ?? '').isNotEmpty)
                                ListingImage(url: r.listingImageUrl!, height: 130),
                              Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(child: Text(r.listingTitle, style: Theme.of(context).textTheme.titleMedium)),
                                        StatusPill(label: r.status.label, color: _statusColor(r.status)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(r.listingLocation, style: Theme.of(context).textTheme.bodyMedium),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Owner: ${r.ownerName ?? 'Not available'}',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(r.note, style: Theme.of(context).textTheme.bodyMedium),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Text(_relativeTime(r.requestedAt), style: Theme.of(context).textTheme.labelSmall),
                                        const Spacer(),
                                        OutlinedButton.icon(
                                          onPressed: () => _openChat(context, r, iAmRequester: true),
                                          icon: const Icon(Icons.chat_bubble_outline, size: 18),
                                          label: const Text('Message owner'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )),
              ],
            ),
    );
  }
}

// ── Received (my listings) ───────────────────────────────────────────────

class _ReceivedRequestsTab extends StatefulWidget {
  const _ReceivedRequestsTab();

  @override
  State<_ReceivedRequestsTab> createState() => _ReceivedRequestsTabState();
}

class _ReceivedRequestsTabState extends State<_ReceivedRequestsTab> {
  List<RentalViewingRequest> _requests = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (!AuthSession.isLoggedIn) {
      setState(() => _error = 'Sign in to manage requests for your listings.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final requests = await BackendRepository.fetchViewingRequestsForMyListings();
      if (mounted) setState(() => _requests = requests);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on ApiUnreachableException {
      if (mounted) setState(() => _error = 'Could not reach the server — pull to retry.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setStatus(RentalViewingRequest r, RequestStatus status) async {
    setState(() => r.status = status);
    if (r.id != null) {
      try {
        await BackendRepository.updateViewingRequestStatus(r.id!, status);
      } on ApiException catch (e) {
        if (mounted) showActionSnackBar(context, e.message);
        return;
      } on ApiUnreachableException {
        // keep the optimistic local update
      }
    }
    if (!mounted) return;
    showActionSnackBar(context, 'Viewing request ${status.label.toLowerCase()} — the requester has been notified.');
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: _loading && _requests.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!, style: const TextStyle(color: AppColors.brick)),
                  ),
                if (_requests.isEmpty && _error == null)
                  const EmptyState(
                    icon: Icons.home_work_outlined,
                    title: 'No requests yet',
                    message: 'When someone requests a viewing for one of your To-Let listings, it will show up here for you to approve, decline, or message them.',
                  )
                else
                  ..._requests.map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if ((r.listingImageUrl ?? '').isNotEmpty)
                                ListingImage(url: r.listingImageUrl!, height: 130),
                              Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(child: Text(r.requesterName, style: Theme.of(context).textTheme.titleMedium)),
                                        StatusPill(label: r.status.label, color: _statusColor(r.status)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text('${r.listingTitle} · ${r.listingLocation}', style: Theme.of(context).textTheme.bodyMedium),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.call_outlined, size: 16, color: AppColors.inkFaint),
                                        const SizedBox(width: 4),
                                        Text(r.requesterPhone, style: Theme.of(context).textTheme.bodyMedium),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(r.note, style: Theme.of(context).textTheme.bodyMedium),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () => _openChat(context, r, iAmRequester: false),
                                            icon: const Icon(Icons.chat_bubble_outline, size: 18),
                                            label: const Text('Message'),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (r.status == RequestStatus.pending) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton(
                                              style: OutlinedButton.styleFrom(foregroundColor: AppColors.brick, side: const BorderSide(color: AppColors.brick)),
                                              onPressed: () => _setStatus(r, RequestStatus.declined),
                                              child: const Text('Decline'),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: () => _setStatus(r, RequestStatus.accepted),
                                              child: const Text('Approve'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )),
              ],
            ),
    );
  }
}

String _relativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inDays >= 1) return '${diff.inDays}d ago';
  if (diff.inHours >= 1) return '${diff.inHours}h ago';
  return '${diff.inMinutes}m ago';
}
