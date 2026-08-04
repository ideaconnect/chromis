import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

/// The primary call-to-action: a rounded button with an optional leading icon.
/// By default it is gradient-filled with a soft glow (used for "New project",
/// "Export", "Remove background"). Pass [solidColor] for a flat, shadowless
/// variant (e.g. the muted "Undo removal" state).
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.gradient,
    this.solidColor,
    this.foreground,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    this.fontSize = 15.5,
    this.glowColor,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Gradient fill. Defaults to the hero gradient from [AppTokens]. Ignored when
  /// [solidColor] is set.
  final Gradient? gradient;

  /// When set, the button renders a flat solid fill with no glow, overriding
  /// [gradient].
  final Color? solidColor;

  /// Icon + label color. Nullable because the default is a theme colour and a
  /// default argument has to be a constant: it resolves to the palette's ink
  /// for a filled accent, which is near-black on dark and white on light.
  final Color? foreground;

  final EdgeInsets padding;
  final double fontSize;
  final Color? glowColor;

  /// When true, shows a spinner and ignores taps.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final solid = solidColor != null;
    final ink = foreground ?? context.colors.onAccent;
    final grad = solid ? null : (gradient ?? tokens.heroGradient);
    final glow = glowColor ?? context.colors.violetBright;
    final enabled = onPressed != null && !busy;

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Opacity(
        opacity: enabled ? 1 : 0.7,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: solidColor,
            gradient: grad,
            borderRadius: BorderRadius.circular(16),
            boxShadow: solid
                ? null
                : [
                    BoxShadow(
                      color: glow.withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: enabled ? onPressed : null,
              child: Padding(
                padding: padding,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (busy)
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation(ink),
                        ),
                      )
                    else if (icon != null)
                      Icon(icon, size: 19, color: ink),
                    if (busy || icon != null) const SizedBox(width: 9),
                    // Flexible, so a caller that caps this button's width (the
                    // editor top bar does, to keep room for the project title)
                    // gets an ellipsis instead of an overflow stripe. The Row
                    // is still mainAxisSize.min, so an uncapped button is
                    // exactly as wide as its label - nothing changes at the
                    // sizes this already fitted.
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppFonts.ui,
                          color: ink,
                          fontSize: fontSize,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
