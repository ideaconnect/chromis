import 'dart:io';

import 'package:chromis/core/theme/app_theme.dart';
import 'package:chromis/features/ads/ad_gate.dart';
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
    var ran = false;
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
    expect(ran, isTrue, reason: 'Pro passes straight through');
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
      if (rel.endsWith('lib/features/ads/ads_service.dart'))
        continue; // declares it
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
}
