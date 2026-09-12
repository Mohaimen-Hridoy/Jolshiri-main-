import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../../data/mock_data.dart';
import '../../models/app_models.dart';
import '../../services/api_client.dart';
import '../../services/api_config.dart';
import '../../services/backend_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Part 7: Complaint Register — a resident files a complaint against their
/// plot and tracks its status/progress here; Jolshiri Management reviews
/// and updates it from the admin dashboard.
class ComplaintsScreen extends StatefulWidget {
  const ComplaintsScreen({super.key});

  @override
  State<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends State<ComplaintsScreen> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (!AuthSession.isLoggedIn) return;
    setState(() => _loading = true);
    try {
      final complaints = await BackendRepository.fetchMyComplaints();
      if (mounted) {
        setState(() {
          MockData.complaints
            ..removeWhere((c) => c.id != null)
            ..insertAll(0, complaints);
        });
      }
    } on ApiException catch (_) {
      // keep existing local list
    } on ApiUnreachableException {
      // offline — keep mock seed data
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openNewComplaint(BuildContext context) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final plotController = TextEditingController(text: MockData.currentUser.address);
    String category = 'Maintenance';
    Uint8List? imageBytes;
    bool submitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('File a complaint', style: Theme.of(sheetContext).textTheme.headlineSmall),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. Streetlight not working'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: const [
                    DropdownMenuItem(value: 'Maintenance', child: Text('Maintenance')),
                    DropdownMenuItem(value: 'Utility', child: Text('Utility')),
                    DropdownMenuItem(value: 'Security', child: Text('Security')),
                    DropdownMenuItem(value: 'Noise', child: Text('Noise')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: (v) => setSheetState(() => category = v ?? 'Maintenance'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: plotController,
                  decoration: const InputDecoration(labelText: 'Plot reference'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description', hintText: 'Describe the issue, where, and since when'),
                ),
                const SizedBox(height: 12),
                ImagePickerField(
                  label: 'Photo (optional)',
                  onChanged: (b) => imageBytes = b,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: submitting
                        ? null
                        : () async {
                      final title = titleController.text.trim();
                      final description = descController.text.trim();
                      final plotReference = plotController.text.trim();
                      if (title.isEmpty || description.isEmpty || plotReference.isEmpty) {
                        showActionSnackBar(sheetContext, 'Please fill in all fields');
                        return;
                      }

                      setSheetState(() => submitting = true);

                      if (AuthSession.isLoggedIn) {
                        try {
                          final saved = await BackendRepository.createComplaint(
                            title: title,
                            category: category,
                            description: description,
                            plotReference: plotReference,
                            imageBytes: imageBytes,
                          );
                          setState(() => MockData.complaints.insert(0, saved));
                          if (!sheetContext.mounted) return;
                          Navigator.pop(sheetContext);
                          if (!context.mounted) return;
                          showActionSnackBar(context, 'Complaint submitted');
                          return;
                        } on ApiException catch (e) {
                          setSheetState(() => submitting = false);
                          if (!sheetContext.mounted) return;
                          showActionSnackBar(sheetContext, e.message);
                          return;
                        } on ApiUnreachableException {
                          // fall through to the offline demo flow below
                        }
                      }

                      setState(() {
                        MockData.complaints.insert(
                          0,
                          Complaint(
                            title: title,
                            category: category,
                            description: description,
                            plotReference: plotReference,
                            createdAt: DateTime.now(),
                            imageBytes: imageBytes,
                          ),
                        );
                      });
                      if (!sheetContext.mounted) return;
                      Navigator.pop(sheetContext);
                      if (!context.mounted) return;
                      showActionSnackBar(context, 'Complaint submitted');
                    },
                    child: submitButtonChild(submitting, 'Submit complaint'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openDetail(Complaint complaint) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => _ComplaintDetailScreen(complaint: complaint)));
  }

  Color _statusColor(ComplaintStatus status) => switch (status) {
        ComplaintStatus.submitted => AppColors.brass,
        ComplaintStatus.inProgress => AppColors.lake,
        ComplaintStatus.resolved => AppColors.parade,
      };

  @override
  Widget build(BuildContext context) {
    final complaints = List.of(MockData.complaints)..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      appBar: AppBar(title: const Text('Complaints')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openNewComplaint(context),
        icon: const Icon(Icons.add),
        label: const Text('File complaint'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            const SectionHeader(eyebrow: 'Track & resolve', title: 'Your complaints'),
            const SizedBox(height: 12),
            if (complaints.isEmpty)
              const EmptyState(
                icon: Icons.report_problem_outlined,
                title: 'No complaints filed',
                message: 'Maintenance, utility, or security issues you report will show up here.',
              )
            else
              ...complaints.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        onTap: () => _openDetail(c),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (c.imageUrl != null || c.imageBytes != null)
                              ListingImage(url: c.imageUrl ?? '', bytes: c.imageBytes, height: 140),
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(child: Text(c.title, style: Theme.of(context).textTheme.titleMedium)),
                                      StatusPill(label: c.status.label, color: _statusColor(c.status)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text('${c.category} · ${c.plotReference}', style: Theme.of(context).textTheme.bodyMedium),
                                  const SizedBox(height: 10),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: LinearProgressIndicator(
                                      value: c.progress / 100,
                                      minHeight: 6,
                                      backgroundColor: AppColors.paperDim,
                                      valueColor: AlwaysStoppedAnimation(_statusColor(c.status)),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(_relativeTime(c.createdAt), style: Theme.of(context).textTheme.labelSmall),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )),
          ],
        ),
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

class _ComplaintDetailScreen extends StatefulWidget {
  final Complaint complaint;
  const _ComplaintDetailScreen({required this.complaint});

  @override
  State<_ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends State<_ComplaintDetailScreen> {
  List<ComplaintUpdate> _updates = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadUpdates();
  }

  Future<void> _loadUpdates() async {
    final id = widget.complaint.id;
    if (id == null || !AuthSession.isLoggedIn) return;
    setState(() => _loading = true);
    try {
      final updates = await BackendRepository.fetchComplaintUpdates(id);
      if (mounted) setState(() => _updates = updates);
    } on ApiException catch (_) {
      // no timeline available; show just the summary card
    } on ApiUnreachableException {
      // offline
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.complaint;
    return Scaffold(
      appBar: AppBar(title: Text(c.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (c.imageUrl != null || c.imageBytes != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.md),
                child: ListingImage(url: c.imageUrl ?? '', bytes: c.imageBytes, height: 200),
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text(c.category, style: Theme.of(context).textTheme.labelSmall)),
                    StatusPill.status(c.status.label),
                  ]),
                  const SizedBox(height: 8),
                  Text(c.description, style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 10),
                  Text(c.plotReference, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeader(eyebrow: 'History', title: 'Timeline'),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: CircularProgressIndicator()))
          else if (_updates.isEmpty)
            const EmptyState(
              icon: Icons.timeline_outlined,
              title: 'No updates yet',
              message: 'Jolshiri Management will post progress updates here once they review your complaint.',
            )
          else
            ..._updates.map((u) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Icon(Icons.circle, size: 10, color: AppColors.brass),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(child: Text(u.status.label, style: Theme.of(context).textTheme.titleSmall)),
                              Text(_relativeTime(u.updatedAt), style: Theme.of(context).textTheme.labelSmall),
                            ]),
                            const SizedBox(height: 4),
                            Text(u.note, style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
        ],
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
