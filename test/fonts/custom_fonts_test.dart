import 'dart:convert';
import 'dart:io';

import 'package:chromis/features/fonts/custom_fonts.dart';
import 'package:chromis/features/fonts/device_fonts.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// The imported-font catalogue as it is loaded at launch - and what it does
/// with a name the app has since started drawing with itself.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory base;
  late Directory fonts;

  setUp(() {
    base = Directory.systemTemp.createTempSync('customfonts');
    fonts = Directory('${base.path}/fonts')..createSync();
  });
  tearDown(() => base.deleteSync(recursive: true));

  /// A catalogue of [families], each backed by a real font file.
  void catalogue(List<String> families) {
    for (final f in families) {
      File(
        'assets/fonts/PatrickHand-Regular.ttf',
      ).copySync('${fonts.path}/$f.ttf');
    }
    File('${fonts.path}/fonts.json').writeAsStringSync(
      jsonEncode([
        for (final f in families) {'family': f, 'file': '$f.ttf'},
      ]),
    );
  }

  List<String> persisted() => [
    for (final m
        in jsonDecode(File('${fonts.path}/fonts.json').readAsStringSync())
            as List)
      (m as Map)['family'] as String,
  ];

  test('an import named like a bundled or UI family is renumbered', () async {
    // "Lobster" was imported before Lobster was bundled; "Manrope" collides
    // with the app's own UI face, which uniqueness never used to check.
    catalogue(['Lobster', 'Manrope', 'My Hand']);
    final loaded = await CustomFontStore(baseDir: base).loadAndRegister();
    expect(loaded.map((c) => c.family), ['Lobster 2', 'Manrope 2', 'My Hand']);
    // Written back, so the next launch starts from the new names...
    expect(persisted(), ['Lobster 2', 'Manrope 2', 'My Hand']);
    // ...and the files are untouched - only the names moved.
    expect(loaded.first.fileName, 'Lobster.ttf');
  });

  test('a catalogue with no collision is left exactly as it was', () async {
    catalogue(['My Hand']);
    final before = File('${fonts.path}/fonts.json').readAsStringSync();
    await CustomFontStore(baseDir: base).loadAndRegister();
    expect(File('${fonts.path}/fonts.json').readAsStringSync(), before);
  });

  test('every imported name is reserved against the device fonts', () async {
    catalogue(['Roboto Import']);
    await CustomFontStore(baseDir: base).loadAndRegister();
    // Reserved, so answered without a scan or a load - synchronously.
    expect(
      DeviceFonts.instance.ensure('Roboto Import'),
      isA<SynchronousFuture<bool>>(),
    );
  });
}
