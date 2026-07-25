import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The on-canvas text caption: fill text with a chunky contrasting outline
/// and a drop shadow - the defining bold-caption look from the design
/// (`WebkitTextStroke` + `paint-order: stroke fill`). Rendered as two stacked
/// [Text] layers with identical layout so the glyphs register exactly.
class TextCaption extends StatelessWidget {
  const TextCaption({
    super.key,
    required this.text,
    required this.fontFamily,
    required this.fontSize,
    this.color = Colors.white,
    this.rotation = -0.087, // ~ -5deg
    this.strokeWidth = 3.5,
    this.strokeColor,
    this.strokeOpacity = 1.0,
    this.scale = 1.0,
    this.decorative = false,
  });

  final String text;
  final String fontFamily;
  final double fontSize;
  final Color color;
  final double rotation;

  /// Outline thickness in 512-canvas units; 0 draws the fill alone.
  final double strokeWidth;

  /// Explicit outline color, or null for the automatic contrast pick.
  final Color? strokeColor;

  /// 0.0 … 1.0
  final double strokeOpacity;

  /// Canvas scale (`side / 512`) so the outline thickness, drop-shadow offset
  /// and letter tracking stay proportional to [fontSize] - matching the 512-px
  /// export drawn by `ProjectRenderer._paintText`, which is the WYSIWYG
  /// reference. At `1.0` (the export at 512) these equal the reference values
  /// (3.5-px stroke, `Offset(0, 4)` shadow, `letterSpacing` 1); the editor
  /// canvas and its thumbnails pass their own smaller scale so the preview no
  /// longer draws a proportionally chunkier outline than the exported image.
  final double scale;

  /// A plain glyph with no outline/shadow - used for emoji & prop layers (#61).
  final bool decorative;

  /// The outline color actually used: [strokeColor] when set, else the
  /// automatic contrast pick - light fills (white / amber) get a dark outline,
  /// everything else white. Shared with `ProjectRenderer._paintText`.
  static Color resolveStrokeColor(Color fill, Color? explicit, double opacity) {
    final base =
        explicit ??
        ((fill == Colors.white || fill == AppColors.amber)
            ? const Color(0xFF14101A)
            : Colors.white);
    return opacity >= 1
        ? base
        : base.withValues(alpha: base.a * opacity.clamp(0.0, 1.0));
  }

  bool get _hasStroke =>
      !decorative && strokeWidth > 0.01 && strokeOpacity > 0.001;

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      height: 1,
      letterSpacing: 1 * scale,
      fontWeight: FontWeight.w700,
    );

    // Emoji / prop, or a caption with its outline turned off: a plain glyph.
    // With no outline there is no drop shadow either - the outline is what
    // carried it, and a layer shadow does that job properly now.
    if (!_hasStroke) {
      return Transform.rotate(
        angle: rotation,
        child: Text(text, style: baseStyle.copyWith(color: color)),
      );
    }

    return Transform.rotate(
      angle: rotation,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outline layer (carries the drop shadow, drawn behind the fill).
          Text(
            text,
            style: baseStyle.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = strokeWidth * scale
                ..strokeJoin = StrokeJoin.round
                ..color = resolveStrokeColor(color, strokeColor, strokeOpacity),
              shadows: [
                Shadow(
                  color: const Color(0x40000000),
                  offset: Offset(0, 4 * scale),
                ),
              ],
            ),
          ),
          // Fill layer.
          Text(text, style: baseStyle.copyWith(color: color)),
        ],
      ),
    );
  }
}
