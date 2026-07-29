import 'package:flutter/material.dart';

import '../../../core/models/layer.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sheet_body.dart';
import 'bubble_view.dart';

/// The user-facing name of a bubble format. One source of truth for the
/// creation sheet and the Bubble panel's format row.
String bubbleShapeLabel(BubbleShape shape) => switch (shape) {
  BubbleShape.speech => 'Speech',
  BubbleShape.thought => 'Thought',
  BubbleShape.shout => 'Shout',
  BubbleShape.caption => 'Caption',
  BubbleShape.whisper => 'Whisper',
};

/// What the format actually looks like, in the words someone would go looking
/// for it by. The names alone hid four of the five formats: nobody guesses that
/// "Caption" is the square box, "Shout" the star, or "Whisper" the line
/// outline - so the picker prints this under the drawing.
String bubbleShapeBlurb(BubbleShape shape) => switch (shape) {
  BubbleShape.speech => 'Rounded, with a tail',
  BubbleShape.thought => 'Cloud with a dot trail',
  BubbleShape.shout => 'Spiky star burst',
  BubbleShape.caption => 'Square narration box',
  BubbleShape.whisper => 'Dashed line outline',
};

/// Asks which comic-bubble format to add, drawing every one. Returns null when
/// the sheet is dismissed without a choice - the caller then adds nothing.
///
/// Creation used to jump straight to a speech bubble, so the other four formats
/// existed only for someone who had already found the Bubble panel's format
/// row; and a bubble appearing with no warning under a panel titled "Text" read
/// as "the Text tool opened", not as "a bubble was added".
Future<BubbleShape?> showBubbleShapeSheet(BuildContext context) {
  return showModalBottomSheet<BubbleShape>(
    context: context,
    // So the sheet may use the height it needs; SheetBody caps and scrolls it.
    isScrollControlled: true,
    backgroundColor: AppColors.panel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SheetBody(
      children: [
        const Text(
          'Add a bubble',
          style: TextStyle(
            fontFamily: AppFonts.display,
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Pick a format. The text, colours and tail are all editable '
          'afterwards - and so is this.',
          style: TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 12,
            height: 1.35,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (_, constraints) {
            // Two up on a phone, three once there is room - a landscape phone
            // is wide and short, which is exactly when a two-column stack of
            // five tiles starts scrolling for no reason.
            const spacing = 10.0;
            final columns = constraints.maxWidth >= 460 ? 3 : 2;
            final width =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final shape in BubbleShape.values)
                  SizedBox(
                    width: width,
                    child: BubbleShapeTile(
                      shape: shape,
                      showBlurb: true,
                      // Bigger than the panel row's: this is where the choice
                      // is actually made, and a scalloped edge or a dashed
                      // outline is unreadable at chip size.
                      thumbWidth: 88,
                      keyPrefix: 'bubble-format',
                      onTap: () => Navigator.of(ctx).pop(shape),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

/// Padding, gap and label metrics of a [BubbleShapeTile]. Exposed only so the
/// panel row can size itself; nothing else should need them.
const double _tilePadV = 10;
const double _tileGap = 8;
const double _tileLabelSize = 12.5;
const double _tileBlurbSize = 10.5;
const double _tileLineHeight = 1.35;

/// The height a [BubbleShapeTile] wants at this [context]'s text scale.
///
/// The Bubble panel puts the tiles in a horizontal list, which needs a fixed
/// cross-axis extent - and a hard-coded one overflows as soon as the system
/// font scale goes up, because the tile ends in a text label. Scaling the label
/// (and, with [showBlurb], the two reserved description lines) is what keeps a
/// large-font device from showing the yellow overflow stripe.
double bubbleShapeTileHeight(
  BuildContext context, {
  required double thumbWidth,
  bool showBlurb = false,
}) {
  final scaler = MediaQuery.textScalerOf(context);
  final thumbHeight =
      thumbWidth * kBubbleBaseSize.height / kBubbleBaseSize.width;
  // Text terms are rounded up individually, and a pixel of slack is added on
  // top: a laid-out line box is not exactly fontSize x height - the engine's
  // own rounding was enough to overflow an exactly-computed box by 0.1px.
  var height =
      _tilePadV * 2 +
      2 + // the 1px border, top and bottom
      thumbHeight +
      _tileGap +
      (scaler.scale(_tileLabelSize) * _tileLineHeight).ceilToDouble() +
      1;
  if (showBlurb) {
    height +=
        2 + (scaler.scale(_tileBlurbSize) * _tileLineHeight * 2).ceilToDouble();
  }
  return height.ceilToDouble();
}

/// A tappable bubble format: the shape drawn by the real painter, its name, and
/// optionally what it looks like.
///
/// Shared by the creation sheet and the Bubble panel's format row so the two can
/// never offer different formats - or draw the same format differently.
class BubbleShapeTile extends StatelessWidget {
  BubbleShapeTile({
    required this.shape,
    required this.onTap,
    required this.thumbWidth,
    this.selected = false,
    this.showBlurb = false,
    String keyPrefix = 'bubble-shape',
  }) : super(key: ValueKey('$keyPrefix-${shape.name}'));

  final BubbleShape shape;
  final VoidCallback onTap;
  final bool selected;
  final bool showBlurb;
  final double thumbWidth;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return Semantics(
      button: true,
      selected: selected,
      label: '${bubbleShapeLabel(shape)} bubble - ${bubbleShapeBlurb(shape)}',
      // The label already reads the name and the description; without this the
      // child Text nodes make a screen reader say both of them a second time.
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: _tilePadV,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.pink.withValues(alpha: 0.16)
                : AppColors.cardAlt,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.pink : AppColors.borderFaint,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              BubbleShapeThumb(shape: shape, width: thumbWidth),
              const SizedBox(height: _tileGap),
              Text(
                bubbleShapeLabel(shape),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppFonts.ui,
                  fontSize: _tileLabelSize,
                  height: _tileLineHeight,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.pink : AppColors.textSecondary,
                ),
              ),
              if (showBlurb) ...[
                const SizedBox(height: 2),
                // Two lines are reserved whether or not this blurb needs both,
                // so tiles sharing a row in the picker's Wrap line up instead
                // of ending at three different heights.
                SizedBox(
                  height: scaler.scale(_tileBlurbSize) * _tileLineHeight * 2,
                  child: Text(
                    bubbleShapeBlurb(shape),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: _tileBlurbSize,
                      height: _tileLineHeight,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A miniature of [shape] painted by [BubblePainter] itself, so a format looks
/// in the picker exactly like the layer it will create - no hand-drawn icons to
/// drift away from the real paths.
class BubbleShapeThumb extends StatelessWidget {
  const BubbleShapeThumb({super.key, required this.shape, required this.width});

  final BubbleShape shape;
  final double width;

  @override
  Widget build(BuildContext context) {
    // The painter is written against [kBubbleBaseSize]'s proportions (tail band
    // included), so the thumb has to keep that aspect or the tail is clipped.
    final height = width * kBubbleBaseSize.height / kBubbleBaseSize.width;
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: BubblePainter(
          BubbleLayer(id: 'preview', name: 'Bubble', shape: shape),
        ),
      ),
    );
  }
}
