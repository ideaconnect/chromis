import 'package:flutter/material.dart';

/// Raw color tokens taken directly from the approved design
/// (`Chromis BG Removal.dc.html`). This is a dark-only app with no
/// theme switching, so widgets may reference these semantic constants directly.
/// Gradients, radii, per-tool accents and any value that could vary with a
/// future theme are exposed through [AppTokens]; read those from the [Theme].
abstract final class AppColors {
  AppColors._();

  // Surfaces (dark theme only) — deep navy from the mockup.
  static const Color pageBackground = Color(0xFF060D16);
  static const Color background = Color(0xFF0A1826);
  static const Color panel = Color(0xFF0E1C2C);
  static const Color card = Color(0xFF0E1C2C);
  static const Color cardAlt = Color(0xFF12233A);
  static const Color inputField = Color(0xFF12233A);
  static const Color chipSurface = Color(0xFF12233A);
  static const Color elevated = Color(0xFF17324A);

  // Text.
  static const Color textPrimary = Color(0xFFEAF1F8);
  static const Color textSecondary = Color(0xFF9FBCD6);
  static const Color textMuted = Color(0xFF7F93A8);
  static const Color textFaint = Color(0xFF5F7488);

  // Accents — each editor tool owns one.
  static const Color violet = Color(0xFF8FA0F5); // Layers
  static const Color cyan = Color(0xFF17B6D6); // Adjust / selection / primary
  static const Color pink = Color(0xFFE87896); // Text / object
  static const Color amber = Color(0xFFE6B84A); // Erase
  static const Color green = Color(0xFF35D0A0); // AI Cut / background removed
  static const Color orange = Color(0xFFF0885A); // Frames

  // Accent support tints.
  static const Color violetBright = Color(0xFF17B6D6); // primary (cyan)
  static const Color violetLight = Color(0xFF7FD6EA); // light cyan
  static const Color magenta = Color(0xFF6C7FE0); // hero-gradient midpoint
  static const Color greenLight = Color(0xFF6EE7C4);
  static const Color teal = Color(0xFF22D3EE);
  static const Color rose = Color(0xFFF08AA0); // destructive
  static const Color cutoutInk = Color(0xFF04121A); // ink on accent buttons
  static const Color neutralButton = Color(0xFF12233A);

  // Hairline borders.
  static const Color border = Color(0x14FFFFFF); // ~8% white
  static const Color borderFaint = Color(0x0FFFFFFF); // ~6% white

  // Gradient stops.
  static const List<Color> heroGradient = [violetBright, magenta, pink];
  static const List<Color> cutoutGradient = [green, teal];
  static const List<Color> logoGradient = [cyan, pink];
}
