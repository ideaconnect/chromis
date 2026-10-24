import 'dart:async';

import 'package:chromis/core/widgets/on_screen_only.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Home banner's `AdWidget` sits in [OnScreenOnly] (#67): a route under an
/// opaque one stays mounted, and a platform view in it stays attached and
/// rendering. No host test can render the ad itself, so this pins the rule
/// the slot relies on, against a real Navigator.
///
/// Every finder here passes `skipOffstage: false`. The default skips offstage
/// widgets, and a covered route IS offstage - so the default would report the
/// child gone while it was still mounted, which is exactly the state that kept
/// the banner's WebView alive.
void main() {
  const adKey = ValueKey('ad');
  final ad = find.byKey(adKey, skipOffstage: false);

  Future<NavigatorState> pumpHome(WidgetTester tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: const Scaffold(
          body: OnScreenOnly(
            child: SizedBox(key: adKey, width: 320, height: 50),
          ),
        ),
      ),
    );
    return navigator.currentState!;
  }

  Route<void> editor() =>
      MaterialPageRoute(builder: (_) => const Scaffold(body: Text('editor')));

  testWidgets('a route pushed over it takes the child out of the tree', (
    tester,
  ) async {
    final nav = await pumpHome(tester);
    expect(ad, findsOneWidget);

    unawaited(nav.push(editor()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      ad,
      findsOneWidget,
      reason: 'still visible while the route slides in',
    );

    await tester.pumpAndSettle();
    expect(ad, findsNothing, reason: 'covered: the platform view must go');
  });

  testWidgets('popping back puts it back as the pop starts', (tester) async {
    final nav = await pumpHome(tester);
    unawaited(nav.push(editor()));
    await tester.pumpAndSettle();
    expect(ad, findsNothing);

    nav.pop();
    await tester.pump();
    // Home is visible again from the first frame of the pop, so the ad has to
    // be there for it rather than popping in after the transition.
    expect(ad, findsOneWidget);
    await tester.pumpAndSettle();
    expect(ad, findsOneWidget);
  });

  testWidgets('a dialog over it leaves it alone', (tester) async {
    final nav = await pumpHome(tester);
    unawaited(
      showDialog<void>(
        context: nav.context,
        builder: (_) => const AlertDialog(content: Text('dialog')),
      ),
    );
    await tester.pumpAndSettle();
    // The page is still on screen behind the scrim, so is the ad.
    expect(ad, findsOneWidget);
  });
}
