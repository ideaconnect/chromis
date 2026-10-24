import 'package:chromis/core/theme/app_theme.dart';
import 'package:chromis/features/editor/widgets/fill_quality_sheet.dart';
import 'package:chromis/features/segmentation/fill_quality.dart';
import 'package:chromis/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/surface.dart';

/// The first-fill prompt (#68). The editor tests drive it from a real tap;
/// these pin what it returns and that it fits.
void main() {
  /// Opens the sheet from a button and returns what it resolved to, via
  /// [result] once it closes.
  Future<List<FillQuality?>> open(
    WidgetTester tester, {
    FillQuality recommended = FillQuality.best,
    Size size = const Size(412, 915),
    Locale locale = const Locale('en'),
  }) async {
    setSurface(tester, size);
    final results = <FillQuality?>[];
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: darkAppTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async => results.add(
                  await FillQualitySheet.show(
                    context,
                    recommended: recommended,
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return results;
  }

  Finder option(FillQuality q) => find.byKey(ValueKey('fill-quality-${q.id}'));

  testWidgets('Continue with no change takes the recommendation', (
    tester,
  ) async {
    final results = await open(tester, recommended: FillQuality.lowMemory);
    expect(
      tester.getSemantics(option(FillQuality.lowMemory)),
      isSemantics(isChecked: true),
    );
    // One badge, on the recommended option only.
    expect(find.text('Recommended for this phone'), findsOneWidget);
    expect(
      find.descendant(
        of: option(FillQuality.lowMemory),
        matching: find.text('Recommended for this phone'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('fill-quality-continue')));
    await tester.pumpAndSettle();
    expect(results, [FillQuality.lowMemory]);
  });

  testWidgets('picking the other one returns that one', (tester) async {
    final results = await open(tester, recommended: FillQuality.lowMemory);
    await tester.tap(find.text('Best quality'));
    await tester.pump();
    expect(
      tester.getSemantics(option(FillQuality.best)),
      isSemantics(isChecked: true),
    );

    await tester.tap(find.byKey(const ValueKey('fill-quality-continue')));
    await tester.pumpAndSettle();
    expect(results, [FillQuality.best]);
  });

  testWidgets('dismissing it answers nothing', (tester) async {
    final results = await open(tester);
    await tester.tapAt(const Offset(20, 20)); // the scrim
    await tester.pumpAndSettle();
    expect(results, [null]);
  });

  // No other sweep pumps sheets in every language, and this one is all prose:
  // two titles, two descriptions and a badge, each up to a third longer in
  // German. SheetBody caps and scrolls it, so what has to hold is that nothing
  // throws and Continue can still be reached.
  for (final locale in AppLocalizations.supportedLocales) {
    for (final (name, size) in const [
      ('360dp phone', Size(360, 640)),
      ('landscape', Size(780, 360)),
    ]) {
      testWidgets('fits a $name in ${locale.languageCode}', (tester) async {
        await open(tester, size: size, locale: locale);
        expect(tester.takeException(), isNull);
        final cont = find.byKey(const ValueKey('fill-quality-continue'));
        await tester.ensureVisible(cont);
        await tester.pump();
        expect(tester.getRect(cont).bottom, lessThanOrEqualTo(size.height));
      });
    }
  }
}
