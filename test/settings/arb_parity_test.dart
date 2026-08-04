import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every message the app can show must exist in every language it ships.
///
/// `flutter gen-l10n` does NOT fail on a missing translation - it silently
/// falls back to the template, so a string added in English simply appears in
/// English on a Polish phone and nothing goes red. That is exactly the failure
/// this file exists to catch, and it is the one a translation set rots by.
///
/// Placeholders are compared too: a `{count}` that a translator dropped throws
/// at runtime, in whichever screen happens to use it, rather than at build.
void main() {
  Map<String, dynamic> arb(String locale) =>
      (jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync()) as Map)
          .cast<String, dynamic>();

  /// Message ids only - `@@locale` and the `@key` metadata blocks are not
  /// messages.
  Set<String> messages(Map<String, dynamic> data) =>
      data.keys.where((k) => !k.startsWith('@')).toSet();

  /// The `{placeholder}` names used in a message, in no particular order.
  Set<String> placeholders(String message) =>
      RegExp(r'\{(\w+)\}').allMatches(message).map((m) => m.group(1)!).toSet();

  /// Every non-template locale that ships. Derived from the ARB files rather
  /// than listed, so adding app_de.arb puts German under these checks too.
  final locales = Directory('lib/l10n')
      .listSync()
      .whereType<File>()
      .map((f) => RegExp(r'app_(\w+)\.arb$').firstMatch(f.path)?.group(1))
      .nonNulls
      .where((l) => l != 'en')
      .toList();

  test('there is at least one translation to check', () {
    expect(locales, isNotEmpty);
    expect(locales, contains('pl'));
  });

  final template = arb('en');
  final templateMessages = messages(template);

  for (final locale in locales) {
    group('app_$locale.arb', () {
      final translated = arb(locale);

      test('declares its own locale', () {
        expect(translated['@@locale'], locale);
      });

      test('translates every message, and invents none', () {
        final theirs = messages(translated);
        expect(
          templateMessages.difference(theirs),
          isEmpty,
          reason: 'untranslated - these would silently fall back to English',
        );
        expect(
          theirs.difference(templateMessages),
          isEmpty,
          reason: 'not in the template - dead strings nothing can read',
        );
      });

      test('no translation is left as the empty string', () {
        for (final key in messages(translated)) {
          expect(
            (translated[key] as String).trim(),
            isNotEmpty,
            reason: '$key is blank',
          );
        }
      });

      test('keeps every placeholder the template declares', () {
        for (final key in templateMessages) {
          final want = placeholders(template[key] as String);
          final got = placeholders(translated[key] as String);
          expect(
            got,
            want,
            reason:
                '$key: placeholders differ - a missing one throws at runtime',
          );
        }
      });
    });
  }

  // A slot whose width the text cannot influence, with the longest string
  // that was measured to fit it on a 360dp phone. Character count is a
  // proxy for width, but a sound one here: these are short UI words in a
  // proportional font, and the alternative - measuring in a widget test -
  // reports roughly double, because flutter_test substitutes a monospaced
  // font in which every glyph is a full em wide.
  //
  // Each of these was found on the device, not by this test: "Dodaj
  // warstwę" rendered as "Dodaj warst…" and the Polish and German font
  // hints lost their last two words. The budgets are what the fix left.
  const fixedSlots = <String, ({int max, String slot})>{
    // _DockItem paints its label in a hard SizedBox(width: 64).
    'goPro': (max: 11, slot: 'editor dock'),
    'toolGrid': (max: 11, slot: 'editor dock'),
    'addLayer': (max: 11, slot: 'editor dock'),
    'toolText': (max: 11, slot: 'editor dock'),
    'bubble': (max: 11, slot: 'editor dock'),
    'aiCut': (max: 11, slot: 'editor dock'),
    'erase': (max: 11, slot: 'editor dock'),
    'crop': (max: 11, slot: 'editor dock'),
    'toolAdjust': (max: 11, slot: 'editor dock'),
    'toolEffects': (max: 11, slot: 'editor dock'),
    'toolLayers': (max: 11, slot: 'editor dock'),
    // _PanelHint as a _panelHeader trailing - shares the row with the title.
    'tapFontToPreview': (max: 28, slot: 'panel header hint'),
    'brushOverCanvas': (max: 28, slot: 'panel header hint'),
    // The three export format chips are Expanded, so each gets a third.
    'formatPngSub': (max: 18, slot: 'export format chip'),
    'formatJpgSub': (max: 18, slot: 'export format chip'),
    'formatWebpSub': (max: 18, slot: 'export format chip'),
    // The Layers panel's two action chips are Expanded halves of one Row,
    // and they carry an icon as well. Bracketed on the device rather than
    // computed: French "Fusionner vers le bas" (21) renders in full, German
    // "Nach unten zusammenfuehren" (25) rendered "Nach unten zusamme...".
    'mergeDown': (max: 22, slot: 'layers panel action chip'),
    'flatten': (max: 22, slot: 'layers panel action chip'),
  };

  // French puts a NON-BREAKING space before : ; ! ? and inside guillemets.
  // A plain space is both a typographic error and a legal line-break point,
  // so the punctuation can start a line. It is invisible in review - the
  // string looks identical - and it is exactly what an edit reintroduces:
  // one round of fixes here rewrote a string and silently dropped the U+00A0,
  // leaving the file's only plain space among fourteen instances.
  test('fr keeps a non-breaking space before high punctuation', () {
    final french = arb('fr');
    final offenders = <String>[];
    for (final key in messages(french)) {
      final value = french[key] as String;
      if (RegExp(r'(?<! ) [:;!?]').hasMatch(value)) {
        offenders.add('$key: "$value"');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'these need U+00A0 (not a plain space) before the punctuation:\n'
          '${offenders.join('\n')}',
    );
  });

  for (final locale in const ['en', 'pl', 'de', 'es', 'fr', 'cs']) {
    test('$locale fits the slots that cannot grow', () {
      final data = arb(locale);
      for (final entry in fixedSlots.entries) {
        final value = data[entry.key] as String;
        expect(
          value.length,
          lessThanOrEqualTo(entry.value.max),
          reason:
              '$locale "${entry.key}" is ${value.length} chars - "$value" '
              'will ellipsize in the ${entry.value.slot}. Shorten it; the '
              'slot has no give.',
        );
      }
    });
  }
}
