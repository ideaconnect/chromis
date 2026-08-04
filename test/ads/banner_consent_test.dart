import 'package:chromis/core/models/project.dart';
import 'package:chromis/core/theme/app_theme.dart';
import 'package:chromis/features/ads/ads_service.dart';
import 'package:chromis/features/editor/widgets/project_canvas.dart';
import 'package:chromis/features/go_pro/iap.dart';
import 'package:chromis/features/home/home_screen.dart';
import 'package:chromis/features/home/project_repository.dart';
import 'package:chromis/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../support/surface.dart';

/// A user who turned ads off must not be shown one.
///
/// The Home slot read `canRequestAds` exactly once, when it mounted, so the two
/// halves of that promise were both broken: consent withdrawn from "Ad privacy
/// choices" left the banner sitting on screen for the rest of the session, and
/// consent granted there put nothing back until a cold start.
///
/// These pump the real [HomeScreen]. Nothing here may reach a real [BannerAd] -
/// the plugin's channel is unimplemented in a host test - which is exactly the
/// property the first test is asserting: refused consent means no request at
/// all, not a request that fails.
void main() {
  setUp(() {
    ProjectCanvas.fileExists = (_) => false;
    ProjectCanvas.existsCache.clear();
  });
  tearDown(() => ProjectCanvas.fileExists = ProjectCanvas.defaultFileExists);

  Future<AdsService> pumpHome(
    WidgetTester tester, {
    required bool consented,
  }) async {
    final ads = AdsService()..debugSetConsent(canRequestAds: consented);
    setSurface(tester, const Size(412, 915));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectRepositoryProvider.overrideWithValue(_EmptyRepo()),
          adsServiceProvider.overrideWithValue(ads),
          isProProvider.overrideWithValue(false),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: darkAppTheme,
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return ads;
  }

  testWidgets('consent refused: no banner, and no ad request to fail', (
    tester,
  ) async {
    await pumpHome(tester, consented: false);

    expect(find.byType(AdWidget), findsNothing);
    // The debug fallback to Google's always-filling test unit must not stand in
    // for a refusal - it exists for a unit that will not serve, not for a user
    // who said no. Reaching it here would mean an ad was requested.
    expect(find.byKey(const ValueKey('home-banner-dev-notice')), findsNothing);
    expect(
      tester.takeException(),
      isNull,
      reason: 'a request would have thrown MissingPluginException',
    );
  });

  testWidgets('consent withdrawn mid-session leaves the slot empty', (
    tester,
  ) async {
    final ads = await pumpHome(tester, consented: true);
    ads.debugSetConsent(canRequestAds: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AdWidget), findsNothing);
    expect(find.byKey(const ValueKey('home-banner-dev-notice')), findsNothing);
  });

  // What the test above CANNOT do: start from a banner that is actually on
  // screen. `AdWidget` is a platform view, so no host test can render one, and
  // the load here never completes. It pins that a withdrawal leaves nothing
  // behind and throws nothing; that an on-screen banner disappears is verified
  // on a device - drawer → Privacy → "Ad privacy choices" → decline.
  //
  // What IS testable is the wiring the slot depends on, so it is pinned here
  // rather than left to the widget test to imply.
  test('AdsService publishes a consent change to its listeners', () {
    final ads = AdsService();
    final seen = <bool>[];
    void listener() => seen.add(ads.canRequestAds);
    ads.canRequestAdsListenable.addListener(listener);
    addTearDown(() => ads.canRequestAdsListenable.removeListener(listener));

    expect(ads.canRequestAds, isTrue, reason: 'nothing refused yet');
    ads.debugSetConsent(canRequestAds: false);
    ads.debugSetConsent(canRequestAds: true);

    expect(seen, [false, true]);
    expect(ads.canRequestAds, isTrue);
  });

  testWidgets('the listener is dropped with the widget', (tester) async {
    final ads = await pumpHome(tester, consented: false);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    // A leaked listener would call setState on a dead State and throw here.
    ads.debugSetConsent(canRequestAds: true);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

class _EmptyRepo implements ProjectRepository {
  @override
  Future<List<Project>> list() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
