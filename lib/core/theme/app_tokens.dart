import 'package:flutter/material.dart';

import 'app_palette.dart';

export 'app_palette.dart' show AppPalette, AppScrim, ToolAccent;

/// Design tokens exposed as a [ThemeExtension] so widgets read them from the
/// active [Theme] instead of importing raw palette constants.
///
/// This is the carrier; [AppPalette] is the content. There is one instance per
/// theme ([dark] / [light]) and Flutter picks between them, which is what makes
/// `context.colors.card` a different colour in the two without a single widget
/// asking which theme it is in.
///
/// The gradients are built here rather than in the palette because a
/// [LinearGradient] is geometry as well as colour, and the direction is a token
/// (fixed) while the stops are a palette value (per-theme).
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.colors,
    this.radiusCard = 18,
    this.radiusPanel = 22,
    this.radiusCanvas = 24,
    this.radiusChip = 14,
  });

  final AppPalette colors;

  final double radiusCard;
  final double radiusPanel;
  final double radiusCanvas;
  final double radiusChip;

  Gradient get heroGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: colors.heroGradient,
    stops: const [0.0, 0.45, 1.0],
  );

  Gradient get cutoutGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: colors.cutoutGradient,
  );

  Gradient get logoGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: colors.logoGradient,
  );

  Color accent(ToolAccent a) => colors.accent(a);

  static const AppTokens dark = AppTokens(colors: AppPalette.dark);
  static const AppTokens light = AppTokens(colors: AppPalette.light);

  @override
  AppTokens copyWith({
    AppPalette? colors,
    double? radiusCard,
    double? radiusPanel,
    double? radiusCanvas,
    double? radiusChip,
  }) {
    return AppTokens(
      colors: colors ?? this.colors,
      radiusCard: radiusCard ?? this.radiusCard,
      radiusPanel: radiusPanel ?? this.radiusPanel,
      radiusCanvas: radiusCanvas ?? this.radiusCanvas,
      radiusChip: radiusChip ?? this.radiusChip,
    );
  }

  @override
  AppTokens lerp(covariant AppTokens? other, double t) {
    if (other == null) return this;
    return AppTokens(
      colors: AppPalette.lerp(colors, other.colors, t),
      radiusCard: lerpDouble(radiusCard, other.radiusCard, t),
      radiusPanel: lerpDouble(radiusPanel, other.radiusPanel, t),
      radiusCanvas: lerpDouble(radiusCanvas, other.radiusCanvas, t),
      radiusChip: lerpDouble(radiusChip, other.radiusChip, t),
    );
  }

  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}

/// Ergonomic access: `context.colors.textMuted`, `context.tokens.radiusCard`,
/// `context.colors.accent(ToolAccent.text)`.
///
/// `colors` is the one to reach for - it is where every colour lives, and
/// reading it from the context is what makes a widget theme-aware. A colour
/// written as a constant in a widget file is a bug in the light theme by
/// construction, because a constant cannot vary.
extension AppTokensContext on BuildContext {
  /// Falls back to the pair matching the theme's brightness rather than
  /// throwing when the extension is absent. Any [ThemeData] has a brightness,
  /// so there is always a right answer, and the alternative is that a widget
  /// blows up under a bare `MaterialApp` - a dialog with its own theme, a
  /// package that wraps our subtree, or a widget test that only cares about
  /// layout. It cannot mask a mistake in the app itself: the fallback picks the
  /// same palette `buildAppTheme` would have installed.
  AppTokens get tokens {
    final theme = Theme.of(this);
    return theme.extension<AppTokens>() ??
        (theme.brightness == Brightness.light
            ? AppTokens.light
            : AppTokens.dark);
  }

  AppPalette get colors => tokens.colors;
}
