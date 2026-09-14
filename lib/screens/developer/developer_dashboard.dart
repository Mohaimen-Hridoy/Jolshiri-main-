import 'package:flutter/material.dart';
import '../../data/mock_data.dart';
import '../../models/app_models.dart';
import '../../services/api_client.dart';
import '../../services/api_config.dart';
import '../../services/backend_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/notification_bell.dart';
import '../auth/login_screen.dart';
import '../resident/construction_lifecycle_screen.dart';

/// Home for a logged-in Developer.
/// Tabs: (1) Quote Requests + Meetings  (2) Plot Archive
class DeveloperDashboard extends StatefulWidget {
  const DeveloperDashboard({super.key, this.developerName});

  /// Company name of the logged-in developer (shown in the AppBar subtitle).
  final String? developerName;

  @override
  State<DeveloperDashboard> createState() => _DeveloperDashboardState();
}

class _DeveloperDashboardState extends State<DeveloperDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Opens the "Company profile" editor — lets the logged-in developer
  /// update the Developer directory record (company name, contact,
  /// specialty) that residents see in the developer directory. Backed by
  /// GET/PATCH /api/developers/me.
  Future<void> _openProfileEditor() async {
    Developer? current;
    try {
      current = await BackendRepository.fetchMyDeveloperProfile();
    } on ApiException catch (e) {
      if (!mounted) return;
      showActionSnackBar(context, e.message);
      return;
    } on ApiUnreachableException {
      if (!mounted) return;
      showActionSnackBar(context, 'Could not reach server — try again later');
      return;
    }
    if (!mounted) return;

    final companyController = TextEditingController(text: current.companyName);
    final contactController = TextEditingController(text: current.contact);
    final specialtyController = TextEditingController(text: current.specialty);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Company profile', style: Theme.of(sheetContext).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'This is what residents see in the developer directory.',
                style: Theme.of(sheetContext).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              TextField(controller: companyController, decoration: const InputDecoration(labelText: 'Company name')),
              const SizedBox(height: 10),
              TextField(controller: contactController, decoration: const InputDecoration(labelText: 'Contact number')),
              const SizedBox(height: 10),
              TextField(controller: specialtyController, decoration: const InputDecoration(labelText: 'Specialty (e.g. Residential construction)')),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final companyName = companyController.text.trim();
                    final contact = contactController.text.trim();
                    final specialty = specialtyController.text.trim();
                    if (companyName.isEmpty || contact.isEmpty || specialty.isEmpty) {
                      showActionSnackBar(sheetContext, 'Please fill in all fields');
                      return;
                    }
                    try {
                      await runWithLoadingOverlay(
                        sheetContext,
                        () => BackendRepository.updateMyDeveloperProfile(
                          companyName: companyName,
                          contact: contact,
                          specialty: specialty,
                        ),
                        message: 'Saving changes…',
                      );
                      if (!sheetContext.mounted) return;
                      Navigator.pop(sheetContext);
                      if (!mounted) return;
                      showActionSnackBar(context, 'Company profile updated');
                    } on ApiException catch (e) {
                      if (!sheetContext.mounted) return;
                      showActionSnackBar(sheetContext, e.message);
                    } on ApiUnreachableException {
                      if (!sheetContext.mounted) return;
                      showActionSnackBar(sheetContext, 'Could not reach server — profile not updated');
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
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Developer Dashboard'),
            if (widget.developerName != null)
              Text(
                widget.developerName!,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
              ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.request_quote_outlined), text: 'Requests'),
            Tab(icon: Icon(Icons.table_chart_outlined), text: 'Plot Archive'),
            Tab(icon: Icon(Icons.construction_outlined), text: 'Construction'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Company profile',
            icon: const Icon(Icons.apartment_outlined),
            onPressed: _openProfileEditor,
          ),
          const NotificationBellButton(),
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // Was navigating to LoginScreen without ever clearing the
              // saved session — see the same fix in resident/profile_screen.dart.
              await AuthSession.clear();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _RequestsTab(),
          _PlotArchiveTab(),
          _ConstructionTab(),
        ],
      ),
    );
  }
}

// ── Tab 1: Quote Requests + Meetings ──────────────────────────────────────────

class _RequestsTab extends StatefulWidget {
  const _RequestsTab();

  @override
  State<_RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<_RequestsTab> {
  RequestStatus? _filter;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final quotes = await BackendRepository.fetchDeveloperQuotes();
      final meetings = await BackendRepository.fetchDeveloperMeetings();
      if (mounted) {
        setState(() {
          if (quotes.isNotEmpty) {
            MockData.quoteRequests..clear()..addAll(quotes);
          }
          if (meetings.isNotEmpty) {
            MockData.developerMeetings..clear()..addAll(meetings);
          }
        });
      }
    } on ApiException catch (_) {
      // keep existing
    } on ApiUnreachableException {
      // keep mock data
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<QuoteRequest> get _quotes {
    final all = MockData.quoteRequests;
    if (_filter == null) return all;
    return all.where((q) => q.status == _filter).toList();
  }

  List<DeveloperMeeting> get _meetings {
    return MockData.developerMeetings.toList()
      ..sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));
  }

  void _setStatus(QuoteRequest quote, RequestStatus status) async {
    setState(() => quote.status = status);
    if (quote.id != null) {
      try {
        await BackendRepository.updateQuoteStatus(quote.id!, status);
      } on ApiException catch (e) {
        if (!mounted) return;
        showActionSnackBar(context, e.message);
        return;
      } on ApiUnreachableException {
        // keep the optimistic local update; backend unreachable
      }
    }
    if (!mounted) return;
    showActionSnackBar(context, 'Quote ${status.label.toLowerCase()}');
  }

  void _setMeetingStatus(DeveloperMeeting meeting, MeetingStatus status, {String? meetingLink}) async {
    setState(() {
      meeting.status = status;
      if (meetingLink != null && meetingLink.isNotEmpty) meeting.meetingLink = meetingLink;
    });
    if (meeting.id != null) {
      try {
        await BackendRepository.updateMeetingStatus(meeting.id!, status, meetingLink: meetingLink);
      } on ApiException catch (e) {
        if (!mounted) return;
        showActionSnackBar(context, e.message);
        return;
      } on ApiUnreachableException {
        // keep the optimistic local update; backend unreachable
      }
    }
    if (!mounted) return;
    showActionSnackBar(context, 'Meeting ${status.label.toLowerCase()}');
  }

  /// Confirming an ONLINE meeting needs the developer's own Zoom/Google
  /// Meet link — Jolshiri can't generate one on their behalf (that would
  /// need their Zoom/Google account credentials). This asks them to create
  /// the meeting in their own Zoom/Meet account first and paste the join
  /// link in here. Returns null if the developer cancels.
  Future<String?> _promptForMeetingLink(DeveloperMeeting meeting) {
    final controller = TextEditingController();
    final platformLabel = meeting.platform?.label ?? 'Zoom/Google Meet';
    return showDialog<String>(
      context: context,
      builder: (dialogCtx) {
        String? errorText;
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              title: Text('Paste your $platformLabel link'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create the meeting in your own $platformLabel account, then paste the join link here — the resident will see it once you confirm.',
                    style: Theme.of(dialogCtx).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      labelText: 'Meeting link',
                      hintText: 'https://zoom.us/j/... or https://meet.google.com/...',
                      errorText: errorText,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final link = controller.text.trim();
                    final uri = Uri.tryParse(link);
                    if (link.isEmpty || uri == null || !uri.isScheme('HTTPS')) {
                      setDialogState(() => errorText = 'Enter a valid https:// link');
                      return;
                    }
                    Navigator.of(dialogCtx).pop(link);
                  },
                  child: const Text('Confirm meeting'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Color _statusColor(RequestStatus s) => switch (s) {
        RequestStatus.pending => AppColors.brass,
        RequestStatus.accepted => AppColors.lake,
        RequestStatus.completed => AppColors.parade,
        RequestStatus.declined => AppColors.brick,
      };

  Color _meetingColor(MeetingStatus s) => switch (s) {
        MeetingStatus.pending => AppColors.brass,
        MeetingStatus.confirmed => AppColors.lake,
        MeetingStatus.completed => AppColors.parade,
        MeetingStatus.cancelled => AppColors.brick,
      };

  @override
  Widget build(BuildContext context) {
    final quotes = _quotes;
    final meetings = _meetings;
    final pendingCount = MockData.quoteRequests
        .where((q) => q.status == RequestStatus.pending)
        .length;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        // Banner
        Container(
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
                    Text('QUOTE REQUESTS',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: AppColors.brass)),
                    const SizedBox(height: 6),
                    Text(
                      '$pendingCount new request${pendingCount == 1 ? '' : 's'}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'serif'),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Respond with quotes to win construction projects',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.engineering_outlined,
                  color: AppColors.brass, size: 36),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Filter chips
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _filterChip('All', null),
              _filterChip('Pending', RequestStatus.pending),
              _filterChip('Accepted', RequestStatus.accepted),
              _filterChip('Completed', RequestStatus.completed),
              _filterChip('Declined', RequestStatus.declined),
            ],
          ),
        ),
        const SizedBox(height: 8),

        if (quotes.isEmpty)
          const EmptyState(
            icon: Icons.request_quote_outlined,
            title: 'No quote requests',
            message: 'Requests from residents will show up in this list.',
          )
        else
          ...quotes.map((q) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                              child: Text(q.customerName,
                                  style:
                                      Theme.of(context).textTheme.titleMedium)),
                          StatusPill(
                              label: q.status.label,
                              color: _statusColor(q.status)),
                        ]),
                        const SizedBox(height: 6),
                        Row(children: [
                          Expanded(
                              child: Text(q.projectType,
                                  style:
                                      Theme.of(context).textTheme.bodyMedium)),
                          Text(_relativeTime(q.requestedAt),
                              style: Theme.of(context).textTheme.labelSmall),
                        ]),
                        const SizedBox(height: 10),
                        Row(children: [
                          const Icon(Icons.place_outlined,
                              size: 16, color: AppColors.inkFaint),
                          const SizedBox(width: 4),
                          Expanded(
                              child: Text(q.plotLocation,
                                  style:
                                      Theme.of(context).textTheme.bodyMedium)),
                        ]),
                        const SizedBox(height: 6),
                        Row(children: [
                          const Icon(Icons.payments_outlined,
                              size: 16, color: AppColors.inkFaint),
                          const SizedBox(width: 4),
                          Text(q.budget,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.parade)),
                        ]),
                        const SizedBox(height: 8),
                        Text(q.note,
                            style: Theme.of(context).textTheme.bodyLarge),
                        const SizedBox(height: 12),
                        _actionsFor(q),
                      ],
                    ),
                  ),
                ),
              )),

        const SizedBox(height: 12),
        SectionHeader(
          eyebrow: 'Online consultations',
          title: 'Meeting requests',
          trailing: Text('${meetings.length} total',
              style: Theme.of(context).textTheme.labelSmall),
        ),
        const SizedBox(height: 12),

        if (meetings.isEmpty)
          const EmptyState(
            icon: Icons.video_call_outlined,
            title: 'No meeting requests',
            message: 'Resident meeting requests will appear here.',
          )
        else
          ...meetings.map((meeting) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                              child: Text(meeting.residentName,
                                  style:
                                      Theme.of(context).textTheme.titleMedium)),
                          StatusPill(
                              label: meeting.status.label,
                              color: _meetingColor(meeting.status)),
                        ]),
                        const SizedBox(height: 6),
                        Text(meeting.subject,
                            style: Theme.of(context).textTheme.bodyLarge),
                        const SizedBox(height: 10),
                        Row(children: [
                          const Icon(Icons.place_outlined,
                              size: 16, color: AppColors.inkFaint),
                          const SizedBox(width: 4),
                          Expanded(
                              child: Text(meeting.plotReference,
                                  style:
                                      Theme.of(context).textTheme.bodyMedium)),
                        ]),
                        const SizedBox(height: 6),
                        Row(children: [
                          const Icon(Icons.schedule_outlined,
                              size: 16, color: AppColors.inkFaint),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${meeting.scheduledFor.day}/${meeting.scheduledFor.month}/${meeting.scheduledFor.year}'
                              ' · ${TimeOfDay.fromDateTime(meeting.scheduledFor).format(context)}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ]),
                        const SizedBox(height: 6),
                        Row(children: [
                          Icon(
                            meeting.meetingType == MeetingType.online && meeting.meetingLink.isEmpty
                                ? Icons.hourglass_top_outlined
                                : Icons.videocam_outlined,
                            size: 16,
                            color: AppColors.inkFaint,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                              child: Text(
                                  meeting.meetingType == MeetingType.online
                                      ? (meeting.meetingLink.isEmpty
                                          ? '${meeting.platform?.label ?? 'Online'} · paste your link when you confirm'
                                          : '${meeting.platform?.label ?? 'Online'} · ${meeting.meetingLink}')
                                      : 'In-person · ${meeting.venue}',
                                  style:
                                      Theme.of(context).textTheme.bodyMedium)),
                        ]),
                        if (meeting.note.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(meeting.note,
                              style: Theme.of(context).textTheme.bodyLarge),
                        ],
                        const SizedBox(height: 12),
                        _meetingActionsFor(meeting),
                      ],
                    ),
                  ),
                ),
              )),
      ],
    ));
  }

  Widget _actionsFor(QuoteRequest q) {
    switch (q.status) {
      case RequestStatus.pending:
        return Row(children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brick,
                  side: const BorderSide(color: AppColors.brick)),
              onPressed: () => _setStatus(q, RequestStatus.declined),
              child: const Text('Decline'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () => _setStatus(q, RequestStatus.accepted),
              child: const Text('Send quote'),
            ),
          ),
        ]);
      case RequestStatus.accepted:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _setStatus(q, RequestStatus.completed),
            child: const Text('Mark as completed'),
          ),
        );
      case RequestStatus.completed:
      case RequestStatus.declined:
        return const SizedBox.shrink();
    }
  }

  Widget _meetingActionsFor(DeveloperMeeting meeting) {
    switch (meeting.status) {
      case MeetingStatus.pending:
        return Row(children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brick,
                  side: const BorderSide(color: AppColors.brick)),
              onPressed: () =>
                  _setMeetingStatus(meeting, MeetingStatus.cancelled),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () async {
                if (meeting.meetingType == MeetingType.online && meeting.meetingLink.isEmpty) {
                  final link = await _promptForMeetingLink(meeting);
                  if (link == null) return; // developer cancelled
                  _setMeetingStatus(meeting, MeetingStatus.confirmed, meetingLink: link);
                } else {
                  _setMeetingStatus(meeting, MeetingStatus.confirmed);
                }
              },
              child: const Text('Confirm'),
            ),
          ),
        ]);
      case MeetingStatus.confirmed:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () =>
                _setMeetingStatus(meeting, MeetingStatus.completed),
            child: const Text('Mark as completed'),
          ),
        );
      case MeetingStatus.completed:
      case MeetingStatus.cancelled:
        return const SizedBox.shrink();
    }
  }

  Widget _filterChip(String label, RequestStatus? status) {
    final selected = _filter == status;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filter = status),
        labelStyle: TextStyle(
            color: selected ? Colors.white : AppColors.ink,
            fontWeight: FontWeight.w600,
            fontSize: 12.5),
      ),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    return '${diff.inMinutes}m ago';
  }
}

// ── Tab 2: Plot Archive ───────────────────────────────────────────────────────

class _PlotArchiveTab extends StatefulWidget {
  const _PlotArchiveTab();

  @override
  State<_PlotArchiveTab> createState() => _PlotArchiveTabState();
}

class _PlotArchiveTabState extends State<_PlotArchiveTab> {
  PlotConstructionStatus? _statusFilter;
  int? _sectorFilter;

  List<PlotArchiveEntry> get _filtered {
    return MockData.effectivePlotArchive.where((e) {
      if (_statusFilter != null && e.constructionStatus != _statusFilter) return false;
      if (_sectorFilter != null && e.sectorNumber != _sectorFilter) return false;
      return true;
    }).toList()
      ..sort((a, b) {
        // Sort: underConstruction first, then notStarted, then completed
        int order(PlotConstructionStatus s) => switch (s) {
              PlotConstructionStatus.underConstruction => 0,
              PlotConstructionStatus.notStarted => 1,
              PlotConstructionStatus.completed => 2,
            };
        final cmp = order(a.constructionStatus).compareTo(order(b.constructionStatus));
        if (cmp != 0) return cmp;
        return a.sectorNumber.compareTo(b.sectorNumber);
      });
  }

  Color _statusChipColor(PlotConstructionStatus s) => switch (s) {
        PlotConstructionStatus.underConstruction => AppColors.brass,
        PlotConstructionStatus.notStarted => AppColors.inkFaint,
        PlotConstructionStatus.completed => AppColors.parade,
      };

  IconData _statusIcon(PlotConstructionStatus s) => switch (s) {
        PlotConstructionStatus.underConstruction => Icons.construction_outlined,
        PlotConstructionStatus.notStarted => Icons.hourglass_empty_outlined,
        PlotConstructionStatus.completed => Icons.check_circle_outline,
      };

  // Summary counts
  int _count(PlotConstructionStatus s) =>
      MockData.effectivePlotArchive.where((e) => e.constructionStatus == s).length;

  @override
  Widget build(BuildContext context) {
    final entries = _filtered;
    final underConstCount = _count(PlotConstructionStatus.underConstruction);
    final notStartedCount = _count(PlotConstructionStatus.notStarted);
    final completedCount = _count(PlotConstructionStatus.completed);

    // Unique sectors for filter
    final sectors = MockData.effectivePlotArchive
        .map((e) => e.sectorNumber)
        .toSet()
        .toList()
      ..sort();

    return Column(
      children: [
        // ── Summary bar ──────────────────────────────────────────────
        Container(
          color: AppColors.parade,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              _SummaryPill(
                icon: Icons.construction_outlined,
                label: 'Under construction',
                count: underConstCount,
                color: AppColors.brass,
              ),
              const SizedBox(width: 10),
              _SummaryPill(
                icon: Icons.hourglass_empty_outlined,
                label: 'Not started',
                count: notStartedCount,
                color: Colors.white.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 10),
              _SummaryPill(
                icon: Icons.check_circle_outline,
                label: 'Completed',
                count: completedCount,
                color: AppColors.lake,
              ),
            ],
          ),
        ),

        // ── Filters ──────────────────────────────────────────────────
        Container(
          color: AppColors.paper,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status filter
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _archiveFilterChip('All statuses', null, isStatus: true),
                    _archiveFilterChip('Under construction',
                        PlotConstructionStatus.underConstruction,
                        isStatus: true),
                    _archiveFilterChip(
                        'Not started', PlotConstructionStatus.notStarted,
                        isStatus: true),
                    _archiveFilterChip(
                        'Completed', PlotConstructionStatus.completed,
                        isStatus: true),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              // Sector filter
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _archiveFilterChip('All sectors', null, isStatus: false),
                    ...sectors.map((s) =>
                        _archiveFilterChip('Sector $s', s, isStatus: false)),
                  ],
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // ── Table header ─────────────────────────────────────────────
        Container(
          color: AppColors.parade.withValues(alpha: 0.08),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              _headerCell('Plot', flex: 2),
              _headerCell('Sector', flex: 1),
              _headerCell('Status', flex: 3),
              _headerCell('Developer', flex: 3),
              _headerCell('Owner', flex: 3),
            ],
          ),
        ),
        const Divider(height: 1),

        // ── Table rows ───────────────────────────────────────────────
        Expanded(
          child: entries.isEmpty
              ? const EmptyState(
                  icon: Icons.table_chart_outlined,
                  title: 'No entries match',
                  message: 'Try clearing the filters.',
                )
              : ListView.separated(
                  itemCount: entries.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 12, endIndent: 12),
                  itemBuilder: (ctx, i) => _ArchiveRow(entry: entries[i],
                      statusColor: _statusChipColor(entries[i].constructionStatus),
                      statusIcon: _statusIcon(entries[i].constructionStatus)),
                ),
        ),

        // ── Footer note ──────────────────────────────────────────────
        Container(
          color: AppColors.paper,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 14, color: AppColors.inkFaint),
              const SizedBox(width: 6),
              Text(
                '${MockData.effectivePlotArchive.length} plots total · Updated as owners register',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.inkFaint),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _headerCell(String text, {required int flex}) => Expanded(
        flex: flex,
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.parade,
            letterSpacing: 0.6,
          ),
        ),
      );

  Widget _archiveFilterChip(String label, dynamic value, {required bool isStatus}) {
    final selected = isStatus ? _statusFilter == value : _sectorFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        visualDensity: VisualDensity.compact,
        onSelected: (_) => setState(() {
          if (isStatus) {
            _statusFilter = selected ? null : value;
          } else {
            _sectorFilter = selected ? null : value;
          }
        }),
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppColors.ink,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

// ── Archive row widget ────────────────────────────────────────────────────────

class _ArchiveRow extends StatelessWidget {
  final PlotArchiveEntry entry;
  final Color statusColor;
  final IconData statusIcon;

  const _ArchiveRow({
    required this.entry,
    required this.statusColor,
    required this.statusIcon,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showDetail(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Plot number
            Expanded(
              flex: 2,
              child: Text(
                entry.plotNumber,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
            // Sector
            Expanded(
              flex: 1,
              child: Text('${entry.sectorNumber}',
                  style: const TextStyle(fontSize: 13)),
            ),
            // Status badge
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Icon(statusIcon, size: 14, color: statusColor),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      entry.constructionStatus.label,
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: statusColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // Developer
            Expanded(
              flex: 3,
              child: Text(
                entry.developerCompany ?? '—',
                style: TextStyle(
                    fontSize: 12,
                    color: entry.developerCompany != null
                        ? AppColors.ink
                        : AppColors.inkFaint),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Owner
            Expanded(
              flex: 3,
              child: Text(
                entry.ownerName,
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadii.lg))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Plot ${entry.plotNumber}',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _detailRow(context, Icons.grid_view_outlined,
                'Sector', 'Sector ${entry.sectorNumber}'),
            _detailRow(context, Icons.construction_outlined,
                'Construction status', entry.constructionStatus.label),
            _detailRow(context, Icons.engineering_outlined,
                'Developer', entry.developerCompany ?? 'Not assigned'),
            _detailRow(context, Icons.person_outline,
                'Plot owner', entry.ownerName),
            _detailRow(context, Icons.update_outlined,
                'Last updated', entry.lastUpdated),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(
      BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.parade),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: AppColors.parade)),
                const SizedBox(height: 2),
                Text(value,
                    style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Summary pill ─────────────────────────────────────────────────────────────

class _SummaryPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;

  const _SummaryPill({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Text(
                '$count',
                style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w800),
              ),
            ]),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(color: Colors.white54, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

// ── Tab 3: Construction Lifecycle Management ──────────────────────────────────

class _ConstructionTab extends StatelessWidget {
  const _ConstructionTab();

  @override
  Widget build(BuildContext context) {
    return const ConstructionBody(
      viewerRole: UserRole.developer,
    );
  }
}
