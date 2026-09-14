import 'package:flutter/material.dart';
import '../../data/mock_data.dart';
import '../../models/app_models.dart';
import '../../services/api_client.dart';
import '../../services/api_config.dart';
import '../../services/backend_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../resident/reviews_screen.dart';

/// Services marketplace: browse and book verified service providers.
class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  String _filter = 'All';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final providers = await BackendRepository.fetchServiceProviders();
      if (mounted && providers.isNotEmpty) {
        setState(() { MockData.serviceProviders..clear()..addAll(providers); });
      }
    } on ApiException catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> get _serviceTypes {
    final types = MockData.serviceProviders.map((s) => s.serviceType).toSet().toList()..sort();
    return ['All', ...types];
  }

  void _book(BuildContext context, ServiceProvider provider) {
    if (!AuthSession.isLoggedIn) {
      showActionSnackBar(context, 'Please log in to book a service');
      return;
    }

    final addressController = TextEditingController(text: MockData.currentUser.address);
    final noteController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          bool submitting = false;
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Book ${provider.name}', style: Theme.of(sheetContext).textTheme.headlineSmall),
                const SizedBox(height: 16),
                TextField(controller: addressController, decoration: const InputDecoration(labelText: 'Address')),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  maxLines: 3,
                  decoration: const InputDecoration(hintText: 'Describe what you need done (optional)'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: submitting
                        ? null
                        : () async {
                            final address = addressController.text.trim();
                            if (address.isEmpty) {
                              showActionSnackBar(sheetContext, 'Please enter an address');
                              return;
                            }

                            setSheetState(() => submitting = true);

                            if (provider.id != null) {
                              try {
                                await BackendRepository.createBooking(
                                  providerId: provider.id!,
                                  serviceType: provider.serviceType,
                                  address: address,
                                  note: noteController.text.trim(),
                                );
                                if (!sheetContext.mounted) return;
                                Navigator.pop(sheetContext);
                                if (!context.mounted) return;
                                showActionSnackBar(context, 'Booking request sent to ${provider.name}');
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

                            if (!sheetContext.mounted) return;
                            Navigator.pop(sheetContext);
                            if (!context.mounted) return;
                            showActionSnackBar(context, 'Booking request sent to ${provider.name}');
                          },
                    child: submitButtonChild(submitting, 'Send booking request'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final providers = MockData.serviceProviders
        .where((s) => _filter == 'All' || s.serviceType == _filter)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Services')),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _serviceTypes.length,
              itemBuilder: (context, i) {
                final type = _serviceTypes[i];
                final selected = _filter == type;
                return ChoiceChip(
                  label: Text(type),
                  selected: selected,
                  onSelected: (_) => setState(() => _filter = type),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : AppColors.ink,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 8),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: providers.isEmpty
                ? const EmptyState(
                    icon: Icons.handyman_outlined,
                    title: 'No providers found',
                    message: 'Try a different service category.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: providers.length,
                    itemBuilder: (context, i) {
                      final ServiceProvider s = providers[i];
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => ReviewsScreen(initialProviderName: s.name)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text(s.name, style: Theme.of(context).textTheme.titleMedium)),
                                    if (s.verified) const VerifiedBadge(),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    StatusPill(label: s.serviceType, color: AppColors.lake),
                                    const Spacer(),
                                    RatingRow(
                                      rating: MockData.providerAverageRating(s),
                                      reviews: MockData.providerReviewCount(s),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    const Icon(Icons.phone_outlined, size: 16, color: AppColors.inkFaint),
                                    const SizedBox(width: 4),
                                    Expanded(child: Text(s.phone, style: Theme.of(context).textTheme.bodyMedium)),
                                    const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.inkFaint),
                                    const SizedBox(width: 2),
                                    Text('Details & reviews', style: Theme.of(context).textTheme.labelSmall),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () => _book(context, s),
                                    child: const Text('Book service'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
