import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

/// A labeled slider row used across the Adjust, Text, Erase and Frames tools:
/// a title on the left, the current value on the right, and an accent-tinted
/// slider beneath. The value text defaults to the accent color (as the Adjust
/// panel uses); pass [valueColor] to override it (the Text/Erase/Frames panels
/// use a muted gray per the design).
class LabeledSlider extends StatelessWidget {
  const LabeledSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.accent,
    this.onChanged,
    this.onChangeEnd,
    this.valueLabel,
    this.valueColor,
    this.divisions,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final Color accent;
  final ValueChanged<double>? onChanged;

  /// Called when a drag gesture ends - used to close an undo step.
  final ValueChanged<double>? onChangeEnd;

  /// Text shown on the right (e.g. "118%"). Defaults to the rounded value.
  final String? valueLabel;

  /// Color of the value text. Defaults to [accent].
  final Color? valueColor;
  final int? divisions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 3),
          // The label yields, the value does not. Both used to be unconstrained
          // in a spaceBetween Row, so a long translation or a large text scale
          // simply pushed them into each other - and this widget backs every
          // slider in Adjust, Text, Erase and Frames, so it did it everywhere
          // at once. The value is the information ("118%", "12 px") and stays
          // whole; the label reads fine truncated.
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                valueLabel ?? value.round().toString(),
                style: TextStyle(
                  fontFamily: AppFonts.ui,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? accent,
                ),
              ),
            ],
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: accent,
            // The thumb is the one part that sits ON the track, so it
            // cannot be a fixed white: on the light theme that is the panel
            // colour. The accent reads against both halves of the track.
            thumbColor: context.colors.isLight ? accent : Colors.white,
            inactiveTrackColor: context.colors.border,
            overlayColor: accent.withValues(alpha: 0.18),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            // Without this a screen reader announces the thumb's position in
            // the range as a percentage, which is only the same thing as the
            // value by coincidence - and for Scale it is not: that slider is
            // driven in bar-position space over a curve, so a layer at 100%
            // would be read out as "25%". [valueLabel] is the number on
            // screen, so it is the one to say.
            semanticFormatterCallback: valueLabel == null
                ? null
                : (_) => valueLabel!,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ),
      ],
    );
  }
}
