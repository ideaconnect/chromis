import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The app's brand mark (the icon tile artwork), for in-app lockups.
///
/// The artwork is a pre-rounded tile, so it is drawn directly rather than inside
/// another chip. What it does need is a ground: the tile's fill is #0A2127,
/// within a few steps of [AppColors.panel], so on the app's own surfaces it
/// dissolves into them and only the brush and wordmark read. [plate] therefore
/// fills [radius] with [AppColors.brandPlate] and insets the tile inside it, the
/// same 7.5% `tool/gen_branding.py` bakes into the splash - so the splash and
/// this lockup show the same proportions. Pass `plate: false` where the ground is
/// already light.
///
/// [shadow] carries the surrounding chip's depth.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    required this.size,
    required this.radius,
    this.shadow = const <BoxShadow>[],
    this.plate = true,
  });

  final double size;
  final double radius;
  final List<BoxShadow> shadow;
  final bool plate;

  static const String assetPath = 'assets/branding/logo.png';

  /// Plate edge to tile edge, as a fraction of [size].
  static const double _pad = 0.075;

  @override
  Widget build(BuildContext context) {
    final double inset = plate ? size * _pad : 0;
    return Semantics(
      container: true,
      label: 'Chromis logo',
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: plate ? AppColors.brandPlate : null,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: shadow,
        ),
        padding: EdgeInsets.all(inset),
        child: ClipRRect(
          // Concentric with the plate, so the two curves do not fight.
          borderRadius: BorderRadius.circular(math.max(0, radius - inset)),
          child: Image.asset(assetPath, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
