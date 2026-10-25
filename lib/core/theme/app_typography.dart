import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Font families bundled in `assets/fonts` and declared in `pubspec.yaml`.
abstract final class AppFonts {
  AppFonts._();

  /// Primary UI / body typeface.
  static const String ui = 'Manrope';

  /// Display / heading typeface.
  static const String display = 'SpaceGrotesk';

  // Text caption typefaces (used inside the canvas, offered in the Text tool).
  static const String bangers = 'Bangers';
  static const String luckiestGuy = 'LuckiestGuy';
  static const String pacifico = 'Pacifico';
  static const String rubik = 'Rubik';
  static const String comicNeue = 'ComicNeue';
  static const String kalam = 'Kalam';
  static const String patrickHand = 'PatrickHand';
  static const String caveatBrush = 'CaveatBrush';
  static const String mali = 'Mali';
  static const String titanOne = 'TitanOne';
  static const String bungee = 'Bungee';
  static const String anton = 'Anton';
  static const String lobster = 'Lobster';
  static const String shrikhand = 'Shrikhand';
  static const String pressStart2P = 'PressStart2P';
  static const String specialElite = 'SpecialElite';

  /// The caption fonts offered in the Text and Bubble font pickers, in
  /// display order. The first five keep their places from before the set
  /// grew; lettering faces lead the rest because a bubble is what most of
  /// them were picked for.
  static const List<String> bundledFonts = [
    bangers,
    luckiestGuy,
    pacifico,
    display,
    rubik,
    comicNeue,
    kalam,
    patrickHand,
    caveatBrush,
    mali,
    titanOne,
    bungee,
    anton,
    lobster,
    shrikhand,
    pressStart2P,
    specialElite,
  ];

  /// The family keys are identity - saved projects carry them - so they keep
  /// the pubspec's spelling; this is what the picker shows instead.
  static const Map<String, String> _names = {
    luckiestGuy: 'Luckiest Guy',
    display: 'Space Grotesk',
    comicNeue: 'Comic Neue',
    patrickHand: 'Patrick Hand',
    caveatBrush: 'Caveat Brush',
    titanOne: 'Titan One',
    pressStart2P: 'Press Start 2P',
    specialElite: 'Special Elite',
  };

  /// [family] as a person would write it. A typeface's name is a proper noun
  /// and is not translated; an imported or device family is returned as is.
  static String nameOf(String family) => _names[family] ?? family;
}

/// Builds the app-wide [TextTheme] on the primary UI font, in [palette]'s ink.
///
/// Takes the palette rather than reading a constant: the default text colour is
/// the one thing every screen inherits, so getting it from the theme is what
/// keeps an unstyled `Text` legible in light as well as dark.
TextTheme buildTextTheme(AppPalette palette) {
  final base = TextStyle(fontFamily: AppFonts.ui, color: palette.textPrimary);
  return TextTheme(
    displayLarge: base.copyWith(
      fontFamily: AppFonts.display,
      fontWeight: FontWeight.w700,
    ),
    displayMedium: base.copyWith(
      fontFamily: AppFonts.display,
      fontWeight: FontWeight.w600,
    ),
    headlineSmall: base.copyWith(
      fontFamily: AppFonts.display,
      fontSize: 20,
      fontWeight: FontWeight.w700,
    ),
    titleLarge: base.copyWith(fontSize: 17, fontWeight: FontWeight.w600),
    titleMedium: base.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
    bodyLarge: base.copyWith(fontSize: 14, fontWeight: FontWeight.w500),
    bodyMedium: base.copyWith(fontSize: 13, fontWeight: FontWeight.w500),
    bodySmall: base.copyWith(fontSize: 12, color: palette.textMuted),
    labelLarge: base.copyWith(fontSize: 13, fontWeight: FontWeight.w700),
    labelMedium: base.copyWith(fontSize: 11.5, fontWeight: FontWeight.w600),
    labelSmall: base.copyWith(
      fontSize: 10.5,
      fontWeight: FontWeight.w600,
      color: palette.textMuted,
    ),
  );
}
