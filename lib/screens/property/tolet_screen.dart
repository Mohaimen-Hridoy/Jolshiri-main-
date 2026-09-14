import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../../data/mock_data.dart';
import '../../models/app_models.dart';
import '../../services/api_client.dart';
import '../../services/api_config.dart';
import '../../services/backend_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'flat_view_requests_screen.dart';

/// To-Let listings: browse rental homes inside Jolshiri and post new ones.
/// Talks to POST /rentals/:id/viewing-requests and POST /rentals; if the
/// backend call fails (offline / server down) it falls back to a
/// local-only mock entry so the demo flow still works end to end.
class ToLetScreen extends StatefulWidget {
  const ToLetScreen({super.key});

  @override
  State<ToLetScreen> createState() => _ToLetScreenState();
}

class _ToLetScreenState extends State<ToLetScreen> {
  bool _loading = false;
  final Set<String> _requestingIds = {};

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

  Future<void> _requestViewing(BuildContext context, RentalListing r) async {
    final requestKey = r.id ?? r.title;
    setState(() => _requestingIds.add(requestKey));

    final requesterName = MockData.currentUser.fullName;
    final requesterPhone = MockData.currentUser.phone;
    final note = 'Interested in ${r.bedrooms}-bed listing at ${r.rentAmount}.';

    RentalViewingRequest request;
    try {
    if (r.id != null) {
      try {
        request = await BackendRepository.requestViewing(
          listing: r,
          requesterName: requesterName,
          requesterPhone: requesterPhone,
          note: note,
        );
      } on ApiException catch (e) {
        if (mounted) showActionSnackBar(context, e.message);
        return;
      } catch (_) {
        // Backend unreachable — fall back to a local-only entry below.
        request = RentalViewingRequest(
          listingTitle: r.title,
          listingLocation: r.location,
          requesterName: requesterName,
          requesterPhone: requesterPhone,
          note: note,
          requestedAt: DateTime.now(),
        );
      }
    } else {
      request = RentalViewingRequest(
        listingTitle: r.title,
        listingLocation: r.location,
        requesterName: requesterName,
        requesterPhone: requesterPhone,
        note: note,
        requestedAt: DateTime.now(),
      );
    }

    setState(() => MockData.viewingRequests.insert(0, request));
    MockData.notifications.insert(
      0,
      AppNotification(
        title: 'Viewing request sent',
        message: 'Your request to view "${r.title}" (${r.location}) has been sent to the management office.',
      ),
    );
    if (mounted) showActionSnackBar(context, 'Viewing request sent for ${r.title}');
    } finally {
      if (mounted) setState(() => _requestingIds.remove(requestKey));
    }
  }

  Future<void> _addRental() async {
    final draft = await showModalBottomSheet<RentalListing>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _AddRentalSheet(),
    );
    if (draft == null) return;

    setState(() => _loading = true);
    var rental = draft;
    try {
      final saved = await BackendRepository.createRentalListing(
        title: draft.title,
        location: draft.location,
        rentAmount: draft.rentAmount,
        availability: draft.availability,
        description: draft.description,
        bedrooms: draft.bedrooms,
        imageBytes: draft.imageBytes,
      );
      rental = saved;
    } on ApiException catch (e) {
      if (mounted) setState(() => _loading = false);
      if (mounted) showActionSnackBar(context, e.message);
      return;
    } catch (_) {
      // Backend unreachable — keep the local-only draft so the demo still works.
    }

    setState(() {
      _loading = false;
      MockData.rentals.insert(0, rental);
    });
    if (mounted) showActionSnackBar(context, '${rental.title} listed');
  }

  Future<void> _editRental(RentalListing existing) async {
    final draft = await showModalBottomSheet<RentalListing>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddRentalSheet(existing: existing),
    );
    if (draft == null) return;

    if (existing.id == null) {
      // Local-only mock entry — just replace it in place.
      setState(() {
        final i = MockData.rentals.indexOf(existing);
        if (i != -1) MockData.rentals[i] = draft;
      });
      if (mounted) showActionSnackBar(context, '${draft.title} updated');
      return;
    }

    try {
      final saved = await runWithLoadingOverlay(
        context,
        () => BackendRepository.updateRentalListing(
          id: existing.id!,
          title: draft.title,
          location: draft.location,
          rentAmount: draft.rentAmount,
          availability: draft.availability,
          description: draft.description,
          bedrooms: draft.bedrooms,
          imageBytes: draft.imageBytes,
        ),
        message: 'Saving changes…',
      );
      if (!mounted) return;
      setState(() {
        final i = MockData.rentals.indexWhere((r) => r.id == existing.id);
        if (i != -1) {
          // The backend's PATCH response doesn't include the `owner`
          // relation, so carry ownerId/ownerName over from the pre-edit
          // listing rather than trusting `saved` for them (otherwise the
          // Edit/Delete menu would disappear after the very edit that
          // triggered it).
          MockData.rentals[i] = RentalListing(
            id: saved.id,
            title: saved.title,
            location: saved.location,
            rentAmount: saved.rentAmount,
            availability: saved.availability,
            description: saved.description,
            bedrooms: saved.bedrooms,
            imageUrl: saved.imageUrl,
            imageBytes: draft.imageBytes ?? existing.imageBytes,
            ownerId: existing.ownerId,
            ownerName: existing.ownerName,
          );
        }
      });
      showActionSnackBar(context, '${saved.title} updated');
    } on ApiException catch (e) {
      if (mounted) showActionSnackBar(context, e.message);
    } on ApiUnreachableException {
      if (mounted) showActionSnackBar(context, 'Could not reach the server — changes were not saved');
    }
  }

  Future<void> _deleteRental(RentalListing listing) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this listing?'),
        content: Text('"${listing.title}" will be removed permanently.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.brick)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    if (listing.id != null) {
      try {
        await runWithLoadingOverlay(
          context,
          () => BackendRepository.deleteRentalListing(listing.id!),
          message: 'Deleting…',
        );
      } on ApiException catch (e) {
        if (mounted) showActionSnackBar(context, e.message);
        return;
      } on ApiUnreachableException {
        if (mounted) showActionSnackBar(context, 'Could not reach the server — listing was not deleted');
        return;
      }
    }
    if (!mounted) return;
    setState(() => MockData.rentals.remove(listing));
    showActionSnackBar(context, 'Listing deleted');
  }

  @override
  Widget build(BuildContext context) {
    final rentals = MockData.rentals;
    return Scaffold(
      appBar: AppBar(
        title: const Text('To-Let'),
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.parade,
        onPressed: _loading ? null : _addRental,
        icon: _loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
              )
            : const Icon(Icons.add),
        label: const Text('List a home'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: rentals.isEmpty && !_loading
          ? const EmptyState(
              icon: Icons.key_outlined,
              title: 'No rentals available',
              message: 'New to-let listings will appear here once published.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: rentals.length,
              itemBuilder: (context, i) {
                final RentalListing r = rentals[i];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListingImage(url: r.imageUrl, bytes: r.imageBytes),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(r.title, style: Theme.of(context).textTheme.titleMedium)),
                                StatusPill.status(r.availability),
                                if (r.ownerId != null && r.ownerId == AuthSession.userId)
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, size: 20),
                                    onSelected: (v) {
                                      if (v == 'edit') _editRental(r);
                                      if (v == 'delete') _deleteRental(r);
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                                    ],
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(r.location, style: Theme.of(context).textTheme.bodyMedium),
                            const SizedBox(height: 10),
                            Text(r.description, style: Theme.of(context).textTheme.bodyLarge),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.bed_outlined, size: 16, color: AppColors.inkFaint),
                                const SizedBox(width: 4),
                                Text('${r.bedrooms} bed', style: Theme.of(context).textTheme.bodyMedium),
                                const Spacer(),
                                Text(r.rentAmount, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.parade)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: _requestingIds.contains(r.id ?? r.title)
                                    ? null
                                    : () => _requestViewing(context, r),
                                child: submitButtonChild(
                                  _requestingIds.contains(r.id ?? r.title),
                                  'Request viewing',
                                  color: AppColors.parade,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 12),
            ),
      ),
    );
  }
}

/// Bottom sheet form for listing a new rental home, or editing an existing
/// one when [existing] is provided (pre-fills every field).
class _AddRentalSheet extends StatefulWidget {
  final RentalListing? existing;
  const _AddRentalSheet({this.existing});

  @override
  State<_AddRentalSheet> createState() => _AddRentalSheetState();
}

class _AddRentalSheetState extends State<_AddRentalSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _location = TextEditingController(text: widget.existing?.location);
  late final _rent = TextEditingController(text: widget.existing?.rentAmount);
  late final _availability = TextEditingController(text: widget.existing?.availability);
  late final _description = TextEditingController(text: widget.existing?.description);
  late final _bedrooms = TextEditingController(text: widget.existing?.bedrooms.toString());
  Uint8List? _imageBytes;

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _rent.dispose();
    _availability.dispose();
    _description.dispose();
    _bedrooms.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final rentText = _rent.text.trim();
    Navigator.pop(
      context,
      RentalListing(
        id: widget.existing?.id,
        title: _title.text.trim(),
        location: _location.text.trim(),
        rentAmount: rentText.startsWith('৳') ? rentText : '৳ $rentText / month',
        availability: _availability.text.trim().isEmpty ? 'Available now' : _availability.text.trim(),
        description: _description.text.trim(),
        bedrooms: int.parse(_bedrooms.text.trim()),
        imageUrl: widget.existing?.imageUrl ?? 'assets/listings/house4.jpg',
        imageBytes: _imageBytes ?? widget.existing?.imageBytes,
        ownerId: widget.existing?.ownerId,
        ownerName: widget.existing?.ownerName,
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
              Text(_isEditing ? 'Edit listing' : 'List a home', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              TextFormField(
                controller: _title,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. Furnished 3-Bed Apartment'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a title' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _location,
                decoration: const InputDecoration(labelText: 'Location', hintText: 'e.g. Sector 7, near Lake Park'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a location' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _rent,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Monthly rent', hintText: 'e.g. 35,000'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter the rent amount' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bedrooms,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Bedrooms', hintText: 'e.g. 3'),
                validator: (v) {
                  final n = int.tryParse(v?.trim() ?? '');
                  if (n == null || n <= 0) return 'Enter a valid number of bedrooms';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _availability,
                decoration: const InputDecoration(labelText: 'Availability (optional)', hintText: 'e.g. Available from Aug 1'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description', hintText: 'Size, facilities, nearby landmarks…'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a description' : null,
              ),
              const SizedBox(height: 12),
              ImagePickerField(
                label: _isEditing ? 'Replace home image (optional)' : 'Home image (optional)',
                onChanged: (b) => _imageBytes = b,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(onPressed: _submit, child: Text(_isEditing ? 'Save changes' : 'Publish listing')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
