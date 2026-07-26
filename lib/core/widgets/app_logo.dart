import 'package:flutter/material.dart';

/// The app's brand mark (the icon tile artwork), for in-app lockups.
///
/// The asset is the whole tile with its own corners already baked in and
/// transparency outside them, so it is drawn directly - no clip, no chip behind
/// it. Clipping it again only fights those corners: at the sizes this is used
/// the surrounding design's radius is roughly twice the tile's own 15.5%, which
/// would trim the silhouette and leave the in-app mark rounder than the same
/// tile on the website. [radius] therefore shapes [shadow] and nothing else.
///
/// No light plate: this tile's gradient is mid-tone teal and reads on
/// `AppColors.panel` unaided. (The icon this replaced was #0A2127, within a
/// couple of steps of the panel, and did need one - if the artwork ever goes
/// dark again, that is the fix.)
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    required this.size,
    required this.radius,
    this.shadow = const <BoxShadow>[],
  });

  final double size;

  /// Corner radius of [shadow]. The artwork's own corners are unaffected.
  final double radius;

  final List<BoxShadow> shadow;

  static const String assetPath = 'assets/branding/logo.png';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Chromis logo',
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: shadow,
        ),
        child: Image.asset(
          assetPath,
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
