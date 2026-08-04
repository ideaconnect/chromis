import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_tokens.dart';
import 'app_typography.dart';

/// The app's [ThemeData], one per brightness.
///
/// Both are built from the same function so the two themes cannot drift into
/// being two designs: everything structural (shape, typography, slider metrics)
/// is written once, and only the [AppPalette] differs. A new component theme
/// added here lands in light and dark together.
ThemeData buildAppTheme(Brightness brightness) {
  final palette = brightness == Brightness.light
      ? AppPalette.light
      : AppPalette.dark;
  final tokens = brightness == Brightness.light
      ? AppTokens.light
      : AppTokens.dark;

  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: palette.cyan,
        brightness: brightness,
      ).copyWith(
        surface: palette.background,
        primary: palette.cyan,
        onPrimary: palette.onAccent,
        secondary: palette.pink,
        onSurface: palette.textPrimary,
        outline: palette.textFaint,
      );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: palette.background,
    canvasColor: palette.background,
    fontFamily: AppFonts.ui,
    textTheme: buildTextTheme(palette),
    // Material's own defaults are seeded from the primary, which puts a cyan
    // wash on every sheet and dialog. The app draws its own surfaces; these
    // just stop the framework painting a different one underneath.
    dialogTheme: DialogThemeData(backgroundColor: palette.panel),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: palette.panel),
    drawerTheme: DrawerThemeData(backgroundColor: palette.panel),
    dividerTheme: DividerThemeData(color: palette.border),
    iconTheme: IconThemeData(color: palette.textSecondary),
    splashFactory: InkRipple.splashFactory,
    sliderTheme: const SliderThemeData(
      trackHeight: 5,
      overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
    ),
    extensions: [tokens],
  );
}

/// Convenience for the two call sites that want a specific theme (the splash,
/// and any test that pumps one directly).
ThemeData get darkAppTheme => buildAppTheme(Brightness.dark);
ThemeData get lightAppTheme => buildAppTheme(Brightness.light);

/// The status- and navigation-bar treatment for [palette].
///
/// This has to be derived, not set once at startup: the app draws behind both
/// bars, so on the light theme white icons land on a white page and the
/// navigation bar is simply invisible. It is applied as an `AnnotatedRegion`
/// under the theme rather than through `SystemChrome`, so it follows a theme
/// change (including the device flipping to night mode) without anyone having
/// to remember to re-apply it.
SystemUiOverlayStyle systemOverlayStyleFor(AppPalette palette) {
  final icons = palette.isLight ? Brightness.dark : Brightness.light;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: icons,
    // iOS names the same thing after the BACKGROUND rather than the icons, so
    // this is the inverse of the line above, not a copy of it.
    statusBarBrightness: palette.brightness,
    systemNavigationBarColor: palette.background,
    systemNavigationBarDividerColor: palette.background,
    systemNavigationBarIconBrightness: icons,
  );
}
