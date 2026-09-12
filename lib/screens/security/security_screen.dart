import 'package:flutter/material.dart';
import '../../data/mock_data.dart';
import '../../models/app_models.dart';
import '../../services/api_client.dart';
import '../../services/api_config.dart';
import '../../services/backend_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

/// Jolshiri Abashon sector centres — used so a resident's sector selection on
/// the SOS/incident forms carries real coordinates through to the backend,
/// which is what lets GET /security-reports/heatmap plot them on the admin
/// map instead of falling back to static mock clusters.
const Map<String, (double, double)> _jolshiriSectors = {
  'Sector 1': (23.8136, 90.4986),
  'Sector 2': (23.8125, 90.5012),
  'Sector 3': (23.8108, 90.5035),
  'Sector 4': (23.8095, 90.5005),
  'Sector 5': (23.8102, 90.4970),
  'Sector 6': (23.8120, 90.4950),
  'Sector 7': (23.8118, 90.4965),
};

class _SecurityScreenState extends State<SecurityScreen> {
  bool _loading = false;
  // Remembers the resident's last-selected sector so the SOS button (which
  // has no form of its own) can still attach a location.
  String? _lastSector;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final reports = await BackendRepository.fetchSecurityReports();
      if (mounted && reports.isNotEmpty) {
        setState(() { MockData.securityReports..clear()..addAll(reports); });
      }
    } on ApiException catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _confirmSOS(BuildContext context) {
    String? sector = _lastSector;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
          title: const Text('Send SOS alert?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('This will immediately notify Jolshiri security control room and share your location.'),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: sector,
                decoration: const InputDecoration(labelText: 'Your sector (helps locate you)'),
                items: _jolshiriSectors.keys
                    .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                    .toList(),
                onChanged: (v) => setDialogState(() => sector = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.brick),
              onPressed: () async {
                Navigator.pop(dialogContext);
                _lastSector = sector;
                final coords = sector != null ? _jolshiriSectors[sector] : null;

                if (!AuthSession.isLoggedIn) {
                  showActionSnackBar(context, 'Please sign in to send an SOS alert');
                  return;
                }

                try {
                  final saved = await runWithLoadingOverlay(
                    context,
                    () => BackendRepository.sendSOS(
                      block: sector,
                      latitude: coords?.$1,
                      longitude: coords?.$2,
                    ),
                    message: 'Sending SOS…',
                  );
                  if (!mounted) return;
                  setState(() {
                    MockData.securityReports.insert(
                      0,
                      SecurityReport(
                        title: saved.title,
                        description: saved.description,
                        status: saved.status,
                        reportedAt: saved.reportedAt,
                        block: saved.block,
                      ),
                    );
                  });
                  showActionSnackBar(context, 'SOS sent — security team has been notified');
                } on ApiException catch (e) {
                  if (mounted) showActionSnackBar(context, 'SOS failed: ${e.message}');
                } on ApiUnreachableException {
                  if (mounted) {
                    showActionSnackBar(context, 'Could not reach the server — SOS was NOT sent. Please call security directly.');
                  }
                }
              },
              child: const Text('Send SOS'),
            ),
          ],
        ),
      ),
    );
  }

  void _reportIncident(BuildContext context) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String? sector = _lastSector;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Report an incident', style: Theme.of(sheetContext).textTheme.headlineSmall),
            const SizedBox(height: 16),
            TextField(controller: titleController, decoration: const InputDecoration(hintText: 'Short title, e.g. Suspicious activity')),
            const SizedBox(height: 12),
            TextField(controller: descController, maxLines: 3, decoration: const InputDecoration(hintText: 'Describe what happened, where, and when')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: sector,
              decoration: const InputDecoration(labelText: 'Sector (helps place this on the security heatmap)'),
              items: _jolshiriSectors.keys
                  .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                  .toList(),
              onChanged: (v) => setSheetState(() => sector = v),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final title = titleController.text.trim();
                  final description = descController.text.trim();
                  if (title.isEmpty || description.isEmpty) {
                    showActionSnackBar(sheetContext, 'Please fill in both fields');
                    return;
                  }
                  _lastSector = sector;
                  final coords = sector != null ? _jolshiriSectors[sector] : null;

                  // POST /api/security-reports — real backend call when
                  // signed in; falls back to a local mock insert if the
                  // backend is unreachable.
                  if (AuthSession.isLoggedIn) {
                    try {
                      final saved = await runWithLoadingOverlay(
                        sheetContext,
                        () => BackendRepository.createSecurityReport(
                          title: title,
                          description: description,
                          block: sector,
                          latitude: coords?.$1,
                          longitude: coords?.$2,
                        ),
                        message: 'Submitting your report…',
                      );
                      setState(() {
                        MockData.securityReports.insert(
                          0,
                          SecurityReport(
                            title: saved.title,
                            description: saved.description,
                            status: saved.status,
                            reportedAt: saved.reportedAt,
                            block: saved.block,
                          ),
                        );
                      });
                      if (!sheetContext.mounted) return;
                      Navigator.pop(sheetContext);
                      showActionSnackBar(context, 'Incident report submitted');
                      return;
                    } on ApiException catch (e) {
                      if (!sheetContext.mounted) return;
                      showActionSnackBar(sheetContext, e.message);
                      return;
                    } on ApiUnreachableException {
                      // fall through to the offline demo flow below
                    }
                  }

                  setState(() {
                    MockData.securityReports.insert(
                      0,
                      SecurityReport(
                        title: title,
                        description: description,
                        status: 'Open',
                        reportedAt: DateTime.now(),
                        block: sector,
                      ),
                    );
                  });
                  if (!sheetContext.mounted) return;
                  Navigator.pop(sheetContext);
                  showActionSnackBar(context, 'Incident report submitted');
                },
                child: const Text('Submit report'),
              ),
            ),
          ],
        ),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Security')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.brick.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(color: AppColors.brick.withValues(alpha: 0.25)),
            ),
            child: Column(
              children: [
                Text('EMERGENCY', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.brick)),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => _confirmSOS(context),
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: AppColors.brick,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: AppColors.brick.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 2)],
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sos_rounded, color: Colors.white, size: 32),
                        SizedBox(height: 4),
                        Text('SOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 1)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Tap to alert the Jolshiri security control room', style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _reportIncident(context),
              icon: const Icon(Icons.report_gmailerrorred_outlined),
              label: const Text('Report an incident'),
            ),
          ),
          const SizedBox(height: 28),
          const SectionHeader(eyebrow: 'Recent activity', title: 'Reports & alerts'),
          const SizedBox(height: 12),
          ...MockData.securityReports.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(child: Text(r.title, style: Theme.of(context).textTheme.titleMedium)),
                          StatusPill.status(r.status),
                        ]),
                        const SizedBox(height: 6),
                        Text(r.description, style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(_relativeTime(r.reportedAt), style: Theme.of(context).textTheme.labelSmall),
                            if (r.block != null) ...[
                              const SizedBox(width: 8),
                              Text('· ${r.block}', style: Theme.of(context).textTheme.labelSmall),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              )),
        ],
      )),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    return '${diff.inMinutes}m ago';
  }
}

