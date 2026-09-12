import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../data/mock_data.dart';
import '../../models/app_models.dart';
import '../../services/api_client.dart';
import '../../services/backend_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../resident/construction_lifecycle_screen.dart';

class JolshiriManagementDashboard extends StatelessWidget {
  const JolshiriManagementDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    // LayoutBuilder gives us the available height from the parent ListView so
    // the tab body adapts to the screen instead of overflowing or leaving a
    // large gap on tablets.  The fallback (infinite constraints) uses 62 % of
    // the screen height — keeps parity with the old hard-coded 600 px on a
    // typical 800-px-tall phone body, but scales correctly everywhere else.
    return LayoutBuilder(
      builder: (context, constraints) {
        final tabBodyHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight - 48 // 48 ≈ TabBar height
            : MediaQuery.of(context).size.height * 0.62;
        return DefaultTabController(
          length: 8,
          child: Column(
            children: [
              const TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppColors.parade,
                unselectedLabelColor: AppColors.inkFaint,
                indicatorColor: AppColors.brass,
                tabs: [
                  Tab(text: 'To-Let'),
                  Tab(text: 'Construction'),
                  Tab(text: 'Permits'),
                  Tab(text: 'Notices'),
                  Tab(text: 'Payments'),
                  Tab(text: 'Verification'),
                  Tab(text: 'Complaints'),
                  Tab(text: 'Reports'),
                ],
              ),
              SizedBox(
                height: tabBodyHeight.clamp(400, 900),
                child: const TabBarView(children: [
                  _PropertyTab(),
                  _ConstructionTab(),
                  _PermitsTab(),
                  _NoticesTab(),
                  _PaymentsAdminTab(),
                  _VerificationTab(),
                  _ComplaintsTab(),
                  _ReportsTab(),
                ]),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Property Management ──────────────────────────────────────────────────────

class _PropertyTab extends StatefulWidget {
  const _PropertyTab();

  @override
  State<_PropertyTab> createState() => _PropertyTabState();
}

class _PropertyTabState extends State<_PropertyTab> {
  bool _loading = false;

  // Note: Rental viewing requests are now handled directly between the
  // resident who owns the listing and the resident requesting the viewing
  // (see the "Flat View Requests" screen and its approve/decline + chat
  // flow) — the Jolshiri Management Authority no longer mediates or even
  // views individual requests here. This tab is now a read-only overview
  // of the To-Let market instead.
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
    } on ApiException catch (e) {
      if (mounted) showActionSnackBar(context, e.message);
    } on ApiUnreachableException {
      // keep mock data — backend unreachable
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rentals = MockData.rentals;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionHeader(
          eyebrow: 'To-Let',
          title: 'Active Rental Listings',
          trailing: Text('${rentals.length} total', style: Theme.of(context).textTheme.labelSmall),
        ),
        const SizedBox(height: 4),
        Text(
          'Viewing requests are arranged directly between residents and are no longer managed here.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        if (rentals.isEmpty)
          const EmptyState(
            icon: Icons.key_outlined,
            title: 'No rental listings',
            message: 'Listings residents post from the To-Let tab will show up here.',
          )
        else
          ...rentals.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(r.title, style: Theme.of(context).textTheme.titleMedium)),
                            Text(r.rentAmount, style: Theme.of(context).textTheme.titleMedium),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('${r.location} · ${r.bedrooms} bed', style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 4),
                        Text(r.availability, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ),
              )),
        const SizedBox(height: 20),
        const SectionHeader(eyebrow: 'Trend', title: 'Monthly User Registrations'),
        const SizedBox(height: 12),
        const _LineChart(points: [
          TrendPoint(label: 'Jan', value: 12),
          TrendPoint(label: 'Feb', value: 18),
          TrendPoint(label: 'Mar', value: 15),
          TrendPoint(label: 'Apr', value: 22),
          TrendPoint(label: 'May', value: 28),
          TrendPoint(label: 'Jun', value: 24),
          TrendPoint(label: 'Jul', value: 31),
        ]),
      ],
    );
  }
}

// ── Construction Monitoring ──────────────────────────────────────────────────

class _ConstructionTab extends StatefulWidget {
  const _ConstructionTab();

  @override
  State<_ConstructionTab> createState() => _ConstructionTabState();
}

class _ConstructionTabState extends State<_ConstructionTab> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final projects = await BackendRepository.fetchConstructionProjects();
      if (mounted && projects.isNotEmpty) {
        setState(() {
          MockData.constructionProjects
            ..removeWhere((p) => p.id != null)
            ..insertAll(0, projects);
        });
      }
    } on ApiException catch (e) {
      if (mounted) showActionSnackBar(context, e.message);
    } on ApiUnreachableException {
      // keep mock data — backend unreachable
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: const ConstructionBody(viewerRole: UserRole.admin),
    );
  }
}

// ── Permits (soil testing applications) ──────────────────────────────────────

class _PermitsTab extends StatefulWidget {
  const _PermitsTab();

  @override
  State<_PermitsTab> createState() => _PermitsTabState();
}

class _PermitsTabState extends State<_PermitsTab> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final apps = await BackendRepository.fetchAllSoilTests();
      if (mounted && apps.isNotEmpty) {
        setState(() {
          MockData.soilTestApplications
            ..removeWhere((a) => a.id != null)
            ..insertAll(0, apps);
        });
      }
    } on ApiException catch (e) {
      if (mounted) showActionSnackBar(context, e.message);
    } on ApiUnreachableException {
      // keep mock data
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setStatus(SoilTestApplication application, SoilTestStatus status) async {
    setState(() => application.status = status);
    if (application.id != null) {
      try {
        await BackendRepository.updateSoilTestStatus(application.id!, status);
      } on ApiException catch (e) {
        if (!mounted) return;
        showActionSnackBar(context, e.message);
        return;
      } on ApiUnreachableException {
        // keep the optimistic local update; backend unreachable
      }
    }
    if (!mounted) return;
    showActionSnackBar(context, 'Soil test marked as ${status.label.toLowerCase()}');
  }

  Color _statusColor(SoilTestStatus status) => switch (status) {
        SoilTestStatus.requested => AppColors.brass,
        SoilTestStatus.permitGranted => AppColors.lake,
        SoilTestStatus.paymentDone => AppColors.parade,
        SoilTestStatus.completed => AppColors.parade,
        SoilTestStatus.rejected => AppColors.brick,
      };

  @override
  Widget build(BuildContext context) {
    final applications = List.of(MockData.soilTestApplications)
      ..sort((a, b) => b.appliedAt.compareTo(a.appliedAt));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionHeader(
          eyebrow: 'Permits',
          title: 'Soil Testing Applications',
          trailing: Text('${applications.length} total', style: Theme.of(context).textTheme.labelSmall),
        ),
        const SizedBox(height: 12),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (!_loading && applications.isEmpty)
          const EmptyState(
            icon: Icons.landscape_outlined,
            title: 'No applications yet',
            message: 'Soil testing permit requests residents submit from Build Track will show up here.',
          )
        else
          ...applications.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(a.applicantName, style: Theme.of(context).textTheme.titleMedium)),
                            StatusPill(label: a.status.label, color: _statusColor(a.status)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('${a.projectName} · ${a.plotReference}', style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 6),
                        Text('Applied ${a.appliedAt.day}/${a.appliedAt.month}/${a.appliedAt.year}',
                            style: Theme.of(context).textTheme.labelSmall),
                        if (a.note.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(a.note, style: Theme.of(context).textTheme.bodyLarge),
                        ],
                        if (a.status == SoilTestStatus.requested) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.brick, side: const BorderSide(color: AppColors.brick)),
                                  onPressed: () => _setStatus(a, SoilTestStatus.rejected),
                                  child: const Text('Reject'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _setStatus(a, SoilTestStatus.permitGranted),
                                  child: const Text('Grant permit'),
                                ),
                              ),
                            ],
                          ),
                        ] else if (a.status == SoilTestStatus.permitGranted) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Waiting for the resident to pay the testing fee.',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(foregroundColor: AppColors.brick, side: const BorderSide(color: AppColors.brick)),
                              onPressed: () => _setStatus(a, SoilTestStatus.rejected),
                              child: const Text('Reject'),
                            ),
                          ),
                        ] else if (a.status == SoilTestStatus.paymentDone) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => _setStatus(a, SoilTestStatus.completed),
                              child: const Text('Testing completed'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              )),
      ],
    );
  }
}

// ── Notice Management ────────────────────────────────────────────────────────

class _NoticesTab extends StatefulWidget {
  const _NoticesTab();

  @override
  State<_NoticesTab> createState() => _NoticesTabState();
}

class _NoticesTabState extends State<_NoticesTab> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  String _category = 'General';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final notices = await BackendRepository.fetchNotices();
      if (mounted && notices.isNotEmpty) {
        setState(() { MockData.notices..clear()..addAll(notices); });
      }
    } on ApiException catch (e) {
      if (mounted) showActionSnackBar(context, e.message);
    } on ApiUnreachableException {
      // keep mock data — backend unreachable
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _publish() async {
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) return;
    final title = _title.text.trim();
    final body = _body.text.trim();
    try {
      final saved = await BackendRepository.createNotice(
        title: title,
        description: body,
        category: _category,
      );
      setState(() => MockData.notices.insert(0, saved));
    } on ApiException catch (e) {
      if (!mounted) return;
      showActionSnackBar(context, e.message);
      return;
    } on ApiUnreachableException {
      setState(() {
        MockData.notices.insert(
          0,
          Notice(title: title, description: body, publishDate: DateTime.now(), category: _category),
        );
      });
    }
    _title.clear();
    _body.clear();
    if (!mounted) return;
    showActionSnackBar(context, 'Notice published');
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionHeader(eyebrow: 'Publish', title: 'New Notice'),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
                const SizedBox(height: 10),
                TextField(controller: _body, maxLines: 3, decoration: const InputDecoration(labelText: 'Body')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: const [
                    DropdownMenuItem(value: 'General', child: Text('General')),
                    DropdownMenuItem(value: 'Emergency', child: Text('Emergency')),
                    DropdownMenuItem(value: 'Construction', child: Text('Construction')),
                    DropdownMenuItem(value: 'Utility', child: Text('Utility')),
                    DropdownMenuItem(value: 'Event', child: Text('Event')),
                  ],
                  onChanged: (v) => setState(() => _category = v ?? 'General'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(onPressed: _publish, child: const Text('Publish notice')),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const SectionHeader(eyebrow: 'Published', title: 'All Notices'),
        const SizedBox(height: 12),
        ...MockData.notices.map((n) => Card(
              child: ListTile(
                leading: const Icon(Icons.campaign_outlined, color: AppColors.parade),
                title: Text(n.title),
                subtitle: Text(n.category),
                trailing: StatusPill(label: n.category, color: AppColors.brass),
              ),
            )),
      ],
    );
  }
}

// ── Payments (create + list) ─────────────────────────────────────────────────

class _PaymentsAdminTab extends StatefulWidget {
  const _PaymentsAdminTab();

  @override
  State<_PaymentsAdminTab> createState() => _PaymentsAdminTabState();
}

class _PaymentsAdminTabState extends State<_PaymentsAdminTab> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _amount = TextEditingController();
  PaymentPurpose _purpose = PaymentPurpose.consultationFee;
  AdminUserSummary? _selectedResident;

  List<AdminUserSummary> _residents = [];
  List<PaymentRecord> _payments = [];
  bool _loading = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final users = await BackendRepository.fetchAdminUsers();
      final payments = await BackendRepository.fetchAdminPayments();
      if (mounted) {
        setState(() {
          _residents = users.where((u) => u.role == 'RESIDENT_OWNER').toList();
          _payments = payments;
        });
      }
    } on ApiException catch (e) {
      if (mounted) showActionSnackBar(context, e.message);
    } on ApiUnreachableException {
      // no backend reachable — leave lists empty, nothing to demo here
      // since payments must be tied to a real signed-up resident.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _issuePayment() async {
    final resident = _selectedResident;
    final title = _title.text.trim();
    final description = _description.text.trim();
    final amount = _amount.text.trim();
    if (resident == null || title.isEmpty || amount.isEmpty) {
      showActionSnackBar(context, 'Pick a resident, and fill in title and amount');
      return;
    }

    setState(() => _submitting = true);
    try {
      final created = await BackendRepository.createAdminPayment(
        userId: resident.id,
        title: title,
        description: description,
        purpose: _purpose,
        amount: amount,
      );
      if (!mounted) return;
      setState(() {
        _payments.insert(0, created);
        _submitting = false;
        _title.clear();
        _description.clear();
        _amount.clear();
      });
      showActionSnackBar(context, 'Payment issued to ${resident.fullName}');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showActionSnackBar(context, e.message);
    } on ApiUnreachableException {
      if (!mounted) return;
      setState(() => _submitting = false);
      showActionSnackBar(context, 'Backend not reachable');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionHeader(eyebrow: 'Issue', title: 'New payment request'),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                DropdownButtonFormField<AdminUserSummary>(
                  initialValue: _selectedResident,
                  decoration: const InputDecoration(labelText: 'Resident'),
                  isExpanded: true,
                  items: _residents
                      .map((r) => DropdownMenuItem(
                            value: r,
                            child: Text('${r.fullName} · ${r.email}', overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedResident = v),
                ),
                const SizedBox(height: 10),
                TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
                const SizedBox(height: 10),
                TextField(
                  controller: _description,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<PaymentPurpose>(
                  initialValue: _purpose,
                  decoration: const InputDecoration(labelText: 'Purpose'),
                  items: const [
                    DropdownMenuItem(value: PaymentPurpose.consultationFee, child: Text('Consultation fee')),
                    DropdownMenuItem(value: PaymentPurpose.developmentAgreement, child: Text('Development agreement')),
                  ],
                  onChanged: (v) => setState(() => _purpose = v ?? PaymentPurpose.consultationFee),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _amount,
                  decoration: const InputDecoration(labelText: 'Amount (e.g. ৳ 5,000)'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _issuePayment,
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                          )
                        : const Text('Issue payment'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const SectionHeader(eyebrow: 'All records', title: 'Payments'),
        const SizedBox(height: 12),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (!_loading && _payments.isEmpty)
          const EmptyState(
            icon: Icons.payments_outlined,
            title: 'No payments yet',
            message: 'Issued payments will show up here once created.',
          )
        else
          ..._payments.map((p) => Card(
                child: ListTile(
                  leading: const Icon(Icons.receipt_long_outlined, color: AppColors.parade),
                  title: Text(p.title),
                  subtitle: Text('${p.reference} · ${p.amount}'),
                  trailing: StatusPill(label: p.status.label, color: _statusColor(p.status)),
                ),
              )),
      ],
    );
  }

  Color _statusColor(PaymentStatus status) => switch (status) {
        PaymentStatus.due => AppColors.brass,
        PaymentStatus.processing => AppColors.lake,
        PaymentStatus.paid => AppColors.parade,
        PaymentStatus.failed => AppColors.brick,
      };
}

// ── Service Provider Verification ────────────────────────────────────────────

class _VerificationTab extends StatefulWidget {
  const _VerificationTab();

  @override
  State<_VerificationTab> createState() => _VerificationTabState();
}

class _VerificationTabState extends State<_VerificationTab> {
  bool _loading = false;

  // Bug fix: tapping the check/cross icon used to give no feedback at all
  // while the network request was in flight — the icon just sat there, so
  // on a slow connection it looked like the tap did nothing. Track which
  // card is currently being approved/rejected so we can show a spinner
  // right on that button and disable it until the request finishes.
  final Set<String> _processingKeys = {};

  String _providerKey(ServiceProvider p) => 'provider:${p.id ?? p.name}';
  String _developerKey(Developer d) => 'developer:${d.id ?? d.companyName}';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final developers = await BackendRepository.fetchDevelopers();
      if (mounted && developers.isNotEmpty) {
        setState(() { MockData.developers..clear()..addAll(developers); });
      }
    } on ApiException catch (e) {
      if (mounted) showActionSnackBar(context, e.message);
    } on ApiUnreachableException {
      // keep mock data — backend unreachable
    }
    try {
      final providers = await BackendRepository.fetchServiceProviders();
      if (mounted && providers.isNotEmpty) {
        setState(() { MockData.serviceProviders..clear()..addAll(providers); });
      }
    } on ApiException catch (e) {
      if (mounted) showActionSnackBar(context, e.message);
    } on ApiUnreachableException {
      // keep mock data — backend unreachable
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _setVerified(ServiceProvider provider, bool verified) async {
    final key = _providerKey(provider);
    if (_processingKeys.contains(key)) return; // already in flight — ignore double-taps
    setState(() => _processingKeys.add(key));

    bool reachedBackend = false;
    try {
      if (provider.id != null) {
        await BackendRepository.verifyProvider(provider.id!, verified);
        reachedBackend = true;
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _processingKeys.remove(key));
        // Bug fix: this error used to only show a SnackBar, which is easy
        // to miss — use a longer, more visible one so a rejected action
        // (e.g. wrong admin permissions, or an already-verified account)
        // is unmistakable instead of looking like nothing happened.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), duration: const Duration(seconds: 4)),
        );
      }
      return;
    } on ApiUnreachableException {
      // fall through — apply the optimistic local update anyway
    }

    final index = MockData.serviceProviders.indexWhere((p) => p.id == provider.id && p.name == provider.name);
    if (index != -1) {
      setState(() {
        MockData.serviceProviders[index] = ServiceProvider(
          id: provider.id,
          name: provider.name,
          serviceType: provider.serviceType,
          phone: provider.phone,
          rating: provider.rating,
          reviews: provider.reviews,
          verified: verified,
        );
      });
    }
    if (!mounted) return;
    setState(() => _processingKeys.remove(key));
    showActionSnackBar(context, '${provider.name} ${verified ? 'approved' : 'rejected'}');
    // Re-sync with the server afterwards so the card reflects the real
    // saved state rather than only the local optimistic guess.
    if (reachedBackend) unawaited(_refresh());
  }

  Future<void> _setDeveloperVerified(Developer developer, bool verified) async {
    final key = _developerKey(developer);
    if (_processingKeys.contains(key)) return;
    setState(() => _processingKeys.add(key));

    bool reachedBackend = false;
    try {
      if (developer.id != null) {
        await BackendRepository.verifyDeveloper(developer.id!, verified);
        reachedBackend = true;
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _processingKeys.remove(key));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), duration: const Duration(seconds: 4)),
        );
      }
      return;
    } on ApiUnreachableException {
      // fall through — apply the optimistic local update anyway
    }

    final index = MockData.developers.indexWhere((d) => d.id == developer.id && d.companyName == developer.companyName);
    if (index != -1) {
      setState(() {
        MockData.developers[index] = Developer(
          id: developer.id,
          companyName: developer.companyName,
          contact: developer.contact,
          rating: developer.rating,
          specialty: developer.specialty,
          verified: verified,
        );
      });
    }
    if (!mounted) return;
    setState(() => _processingKeys.remove(key));
    showActionSnackBar(context, '${developer.companyName} ${verified ? 'approved' : 'rejected'}');
    if (reachedBackend) unawaited(_refresh());
  }

  @override
  Widget build(BuildContext context) {
    final providers = MockData.serviceProviders;
    final byType = <String, List<ServiceProvider>>{};
    for (final p in providers) {
      byType.putIfAbsent(p.serviceType, () => []).add(p);
    }
    final developers = MockData.developers;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        const SectionHeader(eyebrow: 'Verification', title: 'Developers'),
        const SizedBox(height: 12),
        ...developers.map((d) => _ApprovalCard(
              title: d.companyName,
              subtitle: '${d.specialty} · ${d.contact}',
              status: d.verified ? 'Verified' : 'Pending',
              processing: _processingKeys.contains(_developerKey(d)),
              onApprove: () => _setDeveloperVerified(d, true),
              onReject: () => _setDeveloperVerified(d, false),
            )),
        const SizedBox(height: 20),
        const SectionHeader(eyebrow: 'Verification', title: 'Service Providers'),
        const SizedBox(height: 12),
        ...byType.entries.map((entry) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(entry.key,
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.parade)),
                ),
                ...entry.value.map((p) => _ApprovalCard(
                      title: p.name,
                      subtitle: p.phone,
                      status: p.verified ? 'Verified' : 'Pending',
                      processing: _processingKeys.contains(_providerKey(p)),
                      onApprove: () => _setVerified(p, true),
                      onReject: () => _setVerified(p, false),
                    )),
              ],
            )),
        const SizedBox(height: 20),
        const SectionHeader(eyebrow: 'Requests', title: 'Service Requests by Type'),
        const SizedBox(height: 12),
        _BarChart(items: byType.entries
            .map((e) => ProgressItem(
                  label: e.key,
                  progress: providers.isEmpty ? 0 : e.value.length / providers.length,
                  note: '${e.value.length} providers',
                ))
            .toList()),
      ],
      ),
    );
  }
}

// ── Complaint Register ───────────────────────────────────────────────────────

class _ComplaintsTab extends StatefulWidget {
  const _ComplaintsTab();

  @override
  State<_ComplaintsTab> createState() => _ComplaintsTabState();
}

class _ComplaintsTabState extends State<_ComplaintsTab> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final complaints = await BackendRepository.fetchAllComplaints();
      if (mounted) {
        setState(() {
          MockData.complaints
            ..removeWhere((c) => c.id != null)
            ..insertAll(0, complaints);
        });
      }
    } on ApiException catch (e) {
      if (mounted) showActionSnackBar(context, e.message);
    } on ApiUnreachableException {
      // keep the local mock/demo list
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _respond(Complaint complaint) {
    final noteController = TextEditingController();
    ComplaintStatus status = complaint.status == ComplaintStatus.submitted ? ComplaintStatus.inProgress : complaint.status;
    double progress = complaint.progress;

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
                Text('Respond to "${complaint.title}"', style: Theme.of(sheetContext).textTheme.headlineSmall),
                const SizedBox(height: 16),
                DropdownButtonFormField<ComplaintStatus>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: ComplaintStatus.values
                      .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                      .toList(),
                  onChanged: (v) => setSheetState(() => status = v ?? status),
                ),
                const SizedBox(height: 12),
                Text('Progress: ${progress.round()}%', style: Theme.of(sheetContext).textTheme.bodyMedium),
                Slider(
                  value: progress,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  label: '${progress.round()}%',
                  onChanged: (v) => setSheetState(() => progress = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Update note', hintText: 'What was done / next steps'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final note = noteController.text.trim();
                      if (note.isEmpty) {
                        showActionSnackBar(sheetContext, 'Please add a note');
                        return;
                      }
                      final id = complaint.id;
                      if (id != null) {
                        try {
                          await runWithLoadingOverlay(
                            sheetContext,
                            () => BackendRepository.addComplaintUpdate(id, note: note, status: status, progress: progress),
                            message: 'Saving update…',
                          );
                        } on ApiException catch (e) {
                          if (!sheetContext.mounted) return;
                          showActionSnackBar(sheetContext, e.message);
                          return;
                        } on ApiUnreachableException {
                          // apply optimistic local update anyway
                        }
                      }
                      setState(() {
                        complaint.status = status;
                        complaint.progress = progress;
                      });
                      if (!sheetContext.mounted) return;
                      Navigator.pop(sheetContext);
                      if (!context.mounted) return;
                      showActionSnackBar(context, 'Complaint updated');
                    },
                    child: const Text('Save update'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor(ComplaintStatus status) => switch (status) {
        ComplaintStatus.submitted => AppColors.brass,
        ComplaintStatus.inProgress => AppColors.lake,
        ComplaintStatus.resolved => AppColors.parade,
      };

  @override
  Widget build(BuildContext context) {
    final complaints = List.of(MockData.complaints)..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionHeader(
          eyebrow: 'Complaint Register',
          title: 'Resident Complaints',
          trailing: Text('${complaints.length} total', style: Theme.of(context).textTheme.labelSmall),
        ),
        const SizedBox(height: 12),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (!_loading && complaints.isEmpty)
          const EmptyState(
            icon: Icons.report_problem_outlined,
            title: 'No complaints filed',
            message: 'Complaints residents file from the app will show up here for review.',
          )
        else
          ...complaints.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: Padding(
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
                        const SizedBox(height: 6),
                        Text('${c.category} · ${c.plotReference}', style: Theme.of(context).textTheme.bodyMedium),
                        if (c.residentName.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('Filed by ${c.residentName}', style: Theme.of(context).textTheme.labelSmall),
                        ],
                        const SizedBox(height: 8),
                        Text(c.description, style: Theme.of(context).textTheme.bodyLarge),
                        if (c.status != ComplaintStatus.resolved) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () => _respond(c),
                              child: const Text('Respond'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              )),
      ],
    );
  }
}

// ── Reports ──────────────────────────────────────────────────────────────────

class _ReportsTab extends StatefulWidget {
  const _ReportsTab();

  @override
  State<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<_ReportsTab> {
  static const _templates = [
    ReportTemplate(title: 'Monthly Property Registrations', description: 'Plot ownership and transfer activity for the selected month.'),
    ReportTemplate(title: 'Construction Activity', description: 'Active, completed, and delayed projects with stage breakdown.'),
    ReportTemplate(title: 'Resident Growth', description: 'New resident registrations and role distribution over time.'),
    ReportTemplate(title: 'Service Usage', description: 'Booking counts, provider ratings, and category breakdown.'),
  ];

  final Set<String> _generating = {};

  Future<void> _generateReport(ReportTemplate template) async {
    if (_generating.contains(template.title)) return;
    setState(() => _generating.add(template.title));

    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) => [
            // Header
            pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 16),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 1)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Jolshiri Smart City Authority',
                    style: const pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.green800),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    template.title,
                    style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Generated: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 24),
            ..._buildReportContent(template.title),
            pw.SizedBox(height: 32),
            // Footer
            pw.Container(
              padding: const pw.EdgeInsets.only(top: 12),
              decoration: const pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 1)),
              ),
              child: pw.Text(
                'This report is auto-generated by Jolshiri Smart City Management System. All data is subject to change.',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
              ),
            ),
          ],
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: '${template.title.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      showActionSnackBar(context, 'Failed to generate PDF: $e');
    } finally {
      if (mounted) setState(() => _generating.remove(template.title));
    }
  }

  List<pw.Widget> _buildReportContent(String title) {
    switch (title) {
      case 'Monthly Property Registrations':
        return _buildPropertyReport();
      case 'Construction Activity':
        return _buildConstructionReport();
      case 'Resident Growth':
        return _buildResidentReport();
      case 'Service Usage':
        return _buildServiceReport();
      default:
        return [pw.Text('No data available for this report type.')];
    }
  }

  List<pw.Widget> _buildPropertyReport() {
    final rentals = MockData.rentals;
    return [
      pw.Text('Property & Rental Overview', style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 12),
      pw.Text('Total active rental listings: ${rentals.length}', style: const pw.TextStyle(fontSize: 11)),
      pw.SizedBox(height: 8),
      if (rentals.isEmpty)
        pw.Text('No rental listings found.', style: const pw.TextStyle(color: PdfColors.grey500))
      else
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey200),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.green50),
              children: [
                _cell('Title', bold: true),
                _cell('Rent', bold: true),
                _cell('Availability', bold: true),
              ],
            ),
            ...rentals.map((r) => pw.TableRow(children: [
              _cell(r.title),
              _cell(r.rentAmount),
              _cell(r.availability),
            ])),
          ],
        ),
    ];
  }

  List<pw.Widget> _buildConstructionReport() {
    final projects = MockData.constructionProjects;
    final approved = projects.where((p) => p.permitStatus == ConstructionPermitStatus.approved).length;
    final pending = projects.where((p) => p.permitStatus == ConstructionPermitStatus.pending).length;
    final rejected = projects.where((p) => p.permitStatus == ConstructionPermitStatus.rejected).length;
    return [
      pw.Text('Construction Activity', style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 12),
      pw.Row(children: [
        _summaryBox('Total Projects', '${projects.length}'),
        pw.SizedBox(width: 12),
        _summaryBox('Approved', '$approved'),
        pw.SizedBox(width: 12),
        _summaryBox('Pending', '$pending'),
        pw.SizedBox(width: 12),
        _summaryBox('Rejected', '$rejected'),
      ]),
      pw.SizedBox(height: 16),
      if (projects.isEmpty)
        pw.Text('No construction projects found.', style: const pw.TextStyle(color: PdfColors.grey500))
      else
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey200),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(1.5),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.green50),
              children: [
                _cell('Project', bold: true),
                _cell('Developer', bold: true),
                _cell('Permit', bold: true),
                _cell('ETA', bold: true),
              ],
            ),
            ...projects.map((p) => pw.TableRow(children: [
              _cell(p.projectName),
              _cell(p.developerName),
              _cell(p.permitStatus.label),
              _cell(p.estimatedCompletion),
            ])),
          ],
        ),
    ];
  }

  List<pw.Widget> _buildResidentReport() {
    final soilApps = MockData.soilTestApplications;
    return [
      pw.Text('Resident & Soil Test Applications', style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 12),
      pw.Text('Total soil test applications: ${soilApps.length}', style: const pw.TextStyle(fontSize: 11)),
      pw.SizedBox(height: 8),
      if (soilApps.isEmpty)
        pw.Text('No applications found.', style: const pw.TextStyle(color: PdfColors.grey500))
      else
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey200),
          columnWidths: {
            0: const pw.FlexColumnWidth(1.5),
            1: const pw.FlexColumnWidth(1.5),
            2: const pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.green50),
              children: [
                _cell('Applicant', bold: true),
                _cell('Project', bold: true),
                _cell('Status', bold: true),
              ],
            ),
            ...soilApps.map((a) => pw.TableRow(children: [
              _cell(a.applicantName),
              _cell(a.projectName),
              _cell(a.status.label),
            ])),
          ],
        ),
    ];
  }

  List<pw.Widget> _buildServiceReport() {
    final providers = MockData.serviceProviders;
    final byType = <String, int>{};
    for (final p in providers) {
      byType[p.serviceType] = (byType[p.serviceType] ?? 0) + 1;
    }
    final complaints = MockData.complaints;
    return [
      pw.Text('Service Usage Overview', style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 12),
      pw.Text('Total service providers: ${providers.length}', style: const pw.TextStyle(fontSize: 11)),
      pw.Text('Total complaints: ${complaints.length}', style: const pw.TextStyle(fontSize: 11)),
      pw.SizedBox(height: 16),
      pw.Text('Providers by Type', style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      if (byType.isEmpty)
        pw.Text('No providers found.', style: const pw.TextStyle(color: PdfColors.grey500))
      else
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey200),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.green50),
              children: [
                _cell('Service Type', bold: true),
                _cell('Count', bold: true),
              ],
            ),
            ...byType.entries.map((e) => pw.TableRow(children: [
              _cell(e.key),
              _cell('${e.value}'),
            ])),
          ],
        ),
      pw.SizedBox(height: 16),
      pw.Text('Complaint Summary', style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      if (complaints.isEmpty)
        pw.Text('No complaints on record.', style: const pw.TextStyle(color: PdfColors.grey500))
      else ...[
        pw.Text('Submitted: ${complaints.where((c) => c.status == ComplaintStatus.submitted).length}', style: const pw.TextStyle(fontSize: 11)),
        pw.Text('In Progress: ${complaints.where((c) => c.status == ComplaintStatus.inProgress).length}', style: const pw.TextStyle(fontSize: 11)),
        pw.Text('Resolved: ${complaints.where((c) => c.status == ComplaintStatus.resolved).length}', style: const pw.TextStyle(fontSize: 11)),
      ],
    ];
  }

  pw.Widget _cell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  pw.Widget _summaryBox(String label, String value) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: PdfColors.green50,
          border: pw.Border.all(color: PdfColors.green200),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(value, style: const pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
            pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionHeader(eyebrow: 'Generate', title: 'PDF Reports'),
        const SizedBox(height: 4),
        Text(
          'Reports are generated from current data and saved directly as a PDF file.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        ..._templates.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.brick),
                  title: Text(r.title),
                  subtitle: Text(r.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: _generating.contains(r.title)
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : TextButton(
                          onPressed: () => _generateReport(r),
                          child: const Text('Generate'),
                        ),
                ),
              ),
            )),
      ],
    );
  }
}

// ── Shared chart / card widgets ───────────────────────────────────────────────

class _ApprovalCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String status;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  // Bug fix: previously there was no way to tell the check/cross buttons
  // that a request was already in flight, so tapping them while the
  // network call was still running looked like nothing happened. When
  // true, both buttons are disabled and a small spinner replaces whichever
  // icon was pressed.
  final bool processing;

  const _ApprovalCard({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.onApprove,
    required this.onReject,
    this.processing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            StatusPill.status(status),
            const SizedBox(width: 8),
            if (processing)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              )
            else ...[
              IconButton(
                icon: const Icon(Icons.check_circle_outline, color: AppColors.lake),
                tooltip: 'Approve',
                onPressed: onApprove,
              ),
              IconButton(
                icon: const Icon(Icons.cancel_outlined, color: AppColors.brick),
                tooltip: 'Reject',
                onPressed: onReject,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LineChart extends StatelessWidget {
  final List<TrendPoint> points;
  const _LineChart({required this.points});

  @override
  Widget build(BuildContext context) {
    final max = points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: points.map((p) {
                  final h = (p.value / max) * 100;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('${p.value.toInt()}', style: const TextStyle(fontSize: 10, color: AppColors.inkFaint)),
                          const SizedBox(height: 2),
                          Container(
                            height: h,
                            decoration: BoxDecoration(
                              color: AppColors.parade.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: points
                  .map((p) => Expanded(
                        child: Text(p.label,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 10, color: AppColors.inkFaint)),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  final List<ProgressItem> items;
  const _BarChart({required this.items});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: items
              .map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(child: Text(item.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                          Text(item.note, style: const TextStyle(fontSize: 12, color: AppColors.inkFaint)),
                        ]),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: item.progress,
                          backgroundColor: AppColors.paperDim,
                          color: AppColors.lake,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _PieChart extends StatelessWidget {
  final Map<String, int> data;
  const _PieChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final colors = [AppColors.lake, AppColors.parade, AppColors.brick, AppColors.inkFaint];
    final entries = data.entries.toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          children: List.generate(entries.length, (i) {
            final e = entries[i];
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 12, height: 12, decoration: BoxDecoration(color: colors[i % colors.length], shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('${e.key}: ${e.value}', style: const TextStyle(fontSize: 13)),
              ],
            );
          }),
        ),
      ),
    );
  }
}
