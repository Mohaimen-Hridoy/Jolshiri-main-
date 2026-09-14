import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';

/// Swaps a submit button's label for a small spinner while [loading] is
/// true. Used on actions that hit the network and can take a moment —
/// booking a service, requesting a viewing, filing a complaint, scheduling
/// a meeting, paying — so the person sees the app is working instead of a
/// button that looks frozen.
Widget submitButtonChild(bool loading, String label, {Color color = Colors.white}) {
  if (!loading) return Text(label);
  return SizedBox(
    width: 20,
    height: 20,
    child: CircularProgressIndicator(strokeWidth: 2.4, color: color),
  );
}

/// A small non-dismissible "please wait" overlay for actions that take a
/// moment — calling/booking a service provider, requesting a quote,
/// approving a construction stage, filing an incident report, applying for
/// a soil test permit, etc. — anywhere a plain button tap kicks off a
/// network round trip with no other loading affordance nearby, so the
/// screen never looks frozen while it waits on the backend.
Future<T> runWithLoadingOverlay<T>(
  BuildContext context,
  Future<T> Function() action, {
  String message = 'Please wait…',
}) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.md),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 6))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(strokeWidth: 2.6, color: AppColors.parade),
              const SizedBox(height: 14),
              Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    ),
  );
  try {
    return await action();
  } finally {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  }
}

/// An "eyebrow + title" section header used to open each screen section.
class SectionHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final Widget? trailing;

  const SectionHeader({super.key, required this.eyebrow, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(eyebrow.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.brass)),
              const SizedBox(height: 4),
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Small pill used for status / category labels.
class StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const StatusPill({super.key, required this.label, required this.color});

  factory StatusPill.status(String status) {
    final c = switch (status.toLowerCase()) {
      'available' || 'resolved' || 'open now' => AppColors.lake,
      'reserved' || 'in progress' || 'open' => AppColors.brass,
      'sold' => AppColors.brick,
      _ => AppColors.inkFaint,
    };
    return StatusPill(label: status, color: c);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700)),
    );
  }
}

/// A verified checkmark badge for developers / service providers.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return const Tooltip(
      message: 'Verified by Jolshiri Authority',
      child: Icon(Icons.verified, size: 16, color: AppColors.lake),
    );
  }
}

/// Star rating row, e.g. ★ 4.6 (58)
class RatingRow extends StatelessWidget {
  final double rating;
  final int? reviews;

  const RatingRow({super.key, required this.rating, this.reviews});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 16, color: AppColors.brass),
        const SizedBox(width: 2),
        Text(rating.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        if (reviews != null) ...[
          const SizedBox(width: 4),
          Text('($reviews)', style: const TextStyle(color: AppColors.inkFaint, fontSize: 12.5)),
        ],
      ],
    );
  }
}

/// A quick-access tile used on the Home Dashboard grid.
class QuickAccessTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const QuickAccessTile({super.key, required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final tileColor = color ?? AppColors.parade;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: tileColor.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: tileColor, size: 22),
            ),
            const SizedBox(height: 8),
            // FittedBox scales the label down instead of overflowing when a
            // longer two-line label (e.g. "Flat View Requests") doesn't
            // quite fit the grid cell's fixed height.
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A 16:9 listing image (plot / rental) with graceful loading and error
/// placeholders, so a broken or slow URL never breaks the card layout.
/// When [bytes] is provided (image picked from device) it is shown instead
/// of loading [url] from the network.
class ListingImage extends StatelessWidget {
  final String url;
  final Uint8List? bytes;
  final double height;

  const ListingImage({super.key, required this.url, this.bytes, this.height = 170});

  static Widget _placeholder() => Container(
        color: AppColors.paperDim,
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported_outlined, color: AppColors.inkFaint, size: 32),
      );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: bytes != null
          ? Image.memory(bytes!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder())
          : url.startsWith('assets/')
          ? Image.asset(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder())
          : Image.network(
              url,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: AppColors.paperDim,
                  alignment: Alignment.center,
                  child: const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.parade),
                  ),
                );
              },
              errorBuilder: (context, error, stack) => _placeholder(),
            ),
    );
  }
}

/// Empty-state placeholder shown when a list has no items yet.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const EmptyState({super.key, required this.icon, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.inkFaint),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// A form field that lets the user pick an image from their device gallery.
/// Shows a preview once picked and calls [onChanged] with the raw bytes.
class ImagePickerField extends StatefulWidget {
  final String label;
  final ValueChanged<Uint8List?> onChanged;

  const ImagePickerField({super.key, required this.label, required this.onChanged});

  @override
  State<ImagePickerField> createState() => _ImagePickerFieldState();
}

class _ImagePickerFieldState extends State<ImagePickerField> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _bytes;
  bool _loading = false;

  Future<void> _pick() async {
    setState(() => _loading = true);
    try {
      final file = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
      if (file != null) {
        final bytes = await file.readAsBytes();
        if (!mounted) return;
        setState(() => _bytes = bytes);
        widget.onChanged(bytes);
      }
    } catch (_) {
      if (mounted) showActionSnackBar(context, 'Could not open the gallery');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _clear() {
    setState(() => _bytes = null);
    widget.onChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (_bytes != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            child: Stack(
              children: [
                Image.memory(_bytes!, height: 150, width: double.infinity, fit: BoxFit.cover),
                Positioned(
                  top: 6,
                  right: 6,
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.black54,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: _clear,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          InkWell(
            onTap: _loading ? null : _pick,
            borderRadius: BorderRadius.circular(AppRadii.sm),
            child: Container(
              height: 110,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadii.sm),
                border: Border.all(color: AppColors.line),
              ),
              child: Center(
                child: _loading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.parade))
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_photo_alternate_outlined, color: AppColors.parade, size: 30),
                          const SizedBox(height: 6),
                          Text('Choose from device', style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
              ),
            ),
          ),
        if (_bytes != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _pick,
              icon: const Icon(Icons.swap_horiz, size: 18),
              label: const Text('Change image'),
            ),
          ),
      ],
    );
  }
}

/// Simple confirmation SnackBar used after form submissions.
void showActionSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: AppColors.paradeDark,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}
