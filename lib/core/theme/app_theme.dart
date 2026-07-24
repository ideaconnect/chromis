import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_tokens.dart';
import 'app_typography.dart';

/// The single source of truth for the app's (dark-only) [ThemeData].
ThemeData buildAppTheme() {
  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.cyan,
        brightness: Brightness.dark,
      ).copyWith(
        surface: AppColors.background,
        primary: AppColors.cyan,
        secondary: AppColors.pink,
        onSurface: AppColors.textPrimary,
      );

  final textTheme = buildTextTheme();

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.background,
    canvasColor: AppColors.background,
    fontFamily: AppFonts.ui,
    textTheme: textTheme,
    splashFactory: InkRipple.splashFactory,
    sliderTheme: const SliderThemeData(
      trackHeight: 5,
      overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
    ),
    extensions: const [AppTokens.dark],
  );
}
