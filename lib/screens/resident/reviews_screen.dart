import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
import '../../models/app_models.dart';
import '../../services/api_client.dart';
import '../../services/api_config.dart';
import '../../services/backend_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/review_prompt.dart';

class ReviewsScreen extends StatefulWidget {
  final String? initialProviderName;

  const ReviewsScreen({super.key, this.initialProviderName});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  late String _providerName;

  @override
  void initState() {
    super.initState();
    _providerName = widget.initialProviderName ?? MockData.serviceProviders.first.name;
    _loadReviews(_provider);
    _loadMyBookings();
  }

  /// GET /api/bookings/mine — fetches the resident's completed bookings so
  /// the "Pending Reviews" tab shows real backend data instead of mock seed.
  Future<void> _loadMyBookings() async {
    if (!AuthSession.isLoggedIn) return;
    try {
      final bookings = await BackendRepository.fetchMyBookings();
      if (!mounted) return;
      setState(() {
        MockData.serviceBookings
          ..removeWhere((b) => b.customerName == MockData.currentUser.fullName)
          ..insertAll(0, bookings);
      });
    } catch (_) {
      // Backend unreachable — keep existing mock/local bookings.
    }
  }

  ServiceProvider get _provider {
    return MockData.serviceProviders.firstWhere((provider) => provider.name == _providerName);
  }

  /// GET /api/providers/:id/reviews — merges live reviews for this provider
  /// into MockData.serviceReviews so the existing reviewsForProvider()
  /// filter picks them up with no other screen changes needed. Silently
  /// keeps mock data if the backend call fails (offline/unreachable).
  Future<void> _loadReviews(ServiceProvider provider) async {
    if (provider.id == null) return;
    try {
      final reviews = await BackendRepository.fetchProviderReviews(provider);
      if (!mounted) return;
      setState(() {
        MockData.serviceReviews.removeWhere((r) => r.providerName == provider.name);
        MockData.serviceReviews.insertAll(0, reviews);
      });
    } catch (_) {
      // Backend unreachable — keep whatever mock/local reviews already exist.
    }
  }

  // Bookings for the current resident that the provider has just marked
  // complete and that haven't been rated yet.
  List<ServiceBooking> get _pendingReviewBookings => MockData.serviceBookings
      .where((b) =>
          b.customerName == MockData.currentUser.fullName &&
          b.status == RequestStatus.completed &&
          !b.reviewed)
      .toList();

  @override
  Widget build(BuildContext context) {
    final provider = _provider;
    final reviews = MockData.reviewsForProvider(provider.name);
    final pendingBookings = _pendingReviewBookings;

    return Scaffold(
      appBar: AppBar(title: const Text('Service Reviews')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
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
                      Text('RATE YOUR EXPERIENCE', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.brass)),
                      const SizedBox(height: 6),
                      Text(
                        provider.name,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'serif'),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          RatingRow(
                            rating: MockData.providerAverageRating(provider),
                            reviews: MockData.providerReviewCount(provider),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            provider.serviceType,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.74)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.reviews_outlined, color: AppColors.brass, size: 36),
              ],
            ),
          ),
          if (pendingBookings.isNotEmpty) ...[
            const SizedBox(height: 20),
            SectionHeader(
              eyebrow: 'Action needed',
              title: '${pendingBookings.length} service${pendingBookings.length == 1 ? '' : 's'} awaiting your review',
            ),
            const SizedBox(height: 12),
            ...pendingBookings.map(
              (booking) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PendingReviewCard(
                  booking: booking,
                  onRate: () async {
                    final done = await showServiceRatingPrompt(context, booking);
                    if (done && mounted) setState(() {});
                  },
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: _providerName,
            decoration: const InputDecoration(
              labelText: 'Choose service provider',
              prefixIcon: Icon(Icons.handyman_outlined),
            ),
            items: MockData.serviceProviders
                .map(
                  (provider) => DropdownMenuItem<String>(
                    value: provider.name,
                    child: Text(provider.name, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _providerName = value);
              _loadReviews(_provider);
            },
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Share a review', style: Theme.of(context).textTheme.titleMedium),
                      ),
                      TextButton.icon(
                        onPressed: () => _openReviewSheet(provider),
                        icon: const Icon(Icons.rate_review_outlined, size: 18),
                        label: const Text('Write review'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Residents, tenants, and plot owners can rate out of 5 stars and leave written feedback after service completion.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SectionHeader(
            eyebrow: 'Latest feedback',
            title: '${reviews.length} recent review${reviews.length == 1 ? '' : 's'}',
          ),
          const SizedBox(height: 12),
          if (reviews.isEmpty)
            const EmptyState(
              icon: Icons.star_border_rounded,
              title: 'No reviews yet',
              message: 'Once residents submit feedback, it will appear here.',
            )
          else
            ...reviews.map(
              (review) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ReviewCard(review: review),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openReviewSheet(provider),
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('Add review'),
      ),
    );
  }

  Future<void> _openReviewSheet(ServiceProvider provider) async {
    final commentController = TextEditingController();
    var rating = 5;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Review ${provider.name}', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 6),
                  Text(provider.serviceType, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 18),
                  Text('Your rating', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: List.generate(
                      5,
                      (index) => IconButton(
                        onPressed: () => setModalState(() => rating = index + 1),
                        icon: Icon(
                          index < rating ? Icons.star_rounded : Icons.star_border_rounded,
                          color: AppColors.brass,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: commentController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Written review',
                      hintText: 'What went well? Was the service timely and professional?',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final comment = commentController.text.trim();
                        if (comment.isEmpty) {
                          showActionSnackBar(context, 'Please write a short review');
                          return;
                        }
                        ServiceReview review;
                        if (provider.id != null) {
                          try {
                            review = await runWithLoadingOverlay(
                              context,
                              () => BackendRepository.addProviderReview(
                                provider: provider,
                                rating: rating,
                                comment: comment,
                              ),
                              message: 'Submitting review…',
                            );
                          } on ApiException catch (e) {
                            if (mounted) showActionSnackBar(this.context, e.message);
                            return;
                          } catch (_) {
                            review = ServiceReview(
                              providerName: provider.name,
                              serviceType: provider.serviceType,
                              residentName: MockData.currentUser.fullName,
                              rating: rating,
                              comment: comment,
                              reviewedAt: DateTime.now(),
                            );
                          }
                        } else {
                          review = ServiceReview(
                            providerName: provider.name,
                            serviceType: provider.serviceType,
                            residentName: MockData.currentUser.fullName,
                            rating: rating,
                            comment: comment,
                            reviewedAt: DateTime.now(),
                          );
                        }
                        if (!mounted) return;
                        setState(() => MockData.serviceReviews.insert(0, review));
                        Navigator.of(context).pop();
                        showActionSnackBar(this.context, 'Review submitted successfully');
                      },
                      child: const Text('Submit review'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    commentController.dispose();
  }
}

/// Card shown when a booking the resident placed has just been marked
/// complete by the service provider and is still waiting for a rating.
class _PendingReviewCard extends StatelessWidget {
  final ServiceBooking booking;
  final VoidCallback onRate;

  const _PendingReviewCard({required this.booking, required this.onRate});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.paperDim,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.task_alt_outlined, color: AppColors.lake, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${booking.serviceType} service completed', style: Theme.of(context).textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('${booking.providerName} · ${booking.address}', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onRate,
                icon: const Icon(Icons.star_rounded, size: 18),
                label: const Text('Rate & review'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final ServiceReview review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(review.residentName, style: Theme.of(context).textTheme.titleMedium)),
                StatusPill(label: review.serviceType, color: AppColors.lake),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ...List.generate(
                  5,
                  (index) => Icon(
                    index < review.rating ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 18,
                    color: AppColors.brass,
                  ),
                ),
                const Spacer(),
                Text(_relativeTime(review.reviewedAt), style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
            const SizedBox(height: 10),
            Text(review.comment, style: Theme.of(context).textTheme.bodyLarge),
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
