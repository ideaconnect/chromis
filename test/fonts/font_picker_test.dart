import 'dart:io';

import 'package:chromis/core/theme/app_theme.dart';
import 'package:chromis/core/theme/app_typography.dart';
import 'package:chromis/features/fonts/custom_fonts.dart';
import 'package:chromis/features/fonts/device_fonts.dart';
import 'package:chromis/features/fonts/font_picker.dart';
import 'package:chromis/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/surface.dart';

/// The font picker: one field in the panel, one searchable list behind it, in
/// three sections - bundled, imported, the device's own.
void main() {
  /// Two device families, one of which is a twin of a bundled font.
  const device = [
    DeviceFontFamily('Roboto', '/system/fonts/Roboto-Regular.ttf'),
    DeviceFontFamily('Space Grotesk', '/product/fonts/SpaceGrotesk.ttf'),
  ];

  Future<List<FontPick?>> open(
    WidgetTester tester, {
    String current = AppFonts.bangers,
    List<DeviceFontFamily> deviceFonts = device,
    List<CustomFont> imported = const [CustomFont('My Hand', 'My Hand.ttf')],
    Size size = const Size(412, 915),
    Locale locale = const Locale('en'),
    double textScale = 1,
    double keyboard = 0,
    CustomFontsController Function()? importer,
  }) async {
    setSurface(tester, size);
    final results = <FontPick?>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceFontsProvider.overrideWithValue(
            DeviceFonts(directories: const []),
          ),
          deviceFontFamiliesProvider.overrideWith((ref) async => deviceFonts),
          customFontsProvider.overrideWith(
            importer ?? () => _Imported(imported),
          ),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: darkAppTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              viewInsets: EdgeInsets.only(bottom: keyboard),
            ),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async => results.add(
                    await showFontPicker(
                      context,
                      current: current,
                      accent: Colors.pink,
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  final list = find.byKey(const ValueKey('font-list'));
  final search = find.byKey(const ValueKey('font-search'));
  Finder option(String family) =>
      find.byKey(ValueKey('font-option-$family'), skipOffstage: false);

  Future<void> reveal(WidgetTester tester, Finder f) =>
      tester.scrollUntilVisible(
        f,
        200,
        scrollable: find.descendant(
          of: list,
          matching: find.byType(Scrollable),
        ),
      );

  testWidgets('lists the bundled, imported and device fonts in that order', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('In the app'), findsOneWidget);
    // Every bundled family, by its written name rather than its key.
    expect(find.text('Luckiest Guy'), findsOneWidget);
    expect(find.text('LuckiestGuy'), findsNothing);

    await reveal(tester, find.text('My Hand'));
    expect(find.text('Your fonts'), findsOneWidget);
    await reveal(tester, find.text('Roboto'));
    expect(find.text('On this device'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('My Hand')).dy,
      lessThan(tester.getTopLeft(find.text('Roboto')).dy),
    );
  });

  testWidgets('a device twin of a bundled font is listed once', (tester) async {
    await open(tester);
    await tester.enterText(search, 'grotesk');
    await tester.pump();
    expect(find.text('Space Grotesk'), findsOneWidget);
    // ...and it is the bundled one that stays.
    expect(option(AppFonts.display), findsOneWidget);
    expect(option('Space Grotesk'), findsNothing);
    expect(find.text('On this device'), findsNothing);
  });

  testWidgets('typing narrows every section, ignoring case and spaces', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(search, 'LUCKIESTguy');
    await tester.pump();
    expect(option(AppFonts.luckiestGuy), findsOneWidget);
    expect(option(AppFonts.bangers), findsNothing);
    expect(find.text('Your fonts'), findsNothing);

    await tester.enterText(search, 'rob');
    await tester.pump();
    expect(option('Roboto'), findsOneWidget);
    expect(find.text('In the app'), findsNothing);
    expect(find.text('On this device'), findsOneWidget);
  });

  testWidgets('a search with no match says so and still offers an import', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(search, 'zzzz');
    await tester.pump();
    expect(find.text('No fonts match your search'), findsOneWidget);
    expect(find.byKey(const ValueKey('font-import')), findsOneWidget);

    await tester.tap(find.byTooltip('Delete'));
    await tester.pump();
    expect(find.text('No fonts match your search'), findsNothing);
    expect(option(AppFonts.bangers), findsOneWidget);
  });

  testWidgets('tapping a font returns it and closes the sheet', (tester) async {
    final results = await open(tester);
    await tester.enterText(search, 'roboto');
    await tester.pump();
    await tester.tap(option('Roboto'));
    await tester.pumpAndSettle();
    expect(results.single, (family: 'Roboto', imported: false));
    expect(list, findsNothing);
  });

  testWidgets('the current font is marked', (tester) async {
    await open(tester, current: AppFonts.pacifico);
    final row = option(AppFonts.pacifico);
    expect(
      find.descendant(of: row, matching: find.byIcon(Icons.check_rounded)),
      findsOneWidget,
    );
    expect(tester.getSemantics(row), isSemantics(isSelected: true));
    expect(
      find.descendant(
        of: option(AppFonts.bangers),
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsNothing,
    );
  });

  testWidgets('with no device fonts there is no device section', (
    tester,
  ) async {
    await open(tester, deviceFonts: const [], imported: const []);
    await reveal(tester, find.byKey(const ValueKey('font-import')));
    expect(find.text('On this device'), findsNothing);
    expect(find.text('Your fonts'), findsNothing);
  });

  testWidgets('names that differ only by a space are two fonts', (
    tester,
  ) async {
    // Kept apart by the engine and by import naming, so the list must not
    // fold one into the other the way search does.
    await open(
      tester,
      imported: const [CustomFont('RobotoMono', 'RobotoMono.ttf')],
      deviceFonts: const [
        DeviceFontFamily('Roboto Mono', '/system/fonts/RobotoMono.ttf'),
      ],
    );
    await tester.enterText(search, 'robotomono');
    await tester.pump();
    expect(option('RobotoMono'), findsOneWidget);
    expect(option('Roboto Mono'), findsOneWidget);
  });

  testWidgets('a failed import says so and can be tried again', (tester) async {
    final importer = _FailingImport();
    await open(tester, importer: () => importer);
    final row = find.byKey(const ValueKey('font-import'));
    await reveal(tester, row);
    await tester.tap(row);
    await tester.pump();
    expect(find.text("Couldn't add that font file"), findsOneWidget);
    expect(importer.attempts, 1);
    // The row is live again - not stuck waiting on an import that threw.
    await tester.tap(row);
    await tester.pump();
    expect(importer.attempts, 2);
    await tester.pump(const Duration(seconds: 5));
  });

  // Not a SheetBody, so the header - title and search field - has to fit in
  // whatever height is left and only the list may give. Swept here because the
  // locale and text-scale sweeps pump screens, not sheets. The keyboard case is
  // the one that leaves no room to pin the header at all.
  for (final locale in AppLocalizations.supportedLocales) {
    for (final (name, size, keyboard) in const [
      ('360dp phone', Size(360, 640), 0.0),
      ('landscape', Size(780, 360), 0.0),
      ('landscape with the keyboard up', Size(780, 360), 200.0),
    ]) {
      testWidgets('fits a $name at 2x text in ${locale.languageCode}', (
        tester,
      ) async {
        await open(
          tester,
          size: size,
          locale: locale,
          textScale: 2,
          keyboard: keyboard,
        );
        expect(tester.takeException(), isNull);
        expect(search, findsOneWidget);
        expect(option(AppFonts.bangers), findsOneWidget);
        await tester.enterText(search, 'zzzz');
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('the panel field reads as the control and its value', (
    tester,
  ) async {
    setSurface(tester, const Size(412, 915));
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: darkAppTheme,
        home: Scaffold(
          body: FontField(family: AppFonts.luckiestGuy, onTap: () {}),
        ),
      ),
    );
    expect(find.text('Luckiest Guy'), findsOneWidget);
    expect(find.bySemanticsLabel('Font, Luckiest Guy'), findsOneWidget);
    handle.dispose();
  });
}

class _FailingImport extends CustomFontsController {
  var attempts = 0;

  @override
  Future<List<CustomFont>> build() async => const [];

  @override
  Future<String?> importFont() async {
    attempts++;
    throw const FileSystemException('No space left on device');
  }
}

class _Imported extends CustomFontsController {
  _Imported(this.fonts);
  final List<CustomFont> fonts;

  @override
  Future<List<CustomFont>> build() async => fonts;
}
