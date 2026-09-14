import 'package:flutter/material.dart';
import '../../data/mock_data.dart';
import '../../models/app_models.dart';
import '../../services/api_client.dart';
import '../../services/api_config.dart';
import '../../services/backend_repository.dart';
import '../../widgets/common.dart';
import 'flat_view_requests_screen.dart';

/// Property: browse verified developers and request a construction quote.
/// (The old Buy/Sell Plot marketplace has been removed — this screen now
/// only covers the Developers directory.)
/// Backed by GET /api/developers — see lib/services/backend_repository.dart.
class PropertyScreen extends StatefulWidget {
  const PropertyScreen({super.key});

  @override
  State<PropertyScreen> createState() => _PropertyScreenState();
}

class _PropertyScreenState extends State<PropertyScreen> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  // GET /api/developers — was never called here, so this screen only ever
  // showed whatever MockData.developers happened to hold from the
  // app-launch sync (see sync_service.dart). Unlike the sibling Services
  // screen (services_screen.dart), it had no fetch-on-open and no
  // pull-to-refresh, so a newly-verified or newly-updated developer
  // wouldn't show up here until the next app restart.
  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final developers = await BackendRepository.fetchDevelopers();
      if (mounted && developers.isNotEmpty) {
        setState(() { MockData.developers..clear()..addAll(developers); });
      }
    } on ApiException catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _requestQuote(Developer d) async {
    final quote = await showModalBottomSheet<QuoteRequest>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _EnquiryFormSheet(
        title: 'Request a quote from ${d.companyName}',
        projectTypeLabel: 'Project type',
        projectTypeInitial: '',
        projectTypeHint: 'e.g. New construction, boundary wall, renovation',
        plotLocationInitial: '',
        plotLocationHint: 'e.g. Plot 7-142, Sector 7',
        budgetInitial: '',
        budgetHint: 'e.g. ৳ 20,00,000',
        noteHint: 'Describe the work you need done…',
        submitLabel: 'Send request',
      ),
    );
    if (quote == null || !mounted) return;

    // POST /api/quotes — real backend call when the developer has a real
    // id (fetched from the backend) and the user is signed in; otherwise
    // fall back to the local mock insert so the demo still works offline.
    if (d.id != null && AuthSession.isLoggedIn) {
      try {
        final saved = await runWithLoadingOverlay(
          context,
          () => BackendRepository.createQuote(
            developerId: d.id!,
            projectType: quote.projectType,
            plotLocation: quote.plotLocation,
            budget: quote.budget,
            note: quote.note,
          ),
          message: 'Sending your request…',
        );
        if (!mounted) return;
        // Use the backend-returned record (has a real id for future PATCH calls)
        setState(() => MockData.quoteRequests.insert(0, QuoteRequest(
              id: saved.id,
              customerName: MockData.currentUser.fullName,
              projectType: saved.projectType,
              plotLocation: saved.plotLocation,
              budget: saved.budget,
              note: saved.note,
              requestedAt: saved.requestedAt,
              status: saved.status,
            )));
        showActionSnackBar(context, 'Quote request sent to ${d.companyName}');
        return;
      } on ApiException catch (e) {
        if (!mounted) return;
        showActionSnackBar(context, e.message);
        return;
      } on ApiUnreachableException {
        // fall through to the offline demo flow below
      }
    }

    setState(() => MockData.quoteRequests.insert(0, quote));
    showActionSnackBar(context, 'Quote request sent to ${d.companyName}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Property'),
        actions: [
          IconButton(
            tooltip: 'Flat View Requests',
            icon: const Icon(Icons.forum_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FlatViewRequestsScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: _DevelopersTab(onRequestQuote: _requestQuote),
            ),
          ),
        ],
      ),
    );
  }
}

class _DevelopersTab extends StatelessWidget {
  final void Function(Developer) onRequestQuote;
  const _DevelopersTab({required this.onRequestQuote});

  @override
  Widget build(BuildContext context) {
    final developers = MockData.developers;
    if (developers.isEmpty) {
      return const EmptyState(
        icon: Icons.engineering_outlined,
        title: 'No developers listed',
        message: 'Verified developers will appear here soon.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: developers.length,
      itemBuilder: (context, i) {
        final Developer d = developers[i];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(d.companyName, style: Theme.of(context).textTheme.titleMedium)),
                    if (d.verified) const VerifiedBadge(),
                  ],
                ),
                const SizedBox(height: 6),
                Text(d.specialty, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 8),
                Row(
                  children: [
                    RatingRow(rating: d.rating),
                    const Spacer(),
                    Text(d.contact, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => onRequestQuote(d),
                    child: const Text('Request a quote'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 12),
    );
  }
}

/// Bottom sheet form used for "Request a quote" from a developer. Returns a
/// [QuoteRequest] via Navigator.pop when submitted, or null if dismissed.
class _EnquiryFormSheet extends StatefulWidget {
  final String title;
  final String projectTypeLabel;
  final String projectTypeInitial;
  final String? projectTypeHint;
  final String plotLocationInitial;
  final String? plotLocationHint;
  final String budgetInitial;
  final String? budgetHint;
  final String noteHint;
  final String submitLabel;

  const _EnquiryFormSheet({
    required this.title,
    required this.projectTypeLabel,
    required this.projectTypeInitial,
    this.projectTypeHint,
    required this.plotLocationInitial,
    this.plotLocationHint,
    required this.budgetInitial,
    this.budgetHint,
    required this.noteHint,
    required this.submitLabel,
  });

  @override
  State<_EnquiryFormSheet> createState() => _EnquiryFormSheetState();
}

class _EnquiryFormSheetState extends State<_EnquiryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _projectType = TextEditingController();
  final _plotLocation = TextEditingController();
  final _budget = TextEditingController();
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    _projectType.text = widget.projectTypeInitial;
    _plotLocation.text = widget.plotLocationInitial;
    _budget.text = widget.budgetInitial;
  }

  @override
  void dispose() {
    _projectType.dispose();
    _plotLocation.dispose();
    _budget.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final budget = _budget.text.trim();
    Navigator.pop(
      context,
      QuoteRequest(
        customerName: MockData.currentUser.fullName,
        projectType: _projectType.text.trim(),
        plotLocation: _plotLocation.text.trim(),
        budget: budget.isEmpty ? 'Not specified' : (budget.startsWith('৳') ? budget : '৳ $budget'),
        note: _note.text.trim(),
        requestedAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'Sent as ${MockData.currentUser.fullName} · ${MockData.currentUser.phone}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _projectType,
                decoration: InputDecoration(labelText: widget.projectTypeLabel, hintText: widget.projectTypeHint),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter this field' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _plotLocation,
                decoration: InputDecoration(labelText: 'Plot / location reference', hintText: widget.plotLocationHint),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a plot or location' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _budget,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Budget (optional)', hintText: widget.budgetHint),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _note,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Message',
                  hintText: widget.noteHint,
                  alignLabelWithHint: true,
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Add a short message' : null,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(onPressed: _submit, child: Text(widget.submitLabel)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
