import 'package:chromis/core/rendering/resample.dart';
import 'package:chromis/core/theme/app_theme.dart';
import 'package:chromis/features/editor/widgets/canvas_size_sheet.dart';
import 'package:chromis/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/surface.dart';

/// The size sheet's Image tab - Resize image - and that it leaves the Canvas
/// tab and Home's new-project sheet as they were.
void main() {
  Future<List<CanvasSizeResult?>> open(
    WidgetTester tester, {
    bool allowImageResize = true,
    int width = 1080,
    int height = 1350,
    Size size = const Size(412, 915),
    Locale locale = const Locale('en'),
  }) async {
    setSurface(tester, size);
    final results = <CanvasSizeResult?>[];
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
                  await showCanvasSizeSheet(
                    context,
                    title: 'Canvas size',
                    initialWidth: width,
                    initialHeight: height,
                    allowScaleContent: true,
                    allowImageResize: allowImageResize,
                    confirmLabel: 'Apply',
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

  final imageTab = find.byKey(const ValueKey('size-mode-image'));
  final confirm = find.byKey(const ValueKey('size-sheet-confirm'));
  final imageWidth = find.byKey(const ValueKey('image-width'));
  final imageHeight = find.byKey(const ValueKey('image-height'));

  String text(WidgetTester tester, Finder field) =>
      tester.widget<TextField>(field).controller!.text;

  Future<void> apply(WidgetTester tester) async {
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
  }

  testWidgets('Home\'s new-project sheet has no Image tab', (tester) async {
    await open(tester, allowImageResize: false);
    expect(imageTab, findsNothing);
    expect(find.text('Canvas size'), findsOneWidget);
  });

  testWidgets('the Canvas tab still answers a canvas resize', (tester) async {
    final results = await open(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Width'), '800');
    await tester.pump();
    await apply(tester);
    final result = results.single!;
    expect(result.width, 800);
    expect(result.height, 1350); // the canvas tab does not link the two
    expect(result.resample, isNull);
  });

  testWidgets('width and height move together, in proportion', (tester) async {
    await open(tester);
    await tester.tap(imageTab);
    await tester.pump();
    expect(find.text('Image size'), findsOneWidget);

    await tester.enterText(imageWidth, '540');
    await tester.pump();
    expect(text(tester, imageHeight), '675');

    await tester.enterText(imageHeight, '2700');
    await tester.pump();
    expect(text(tester, imageWidth), '2160');
  });

  testWidgets('a percentage sets both, and Apply returns the method', (
    tester,
  ) async {
    final results = await open(tester);
    await tester.tap(imageTab);
    await tester.pump();
    await tester.tap(find.text('50%'));
    await tester.pump();
    expect(text(tester, imageWidth), '540');
    expect(text(tester, imageHeight), '675');

    await tester.tap(find.byKey(const ValueKey('resample-lanczos')));
    await tester.pump();
    // The selected method says what it looks like, not just its name.
    expect(find.textContaining('best for shrinking'), findsOneWidget);

    await apply(tester);
    final result = results.single!;
    expect(result.width, 540);
    expect(result.height, 675);
    expect(result.resample, ResampleMethod.lanczos);
  });

  testWidgets('the chosen method is remembered for the next resize', (
    tester,
  ) async {
    final results = await open(tester);
    await tester.tap(imageTab);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('resample-nearest')));
    await tester.tap(find.text('200%'));
    await tester.pump();
    await apply(tester);
    expect(results.single!.resample, ResampleMethod.nearest);

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(imageTab);
    await tester.pump();
    expect(
      tester.getSemantics(find.byKey(const ValueKey('resample-nearest'))),
      isSemantics(isSelected: true),
    );
  });

  testWidgets('the size it already is cannot be applied', (tester) async {
    await open(tester);
    await tester.tap(imageTab);
    await tester.pump();
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await tester.tap(find.text('75%'));
    await tester.pump();
    expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
  });

  testWidgets('a size past the canvas bounds is refused', (tester) async {
    // 200% of 6000 is past the 8192 canvas limit, so that shortcut is not
    // offered and typing it leaves Apply off.
    await open(tester, width: 6000, height: 4000);
    await tester.tap(imageTab);
    await tester.pump();
    expect(find.text('200%'), findsNothing);
    expect(find.text('150%'), findsNothing);
    expect(find.text('75%'), findsOneWidget);
    await tester.enterText(imageWidth, '9000');
    await tester.pump();
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
  });

  // Prose, four chips and two tabs, each up to a third longer in German.
  // SheetBody caps and scrolls it, so what has to hold is that nothing throws
  // and Apply can still be reached.
  for (final locale in AppLocalizations.supportedLocales) {
    for (final (name, size) in const [
      ('360dp phone', Size(360, 640)),
      ('landscape', Size(780, 360)),
    ]) {
      testWidgets('the Image tab fits a $name in ${locale.languageCode}', (
        tester,
      ) async {
        await open(tester, size: size, locale: locale);
        await tester.tap(imageTab);
        await tester.pump();
        for (final method in ResampleMethod.values) {
          await tester.ensureVisible(
            find.byKey(ValueKey('resample-${method.name}')),
          );
          await tester.tap(find.byKey(ValueKey('resample-${method.name}')));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: '$method');
        }
        await tester.ensureVisible(confirm);
        await tester.pump();
        expect(tester.getRect(confirm).bottom, lessThanOrEqualTo(size.height));
      });
    }
  }
}
