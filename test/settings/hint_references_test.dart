import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Hints that tell the user to tap a control by name.
///
/// "Tap Add to import a photo" is only true while some control is actually
/// labelled "Add". English is self-consistent by construction, so nothing
/// goes red when a translation renames the button and leaves the hint
/// pointing at a name that is no longer on screen - which is exactly what
/// happened when the Polish dock label was shortened to fit: it became
/// "Dodaj", identical to the chip the hint meant, and the sentence stopped
/// picking one of them out.
///
/// The pairs are derived from the English rather than listed, so a hint
/// added later is covered without anyone remembering to add it here.
void main() {
  Map<String, String> arb(String locale) {
    final raw =
        (jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync()) as Map)
            .cast<String, dynamic>();
    return {
      for (final entry in raw.entries)
        if (!entry.key.startsWith('@') && entry.value is String)
          entry.key: entry.value as String,
    };
  }

  /// "Tap Add to…", "tap Restore purchase", "use the Erase brush".
  final instruction = RegExp(
    r"(?:[Tt]ap|[Tt]ouch|use the)\s+([A-Z][\w'-]*(?:\s+[a-z][\w'-]*)?)",
  );

  /// A hint whose reference deliberately uses a different word from the
  /// control it points at, with the reason it is still correct.
  const allowed = <String, String>{
    // The dock button is the verb (Effacer / Mazat) but the panel it opens
    // is titled with the noun (toolErasePanel: "Gomme manuelle" / "Rucni
    // mazani"), and the prose consistently uses the noun. English has one
    // word for both, so the split only exists in translation.
    'objectAiUnavailable|erase': 'names the erase panel, not the dock button',
    'objectAiUnavailable|toolErase':
        'names the erase panel, not the dock '
        'button',
  };

  final en = arb('en');
  final byValue = <String, List<String>>{};
  en.forEach((k, v) => byValue.putIfAbsent(v, () => []).add(k));
  final labels = byValue.keys.where((v) => v.length >= 3 && !v.contains('{'));

  /// (hint key, control key) for every English sentence naming a control.
  final references = <MapEntry<String, String>>[];
  en.forEach((key, text) {
    for (final m in instruction.allMatches(text)) {
      final phrase = m.group(1)!.trim();
      final match = labels
          .where((v) => phrase == v || phrase.startsWith('$v '))
          .fold<String?>(
            null,
            (best, v) => best == null || v.length > best.length ? v : best,
          );
      if (match == null) continue;
      for (final controlKey in byValue[match]!) {
        if (controlKey != key) {
          references.add(MapEntry(key, controlKey));
        }
      }
    }
  });

  test('the English itself names controls that exist', () {
    expect(
      references,
      isNotEmpty,
      reason: 'the instruction regex stopped matching - the hints changed',
    );
  });

  for (final locale in const ['pl', 'de', 'es', 'fr', 'cs']) {
    // The half that actually caught the Polish regression. Resolving is not
    // enough: "Dodaj" appeared in the hint AND on two different controls, so
    // the sentence pointed at both. A name a hint uses has to be unique.
    test('$locale names in hints point at exactly one control', () {
      final data = arb(locale);
      for (final ref in references) {
        if (allowed.containsKey('${ref.key}|${ref.value}')) continue;
        final control = data[ref.value];
        if (control == null) continue;
        final sharing = data.entries
            .where((e) => e.value == control && e.key != ref.value)
            .map((e) => e.key)
            .toList();
        expect(
          sharing,
          isEmpty,
          reason:
              '$locale "${ref.key}" tells the user to tap "$control", but '
              '$sharing also render as "$control". The hint cannot pick one '
              'of them out - give the other control a different label.',
        );
      }
    });

    test('$locale hints still name a control that is on screen', () {
      final data = arb(locale);
      for (final ref in references) {
        if (allowed.containsKey('${ref.key}|${ref.value}')) continue;
        final hint = data[ref.key];
        final control = data[ref.value];
        if (hint == null || control == null) continue;
        // The label is often inflected where it is quoted, so match a stem
        // rather than the whole word.
        final stem = control
            .substring(
              0,
              control.length - 3 < 4 ? control.length : control.length - 3,
            )
            .toLowerCase();
        expect(
          hint.toLowerCase(),
          contains(stem),
          reason:
              '$locale "${ref.key}" tells the user to tap "${ref.value}" '
              '(= "$control"), but the sentence does not contain it:\n'
              '  $hint\n'
              'Either the hint or the control was renamed without the other.',
        );
      }
    });
  }
}
