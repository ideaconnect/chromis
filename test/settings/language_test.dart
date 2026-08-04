import 'dart:io';

import 'package:chromis/app/router.dart';
import 'package:chromis/core/settings/locale_controller.dart';
import 'package:chromis/core/settings/settings_store.dart';
import 'package:chromis/features/settings/settings_screen.dart';
import 'package:chromis/l10n/app_localizations.dart';
import 'package:chromis/l10n/app_localizations_pl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// The UI language: how it is resolved, chosen and remembered.
///
/// The three rules this file exists to pin down, because each fails silently:
/// the app follows the DEVICE unless the user has chosen otherwise (a Polish
/// phone must not get English), an unsupported device language falls back to
/// English rather than throwing, and a choice survives a restart - "remembered"
/// is the whole point of the setting.
void main() {
  final polish = AppLocalizationsPl();

  /// A temp dir torn down after the current test; the settings file lives
  /// directly at `<base>/settings.json`.
  Directory freshTemp() {
    final dir = Directory.systemTemp.createTempSync('language_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    return dir;
  }

  group('locale resolution', () {
    test('every shipped language is supported', () {
      expect(AppLocalizations.supportedLocales, contains(const Locale('en')));
      expect(AppLocalizations.supportedLocales, contains(const Locale('pl')));
      expect(AppLocalizations.supportedLocales, contains(const Locale('de')));
      expect(AppLocalizations.supportedLocales, contains(const Locale('es')));
      expect(AppLocalizations.supportedLocales, contains(const Locale('fr')));
      expect(AppLocalizations.supportedLocales, contains(const Locale('cs')));
    });

    test('English is the fallback whatever order the list is in', () {
      // This is THE "defaults to English" rule, and it used to be an accident:
      // Flutter falls back to the FIRST supported locale, and gen-l10n emits
      // that list alphabetically - so adding German put `de` at the front and
      // silently made German the default for every untranslated device.
      // resolveAppLocale states the rule instead of depending on sort order,
      // so this test passes a list deliberately NOT starting with English.
      const supported = [
        Locale('cs'),
        Locale('de'),
        Locale('en'),
        Locale('es'),
        Locale('fr'),
        Locale('pl'),
      ];

      expect(
        resolveAppLocale([const Locale('ja')], supported),
        const Locale('en'),
      );
      expect(resolveAppLocale(null, supported), const Locale('en'));
      expect(resolveAppLocale(const [], supported), const Locale('en'));
    });

    test('the device language wins when the app has it', () {
      const supported = [Locale('de'), Locale('en'), Locale('pl')];

      expect(
        resolveAppLocale([const Locale('pl')], supported),
        const Locale('pl'),
      );
      expect(
        resolveAppLocale([const Locale('de')], supported),
        const Locale('de'),
      );
      // Region is ignored - de_AT is still German.
      expect(
        resolveAppLocale([const Locale('de', 'AT')], supported),
        const Locale('de'),
      );
      // The first device locale we can serve wins, not the first we are given.
      expect(
        resolveAppLocale([
          const Locale('ja'),
          const Locale('pl'),
          const Locale('de'),
        ], supported),
        const Locale('pl'),
      );
    });

    /// The device speaks [language]; nothing has been chosen in Settings.
    Future<AppLocalizations> resolveFor(
      WidgetTester tester,
      String language,
    ) async {
      late AppLocalizations l10n;
      await tester.pumpWidget(
        MaterialApp(
          localeListResolutionCallback: (_, supported) =>
              resolveAppLocale([Locale(language)], supported),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context);
              return Text(l10n.settings);
            },
          ),
        ),
      );
      return l10n;
    }

    testWidgets('a Polish device gets Polish with no choice made', (
      tester,
    ) async {
      final l10n = await resolveFor(tester, 'pl');
      expect(l10n.localeName, 'pl');
      expect(find.text('Ustawienia'), findsOneWidget);
    });

    testWidgets('a German device gets German with no choice made', (
      tester,
    ) async {
      final l10n = await resolveFor(tester, 'de');
      expect(l10n.localeName, 'de');
      expect(find.text('Einstellungen'), findsOneWidget);
    });

    testWidgets('a Spanish device gets Spanish with no choice made', (
      tester,
    ) async {
      final l10n = await resolveFor(tester, 'es');
      expect(l10n.localeName, 'es');
      expect(find.text('Configuración'), findsOneWidget);
    });

    testWidgets('a French device gets French with no choice made', (
      tester,
    ) async {
      final l10n = await resolveFor(tester, 'fr');
      expect(l10n.localeName, 'fr');
      expect(find.text('Paramètres'), findsOneWidget);
    });

    testWidgets('a Czech device gets Czech with no choice made', (
      tester,
    ) async {
      final l10n = await resolveFor(tester, 'cs');
      expect(l10n.localeName, 'cs');
      expect(find.text('Nastavení'), findsOneWidget);
    });

    testWidgets('an unsupported device language falls back to English', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localeListResolutionCallback: (_, supported) =>
              resolveAppLocale([const Locale('ja')], supported),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Text(AppLocalizations.of(context).settings),
          ),
        ),
      );
      expect(find.text('Settings'), findsOneWidget);
    });
  });

  group('localeFromTag', () {
    test('null means follow the device, not English', () {
      expect(localeFromTag(null), isNull);
    });

    test('a supported tag resolves to that locale', () {
      expect(localeFromTag('pl'), const Locale('pl'));
      expect(localeFromTag('en'), const Locale('en'));
      expect(localeFromTag('de'), const Locale('de'));
      expect(localeFromTag('es'), const Locale('es'));
      expect(localeFromTag('fr'), const Locale('fr'));
      expect(localeFromTag('cs'), const Locale('cs'));
    });

    test('an unknown tag reads as "follow the device"', () {
      // A settings.json written by a newer build (or hand-edited) must not
      // brick the app into a language it has no strings for.
      expect(localeFromTag('ja'), isNull);
      expect(localeFromTag(''), isNull);
    });

    test('every offered language is actually supported', () {
      for (final language in kAppLanguages) {
        expect(
          AppLocalizations.supportedLocales,
          contains(language.locale),
          reason: '${language.label} is offered but has no translations',
        );
        expect(language.label.trim(), isNotEmpty);
      }
    });
  });

  group('persistence', () {
    test('localeTag is null until set, and survives a fresh store', () async {
      final base = freshTemp();
      final store = SettingsStore(baseDir: base);

      expect(await store.localeTag(), isNull);

      await store.setLocaleTag('pl');
      expect(await SettingsStore(baseDir: base).localeTag(), 'pl');
    });

    test('clearing removes the key rather than writing null', () async {
      // "never chose" and "chose System" have to be the same state; a stale
      // null left behind would be a third one for the next launch to misread.
      final base = freshTemp();
      final store = SettingsStore(baseDir: base);
      await store.setLocaleTag('pl');
      await store.setLocaleTag(null);

      expect(await SettingsStore(baseDir: base).localeTag(), isNull);
      expect(
        File('${base.path}/settings.json').readAsStringSync(),
        isNot(contains('locale')),
      );
    });

    test('the language does not clobber the other settings', () async {
      final base = freshTemp();
      final store = SettingsStore(baseDir: base);
      await store.setOnboardingSeen(true);
      await store.setProEntitled(true);

      await store.setLocaleTag('pl');

      final reread = SettingsStore(baseDir: base);
      expect(await reread.onboardingSeen(), isTrue);
      expect(await reread.proEntitled(), isTrue);
      expect(await reread.localeTag(), 'pl');
    });
  });

  group('Settings screen', () {
    /// A [SettingsStore] that keeps the language in memory.
    ///
    /// Deliberately not the real one: a widget test runs in fake async, where
    /// the `dart:io` write a tap kicks off never completes, so an assertion
    /// against a real settings.json would be a race. That the value reaches
    /// DISK is what the `persistence` group above proves; what this group
    /// proves is that the screen hands it over and re-renders.
    final store = _InMemorySettings();

    /// Pumps the Settings screen with the app's own locale wiring.
    Future<void> pumpSettings(WidgetTester tester) async {
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
              locale: ref.watch(localeControllerProvider).asData?.value,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: router,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    setUp(() => store.tag = null);

    /// The LANGUAGE row's label. Scoped, because the appearance picker above it
    /// offers "System default" too - they are the same concept applied to two
    /// different settings, and each is disambiguated on screen by its section
    /// header and its own sub-label. A bare `find.text` matches both.
    Finder languageSystemLabel(String label) => find.descendant(
      of: find.byKey(const ValueKey('language-system')),
      matching: find.text(label),
    );

    testWidgets('picking Polski re-renders in Polish and remembers it', (
      tester,
    ) async {
      await pumpSettings(tester);
      // The section header is upper-cased by the screen, so assert on a row
      // label instead - those are rendered verbatim.
      expect(languageSystemLabel('System default'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('language-pl')));
      await tester.pumpAndSettle();

      // The screen itself is now Polish - the switch is live, not on restart.
      expect(find.text(polish.languageSystem), findsOneWidget);
      expect(find.text('System default'), findsNothing);
      expect(store.tag, 'pl');
    });

    testWidgets('picking System clears the saved choice', (tester) async {
      await pumpSettings(tester);

      await tester.tap(find.byKey(const ValueKey('language-pl')));
      await tester.pumpAndSettle();
      expect(store.tag, 'pl');

      await tester.tap(find.byKey(const ValueKey('language-system')));
      await tester.pumpAndSettle();

      expect(store.tag, isNull);
      // The device's language again.
      expect(languageSystemLabel('System default'), findsOneWidget);
    });

    testWidgets('a saved choice is what the screen opens on', (tester) async {
      store.tag = 'pl';

      await pumpSettings(tester);

      expect(find.text(polish.languageSystem), findsOneWidget);
    });
  });
}

/// See the `Settings screen` group: the language, held in memory.
class _InMemorySettings extends SettingsStore {
  String? tag;

  @override
  Future<String?> localeTag() async => tag;

  @override
  Future<void> setLocaleTag(String? value) async => tag = value;
}
