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

/// Home for a logged-in Service Provider: manage incoming booking requests.
class ProviderDashboard extends StatefulWidget {
  const ProviderDashboard({super.key, this.providerName});

  /// Name of the logged-in service provider (shown in the AppBar subtitle).
  final String? providerName;

  @override
  State<ProviderDashboard> createState() => _ProviderDashboardState();
}

class _ProviderDashboardState extends State<ProviderDashboard> {
  RequestStatus? _filter;
  bool _loading = false;
  final Set<String> _updatingIds = {};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final bookings = await BackendRepository.fetchProviderBookings();
      if (mounted && bookings.isNotEmpty) {
        setState(() {
          MockData.serviceBookings..clear()..addAll(bookings);
        });
      }
    } on ApiException catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Opens the "Business profile" editor — lets the logged-in provider
  /// update the ServiceProvider directory record (display name, service
  /// type, business phone) that residents see when browsing/booking.
  /// Backed by GET/PATCH /api/providers/me.
  Future<void> _openProfileEditor() async {
    ServiceProvider? current;
    try {
      current = await BackendRepository.fetchMyProviderProfile();
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

    final nameController = TextEditingController(text: current.name);
    final serviceTypeController = TextEditingController(text: current.serviceType);
    final phoneController = TextEditingController(text: current.phone);

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
              Text('Business profile', style: Theme.of(sheetContext).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'This is what residents see when they browse providers.',
                style: Theme.of(sheetContext).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Business / display name')),
              const SizedBox(height: 10),
              TextField(controller: serviceTypeController, decoration: const InputDecoration(labelText: 'Service type (e.g. Electrician, Plumber)')),
              const SizedBox(height: 10),
              TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Business phone')),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final serviceType = serviceTypeController.text.trim();
                    final phone = phoneController.text.trim();
                    if (name.isEmpty || serviceType.isEmpty || phone.isEmpty) {
                      showActionSnackBar(sheetContext, 'Please fill in all fields');
                      return;
                    }
                    try {
                      await runWithLoadingOverlay(
                        sheetContext,
                        () => BackendRepository.updateMyProviderProfile(
                          name: name,
                          serviceType: serviceType,
                          phone: phone,
                        ),
                        message: 'Saving changes…',
                      );
                      if (!sheetContext.mounted) return;
                      Navigator.pop(sheetContext);
                      if (!mounted) return;
                      showActionSnackBar(context, 'Business profile updated');
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

  List<ServiceBooking> get _bookings {
    final all = MockData.serviceBookings;
    if (_filter == null) return all;
    return all.where((b) => b.status == _filter).toList();
  }

  void _setStatus(ServiceBooking booking, RequestStatus status) async {
    final key = booking.id ?? '${booking.customerName}-${booking.requestedAt}';
    setState(() {
      booking.status = status;
      _updatingIds.add(key);
    });
    if (booking.id != null) {
      try {
        await BackendRepository.updateBookingStatus(booking.id!, status);
      } on ApiException catch (e) {
        if (!mounted) return;
        setState(() => _updatingIds.remove(key));
        showActionSnackBar(context, e.message);
        return;
      } on ApiUnreachableException {
        // keep the optimistic local update; backend unreachable
      }
    }
    if (!mounted) return;
    setState(() => _updatingIds.remove(key));
    showActionSnackBar(
      context,
      status == RequestStatus.completed
          ? 'Marked completed — the resident has been notified and asked to rate this service.'
          : 'Booking ${status.label.toLowerCase()}',
    );
  }

  Color _statusColor(RequestStatus status) => switch (status) {
        RequestStatus.pending => AppColors.brass,
        RequestStatus.accepted => AppColors.lake,
        RequestStatus.completed => AppColors.parade,
        RequestStatus.declined => AppColors.brick,
      };

  @override
  Widget build(BuildContext context) {
    final bookings = _bookings;
    final pendingCount = MockData.serviceBookings.where((b) => b.status == RequestStatus.pending).length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Provider Dashboard'),
            if (widget.providerName != null)
              Text(
                widget.providerName!,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Business profile',
            icon: const Icon(Icons.storefront_outlined),
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
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (_loading) const LinearProgressIndicator(minHeight: 2),
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
                      Text('INCOMING WORK', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.brass)),
                      const SizedBox(height: 6),
                      Text(
                        '$pendingCount pending request${pendingCount == 1 ? '' : 's'}',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'serif'),
                      ),
                      const SizedBox(height: 4),
                      Text('Accept jobs and keep your schedule up to date', style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12.5)),
                    ],
                  ),
                ),
                const Icon(Icons.handyman_outlined, color: AppColors.brass, size: 36),
              ],
            ),
          ),
          const SizedBox(height: 20),
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
          if (bookings.isEmpty)
            const EmptyState(
              icon: Icons.inbox_outlined,
              title: 'No requests here',
              message: 'Booking requests from residents will show up in this list.',
            )
          else
            ...bookings.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(b.customerName, style: Theme.of(context).textTheme.titleMedium)),
                              StatusPill(label: b.status.label, color: _statusColor(b.status)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              StatusPill(label: b.serviceType, color: AppColors.lake),
                              const Spacer(),
                              Text(_relativeTime(b.requestedAt), style: Theme.of(context).textTheme.labelSmall),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(Icons.place_outlined, size: 16, color: AppColors.inkFaint),
                              const SizedBox(width: 4),
                              Expanded(child: Text(b.address, style: Theme.of(context).textTheme.bodyMedium)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(b.note, style: Theme.of(context).textTheme.bodyLarge),
                          const SizedBox(height: 12),
                          _actionsFor(b, _updatingIds.contains(b.id ?? '${b.customerName}-${b.requestedAt}')),
                        ],
                      ),
                    ),
                  ),
                )),
        ],
      )),
    );
  }

  Widget _actionsFor(ServiceBooking b, bool updating) {
    switch (b.status) {
      case RequestStatus.pending:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.brick, side: const BorderSide(color: AppColors.brick)),
                onPressed: updating ? null : () => _setStatus(b, RequestStatus.declined),
                child: const Text('Decline'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: updating ? null : () => _setStatus(b, RequestStatus.accepted),
                child: submitButtonChild(updating, 'Accept'),
              ),
            ),
          ],
        );
      case RequestStatus.accepted:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: updating ? null : () => _setStatus(b, RequestStatus.completed),
            child: submitButtonChild(updating, 'Mark as completed'),
          ),
        );
      case RequestStatus.completed:
      case RequestStatus.declined:
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
        labelStyle: TextStyle(color: selected ? Colors.white : AppColors.ink, fontWeight: FontWeight.w600, fontSize: 12.5),
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
