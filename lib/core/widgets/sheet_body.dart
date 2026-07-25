import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Standard body for the app's bottom sheets: the grab handle, the usual
/// padding, and - the part that matters - a scroll view bounded to the height
/// actually available.
///
/// A sheet is a `Column(mainAxisSize: min)` of fixed-height controls, which is
/// fine until the viewport is short: a phone in landscape leaves ~400 logical
/// px, and a sheet authored for a tall screen then overflows instead of
/// scrolling, taking part of itself out of reach. Every sheet grew that bug the
/// moment the app was allowed to rotate, so the fix lives in one place.
///
/// Also keeps the sheet clear of the keyboard ([MediaQuery.viewInsetsOf]) and
/// of the system gesture bar ([SafeArea]).
class SheetBody extends StatelessWidget {
  const SheetBody({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(20, 14, 20, 20),
  });

  final List<Widget> children;
  final EdgeInsets padding;

  /// The most of the screen a sheet may take before it starts scrolling.
  /// Short of 1.0 so the sheet still reads as a sheet - you can see there is a
  /// screen behind it, and the scrim stays tappable to dismiss.
  static const double maxHeightFraction = 0.92;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: media.size.height * maxHeightFraction,
      ),
      child: SafeArea(
        top: false,
        // NO ResponsiveCenter here, deliberately. Its Center takes the height
        // it is offered, and what is offered is maxHeightFraction of the
        // screen - so the sheet stopped hugging its content and became a
        // near-full-height panel with everything floating in the middle of it.
        //
        // The width cap it was there for is unnecessary anyway: Material
        // already constrains a modal bottom sheet to 640 on a wide screen.
        // The scroll view sizing itself to its child is what keeps a sheet
        // sheet-shaped, so nothing may sit between it and the constraint.
        child: SingleChildScrollView(
          padding: padding.copyWith(
            bottom: padding.bottom + media.viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _GrabHandle(),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _GrabHandle extends StatelessWidget {
  const _GrabHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.elevated,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
