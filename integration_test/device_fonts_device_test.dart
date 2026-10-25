// The device's own fonts, on real Android.
//
// Nothing on a host can check this: the directories the scan reads do not
// exist there, so every widget test sees an empty "On this device" section,
// and a scan that found nothing on a phone would look exactly the same. And a
// font that failed to register does not fail - it draws in the fallback face -
// so "the app did not crash" proves nothing here either. This asserts that the
// scan finds the phone's fonts, that a registered one really changes how text
// lays out, and that an export of a caption in a device font is drawn in it.
//
// Run: flutter test integration_test/device_fonts_device_test.dart -d <deviceId>
import 'package:chromis/core/models/frame.dart';
import 'package:chromis/core/models/layer.dart';
import 'package:chromis/core/theme/app_typography.dart';
import 'package:chromis/features/export/project_renderer.dart';
import 'package:chromis/features/fonts/device_fonts.dart';
import 'package:chromis/features/fonts/font_file_info.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// A name no font on any phone has, so the engine draws it in its fallback.
const _nowhere = 'No Such Family 7f3a';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  double widthIn(String family) {
    final tp = TextPainter(
      text: TextSpan(
        text: 'Hamburgefonstiv WAVY 0123',
        style: TextStyle(
          fontFamily: family,
          fontSize: 40,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final w = tp.width;
    tp.dispose();
    return w;
  }

  // The bundled set belongs here too, for the same reason: a bundled file the
  // engine will not load draws in the fallback without a word, and only a
  // device's real text engine can say so.
  testWidgets('every bundled caption font is drawn in its own face', (
    tester,
  ) async {
    final fallback = widthIn(_nowhere);
    final unresolved = [
      for (final family in AppFonts.bundledFonts)
        if ((widthIn(family) - fallback).abs() < 0.01) family,
    ];
    expect(unresolved, isEmpty, reason: 'drawn in the fallback face');
  });

  late List<DeviceFontFamily> families;

  testWidgets('the scan finds the phone\'s Latin fonts', (tester) async {
    var ms = 0;
    await tester.runAsync(() async {
      final watch = Stopwatch()..start();
      families = await DeviceFonts.instance.families();
      ms = watch.elapsedMilliseconds;
    });
    debugPrint(
      'device fonts: ${families.length} families in $ms ms: '
      '${families.map((f) => f.family).join(', ')}',
    );
    expect(families, isNotEmpty, reason: 'no fonts found on the device');
    // Every Android since 5.0 ships Roboto in /system/fonts.
    expect(families.map((f) => f.family), contains('Roboto'));
    for (final f in families) {
      final info = readFontFaceInfo(f.path)!;
      expect(info.latin, isTrue, reason: f.path);
      expect(info.italic, isFalse, reason: f.path);
      // Offered only under a licence the file itself states - OFL or Apache.
      expect(info.openLicense, isTrue, reason: f.path);
      expect(info.bytes, lessThanOrEqualTo(kMaxDeviceFontBytes));
      expect(f.family.startsWith('.'), isFalse);
    }
    // Only what Android itself offers by name: no Noto script fallbacks that
    // happen to carry Latin, no duplicate RobotoStatic.
    final named = namedFontFiles(kDeviceFontConfigs);
    expect(named, isNotEmpty, reason: 'fonts.xml could not be read');
    for (final f in families) {
      expect(named, contains(f.path.split('/').last), reason: f.family);
    }
    expect(families.map((f) => f.family), isNot(contains('RobotoStatic')));
    // The emoji font and the CJK collections are what the cap is for.
    expect(
      families.where(
        (f) => f.path.contains('Emoji') || f.path.endsWith('.ttc'),
      ),
      isEmpty,
    );
  });

  testWidgets('a registered device font is the face text is drawn in', (
    tester,
  ) async {
    // A face that is plainly not the fallback sans: a serif or a mono.
    final pick = families
        .where(
          (f) => const [
            'Noto Serif',
            'Cutive Mono',
            'Droid Sans Mono',
          ].contains(f.family),
        )
        .firstOrNull;
    if (pick == null) {
      markTestSkipped('no serif or mono family on this device');
      return;
    }
    final before = widthIn(pick.family);
    expect(before, widthIn(_nowhere), reason: 'drawn in the fallback first');
    late bool loaded;
    await tester.runAsync(() async {
      loaded = await DeviceFonts.instance.ensure(pick.family);
    });
    expect(loaded, isTrue);
    expect(
      widthIn(pick.family),
      isNot(before),
      reason: '${pick.family} still measures as the fallback',
    );
  });

  testWidgets('an export waits for a device font it has not seen yet', (
    tester,
  ) async {
    // A family nothing has loaded yet in this process, so it is the renderer's
    // own wait that has to load it.
    final pick = families
        .where(
          (f) =>
              !const [
                'Noto Serif',
                'Cutive Mono',
                'Droid Sans Mono',
                'Roboto',
              ].contains(f.family) &&
              (widthIn(f.family) - widthIn(_nowhere)).abs() < 0.01,
        )
        .firstOrNull;
    if (pick == null) {
      markTestSkipped('no second unloaded family on this device');
      return;
    }
    Future<Uint8List> render(String family) async {
      final frame = Frame(
        id: 'f',
        layers: [
          TextLayer(
            id: 't',
            name: 't',
            text: 'Hamburgefonstiv',
            fontFamily: family,
            fontSize: 60,
          ),
        ],
      );
      final image = await ProjectRenderer.renderImageSized(
        frame,
        canvasWidth: 512,
        canvasHeight: 512,
      );
      final data = await image.toByteData();
      image.dispose();
      return data!.buffer.asUint8List();
    }

    late Uint8List inFont;
    late Uint8List inFallback;
    await tester.runAsync(() async {
      inFont = await render(pick.family);
      inFallback = await render(_nowhere);
    });
    debugPrint('export probe family: ${pick.family}');
    expect(
      listEquals(inFont, inFallback),
      isFalse,
      reason: 'the export drew ${pick.family} in the fallback face',
    );
  });
}
