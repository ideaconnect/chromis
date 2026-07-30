import 'dart:io';

import 'package:chromis/core/theme/app_theme.dart';
import 'package:chromis/features/ads/ad_gate.dart';
import 'package:chromis/features/ads/ads_service.dart';
import 'package:chromis/features/go_pro/iap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The one prompt that stands between a free user and an ad.
///
/// Its whole job is to make "buy Pro once" as visible as "watch an ad" - if the
/// upgrade is easy to miss, the only way out of ads is effectively hidden. These
/// tests pin that the choice exists, that neither option is styled as an
/// afterthought, and - the structural one - that no future gate can reach the
/// rewarded ad without going through here.
void main() {
  final watch = find.byKey(const ValueKey('ad-gate-watch'));
  final goPro = find.byKey(const ValueKey('ad-gate-go-pro'));

  Future<void> pumpSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(
            body: AdGateSheet(
              title: 'Unlock AI tools',
              message: 'Watch a short ad, or go Pro.',
              watchLabel: 'Watch & unlock',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('offers both a watch and a Go Pro option', (tester) async {
    await pumpSheet(tester);
    expect(watch, findsOneWidget, reason: 'the ad option must be offered');
    expect(
      goPro,
      findsOneWidget,
      reason: 'the paid upgrade is the only way out of ads - it must be here',
    );
    expect(find.text('Watch & unlock'), findsOneWidget);
    expect(find.textContaining('Go Pro'), findsOneWidget);
    // Says it is a one-off, because "Pro" alone reads as a subscription.
    expect(find.textContaining('One-time'), findsOneWidget);
  });

  testWidgets('neither option is styled as an afterthought', (tester) async {
    await pumpSheet(tester);
    final w = tester.getSize(watch);
    final p = tester.getSize(goPro);
    // Same height and full width apiece. The bug this replaced was a dialog
    // where Go Pro was a bare text button beside Cancel, so "both are present"
    // is not enough of an assertion - they have to carry the same weight.
    expect(
      p.height,
      w.height,
      reason: 'Go Pro must be as tall a target as Watch',
    );
    expect(
      p.width,
      moreOrLessEquals(w.width, epsilon: 1),
      reason: 'Go Pro must be as wide as Watch',
    );
    expect(
      tester.getTopLeft(goPro).dy,
      greaterThan(tester.getTopLeft(watch).dy),
      reason: 'watch stays the default action, directly above the upgrade',
    );
  });

  testWidgets('each button reports its own choice', (tester) async {
    for (final (finder, expected) in [
      (watch, AdGateChoice.watch),
      (goPro, AdGateChoice.goPro),
    ]) {
      AdGateChoice? got;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async =>
                      got = await showModalBottomSheet<AdGateChoice>(
                        context: context,
                        builder: (_) => const AdGateSheet(
                          title: 't',
                          message: 'm',
                          watchLabel: 'Watch & unlock',
                        ),
                      ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
      expect(got, expected);
    }
  });

  testWidgets('a Pro user is never asked', (tester) async {
    AdGateOutcome? ran;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [isProProvider.overrideWithValue(true)],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  ran = await AdGate.run(
                    context,
                    ref,
                    title: 't',
                    message: 'm',
                    watchLabel: 'w',
                  );
                },
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(ran, AdGateOutcome.allowed, reason: 'Pro passes straight through');
    expect(watch, findsNothing, reason: 'and is shown no prompt at all');
  });

  test('the rewarded ad is only reachable through AdGate', () {
    // Structural, deliberately. The failure this guards against is a NEW gate
    // being added that calls showRewarded() directly and so never offers the
    // upgrade - which is invisible in any per-screen test, because the screen
    // that forgot it is the one nobody wrote a test for.
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final rel = f.path.replaceAll(r'\', '/');
      if (rel.endsWith('lib/features/ads/ad_gate.dart')) continue;
      if (rel.endsWith('lib/features/ads/ads_service.dart')) {
        continue; // declares it
      }
      for (final (i, line) in f.readAsLinesSync().indexed) {
        // Calls only - doc comments referencing [showRewarded] are fine.
        if (line.contains('showRewarded(') &&
            !line.trimLeft().startsWith('///')) {
          offenders.add('$rel:${i + 1}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'these call AdsService.showRewarded() directly and so skip the '
          'watch-or-go-Pro prompt; route them through AdGate.run instead',
    );
  });

  testWidgets('reports which ending it reached, not just pass/fail', (
    tester,
  ) async {
    // The regression this guards: AdGate.run once returned a bare bool, so the
    // AI gate could not tell "the ad did not count" from "they chose Go Pro" or
    // "they closed the sheet" - and fired its "watch the full ad" nag on all
    // three, including on top of the Go Pro screen the user had just opened.
    AdGateOutcome? outcome;
    Future<void> pump(WidgetTester tester) async {
      outcome = null;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [isProProvider.overrideWithValue(false)],
          child: MaterialApp(
            theme: buildAppTheme(),
            // A real Navigator, so pushing Go Pro from inside the gate works.
            routes: {'/pro': (_) => const Scaffold(body: Text('PRO'))},
            home: Consumer(
              builder: (context, ref, _) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    outcome = await AdGate.run(
                      context,
                      ref,
                      title: 't',
                      message: 'm',
                      watchLabel: 'w',
                    );
                  },
                  child: const Text('go'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
    }

    // Dismissed: tap the scrim above the sheet.
    await pump(tester);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(
      outcome,
      AdGateOutcome.dismissed,
      reason: 'closing the sheet is an answer, and must be distinguishable',
    );
    expect(outcome!.allows, isFalse);
  });

  _consentGateTests();

  test('only one outcome lets the action through', () {
    // If a new ending is added, it must be a deliberate decision whether it
    // proceeds - so the mapping is pinned rather than left to `!= dismissed`.
    expect(AdGateOutcome.values.where((o) => o.allows), [
      AdGateOutcome.allowed,
    ]);
  });
}

// ---------------------------------------------------------------------------
// Consent-blocked gate.
//
// An ad is the price of a free export, so a user whose consent choice switched
// ads off must not simply be waved through - that was the hole: `showRewarded`
// fails open on a missing ad, and "the user refused ads" looked identical to
// "AdMob had no fill", so declining consent quietly bought the whole free tier.
// ---------------------------------------------------------------------------

/// Consent state without a platform UMP round-trip, which no host test can do.
class _FakeAds extends AdsService {
  _FakeAds({required this.allowed, this.grantsOnAsk = false});

  bool allowed;

  /// Whether answering the re-opened form turns ads back on.
  final bool grantsOnAsk;

  int asked = 0;
  int watched = 0;

  @override
  bool get canRequestAds => allowed;

  @override
  Future<bool> requestConsent({void Function(String message)? onError}) async {
    asked++;
    if (grantsOnAsk) allowed = true;
    return allowed;
  }

  @override
  Future<bool> showRewarded() async {
    watched++;
    return true;
  }
}

void _consentGateTests() {
  final watch = find.byKey(const ValueKey('ad-gate-watch'));
  final goPro = find.byKey(const ValueKey('ad-gate-go-pro'));
  final consent = find.byKey(const ValueKey('ad-gate-consent'));
  final warning = find.byKey(const ValueKey('ad-gate-consent-warning'));

  Future<void> pumpSheet(WidgetTester tester, _FakeAds ads) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isProProvider.overrideWithValue(false),
          adsServiceProvider.overrideWithValue(ads),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(
            body: AdGateSheet(
              title: 'Watch a short ad to export',
              message: 'Free exports are supported by a short ad.',
              watchLabel: 'Watch & export',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('consent refused: watch is disabled and says why', (
    tester,
  ) async {
    await pumpSheet(tester, _FakeAds(allowed: false));

    expect(warning, findsOneWidget, reason: 'the state must be explained');
    expect(
      tester.widget<FilledButton>(watch).onPressed,
      isNull,
      reason: 'there is no ad to watch, so the action must be greyed out',
    );
    // Both ways out are named, and the upgrade still works.
    expect(consent, findsOneWidget);
    expect(tester.widget<OutlinedButton>(goPro).onPressed, isNotNull);
    expect(find.textContaining('Allow ads'), findsOneWidget);
    expect(find.textContaining('go Pro'), findsOneWidget);
  });

  testWidgets('allowing ads from the sheet re-enables watch in place', (
    tester,
  ) async {
    final ads = _FakeAds(allowed: false, grantsOnAsk: true);
    await pumpSheet(tester, ads);
    expect(tester.widget<FilledButton>(watch).onPressed, isNull);

    await tester.tap(consent);
    await tester.pumpAndSettle();

    expect(ads.asked, 1, reason: 'the consent form must be re-opened');
    expect(
      tester.widget<FilledButton>(watch).onPressed,
      isNotNull,
      reason: 'consent given - the ad is available without reopening the sheet',
    );
    expect(warning, findsNothing);
  });

  testWidgets('declining again leaves the gate closed', (tester) async {
    final ads = _FakeAds(allowed: false);
    await pumpSheet(tester, ads);
    await tester.tap(consent);
    await tester.pumpAndSettle();

    expect(ads.asked, 1);
    expect(warning, findsOneWidget, reason: 'still no ad, still explained');
    expect(tester.widget<FilledButton>(watch).onPressed, isNull);
  });

  testWidgets('the gate re-asks on the way in, and reports adsDeclined', (
    tester,
  ) async {
    final ads = _FakeAds(allowed: false);
    AdGateOutcome? outcome;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isProProvider.overrideWithValue(false),
          adsServiceProvider.overrideWithValue(ads),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  outcome = await AdGate.run(
                    context,
                    ref,
                    title: 't',
                    message: 'm',
                    watchLabel: 'w',
                  );
                },
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(
      ads.asked,
      1,
      reason: 'a user who turned ads off is asked again before being refused',
    );

    await tester.tapAt(const Offset(10, 10)); // dismiss
    await tester.pumpAndSettle();
    expect(
      outcome,
      AdGateOutcome.adsDeclined,
      reason:
          'distinct from `dismissed`, so callers do not tell someone to watch '
          'an ad that does not exist',
    );
    expect(outcome!.allows, isFalse, reason: 'and the export must not happen');
    expect(ads.watched, 0);
  });

  testWidgets('an allowed user is never asked and keeps the plain sheet', (
    tester,
  ) async {
    final ads = _FakeAds(allowed: true);
    await pumpSheet(tester, ads);
    expect(warning, findsNothing);
    expect(tester.widget<FilledButton>(watch).onPressed, isNotNull);
    expect(ads.asked, 0, reason: 'nothing to re-ask - do not nag');
  });

  test('showRewarded does not fail open when consent forbids ads', () async {
    // The backstop behind the disabled button, and the actual hole this closes:
    // `showRewarded` returns true when there is no ad, so before this a user
    // who declined consent got every gated action for free - indistinguishable
    // from a no-fill.
    //
    // Only the refused branch is asserted here. The fail-open branch it must
    // NOT disturb reaches `RewardedInterstitialAd.load`, and the AdMob channel
    // carries its own message codec that the test messenger cannot encode for,
    // so exercising it on the host is not possible; the gate-level tests above
    // cover the allowed path instead.
    final blocked = AdsService()..debugSetConsent(canRequestAds: false);
    expect(await blocked.showRewarded(), isFalse);
  });
}
