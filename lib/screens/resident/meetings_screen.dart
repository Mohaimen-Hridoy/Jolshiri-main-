import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/mock_data.dart';
import '../../models/app_models.dart';
import '../../services/api_client.dart';
import '../../services/api_config.dart';
import '../../services/backend_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class MeetingsScreen extends StatefulWidget {
  const MeetingsScreen({super.key});

  @override
  State<MeetingsScreen> createState() => _MeetingsScreenState();
}

class _MeetingsScreenState extends State<MeetingsScreen> {
  String? _developerName;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final meetings = await BackendRepository.fetchMyMeetings();
      final quotes = await BackendRepository.fetchMyQuotes();
      if (mounted) {
        setState(() {
        if (meetings.isNotEmpty) { MockData.developerMeetings..clear()..addAll(meetings); }
        if (quotes.isNotEmpty) { MockData.quoteRequests..clear()..addAll(quotes); }
        // Set default developer name once developers list is confirmed non-empty
        if (_developerName == null && MockData.developers.isNotEmpty) {
          _developerName = MockData.developers.first.companyName;
        }
      });
      }
    } on ApiException catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<DeveloperMeeting> get _meetings {
    final meetings = MockData.developerMeetings
        .where((m) => m.residentName == MockData.currentUser.fullName)
        .toList()
      ..sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));
    return meetings;
  }

  Developer? get _developer => MockData.developers.isEmpty ? null : MockData.developers
      .firstWhere((d) => d.companyName == _developerName, orElse: () => MockData.developers.first);

  @override
  Widget build(BuildContext context) {
    final meetings = _meetings;
    final pendingCount =
        meetings.where((m) => m.status == MeetingStatus.pending).length;
    final onlineCount =
        meetings.where((m) => m.meetingType == MeetingType.online).length;
    final offlineCount =
        meetings.where((m) => m.meetingType == MeetingType.offline).length;
    final developer = _developer;

    return Scaffold(
      appBar: AppBar(title: const Text('Developer Meetings')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          // ── Banner ─────────────────────────────────────────────────
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
                      Text('MEETINGS',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: AppColors.brass)),
                      const SizedBox(height: 6),
                      Text(
                        '${meetings.length} total · $onlineCount online · $offlineCount offline',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'serif'),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        pendingCount == 0
                            ? 'Track confirmed sessions here.'
                            : '$pendingCount awaiting developer confirmation.',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.calendar_month_outlined,
                    color: AppColors.brass, size: 36),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Schedule new meeting card ────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Schedule a new meeting',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _developerName,
                    decoration: const InputDecoration(
                      labelText: 'Developer / real-estate company',
                      prefixIcon: Icon(Icons.apartment_outlined),
                    ),
                    items: MockData.developers
                        .map((d) => DropdownMenuItem<String>(
                              value: d.companyName,
                              child: Text(d.companyName,
                                  overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _developerName = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  if (developer != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(developer.specialty,
                            style: Theme.of(context).textTheme.bodyMedium),
                      ),
                      RatingRow(rating: developer.rating),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Two buttons: Online + Offline
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _openMeetingSheet(developer, MeetingType.offline),
                          icon: const Icon(Icons.handshake_outlined, size: 18),
                          label: const Text('In-person'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _openMeetingSheet(developer, MeetingType.online),
                          icon: const Icon(Icons.videocam_outlined, size: 18),
                          label: const Text('Online'),
                        ),
                      ),
                    ],
                  ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Timeline ────────────────────────────────────────────
          const SectionHeader(
            eyebrow: 'Your sessions',
            title: 'Meeting timeline',
          ),
          const SizedBox(height: 12),

          if (meetings.isEmpty)
            const EmptyState(
              icon: Icons.calendar_month_outlined,
              title: 'No meetings booked',
              message:
                  'Schedule online (Zoom / Google Meet) or in-person sessions with developers.',
            )
          else
            ...meetings.map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _MeetingCard(meeting: m),
                )),
        ],
      )),
    );
  }

  // ── Book meeting bottom sheet ──────────────────────────────────────
  Future<void> _openMeetingSheet(
      Developer developer, MeetingType initialType) async {
    final subjectController = TextEditingController();
    final plotController =
        TextEditingController(text: 'Plot 7-142, Sector 7, Lake View');
    final noteController = TextEditingController();
    final venueController = TextEditingController();

    var meetingType = initialType;
    var platform = MeetingPlatform.googleMeet;
    DateTime? selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 10, minute: 0);
    var submitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadii.lg))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            Future<void> pickDate() async {
              final date = await showDatePicker(
                context: ctx,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 90)),
                initialDate: selectedDate ?? DateTime.now(),
              );
              if (date != null) setModal(() => selectedDate = date);
            }

            Future<void> pickTime() async {
              final time = await showTimePicker(
                  context: ctx, initialTime: selectedTime);
              if (time != null) setModal(() => selectedTime = time);
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 12, 16,
                  MediaQuery.of(ctx).viewInsets.bottom + 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Book with ${developer.companyName}',
                        style:
                            Theme.of(ctx).textTheme.headlineSmall),
                    const SizedBox(height: 16),

                    // ── Meeting type dropdown ─────────────────────
                    DropdownButtonFormField<MeetingType>(
                      initialValue: meetingType,
                      decoration: const InputDecoration(
                        labelText: 'Meeting type',
                        prefixIcon: Icon(Icons.swap_horiz_outlined),
                      ),
                      items: MeetingType.values
                          .map((t) => DropdownMenuItem(
                                value: t,
                                child: Row(
                                  children: [
                                    Icon(
                                      t == MeetingType.online
                                          ? Icons.videocam_outlined
                                          : Icons.handshake_outlined,
                                      size: 18,
                                      color: AppColors.parade,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(t.label),
                                  ],
                                ),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setModal(() => meetingType = v);
                      },
                    ),
                    const SizedBox(height: 12),

                    // ── Online-only: platform ─────────────────────
                    if (meetingType == MeetingType.online) ...[
                      DropdownButtonFormField<MeetingPlatform>(
                        initialValue: platform,
                        decoration: const InputDecoration(
                          labelText: 'Platform',
                          prefixIcon: Icon(Icons.link_outlined),
                        ),
                        items: MeetingPlatform.values
                            .map((p) => DropdownMenuItem(
                                  value: p,
                                  child: Text(p.label),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setModal(() => platform = v);
                        },
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'The developer will share the actual ${platform.label} join link once they confirm.',
                        style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: AppColors.inkFaint),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // ── Offline-only: venue ───────────────────────
                    if (meetingType == MeetingType.offline) ...[
                      TextField(
                        controller: venueController,
                        decoration: const InputDecoration(
                          labelText: 'Venue / address',
                          hintText:
                              'e.g. Jolshiri Project Office, Sector 3',
                          prefixIcon: Icon(Icons.place_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // ── Common fields ─────────────────────────────
                    TextField(
                      controller: subjectController,
                      decoration: const InputDecoration(
                        labelText: 'Meeting subject',
                        hintText:
                            'Design consultation / agreement discussion',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: plotController,
                      decoration: const InputDecoration(
                        labelText: 'Plot / property reference',
                        prefixIcon: Icon(Icons.home_work_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Date + time pickers
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: pickDate,
                            icon: const Icon(
                                Icons.calendar_today_outlined, size: 16),
                            label: Text(selectedDate == null
                                ? 'Pick date'
                                : _dateLabel(selectedDate!)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: pickTime,
                            icon: const Icon(
                                Icons.schedule_outlined, size: 16),
                            label: Text(selectedTime.format(ctx)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Notes for developer',
                        hintText:
                            'Budget, design preference, or discussion points.',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 18),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: Icon(
                          meetingType == MeetingType.online
                              ? Icons.videocam_outlined
                              : Icons.handshake_outlined,
                          size: 18,
                        ),
                        label: submitButtonChild(
                          submitting,
                          meetingType == MeetingType.online
                              ? 'Send online meeting request'
                              : 'Send in-person meeting request',
                        ),
                        onPressed: submitting ? null : () {
                          if (subjectController.text.trim().isEmpty ||
                              plotController.text.trim().isEmpty ||
                              selectedDate == null) {
                            showActionSnackBar(
                                ctx, 'Please fill in meeting details');
                            return;
                          }
                          if (meetingType == MeetingType.offline &&
                              venueController.text.trim().isEmpty) {
                            showActionSnackBar(ctx, 'Please enter a venue');
                            return;
                          }
                          final scheduledFor = DateTime(
                            selectedDate!.year,
                            selectedDate!.month,
                            selectedDate!.day,
                            selectedTime.hour,
                            selectedTime.minute,
                          );
                          setModal(() => submitting = true);
                          () async {
                            final localMeeting = DeveloperMeeting(
                              developerName: developer.companyName,
                              residentName: MockData.currentUser.fullName,
                              subject: subjectController.text.trim(),
                              plotReference: plotController.text.trim(),
                              meetingType: meetingType,
                              platform: meetingType == MeetingType.online
                                  ? platform
                                  : null,
                              // Not generated here — the developer pastes
                              // their own Zoom/Meet link when they confirm.
                              meetingLink: '',
                              venue: meetingType == MeetingType.offline
                                  ? venueController.text.trim()
                                  : '',
                              scheduledFor: scheduledFor,
                              note: noteController.text.trim(),
                            );

                            // POST /api/meetings — real backend call when the
                            // developer has a real id and the user is signed
                            // in; otherwise fall back to the local mock
                            // insert so the demo still works offline.
                            if (developer.id != null && AuthSession.isLoggedIn) {
                              try {
                                final saved = await BackendRepository.createMeeting(
                                  developerId: developer.id!,
                                  developerName: developer.companyName,
                                  subject: localMeeting.subject,
                                  plotReference: localMeeting.plotReference,
                                  meetingType: meetingType,
                                  platform: meetingType == MeetingType.online ? platform : null,
                                  location: meetingType == MeetingType.offline
                                      ? venueController.text.trim()
                                      : null,
                                  scheduledFor: scheduledFor,
                                  note: localMeeting.note,
                                );
                                setState(() {
                                  MockData.developerMeetings.insert(
                                    0,
                                    DeveloperMeeting(
                                      developerName: developer.companyName,
                                      residentName: MockData.currentUser.fullName,
                                      subject: saved.subject,
                                      plotReference: saved.plotReference,
                                      meetingType: saved.meetingType,
                                      platform: saved.platform,
                                      meetingLink: saved.meetingLink,
                                      venue: saved.venue,
                                      scheduledFor: saved.scheduledFor,
                                      note: saved.note,
                                      status: saved.status,
                                    ),
                                  );
                                });
                              } on ApiException catch (e) {
                                setModal(() => submitting = false);
                                if (!ctx.mounted) return;
                                Navigator.of(ctx).pop();
                                showActionSnackBar(context, e.message);
                                return;
                              } on ApiUnreachableException {
                                setState(() {
                                  MockData.developerMeetings.insert(0, localMeeting);
                                });
                              }
                            } else {
                              setState(() {
                                MockData.developerMeetings.insert(0, localMeeting);
                              });
                            }

                            if (!ctx.mounted) return;
                            Navigator.of(ctx).pop();
                            showActionSnackBar(
                              // ignore: use_build_context_synchronously
                              context,
                              meetingType == MeetingType.online
                                  ? 'Online meeting request sent'
                                  : 'In-person meeting request sent',
                            );
                          }();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    subjectController.dispose();
    plotController.dispose();
    noteController.dispose();
    venueController.dispose();
  }

  String _dateLabel(DateTime d) {
    const m = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${d.day} ${m[d.month - 1]}';
  }
}

// ── Meeting card ──────────────────────────────────────────────────────────────

class _MeetingCard extends StatelessWidget {
  final DeveloperMeeting meeting;
  const _MeetingCard({required this.meeting});

  bool get _isOnline => meeting.meetingType == MeetingType.online;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                // Meeting type badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _isOnline
                        ? AppColors.lake.withValues(alpha: 0.12)
                        : AppColors.brass.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isOnline
                            ? Icons.videocam_outlined
                            : Icons.handshake_outlined,
                        size: 13,
                        color: _isOnline ? AppColors.lake : AppColors.brass,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isOnline ? 'Online' : 'In-person',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _isOnline ? AppColors.lake : AppColors.brass,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(meeting.developerName,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                StatusPill(
                    label: meeting.status.label,
                    color: _statusColor(meeting.status)),
              ],
            ),
            const SizedBox(height: 8),
            Text(meeting.subject,
                style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 10),

            _InfoRow(Icons.home_work_outlined, meeting.plotReference),
            const SizedBox(height: 6),
            _InfoRow(Icons.calendar_month_outlined,
                _dateTimeLabel(context, meeting.scheduledFor)),
            const SizedBox(height: 6),

            // Online: show platform + link (or a waiting note until the
            // developer pastes their own link in); Offline: show venue.
            if (_isOnline && meeting.platform != null && meeting.meetingLink.isNotEmpty)
              InkWell(
                onTap: () => _joinMeeting(context, meeting.meetingLink),
                child: _InfoRow(
                  Icons.videocam_outlined,
                  '${meeting.platform!.label} · ${meeting.meetingLink}',
                  color: AppColors.lake,
                ),
              )
            else if (_isOnline && meeting.platform != null)
              _InfoRow(
                Icons.hourglass_top_outlined,
                'Waiting for ${meeting.developerName} to share the ${meeting.platform!.label} link',
              )
            else if (!_isOnline && meeting.venue.isNotEmpty)
              _InfoRow(Icons.place_outlined, meeting.venue),

            if (meeting.note.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(meeting.note,
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(MeetingStatus s) => switch (s) {
        MeetingStatus.pending => AppColors.brass,
        MeetingStatus.confirmed => AppColors.lake,
        MeetingStatus.completed => AppColors.parade,
        MeetingStatus.cancelled => AppColors.brick,
      };

  String _dateTimeLabel(BuildContext ctx, DateTime dt) {
    final time = TimeOfDay.fromDateTime(dt).format(ctx);
    return '${dt.day}/${dt.month}/${dt.year} · $time';
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  const _InfoRow(this.icon, this.text, {this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color ?? AppColors.inkFaint),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// Opens the developer's pasted-in Zoom/Google Meet link.
Future<void> _joinMeeting(BuildContext context, String link) async {
  final uri = Uri.tryParse(link);
  if (uri == null) return;
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched && context.mounted) {
    showActionSnackBar(context, 'Could not open the meeting link');
  }
}
