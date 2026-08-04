import 'dart:io';
import 'dart:math' as math;

import 'package:chromis/app/router.dart';
import 'package:chromis/core/settings/settings_store.dart';
import 'package:chromis/core/settings/theme_controller.dart';
import 'package:chromis/core/theme/app_palette.dart';
import 'package:chromis/core/theme/app_theme.dart';
import 'package:chromis/features/settings/settings_screen.dart';
import 'package:chromis/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// The light/dark theme: how it is resolved, chosen, remembered - and whether
/// its colours are actually legible.
///
/// The contrast group is the part that earns its keep. Every other check here
/// would fail loudly; a colour that is two steps too pale fails silently, looks
/// fine to whoever picked it on the monitor they picked it on, and only shows
/// up as "I can't read this outside". There is no way to notice that by
/// pumping widgets, because nothing overflows and nothing throws - so the
/// ratios are asserted directly against the palette.
void main() {
  /// WCAG relative luminance. Not `Color.computeLuminance` - that is the same
  /// formula, but writing it out is what lets the failure message below quote a
  /// ratio a reader can check against the spec.
  double luminance(Color c) {
    double channel(double v) =>
        v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4) as double;
    return 0.2126 * channel(c.r) +
        0.7152 * channel(c.g) +
        0.0722 * channel(c.b);
  }

  double contrast(Color a, Color b) {
    final (x, y) = (luminance(a), luminance(b));
    return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
  }

  /// A temp dir torn down after the current test; settings.json lives at
  /// `<base>/settings.json`.
  Directory freshTemp() {
    final dir = Directory.systemTemp.createTempSync('appearance_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    return dir;
  }

  group('themeModeFromName', () {
    test('null means follow the device, not dark', () {
      // The app shipped dark-only, so "no preference" reading as dark would be
      // an easy and invisible mistake - and it would strand every light-mode
      // phone in the theme this change exists to stop being the only option.
      expect(themeModeFromName(null), ThemeMode.system);
    });

    test('the two explicit choices round-trip through their name', () {
      expect(themeModeFromName(ThemeMode.light.name), ThemeMode.light);
      expect(themeModeFromName(ThemeMode.dark.name), ThemeMode.dark);
    });

    test('an unknown value reads as "follow the device"', () {
      // A settings.json written by a newer build (or hand-edited) must not
      // leave the app in a theme the user cannot see their way out of.
      expect(themeModeFromName('sepia'), ThemeMode.system);
      expect(themeModeFromName(''), ThemeMode.system);
    });

    test('every offered mode is one the picker can render', () {
      expect(kAppThemeModes, contains(ThemeMode.system));
      expect(kAppThemeModes.first, ThemeMode.system);
      expect(kAppThemeModes.toSet(), hasLength(kAppThemeModes.length));
    });
  });

  group('persistence', () {
    test('unset until chosen, and survives a fresh store', () async {
      final base = freshTemp();
      final store = SettingsStore(baseDir: base);

      expect(await store.themeModeName(), isNull);

      await store.setThemeModeName('light');
      expect(await SettingsStore(baseDir: base).themeModeName(), 'light');
    });

    test('clearing removes the key rather than writing null', () async {
      // "never chose" and "chose System" have to be the same state; a stale
      // null left behind would be a third one for the next launch to misread.
      final base = freshTemp();
      final store = SettingsStore(baseDir: base);
      await store.setThemeModeName('dark');
      await store.setThemeModeName(null);

      expect(await SettingsStore(baseDir: base).themeModeName(), isNull);
      expect(
        File('${base.path}/settings.json').readAsStringSync(),
        isNot(contains('themeMode')),
      );
    });

    test('the appearance does not clobber the other settings', () async {
      final base = freshTemp();
      final store = SettingsStore(baseDir: base);
      await store.setProEntitled(true);
      await store.setLocaleTag('pl');

      await store.setThemeModeName('light');

      final reread = SettingsStore(baseDir: base);
      expect(await reread.proEntitled(), isTrue);
      expect(await reread.localeTag(), 'pl');
      expect(await reread.themeModeName(), 'light');
    });
  });

  group('the two palettes', () {
    test('every surface differs between them', () {
      // A field left out of one palette is a field that keeps its dark value in
      // the light theme - a black card on a white page. Nothing else catches
      // it: it compiles, it renders, and it is only wrong to look at.
      const dark = AppPalette.dark;
      const light = AppPalette.light;
      final surfaces = <String, (Color, Color)>{
        'pageBackground': (dark.pageBackground, light.pageBackground),
        'background': (dark.background, light.background),
        'panel': (dark.panel, light.panel),
        'card': (dark.card, light.card),
        'cardAlt': (dark.cardAlt, light.cardAlt),
        'inputField': (dark.inputField, light.inputField),
        'chipSurface': (dark.chipSurface, light.chipSurface),
        'elevated': (dark.elevated, light.elevated),
        'textPrimary': (dark.textPrimary, light.textPrimary),
        'textSecondary': (dark.textSecondary, light.textSecondary),
        'textMuted': (dark.textMuted, light.textMuted),
        'textFaint': (dark.textFaint, light.textFaint),
        'onAccent': (dark.onAccent, light.onAccent),
        'checkerBase': (dark.checkerBase, light.checkerBase),
        'shadow': (dark.shadow, light.shadow),
      };
      for (final entry in surfaces.entries) {
        expect(
          entry.value.$1,
          isNot(entry.value.$2),
          reason: '${entry.key} is the same in both themes',
        );
      }
    });

    test('dark is genuinely dark and light is genuinely light', () {
      // The point of the dark theme is that an OLED panel can switch those
      // pixels off, so its floor is black rather than "a dark colour".
      expect(AppPalette.dark.background, const Color(0xFF000000));
      expect(luminance(AppPalette.light.background), greaterThan(0.8));
      expect(AppPalette.dark.brightness, Brightness.dark);
      expect(AppPalette.light.brightness, Brightness.light);
      expect(AppPalette.light.isLight, isTrue);
      expect(AppPalette.dark.isLight, isFalse);
    });

    for (final (name, palette) in [
      ('dark', AppPalette.dark),
      ('light', AppPalette.light),
    ]) {
      test('$name text is readable on every surface it lands on', () {
        final surfaces = {
          'background': palette.background,
          'panel': palette.panel,
          'card': palette.card,
          'cardAlt': palette.cardAlt,
          'chipSurface': palette.chipSurface,
          'elevated': palette.elevated,
        };
        // 4.5:1 is the WCAG AA floor for body text; textFaint is only ever a
        // disabled state or an unselected control, which AA rates as a
        // graphical object at 3:1.
        final inks = {
          'textPrimary': (palette.textPrimary, 4.5),
          'textSecondary': (palette.textSecondary, 4.5),
          'textMuted': (palette.textMuted, 4.5),
          'textFaint': (palette.textFaint, 3.0),
        };
        for (final surface in surfaces.entries) {
          for (final ink in inks.entries) {
            final ratio = contrast(ink.value.$1, surface.value);
            expect(
              ratio,
              greaterThanOrEqualTo(ink.value.$2),
              reason:
                  '$name ${ink.key} on ${surface.key} is '
                  '${ratio.toStringAsFixed(2)}:1, under ${ink.value.$2}:1',
            );
          }
        }
      });

      test('$name accents read on a card, and take their own ink', () {
        final accents = {
          'violet': palette.violet,
          'cyan': palette.cyan,
          'pink': palette.pink,
          'amber': palette.amber,
          'green': palette.green,
          'orange': palette.orange,
          'gold': palette.gold,
          'rose': palette.rose,
          'teal': palette.teal,
          'greenLight': palette.greenLight,
          'violetLight': palette.violetLight,
          'magenta': palette.magenta,
        };
        for (final accent in accents.entries) {
          // As an icon or a border on a card: a graphical object, 3:1.
          final onCard = contrast(accent.value, palette.card);
          expect(
            onCard,
            greaterThanOrEqualTo(3.0),
            reason:
                '$name ${accent.key} on card is '
                '${onCard.toStringAsFixed(2)}:1, under 3:1',
          );
          // As a filled button: onAccent is the ONE ink for all of them, which
          // only works if it clears the text floor against every single one.
          final ink = contrast(palette.onAccent, accent.value);
          expect(
            ink,
            greaterThanOrEqualTo(4.5),
            reason:
                '$name onAccent on ${accent.key} is '
                '${ink.toStringAsFixed(2)}:1, under 4.5:1',
          );
        }
      });
    }

    test('lerp lands on each palette at its own end', () {
      expect(
        AppPalette.lerp(AppPalette.dark, AppPalette.light, 0).background,
        AppPalette.dark.background,
      );
      expect(
        AppPalette.lerp(AppPalette.dark, AppPalette.light, 1).background,
        AppPalette.light.background,
      );
      // Halfway through a theme switch the brightness has to commit to one or
      // the other - it is a flag, not a colour, and nothing can interpolate it.
      final half = AppPalette.lerp(AppPalette.dark, AppPalette.light, 0.5);
      expect(half.brightness, Brightness.light);
    });
  });

  group('the theme carries the palette', () {
    test('each brightness installs its own tokens', () {
      expect(lightAppTheme.brightness, Brightness.light);
      expect(darkAppTheme.brightness, Brightness.dark);
      expect(
        lightAppTheme.scaffoldBackgroundColor,
        AppPalette.light.background,
      );
      expect(darkAppTheme.scaffoldBackgroundColor, AppPalette.dark.background);
    });

    test('the system bars follow the theme rather than the launch', () {
      // The app draws behind both bars, so white icons on the light theme land
      // on a white page and the navigation bar disappears entirely.
      final light = systemOverlayStyleFor(AppPalette.light);
      final dark = systemOverlayStyleFor(AppPalette.dark);
      expect(light.statusBarIconBrightness, Brightness.dark);
      expect(dark.statusBarIconBrightness, Brightness.light);
      expect(light.systemNavigationBarColor, AppPalette.light.background);
      expect(dark.systemNavigationBarColor, AppPalette.dark.background);
    });
  });

  group('Settings screen', () {
    /// A [SettingsStore] that keeps the appearance in memory - see the same
    /// note in `language_test.dart`: a widget test runs in fake async, where
    /// the `dart:io` write a tap kicks off never completes. That the value
    /// reaches DISK is what the `persistence` group above proves.
    final store = _InMemorySettings();

    /// Pins the DEVICE to dark, so "System" has something to follow and the
    /// light choice below is a visible change. Left to the binding's default
    /// this would assert the framework's preference rather than ours.
    Future<void> pumpSettings(
      WidgetTester tester, {
      Brightness device = Brightness.dark,
    }) async {
      tester.platformDispatcher.platformBrightnessTestValue = device;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            name: Routes.settings,
            builder: (_, _) => const SettingsScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [settingsStoreProvider.overrideWithValue(store)],
          child: Consumer(
            builder: (context, ref, _) => MaterialApp.router(
              theme: lightAppTheme,
              darkTheme: darkAppTheme,
              themeMode:
                  ref.watch(themeModeControllerProvider).asData?.value ??
                  ThemeMode.system,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: router,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// What the screen is actually painted in, read back from the tree.
    Brightness rendered(WidgetTester tester) =>
        Theme.of(tester.element(find.byType(SettingsScreen))).brightness;

    setUp(() => store.mode = null);

    testWidgets('picking Light repaints the screen light and remembers it', (
      tester,
    ) async {
      await pumpSettings(tester);
      expect(rendered(tester), Brightness.dark); // following the device

      await tester.tap(find.byKey(const ValueKey('appearance-light')));
      await tester.pumpAndSettle();

      expect(rendered(tester), Brightness.light);
      expect(store.mode, 'light');
    });

    testWidgets('picking System clears the saved choice', (tester) async {
      await pumpSettings(tester);

      await tester.tap(find.byKey(const ValueKey('appearance-light')));
      await tester.pumpAndSettle();
      expect(store.mode, 'light');

      await tester.tap(find.byKey(const ValueKey('appearance-system')));
      await tester.pumpAndSettle();

      expect(store.mode, isNull);
      expect(rendered(tester), Brightness.dark); // the device's again
    });

    testWidgets('a saved choice is what the screen opens on', (tester) async {
      store.mode = 'light';

      await pumpSettings(tester);

      expect(rendered(tester), Brightness.light);
    });

    testWidgets('System follows the device both ways', (tester) async {
      // The default, and the reason it is the default: the device setting is
      // the one the user has already made. A phone on its night theme has to
      // get the dark app without anyone opening this screen.
      await pumpSettings(tester, device: Brightness.light);
      expect(rendered(tester), Brightness.light);
      expect(store.mode, isNull);
    });

    testWidgets('the appearance rows are a mutually exclusive group', (
      tester,
    ) async {
      // Nine identical "button" nodes is what the colour swatches were before
      // #a11y; a radio list has to announce itself as one.
      await pumpSettings(tester);
      for (final mode in kAppThemeModes) {
        expect(
          find.byKey(ValueKey('appearance-${mode.name}')),
          findsOneWidget,
          reason: '${mode.name} is offered but has no row',
        );
      }
    });
  });
}

/// See the `Settings screen` group: the appearance, held in memory.
class _InMemorySettings extends SettingsStore {
  String? mode;

  @override
  Future<String?> themeModeName() async => mode;

  @override
  Future<void> setThemeModeName(String? value) async => mode = value;
}
