import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The two label tables that fall back to English *silently*.
///
/// Most of `lib/l10n/localized_labels.dart` switches on the enum itself, so a
/// new value is a compile error and the compiler is the test. Grid templates
/// and canvas presets are different: they are matched by their English `label`
/// string, so their lookups switch on a String and need a default arm - and
/// `_ => label` means a template added later renders in English in every
/// language, with nothing going red.
///
/// The tables are complete today; this is what keeps them that way. It reads
/// the sources rather than calling the code because both lists are private to
/// their libraries, and a behavioural check cannot tell "translated to the
/// same string" from "fell through" - '2 x 2' is '2 x 2' in all six languages.
void main() {
  String read(String path) => File(path).readAsStringSync();

  Set<String> literalsIn(String source, RegExp pattern) =>
      pattern.allMatches(source).map((m) => m.group(1)!).toSet();

  /// Swept over the whole of `lib` on purpose: there is more than one list of
  /// these. `CanvasPreset` is declared twice - the canvas-size sheet offers
  /// six, the grid setup sheet offers four - so reading a single file would
  /// let a preset added to the other one slip through untranslated.
  Set<String> constructedAcrossLib(RegExp pattern) {
    final found = <String>{};
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        found.addAll(literalsIn(entity.readAsStringSync(), pattern));
      }
    }
    return found;
  }

  final gridLabels = RegExp(r"GridTemplate\(\s*'([^']*)'");
  final presetLabels = RegExp(r"CanvasPreset\(\s*'([^']*)'");

  /// The `'...' =>` case labels inside one extension block.
  Set<String> casesOf(String source, String extensionName) {
    final start = source.indexOf('extension $extensionName');
    expect(start, isNot(-1), reason: '$extensionName is gone - rename?');
    final end = source.indexOf('\n}', start);
    return literalsIn(source.substring(start, end), RegExp(r"'([^']*)' =>"));
  }

  final labels = read('lib/l10n/localized_labels.dart');

  test('every grid template label has a translation', () {
    final defined = constructedAcrossLib(gridLabels);
    expect(defined, isNotEmpty, reason: 'regex stopped matching the source');
    expect(
      defined.difference(casesOf(labels, 'GridTemplateL10n')),
      isEmpty,
      reason:
          'these templates hit the `_ => label` arm and render in English '
          'in every language',
    );
  });

  test('every canvas preset label has a translation', () {
    final defined = constructedAcrossLib(presetLabels);
    expect(defined, isNotEmpty, reason: 'regex stopped matching the source');
    expect(
      defined.difference(casesOf(labels, 'CanvasPresetL10n')),
      isEmpty,
      reason:
          'these presets hit the `_ => label` arm and render in English '
          'in every language',
    );
  });

  test('no label table carries a case for a label that no longer exists', () {
    expect(
      casesOf(
        labels,
        'GridTemplateL10n',
      ).difference(constructedAcrossLib(gridLabels)),
      isEmpty,
      reason: 'dead cases - the template was renamed or removed',
    );
    expect(
      casesOf(
        labels,
        'CanvasPresetL10n',
      ).difference(constructedAcrossLib(presetLabels)),
      isEmpty,
      reason: 'dead cases - the preset was renamed or removed',
    );
  });
}
