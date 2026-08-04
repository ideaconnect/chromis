import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'settings_store.dart';

/// The app's UI language.
///
/// State is the user's *override*: null means "follow the device", which is the
/// default and is NOT the same as English. Flutter then resolves the platform
/// locales against [AppLocalizations.supportedLocales] and falls back to the
/// first one (`en`) when nothing matches - so a Polish phone gets Polish, a
/// Japanese phone gets English, and neither had to be special-cased here.
///
/// A chosen language is persisted (see [SettingsStore.setLocaleTag]) and read
/// back before the first frame, so the app never flashes one language and then
/// swaps to another.
class LocaleController extends AsyncNotifier<Locale?> {
  @override
  Future<Locale?> build() async {
    final tag = await ref.read(settingsStoreProvider).localeTag();
    return localeFromTag(tag);
  }

  /// Switches the UI language. Pass null to go back to following the device.
  ///
  /// The state moves first and the write is awaited after, so the UI re-renders
  /// on the same frame as the tap - a settings write is a file write and would
  /// otherwise show as a visible lag on the picker.
  Future<void> setLocale(Locale? locale) async {
    if (state.asData?.value == locale) return;
    state = AsyncData(locale);
    await ref.read(settingsStoreProvider).setLocaleTag(locale?.languageCode);
  }
}

final localeControllerProvider =
    AsyncNotifierProvider<LocaleController, Locale?>(LocaleController.new);

/// The language to render when the user has not chosen one: the device's, if
/// the app has it, and English otherwise.
///
/// Written down rather than left to Flutter's default, which falls back to the
/// FIRST entry of `supportedLocales` - and that list is generated in
/// alphabetical order. Adding German put `de` at the front, which silently made
/// German the language every device we do not translate for would have got.
/// "Defaults to English" is a product rule; it must not depend on where a new
/// ARB file happens to sort.
Locale resolveAppLocale(
  List<Locale>? deviceLocales,
  Iterable<Locale> supported,
) {
  for (final device in deviceLocales ?? const <Locale>[]) {
    for (final candidate in supported) {
      if (candidate.languageCode == device.languageCode) return candidate;
    }
  }
  return const Locale('en');
}

/// Parses a persisted tag into a supported [Locale], or null for "follow the
/// device". An unknown tag also reads as null rather than as an error: a
/// settings file written by a newer build (or hand-edited) must not brick the
/// app into an unsupported language it has no strings for.
Locale? localeFromTag(String? tag) {
  if (tag == null) return null;
  for (final locale in AppLocalizations.supportedLocales) {
    if (locale.languageCode == tag) return locale;
  }
  return null;
}

/// The languages offered in Settings, in menu order. The label is deliberately
/// written in ITS OWN language (Polski, not Polish): someone who has landed in
/// a language they cannot read has to be able to find their way out.
const List<({Locale locale, String label})> kAppLanguages = [
  (locale: Locale('en'), label: 'English'),
  (locale: Locale('pl'), label: 'Polski'),
  (locale: Locale('de'), label: 'Deutsch'),
  (locale: Locale('es'), label: 'Español'),
  (locale: Locale('fr'), label: 'Français'),
  (locale: Locale('cs'), label: 'Čeština'),
];
