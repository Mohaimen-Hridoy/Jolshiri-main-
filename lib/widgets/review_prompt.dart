import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../models/app_models.dart';
import '../services/api_client.dart';
import '../services/backend_repository.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Quick-reaction shown alongside the star rating on the "rate & review"
/// prompt that appears once a service provider marks a booking completed
/// (Part 6: Service Provider Directory — post-completion review flow).
enum ServiceReaction { happy, sad, angry }

extension _ReactionMeta on ServiceReaction {
  String get emoji => switch (this) {
        ServiceReaction.happy => '😊',
        ServiceReaction.sad => '😢',
        ServiceReaction.angry => '😠',
      };
  String get label => switch (this) {
        ServiceReaction.happy => 'Very good',
        ServiceReaction.sad => 'Good',
        ServiceReaction.angry => 'Bad',
      };
  int get rating => switch (this) {
        ServiceReaction.happy => 5,
        ServiceReaction.sad => 3,
        ServiceReaction.angry => 1,
      };
}

/// Shows the "rate & review" bottom sheet for a booking the provider has
/// just marked as completed. Star rating + a quick emoji reaction are both
/// supported and stay in sync; the written review is always optional, so a
/// resident can submit with just a tap.
///
/// Returns true once a review has actually been submitted.
Future<bool> showServiceRatingPrompt(BuildContext context, ServiceBooking booking) async {
  final commentController = TextEditingController();
  int rating = 5;
  ServiceReaction? reaction = ServiceReaction.happy;
  bool submitted = false;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (sheetContext, setModalState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.of(sheetContext).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.task_alt_outlined, color: AppColors.lake, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${booking.serviceType} service completed',
                        style: Theme.of(sheetContext).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  "How was ${booking.providerName}'s service?",
                  style: Theme.of(sheetContext).textTheme.headlineSmall,
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: ServiceReaction.values.map((r) {
                    final selected = reaction == r;
                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => setModalState(() {
                        reaction = r;
                        rating = r.rating;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.paperDim : Colors.transparent,
                          border: Border.all(
                            color: selected ? AppColors.brass : AppColors.inkFaint.withValues(alpha: 0.3),
                            width: selected ? 1.6 : 1,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Text(r.emoji, style: const TextStyle(fontSize: 30)),
                            const SizedBox(height: 6),
                            Text(
                              r.label,
                              style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                Text('Your rating', style: Theme.of(sheetContext).textTheme.titleMedium),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  children: List.generate(
                    5,
                    (index) => IconButton(
                      onPressed: () => setModalState(() {
                        rating = index + 1;
                        reaction = null;
                      }),
                      icon: Icon(
                        index < rating ? Icons.star_rounded : Icons.star_border_rounded,
                        color: AppColors.brass,
                        size: 30,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: commentController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Detailed review (optional)',
                    hintText: 'Anything else about the service?',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final comment = commentController.text.trim();
                      ServiceProvider? matched;
                      for (final p in MockData.serviceProviders) {
                        if (p.name == booking.providerName) {
                          matched = p;
                          break;
                        }
                      }

                      ServiceReview review;
                      if (matched != null && matched.id != null) {
                        try {
                          review = await runWithLoadingOverlay(
                            sheetContext,
                            () => BackendRepository.addProviderReview(
                              provider: matched!,
                              rating: rating,
                              comment: comment,
                            ),
                            message: 'Submitting review…',
                          );
                        } on ApiException catch (e) {
                          if (sheetContext.mounted) showActionSnackBar(sheetContext, e.message);
                          return;
                        } catch (_) {
                          review = ServiceReview(
                            providerName: booking.providerName,
                            serviceType: booking.serviceType,
                            residentName: MockData.currentUser.fullName,
                            rating: rating,
                            comment: comment,
                            reviewedAt: DateTime.now(),
                          );
                        }
                      } else {
                        review = ServiceReview(
                          providerName: booking.providerName,
                          serviceType: booking.serviceType,
                          residentName: MockData.currentUser.fullName,
                          rating: rating,
                          comment: comment,
                          reviewedAt: DateTime.now(),
                        );
                      }

                      MockData.serviceReviews.insert(0, review);
                      booking.reviewed = true;
                      if (booking.id != null) {
                        // Best-effort — local state above already reflects it.
                        BackendRepository.markBookingReviewed(booking.id!).catchError((_) {});
                      }
                      submitted = true;
                      if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                    },
                    child: const Text('Submit rating'),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('Maybe later'),
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
  if (submitted && context.mounted) {
    showActionSnackBar(context, 'Thanks for your feedback!');
  }
  return submitted;
}
