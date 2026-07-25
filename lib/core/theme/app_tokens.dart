import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Design tokens exposed as a [ThemeExtension] so widgets read them from the
/// active [Theme] instead of importing raw palette constants. Mirrors the
/// tokens in the approved app design.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.panel,
    required this.card,
    required this.cardAlt,
    required this.inputField,
    required this.border,
    required this.textMuted,
    required this.textSecondary,
    required this.accents,
    required this.heroGradient,
    required this.cutoutGradient,
    required this.logoGradient,
    required this.radiusCard,
    required this.radiusPanel,
    required this.radiusCanvas,
    required this.radiusChip,
  });

  final Color panel;
  final Color card;
  final Color cardAlt;
  final Color inputField;
  final Color border;
  final Color textMuted;
  final Color textSecondary;

  /// Per-tool accent colors, keyed by [ToolAccent].
  final Map<ToolAccent, Color> accents;

  final Gradient heroGradient;
  final Gradient cutoutGradient;
  final Gradient logoGradient;

  final double radiusCard;
  final double radiusPanel;
  final double radiusCanvas;
  final double radiusChip;

  Color accent(ToolAccent a) => accents[a]!;

  static const AppTokens dark = AppTokens(
    panel: AppColors.panel,
    card: AppColors.card,
    cardAlt: AppColors.cardAlt,
    inputField: AppColors.inputField,
    border: AppColors.border,
    textMuted: AppColors.textMuted,
    textSecondary: AppColors.textSecondary,
    accents: {
      ToolAccent.layers: AppColors.violet,
      ToolAccent.adjust: AppColors.cyan,
      ToolAccent.text: AppColors.pink,
      ToolAccent.erase: AppColors.amber,
      ToolAccent.cutout: AppColors.green,
      ToolAccent.frames: AppColors.orange,
      ToolAccent.grid: AppColors.violet,
    },
    heroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: AppColors.heroGradient,
      stops: [0.0, 0.45, 1.0],
    ),
    cutoutGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: AppColors.cutoutGradient,
    ),
    logoGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: AppColors.logoGradient,
    ),
    radiusCard: 18,
    radiusPanel: 22,
    radiusCanvas: 24,
    radiusChip: 14,
  );

  @override
  AppTokens copyWith({
    Color? panel,
    Color? card,
    Color? cardAlt,
    Color? inputField,
    Color? border,
    Color? textMuted,
    Color? textSecondary,
    Map<ToolAccent, Color>? accents,
    Gradient? heroGradient,
    Gradient? cutoutGradient,
    Gradient? logoGradient,
    double? radiusCard,
    double? radiusPanel,
    double? radiusCanvas,
    double? radiusChip,
  }) {
    return AppTokens(
      panel: panel ?? this.panel,
      card: card ?? this.card,
      cardAlt: cardAlt ?? this.cardAlt,
      inputField: inputField ?? this.inputField,
      border: border ?? this.border,
      textMuted: textMuted ?? this.textMuted,
      textSecondary: textSecondary ?? this.textSecondary,
      accents: accents ?? this.accents,
      heroGradient: heroGradient ?? this.heroGradient,
      cutoutGradient: cutoutGradient ?? this.cutoutGradient,
      logoGradient: logoGradient ?? this.logoGradient,
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
      panel: Color.lerp(panel, other.panel, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardAlt: Color.lerp(cardAlt, other.cardAlt, t)!,
      inputField: Color.lerp(inputField, other.inputField, t)!,
      border: Color.lerp(border, other.border, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      accents: t < 0.5 ? accents : other.accents,
      heroGradient: Gradient.lerp(heroGradient, other.heroGradient, t)!,
      cutoutGradient: Gradient.lerp(cutoutGradient, other.cutoutGradient, t)!,
      logoGradient: Gradient.lerp(logoGradient, other.logoGradient, t)!,
      radiusCard: lerpDouble(radiusCard, other.radiusCard, t),
      radiusPanel: lerpDouble(radiusPanel, other.radiusPanel, t),
      radiusCanvas: lerpDouble(radiusCanvas, other.radiusCanvas, t),
      radiusChip: lerpDouble(radiusChip, other.radiusChip, t),
    );
  }

  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}

/// The editor tools, each with its own accent color.
enum ToolAccent { layers, adjust, text, erase, cutout, frames, grid }

/// Ergonomic access: `context.tokens.accent(ToolAccent.text)`.
extension AppTokensContext on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}
