import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/settings/settings_store.dart';
import '../core/theme/app_theme.dart';
import '../features/ads/ads_service.dart';
import '../features/fonts/custom_fonts.dart';
import '../features/go_pro/iap.dart';
import '../l10n/app_localizations.dart';
import 'router.dart';

/// Root shell. Resolves the first-run flag, then hosts a [MaterialApp.router]
/// starting on onboarding (first run) or Home. Holds the native splash colour
/// while the flag loads; fails open to Home if it can't be read.
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
      error: (_, _) => '/', // fail open — never trap the user on a splash
      orElse: () => null,
    );
    if (start == null) return const _Splash();
    return _RouterHost(initialLocation: start);
  }
}

/// Owns the per-instance [GoRouter] so navigation state never leaks between
/// tests and the router is disposed with the app.
class _RouterHost extends StatefulWidget {
  const _RouterHost({required this.initialLocation});

  final String initialLocation;

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
      theme: buildAppTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: _router,
    );
  }
}

/// A flat brand-colour hold shown only for the few milliseconds the first-run
/// flag takes to load. It matches the native splash background exactly
/// (`android_12.color` in pubspec), so the native OS splash stays the only
/// splash the user sees — it hands off to Home with no visible seam.
class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(backgroundColor: Color(0xFF0A1526)),
    );
  }
}
