import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

/// A compact rounded "pill" button used for actions like Reset, Add, Play/Pause
/// and the font chips. Tints to [accent] when [selected].
class PillChip extends StatelessWidget {
  const PillChip({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.accent,
    this.selected = false,
    this.labelStyle,
    this.radius = 20,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  /// The tint when [selected]. Nullable because the default is a theme colour
  /// and a default argument has to be a constant - it resolves to the Layers
  /// accent in [build], where there is a context to read it from.
  final Color? accent;

  final bool selected;

  /// Overrides the label text style (e.g. to preview a caption font).
  final TextStyle? labelStyle;

  /// Corner radius. Fully-rounded pills use 20 (default); the squarer font
  /// swatches use 12.
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = this.accent ?? colors.violet;
    final fg = selected ? accent : colors.textSecondary;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: icon != null ? 12 : 15,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.15)
                : colors.inputField,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: selected ? accent : colors.border,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: fg),
                const SizedBox(width: 5),
              ],
              // Flexible + ellipsis, so a caller that bounds this chip gets a
              // shortened label instead of an overflow stripe. The Row is
              // still mainAxisSize.min, so an unbounded chip is exactly as
              // wide as its label and nothing changes where it already fitted.
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      labelStyle ??
                      TextStyle(
                        fontFamily: AppFonts.ui,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: fg,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
