import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:chromis/core/models/layer.dart';
import 'package:chromis/features/fonts/device_fonts.dart';
import 'package:chromis/features/fonts/font_file_info.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// The device-font half of the font picker: reading a font file's names and
/// coverage without loading it, choosing the one face per family that gets
/// registered, and registering it.
///
/// The fixtures are the bundled caption fonts - real files, with the real
/// tables a phone's fonts have - copied into a temporary "system" directory.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String font(String name) => 'assets/fonts/$name';

  group('readFontFaceInfo', () {
    test('reads the family, weight and Latin coverage of a static font', () {
      final info = readFontFaceInfo(font('Bangers-Regular.ttf'))!;
      expect(info.family, 'Bangers');
      expect(info.weight, 400);
      expect(info.italic, isFalse);
      expect(info.latin, isTrue);
      expect(info.variable, isFalse);
      expect(info.bytes, File(font('Bangers-Regular.ttf')).lengthSync());
    });

    test('a Bold reports 700 and keeps its family name', () {
      final info = readFontFaceInfo(font('ComicNeue-Bold.ttf'))!;
      expect(info.family, 'Comic Neue');
      expect(info.weight, 700);
    });

    test('a variable font says so', () {
      final info = readFontFaceInfo(font('SpaceGrotesk-Variable.ttf'))!;
      expect(info.family, 'Space Grotesk');
      expect(info.variable, isTrue);
    });

    test(
      'every bundled font maps the Latin alphabet, under an open licence',
      () {
        for (final f in Directory(
          'assets/fonts',
        ).listSync().whereType<File>()) {
          if (!f.path.endsWith('.ttf')) continue;
          final info = readFontFaceInfo(f.path);
          expect(info, isNotNull, reason: f.path);
          expect(info!.latin, isTrue, reason: f.path);
          expect(info.family, isNotEmpty, reason: f.path);
          // Every one of them states it in its own name table, OFL or Apache -
          // the same test a device font has to pass to be offered.
          expect(info.openLicense, isTrue, reason: f.path);
        }
      },
    );

    test('a font that does not state its licence is not open', () {
      final dir = Directory.systemTemp.createTempSync('nolicence');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/Bangers.ttf')
        ..writeAsBytesSync(withoutLicence(font('Bangers-Regular.ttf')));
      final info = readFontFaceInfo(file.path)!;
      expect(info.family, 'Bangers', reason: 'still read as a font');
      expect(info.openLicense, isFalse);
    });

    test('anything that is not a single font is refused, not thrown', () {
      final dir = Directory.systemTemp.createTempSync('fontinfo');
      addTearDown(() => dir.deleteSync(recursive: true));
      final text = File('${dir.path}/notes.ttf')..writeAsStringSync('hello');
      final truncated = File('${dir.path}/cut.ttf')
        ..writeAsBytesSync(
          File(font('Bangers-Regular.ttf')).readAsBytesSync().sublist(0, 200),
        );
      final collection = File('${dir.path}/c.ttc')
        ..writeAsBytesSync([0x74, 0x74, 0x63, 0x66, 0, 1, 0, 0, 0, 0, 0, 0]);
      expect(readFontFaceInfo(text.path), isNull);
      expect(readFontFaceInfo(truncated.path), isNull);
      expect(readFontFaceInfo(collection.path), isNull);
      expect(readFontFaceInfo('${dir.path}/missing.ttf'), isNull);
    });
  });

  group('isOpenFontLicence', () {
    test('knows the OFL and Apache 2.0 by their own words and URLs', () {
      for (final open in [
        'This Font Software is licensed under the SIL Open Font License, '
            'Version 1.1.',
        'https://scripts.sil.org/OFL',
        'https://openfontlicense.org',
        'Licensed under the Apache License, Version 2.0',
        'http://www.apache.org/licenses/LICENSE-2.0',
      ]) {
        expect(isOpenFontLicence(open), isTrue, reason: open);
      }
    });

    test('anything else is not open', () {
      for (final closed in [
        '',
        'All rights reserved.',
        'Licensed for use in Google products only.',
        'Monotype Imaging EULA - https://www.monotype.com/legal/eula',
        // Three letters are not a licence.
        'PROFL Corporation proprietary',
      ]) {
        expect(isOpenFontLicence(closed), isFalse, reason: closed);
      }
    });
  });

  group('pickDrawingFace', () {
    FontFaceInfo face(
      int weight, {
      bool italic = false,
      bool variable = false,
      int bytes = 100,
      String path = '',
    }) => FontFaceInfo(
      path: path.isEmpty ? 'w$weight${italic ? 'i' : ''}' : path,
      family: 'F',
      weight: weight,
      italic: italic,
      latin: true,
      variable: variable,
      openLicense: true,
      bytes: bytes,
    );

    test('takes the face nearest the w700 captions are drawn at', () {
      expect(
        pickDrawingFace([face(300), face(400), face(700), face(900)])!.weight,
        700,
      );
      expect(pickDrawingFace([face(400), face(500)])!.weight, 500);
    });

    test('never an italic, even the only Bold', () {
      expect(
        pickDrawingFace([face(400), face(700, italic: true)])!.weight,
        400,
      );
      expect(pickDrawingFace([face(700, italic: true)]), isNull);
    });

    test('a static face before a variable one, then the smaller file', () {
      expect(
        pickDrawingFace([
          face(400, variable: true, bytes: 10),
          face(400, path: 'static', bytes: 90),
        ])!.path,
        'static',
      );
      expect(
        pickDrawingFace([
          face(400, path: 'big', bytes: 90),
          face(400, path: 'small', bytes: 10),
        ])!.path,
        'small',
      );
    });
  });

  group('scanFontDirectories', () {
    late Directory system;
    setUp(() {
      system = Directory.systemTemp.createTempSync('systemfonts');
      for (final name in [
        'ComicNeue-Bold.ttf',
        'Bangers-Regular.ttf',
        'Kalam-Bold.ttf',
      ]) {
        File(font(name)).copySync('${system.path}/$name');
      }
      File('${system.path}/fonts.xml').writeAsStringSync('<familyset/>');
    });
    tearDown(() => system.deleteSync(recursive: true));

    test('lists Latin families by name, sorted, skipping non-fonts', () {
      expect(scanFontDirectories([system.path]).map((f) => f.family), [
        'Bangers',
        'Comic Neue',
        'Kalam',
      ]);
    });

    test('leaves out a file past the size cap', () {
      // Kalam is ~460 KB (it carries Devanagari); the other two are < 60 KB.
      expect(
        scanFontDirectories([
          system.path,
        ], maxBytes: 100 * 1024).map((f) => f.family),
        ['Bangers', 'Comic Neue'],
      );
    });

    test('a font that does not state an open licence is not offered', () {
      // Named in no config here, so only the licence can be what drops it.
      File(
        '${system.path}/Kalam-Bold.ttf',
      ).writeAsBytesSync(withoutLicence(font('Kalam-Bold.ttf')));
      expect(scanFontDirectories([system.path]).map((f) => f.family), [
        'Bangers',
        'Comic Neue',
      ]);
    });

    test('a directory that is not there is skipped', () {
      expect(
        scanFontDirectories([
          '${system.path}/nope',
          system.path,
        ]).map((f) => f.family),
        hasLength(3),
      );
    });

    test('keeps only what the font config offers by name', () {
      // Shaped like AOSP's fonts.xml: named families, a script fallback that
      // carries Latin anyway, and a header comment that mentions a family.
      final config = File('${system.path}/fonts.xml')
        ..writeAsStringSync('''
<?xml version="1.0" encoding="utf-8"?>
<!-- e.g. <family name="x"><font>ComicNeue-Bold.ttf</font></family> -->
<familyset version="23">
  <family name="sans-serif">
    <font weight="400" style="normal">Bangers-Regular.ttf
      <axis tag="wght" stylevalue="400" />
    </font>
  </family>
  <family customizationType="new-named-family" name="kalam">
    <font weight="700" style="normal">Kalam-Bold.ttf</font>
  </family>
  <family lang="und-Latn">
    <font weight="700" style="normal">ComicNeue-Bold.ttf</font>
  </family>
</familyset>
''');
      expect(namedFontFiles([config.path]), {
        'Bangers-Regular.ttf',
        'Kalam-Bold.ttf',
      });
      expect(
        scanFontDirectories(
          [system.path],
          configs: [config.path],
        ).map((f) => f.family),
        ['Bangers', 'Kalam'],
      );
    });

    test('with no readable config the Latin check alone decides', () {
      expect(namedFontFiles(['${system.path}/missing.xml']), isEmpty);
      expect(
        scanFontDirectories(
          [system.path],
          configs: ['${system.path}/missing.xml'],
        ).map((f) => f.family),
        hasLength(3),
      );
    });
  });

  group('DeviceFonts', () {
    late Directory system;
    setUp(() {
      system = Directory.systemTemp.createTempSync('devicefonts');
      // Copied under a name no bundled family uses, so the registry treats it
      // as the device's: its family is "Patrick Hand", the bundled key is
      // "PatrickHand".
      File(
        font('PatrickHand-Regular.ttf'),
      ).copySync('${system.path}/PatrickHand-Regular.ttf');
    });
    tearDown(() => system.deleteSync(recursive: true));

    test(
      'finds nothing, without an isolate, where no directory exists',
      () async {
        final fonts = DeviceFonts(directories: const ['/definitely/not/here']);
        expect(await fonts.families(), isEmpty);
        expect(await fonts.ensure('Roboto'), isFalse);
      },
    );

    test('registers a device family on demand, once', () async {
      final fonts = DeviceFonts(directories: [system.path]);
      expect(
        (await fonts.families()).map((f) => f.family),
        contains('Patrick Hand'),
      );
      final first = fonts.ensure('Patrick Hand');
      expect(identical(first, fonts.ensure('Patrick Hand')), isTrue);
      expect(await first, isTrue);
    });

    test('bundled and imported families are never the device\'s', () async {
      final fonts = DeviceFonts(directories: [system.path]);
      // Answered without a scan: the bundled set is never looked up.
      expect(await fonts.ensure('Bangers'), isTrue);
      fonts.reserve('Patrick Hand');
      expect(await fonts.ensure('Patrick Hand'), isTrue);
    });

    test('a load that failed is tried again by the next ensure', () async {
      final fonts = DeviceFonts(directories: [system.path]);
      final file = File('${system.path}/PatrickHand-Regular.ttf');
      final bytes = file.readAsBytesSync();
      // Scanned while the file is there, then gone when the load reads it.
      expect((await fonts.families()).map((f) => f.family), isNotEmpty);
      file.deleteSync();
      expect(await fonts.ensure('Patrick Hand'), isFalse);
      // A miss like this is not "the phone has no such font": once the file
      // is readable again, asking again loads it.
      file.writeAsBytesSync(bytes);
      expect(await fonts.ensure('Patrick Hand'), isTrue);
    });

    test('loads wait for the imported names, and yield to them', () async {
      final fonts = DeviceFonts(directories: [system.path]);
      final imports = Completer<void>();
      fonts.holdUntilImportsKnown(imports.future);
      var settled = false;
      final load = fonts.ensure('Patrick Hand');
      unawaited(load.then((_) => settled = true));
      await Future<void>.delayed(Duration.zero);
      expect(settled, isFalse, reason: 'held until the imports are known');
      // The catalogue turns out to have an import of that name: it is the
      // import's to draw, and no device face may be registered under it.
      fonts.reserve('Patrick Hand');
      imports.complete();
      expect(await load, isTrue);
    });

    test('ensureFor waits for every family the layers draw with', () async {
      final fonts = DeviceFonts(directories: [system.path]);
      final layers = <Layer>[
        const TextLayer(
          id: 't',
          name: 't',
          text: 'Hi',
          fontFamily: 'Patrick Hand',
        ),
        const BubbleLayer(id: 'b', name: 'b', text: 'Hi'),
      ];
      await fonts.ensureFor(layers);
      expect(await fonts.ensure('Patrick Hand'), isTrue);
    });

    test('a font load is announced to everything that lays text out', () async {
      final fonts = DeviceFonts(directories: [system.path]);
      var announced = 0;
      void listener() => announced++;
      PaintingBinding.instance.systemFonts.addListener(listener);
      addTearDown(
        () => PaintingBinding.instance.systemFonts.removeListener(listener),
      );
      await fonts.ensure('Patrick Hand');
      // Delivered as a platform message, so give it a turn of the loop.
      await Future<void>.delayed(Duration.zero);
      expect(announced, greaterThan(0));
    });
  });
}

/// [source]'s bytes with its licence records - name ids 13 and 14 -
/// renumbered out of the way: the same font, no longer saying what it is
/// licensed under. Patched in place rather than through a font tool so the
/// test needs nothing but the bundled files.
List<int> withoutLicence(String source) {
  final bytes = File(source).readAsBytesSync();
  final data = ByteData.sublistView(bytes);
  final tables = data.getUint16(4);
  for (var i = 0; i < tables; i++) {
    final at = 12 + i * 16;
    if (String.fromCharCodes(bytes.sublist(at, at + 4)) != 'name') continue;
    final name = data.getUint32(at + 8);
    final count = data.getUint16(name + 2);
    for (var r = 0; r < count; r++) {
      final id = name + 6 + r * 12 + 6;
      final value = data.getUint16(id);
      if (value == 13 || value == 14) data.setUint16(id, 300);
    }
  }
  return bytes;
}
