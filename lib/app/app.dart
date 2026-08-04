import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/settings/locale_controller.dart';
import '../core/settings/settings_store.dart';
import '../core/settings/theme_controller.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_tokens.dart';
import '../features/ads/ads_service.dart';
import '../features/fonts/custom_fonts.dart';
import '../features/go_pro/iap.dart';
import '../l10n/app_localizations.dart';
import 'router.dart';

/// Root shell. Resolves the first-run flag and the saved UI language, then
/// hosts a [MaterialApp.router] starting on onboarding (first run) or Home.
/// Holds the native splash colour while they load; fails open to Home in the
/// device's language if they can't be read.
class ChromisApp extends ConsumerWidget {
  const ChromisApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Activate IAP purchase delivery for the app's lifetime (acknowledge +
    // grant the Go Pro entitlement, including purchases that complete later).
    ref.watch(purchaseDeliveryProvider);
    // Initialize AdMob + UMP consent once (no-op thereafter).
    ref.watch(adsInitProvider);
    // Load + register user-imported fonts once, so they render immediately.
    ref.watch(customFontsProvider);
    final seen = ref.watch(onboardingSeenProvider);
    final start = seen.maybeWhen(
      data: (v) => v ? '/' : '/onboarding',
      error: (_, _) => '/', // fail open - never trap the user on a splash
      orElse: () => null,
    );
    // Held on the splash too: rendering a frame before the saved language is
    // known would show the device's language and then swap, and the first
    // frame is Home or onboarding - the two screens most worth getting right.
    final locale = ref.watch(localeControllerProvider);
    // Held for the same reason as the language, and it matters more: rendering
    // before the saved appearance is known would show one theme and then swap,
    // which on a phone set to dark is a full-screen white flash.
    final themeMode = ref.watch(themeModeControllerProvider);
    if (start == null || locale.isLoading || themeMode.isLoading) {
      return const _Splash();
    }
    return _RouterHost(
      initialLocation: start,
      // null on error as well as on "never chose": follow the device.
      locale: locale.asData?.value,
      // system on error, likewise - the device's setting is the safe answer.
      themeMode: themeMode.asData?.value ?? ThemeMode.system,
    );
  }
}

/// Owns the per-instance [GoRouter] so navigation state never leaks between
/// tests and the router is disposed with the app.
class _RouterHost extends StatefulWidget {
  const _RouterHost({
    required this.initialLocation,
    required this.locale,
    required this.themeMode,
  });

  final String initialLocation;

  /// The user's chosen appearance, or [ThemeMode.system] to follow the device.
  final ThemeMode themeMode;

  /// The user's chosen language, or null to follow the device. Changing it
  /// rebuilds this widget without recreating its [GoRouter], so switching
  /// language in Settings re-renders in place instead of resetting navigation.
  final Locale? locale;

  @override
  State<_RouterHost> createState() => _RouterHostState();
}

class _RouterHostState extends State<_RouterHost> {
  late final GoRouter _router = createAppRouter(
    initialLocation: widget.initialLocation,
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: lightAppTheme,
      darkTheme: darkAppTheme,
      themeMode: widget.themeMode,
      locale: widget.locale,
      localeListResolutionCallback: resolveAppLocale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: _router,
      // Inside the builder, so `context` is below the Theme and the system bars
      // follow whichever of the two is live. Setting them once in `main` cannot
      // work: the app draws behind both bars, so the light theme needs dark
      // icons, and nothing would re-apply them when the device flips to night.
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: systemOverlayStyleFor(context.colors),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}

/// A flat brand-colour hold shown only for the few milliseconds the first-run
/// flag takes to load. It matches the native splash background exactly
/// (`android_12.color` in pubspec), so the native OS splash stays the only
/// splash the user sees - it hands off to Home with no visible seam.
///
/// Deliberately NOT theme-aware, and it is the one screen that must not be:
/// the colour it has to match is baked into the Android manifest by
/// `flutter_native_splash` and is on screen before any Dart runs, so it cannot
/// know the user's override. Following the theme here would replace a seamless
/// hand-off with a visible cut on every launch.
class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: darkAppTheme,
      localeListResolutionCallback: resolveAppLocale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(backgroundColor: Color(0xFF0A1526)),
    );
  }
}
