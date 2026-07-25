import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/models/grid.dart';

/// A miniature of a Photo Grid layout: the template's cells as filled rounded
/// rects, laid out by the same [layoutGrid] the editor and the export renderer
/// use, so a preview can never disagree with what the layout actually produces.
///
/// Sizes itself to its parent's constraints; the caller picks the box (and its
/// aspect, so a portrait collage previews as portrait).
class GridTemplatePreview extends StatelessWidget {
  const GridTemplatePreview({
    super.key,
    required this.root,
    required this.color,
    this.gapFraction = 0.07,
    this.radiusFraction = 0.07,
  });

  final GridNode root;
  final Color color;

  /// Gap between cells as a fraction of the box's shorter side.
  final double gapFraction;

  /// Cell corner radius as a fraction of the box's shorter side.
  final double radiusFraction;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: CustomPaint(
        painter: _MiniGridPainter(
          root: root,
          color: color,
          gapFraction: gapFraction,
          radiusFraction: radiusFraction,
        ),
      ),
    );
  }
}

class _MiniGridPainter extends CustomPainter {
  _MiniGridPainter({
    required this.root,
    required this.color,
    required this.gapFraction,
    required this.radiusFraction,
  });

  final GridNode root;
  final Color color;
  final double gapFraction;
  final double radiusFraction;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final unit = math.min(size.width, size.height);
    // No outer margin: the preview fills its tile and the caller pads.
    final layout = layoutGrid(
      GridSpec(root: root, borderWidth: unit * gapFraction, outerMargin: 0),
      size,
    );
    final paint = Paint()..color = color;
    final radius = Radius.circular(unit * radiusFraction);
    for (final rect in layout.cells.values) {
      canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), paint);
    }
  }

  @override
  bool shouldRepaint(_MiniGridPainter old) =>
      old.root != root ||
      old.color != color ||
      old.gapFraction != gapFraction ||
      old.radiusFraction != radiusFraction;
}
