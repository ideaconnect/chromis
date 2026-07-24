import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:photo_editor_ai/features/segmentation/alpha_mask.dart';
import 'package:photo_editor_ai/features/segmentation/mask_store.dart';

/// Mask persistence + GC: the PNG round-trip that carries coverage in the alpha
/// channel (RGB left white) and the SupersededMaskCollector's undo/redo-aware
/// deletion queue. encodePng/decodeAlpha touch dart:ui, so the test engine
/// binding is initialized first.
Future<Uint8List> _decodeStraightRgba(Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png);
  final frame = await codec.getNextFrame();
  final data = await frame.image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  frame.image.dispose();
  codec.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('encodePng / decodeAlpha', () {
    test('round-trips the alpha channel of a gradient mask', () async {
      final mask = AlphaMask(
        width: 4,
        height: 1,
        alpha: Uint8List.fromList([0, 85, 170, 255]),
      );
      final png = await MaskStore.encodePng(mask);
      final decoded = await MaskStore.decodeAlpha(png);
      expect(decoded.width, 4);
      expect(decoded.height, 1);
      expect(decoded.alpha, mask.alpha);
      expect(decoded, mask); // AlphaMask == compares dims + coverage bytes
    });

    test('stores coverage in the alpha channel and leaves RGB white', () async {
      // All-nonzero alpha so premultiply/unpremultiply can't zero the RGB.
      final mask = AlphaMask(
        width: 4,
        height: 1,
        alpha: Uint8List.fromList([64, 128, 192, 255]),
      );
      final png = await MaskStore.encodePng(mask);
      final rgba = await _decodeStraightRgba(png);
      for (var i = 0; i < mask.length; i++) {
        expect(rgba[i * 4], 255, reason: 'R @$i');
        expect(rgba[i * 4 + 1], 255, reason: 'G @$i');
        expect(rgba[i * 4 + 2], 255, reason: 'B @$i');
        expect(rgba[i * 4 + 3], mask.alpha[i], reason: 'A @$i');
      }
    });
  });

  group('SupersededMaskCollector', () {
    late Directory tmp;
    late MaskStore store;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('supersede_test');
      store = MaskStore(baseDir: tmp);
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    File touch(String name) {
      final f = File('${tmp.path}/$name');
      f.writeAsBytesSync(const [0, 1, 2]);
      return f;
    }

    test('supersede ignores a null or unchanged previous path', () {
      final c = SupersededMaskCollector(store);
      final same = '${tmp.path}/a.png';
      c.supersede(null, same);
      c.supersede(same, same);
      expect(c.pending, isEmpty);
    });

    test('distinct superseded paths accumulate once each', () {
      final c = SupersededMaskCollector(store);
      final a = '${tmp.path}/a.png';
      final b = '${tmp.path}/b.png';
      c.supersede(a, '${tmp.path}/cur.png');
      c.supersede(b, '${tmp.path}/cur.png');
      c.supersede(a, '${tmp.path}/cur2.png'); // dup previous -> Set dedups
      expect(c.pending, {a, b});
    });

    test('collect deletes only unreferenced paths and forgets them', () async {
      final c = SupersededMaskCollector(store);
      final a = touch('a.png');
      final b = touch('b.png');
      final cc = touch('c.png');
      c.supersede(a.path, 'cur');
      c.supersede(b.path, 'cur');
      c.supersede(cc.path, 'cur');
      expect(c.pending, {a.path, b.path, cc.path});

      // Keep b (still undo/redo-reachable); drop a and c.
      await c.collect((path) => path == b.path);
      expect(a.existsSync(), isFalse);
      expect(cc.existsSync(), isFalse);
      expect(b.existsSync(), isTrue);
      expect(c.pending, {b.path});

      // A later pass with nothing referenced clears the remainder.
      await c.collect((_) => false);
      expect(b.existsSync(), isFalse);
      expect(c.pending, isEmpty);
    });

    test(
      'collect on an empty queue is a no-op (predicate never called)',
      () async {
        final c = SupersededMaskCollector(store);
        await c.collect((_) => throw StateError('should not be called'));
        expect(c.pending, isEmpty);
      },
    );
  });
}
