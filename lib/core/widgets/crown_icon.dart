import 'package:flutter/widgets.dart';

/// A crown, drawn rather than picked from a font.
///
/// Material's icon set has no crown - `workspace_premium` is a rosette and
/// `emoji_events` a trophy - and the crown emoji renders in whatever colour and
/// shape the platform font decides, which is no use next to a tinted icon row.
/// So it is a path: it takes a colour like any other icon, scales cleanly, and
/// looks the same on every device.
class CrownIcon extends StatelessWidget {
  const CrownIcon({super.key, required this.color, this.size = 20});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _CrownPainter(color));
}

class _CrownPainter extends CustomPainter {
  const _CrownPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Authored on a 24x24 grid, the same one Material icons use, so the crown
    // sits at the same optical weight as its neighbours in the dock.
    final k = size.width / 24.0;
    double x(double v) => v * k;

    final paint = Paint()
      ..color = color
      ..isAntiAlias = true;

    // Band: the three peaks and two valleys, closed along the bottom.
    final band = Path()
      ..moveTo(x(2.4), x(6.6))
      ..lineTo(x(7.7), x(11.2))
      ..lineTo(x(12), x(4.2))
      ..lineTo(x(16.3), x(11.2))
      ..lineTo(x(21.6), x(6.6))
      ..lineTo(x(20.1), x(16.8))
      ..lineTo(x(3.9), x(16.8))
      ..close();
    canvas.drawPath(band, paint);

    // Base, separated from the band by a hairline gap - that gap is what reads
    // as a crown rather than a jagged blob at 20px. Deliberately no jewels:
    // at dock size they turn into noise, and the three-peak silhouette is
    // already unambiguous.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x(3.4), x(18.2), x(17.2), x(2.9)),
        Radius.circular(x(1.1)),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_CrownPainter old) => old.color != color;
}
