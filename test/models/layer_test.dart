import 'dart:ui';

import 'package:chromis/core/models/image_adjustments.dart';
import 'package:chromis/core/models/layer.dart';
import 'package:chromis/core/models/layer_transform.dart';
import 'package:flutter_test/flutter_test.dart';

/// Value-semantics + JSON contract for the [Layer] hierarchy. These are the
/// serialization guarantees the editor's undo stack and project save/load rely
/// on: copyWith mutates exactly one field, toJson->fromJson round-trips, and
/// fromJson tolerates missing/legacy keys via documented defaults.

const _fullRect = Rect.fromLTRB(0, 0, 1, 1);

/// A fully non-default ImageLayer so copyWith / round-trip tests exercise every
/// field (nothing sitting at its default value that a bug could silently match).
ImageLayer fullImage() => const ImageLayer(
  id: 'img-1',
  name: 'Photo',
  assetPath: '/assets/photo.png',
  transform: LayerTransform(position: Offset(10, 20), scale: 2, rotation: 0.5),
  visible: false,
  opacity: 0.5,
  maskPath: '/assets/mask.png',
  adjustments: ImageAdjustments(
    brightness: 1.2,
    contrast: 0.8,
    saturation: 1.5,
    hue: 30,
  ),
  outlineWidth: 4,
  outlineColor: Color(0xFF00FF00),
  cropRect: Rect.fromLTRB(0.1, 0.2, 0.8, 0.9),
);

TextLayer fullText() => const TextLayer(
  id: 'txt-1',
  name: 'Caption',
  text: 'Hello',
  fontFamily: 'Manrope',
  fontSize: 52,
  color: Color(0xFFAABBCC),
  decorative: true,
  transform: LayerTransform(position: Offset(7, 8), scale: 0.9, rotation: 0.1),
  visible: false,
  opacity: 0.6,
);

BubbleLayer fullBubble() => const BubbleLayer(
  id: 'bub-1',
  name: 'Bubble',
  text: 'POW',
  shape: BubbleShape.thought,
  fontFamily: 'Comic',
  fontSize: 33,
  fillColor: Color(0xFF112233),
  strokeColor: Color(0xFF445566),
  textColor: Color(0xFF778899),
  tail: Offset(0.3, -0.4),
  transform: LayerTransform(position: Offset(5, 6), scale: 1.5, rotation: -0.2),
  visible: false,
  opacity: 0.75,
);

void main() {
  // Layers hold Color / Rect / Offset (dart:ui) - bind before touching them.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ImageLayer', () {
    test('default constructor values', () {
      const l = ImageLayer(id: 'i', name: 'n', assetPath: '/p');
      expect(l.type, 'image');
      expect(l.transform, LayerTransform.identity);
      expect(l.visible, isTrue);
      expect(l.opacity, 1.0);
      expect(l.maskPath, isNull);
      expect(l.adjustments, ImageAdjustments.identity);
      expect(l.outlineWidth, 0);
      expect(l.outlineColor, const Color(0xFFFFFFFF));
      expect(l.cropRect, _fullRect);
      expect(l.hasOutline, isFalse);
      expect(l.isCropped, isFalse);
    });

    test('copyWith changes exactly one field, leaving the rest untouched', () {
      final o = fullImage();
      // For each field: the new value lands, and restoring it reproduces the
      // original exactly (so nothing else moved).
      expect(o.copyWith(id: 'z').id, 'z');
      expect(o.copyWith(id: 'z').copyWith(id: o.id), o);

      expect(o.copyWith(name: 'Z').name, 'Z');
      expect(o.copyWith(name: 'Z').copyWith(name: o.name), o);

      const t = LayerTransform(scale: 9);
      expect(o.copyWith(transform: t).transform, t);
      expect(o.copyWith(transform: t).copyWith(transform: o.transform), o);

      expect(o.copyWith(visible: true).visible, isTrue);
      expect(o.copyWith(visible: true).copyWith(visible: o.visible), o);

      expect(o.copyWith(opacity: 0.1).opacity, 0.1);
      expect(o.copyWith(opacity: 0.1).copyWith(opacity: o.opacity), o);

      expect(o.copyWith(assetPath: '/x').assetPath, '/x');
      expect(o.copyWith(assetPath: '/x').copyWith(assetPath: o.assetPath), o);

      expect(o.copyWith(maskPath: '/m2').maskPath, '/m2');
      expect(o.copyWith(maskPath: '/m2').copyWith(maskPath: o.maskPath), o);

      const adj = ImageAdjustments(hue: 90);
      expect(o.copyWith(adjustments: adj).adjustments, adj);
      expect(
        o.copyWith(adjustments: adj).copyWith(adjustments: o.adjustments),
        o,
      );

      expect(o.copyWith(outlineWidth: 12).outlineWidth, 12);
      expect(
        o.copyWith(outlineWidth: 12).copyWith(outlineWidth: o.outlineWidth),
        o,
      );

      const oc = Color(0xFF010203);
      expect(o.copyWith(outlineColor: oc).outlineColor, oc);
      expect(
        o.copyWith(outlineColor: oc).copyWith(outlineColor: o.outlineColor),
        o,
      );

      const cr = Rect.fromLTRB(0, 0, 0.4, 0.4);
      expect(o.copyWith(cropRect: cr).cropRect, cr);
      expect(o.copyWith(cropRect: cr).copyWith(cropRect: o.cropRect), o);
    });

    test('copyWith(clearMask: true) forces maskPath null even when a maskPath '
        'is also passed', () {
      final o = fullImage();
      expect(o.maskPath, isNotNull);
      expect(o.copyWith(clearMask: true).maskPath, isNull);
      expect(
        o.copyWith(clearMask: true, maskPath: '/ignored.png').maskPath,
        isNull,
      );
    });

    test(
      'toJson -> fromJson round-trips, incl. crop list and outlineColor',
      () {
        final o = fullImage();
        final json = o.toJson();
        // Documented serialized shape.
        expect(json['type'], 'image');
        expect(json['crop'], [0.1, 0.2, 0.8, 0.9]);
        expect(json['outlineColor'], 0xFF00FF00);
        // Round-trips through both the subtype and the dispatcher.
        expect(ImageLayer.fromJson(json), o);
        expect(Layer.fromJson(json), o);
      },
    );

    test('fromJson applies documented defaults for missing optional keys', () {
      final json = <String, dynamic>{
        'type': 'image',
        'id': 'i',
        'name': 'n',
        'transform': const LayerTransform().toJson(),
        'assetPath': '/p',
        // visible, opacity, adjustments, outlineWidth, outlineColor, crop, mask
        // all omitted.
      };
      final l = ImageLayer.fromJson(json);
      expect(l.visible, isTrue);
      expect(l.opacity, 1.0);
      expect(l.adjustments, ImageAdjustments.identity);
      expect(l.outlineWidth, 0);
      expect(l.outlineColor, const Color(0xFFFFFFFF));
      expect(l.maskPath, isNull);
      expect(l.cropRect, _fullRect);
    });

    test('crop parsing falls back to the full rect for missing / wrong-length '
        '/ non-list values', () {
      ImageLayer withCrop(Object? crop) => ImageLayer.fromJson({
        'type': 'image',
        'id': 'i',
        'name': 'n',
        'transform': const LayerTransform().toJson(),
        'assetPath': '/p',
        'crop': ?crop,
      });
      expect(withCrop(null).cropRect, _fullRect); // missing key
      expect(withCrop(<double>[0.0, 0.0, 1.0]).cropRect, _fullRect); // len 3
      expect(
        withCrop(<double>[0.0, 0.0, 1.0, 1.0, 1.0]).cropRect,
        _fullRect,
      ); // len 5
      expect(withCrop('nope').cropRect, _fullRect); // non-list
      expect(withCrop(42).cropRect, _fullRect); // non-list
      // A well-formed 4-element list is honored.
      expect(
        withCrop(<double>[0.25, 0.25, 0.75, 0.75]).cropRect,
        const Rect.fromLTRB(0.25, 0.25, 0.75, 0.75),
      );
    });

    test('isCropped and hasOutline reflect their fields', () {
      const base = ImageLayer(id: 'i', name: 'n', assetPath: '/p');
      expect(base.isCropped, isFalse);
      expect(base.hasOutline, isFalse);
      expect(base.copyWith(cropRect: _fullRect).isCropped, isFalse);
      expect(
        base.copyWith(cropRect: const Rect.fromLTRB(0, 0, 0.5, 1)).isCropped,
        isTrue,
      );
      expect(base.copyWith(outlineWidth: 0).hasOutline, isFalse);
      expect(base.copyWith(outlineWidth: 2).hasOutline, isTrue);
    });

    test('== and hashCode distinguish cropRect / adjustments / transform / '
        'color / maskPath', () {
      final o = fullImage();
      final variants = <ImageLayer>[
        o.copyWith(cropRect: const Rect.fromLTRB(0, 0, 0.5, 0.5)),
        o.copyWith(adjustments: const ImageAdjustments(brightness: 2)),
        o.copyWith(transform: const LayerTransform(scale: 3)),
        o.copyWith(outlineColor: const Color(0xFF010203)),
        o.copyWith(maskPath: '/different.png'),
      ];
      for (final v in variants) {
        expect(v, isNot(equals(o)));
        expect(v.hashCode, isNot(equals(o.hashCode)));
      }
      // Two independently-built identical instances are equal.
      expect(fullImage(), equals(o));
      expect(fullImage().hashCode, equals(o.hashCode));
    });
  });

  group('TextLayer', () {
    test('default constructor values', () {
      const l = TextLayer(
        id: 't',
        name: 'n',
        text: 'hi',
        fontFamily: 'Manrope',
      );
      expect(l.type, 'text');
      expect(l.transform, LayerTransform.identity);
      expect(l.visible, isTrue);
      expect(l.opacity, 1.0);
      expect(l.fontSize, 40);
      expect(l.color, const Color(0xFFFFFFFF));
      expect(l.decorative, isFalse);
    });

    test('copyWith changes exactly one field, leaving the rest untouched', () {
      final o = fullText();
      expect(o.copyWith(id: 'z').id, 'z');
      expect(o.copyWith(id: 'z').copyWith(id: o.id), o);

      expect(o.copyWith(name: 'Z').name, 'Z');
      expect(o.copyWith(name: 'Z').copyWith(name: o.name), o);

      const t = LayerTransform(scale: 9);
      expect(o.copyWith(transform: t).transform, t);
      expect(o.copyWith(transform: t).copyWith(transform: o.transform), o);

      expect(o.copyWith(visible: true).visible, isTrue);
      expect(o.copyWith(visible: true).copyWith(visible: o.visible), o);

      expect(o.copyWith(opacity: 0.1).opacity, 0.1);
      expect(o.copyWith(opacity: 0.1).copyWith(opacity: o.opacity), o);

      expect(o.copyWith(text: 'Bye').text, 'Bye');
      expect(o.copyWith(text: 'Bye').copyWith(text: o.text), o);

      expect(o.copyWith(fontFamily: 'Space').fontFamily, 'Space');
      expect(
        o.copyWith(fontFamily: 'Space').copyWith(fontFamily: o.fontFamily),
        o,
      );

      expect(o.copyWith(fontSize: 11).fontSize, 11);
      expect(o.copyWith(fontSize: 11).copyWith(fontSize: o.fontSize), o);

      const c = Color(0xFF010203);
      expect(o.copyWith(color: c).color, c);
      expect(o.copyWith(color: c).copyWith(color: o.color), o);

      expect(o.copyWith(decorative: false).decorative, isFalse);
      expect(
        o.copyWith(decorative: false).copyWith(decorative: o.decorative),
        o,
      );
    });

    test('toJson -> fromJson round-trips, incl. color and decorative', () {
      final o = fullText();
      final json = o.toJson();
      expect(json['type'], 'text');
      expect(json['color'], 0xFFAABBCC);
      expect(json['decorative'], isTrue);
      expect(TextLayer.fromJson(json), o);
      expect(Layer.fromJson(json), o);
    });

    test('fromJson defaults: missing fontSize -> 40, decorative -> false', () {
      final l = TextLayer.fromJson({
        'type': 'text',
        'id': 't',
        'name': 'n',
        'transform': const LayerTransform().toJson(),
        'text': 'hi',
        'fontFamily': 'Manrope',
        'color': 0xFF123456,
        // fontSize + decorative omitted.
      });
      expect(l.fontSize, 40);
      expect(l.decorative, isFalse);
    });

    test('fromJson requires color (it has no default)', () {
      final json = <String, dynamic>{
        'type': 'text',
        'id': 't',
        'name': 'n',
        'transform': const LayerTransform().toJson(),
        'text': 'hi',
        'fontFamily': 'Manrope',
        // color intentionally missing.
      };
      expect(() => TextLayer.fromJson(json), throwsA(isA<TypeError>()));
    });

    test('== and hashCode distinguish color (and other fields)', () {
      final o = fullText();
      final variants = <TextLayer>[
        o.copyWith(color: const Color(0xFF010203)),
        o.copyWith(transform: const LayerTransform(scale: 3)),
        o.copyWith(text: 'other'),
      ];
      for (final v in variants) {
        expect(v, isNot(equals(o)));
        expect(v.hashCode, isNot(equals(o.hashCode)));
      }
      expect(fullText(), equals(o));
      expect(fullText().hashCode, equals(o.hashCode));
    });
  });

  group('BubbleLayer', () {
    test('default constructor values', () {
      const l = BubbleLayer(id: 'b', name: 'n');
      expect(l.type, 'bubble');
      expect(l.transform, LayerTransform.identity);
      expect(l.visible, isTrue);
      expect(l.opacity, 1.0);
      expect(l.text, '');
      expect(l.shape, BubbleShape.speech);
      expect(l.fontFamily, 'Bangers');
      expect(l.fontSize, 26);
      expect(l.fillColor, const Color(0xFFFFFFFF));
      expect(l.strokeColor, const Color(0xFF14101A));
      expect(l.textColor, const Color(0xFF14101A));
      expect(l.tail, const Offset(-0.28, 0.86));
    });

    test('copyWith changes exactly one field, leaving the rest untouched', () {
      final o = fullBubble();
      expect(o.copyWith(id: 'z').id, 'z');
      expect(o.copyWith(id: 'z').copyWith(id: o.id), o);

      expect(o.copyWith(name: 'Z').name, 'Z');
      expect(o.copyWith(name: 'Z').copyWith(name: o.name), o);

      const t = LayerTransform(scale: 9);
      expect(o.copyWith(transform: t).transform, t);
      expect(o.copyWith(transform: t).copyWith(transform: o.transform), o);

      expect(o.copyWith(visible: true).visible, isTrue);
      expect(o.copyWith(visible: true).copyWith(visible: o.visible), o);

      expect(o.copyWith(opacity: 0.1).opacity, 0.1);
      expect(o.copyWith(opacity: 0.1).copyWith(opacity: o.opacity), o);

      expect(o.copyWith(text: 'BANG').text, 'BANG');
      expect(o.copyWith(text: 'BANG').copyWith(text: o.text), o);

      expect(o.copyWith(shape: BubbleShape.whisper).shape, BubbleShape.whisper);
      expect(
        o.copyWith(shape: BubbleShape.whisper).copyWith(shape: o.shape),
        o,
      );

      expect(o.copyWith(fontFamily: 'Bangers').fontFamily, 'Bangers');
      expect(
        o.copyWith(fontFamily: 'Bangers').copyWith(fontFamily: o.fontFamily),
        o,
      );

      expect(o.copyWith(fontSize: 9).fontSize, 9);
      expect(o.copyWith(fontSize: 9).copyWith(fontSize: o.fontSize), o);

      const fc = Color(0xFF010203);
      expect(o.copyWith(fillColor: fc).fillColor, fc);
      expect(o.copyWith(fillColor: fc).copyWith(fillColor: o.fillColor), o);

      const sc = Color(0xFF040506);
      expect(o.copyWith(strokeColor: sc).strokeColor, sc);
      expect(
        o.copyWith(strokeColor: sc).copyWith(strokeColor: o.strokeColor),
        o,
      );

      const tc = Color(0xFF070809);
      expect(o.copyWith(textColor: tc).textColor, tc);
      expect(o.copyWith(textColor: tc).copyWith(textColor: o.textColor), o);

      const tail = Offset(0.11, 0.22);
      expect(o.copyWith(tail: tail).tail, tail);
      expect(o.copyWith(tail: tail).copyWith(tail: o.tail), o);
    });

    test(
      'toJson -> fromJson round-trips, incl. shape.name, tail and colors',
      () {
        final o = fullBubble();
        final json = o.toJson();
        expect(json['type'], 'bubble');
        expect(json['shape'], 'thought');
        expect(json['tailDx'], 0.3);
        expect(json['tailDy'], -0.4);
        expect(json['fillColor'], 0xFF112233);
        expect(json['strokeColor'], 0xFF445566);
        expect(json['textColor'], 0xFF778899);
        expect(json['fontFamily'], 'Comic');
        expect(json['fontSize'], 33);
        expect(json['text'], 'POW');
        expect(BubbleLayer.fromJson(json), o);
        expect(Layer.fromJson(json), o);
      },
    );

    test('fromJson defaults: unknown shape -> speech, missing tail/colors/'
        'text/font use documented defaults', () {
      final l = BubbleLayer.fromJson({
        'type': 'bubble',
        'id': 'b',
        'name': 'n',
        'transform': const LayerTransform().toJson(),
        'shape': 'not-a-real-shape',
        // text, fontFamily, fontSize, colors, tailDx, tailDy all omitted.
      });
      expect(l.shape, BubbleShape.speech);
      expect(l.text, '');
      expect(l.fontFamily, 'Bangers');
      expect(l.fontSize, 26);
      expect(l.fillColor, const Color(0xFFFFFFFF));
      expect(l.strokeColor, const Color(0xFF14101A));
      expect(l.textColor, const Color(0xFF14101A));
      expect(l.tail, const Offset(-0.28, 0.86));
    });

    test('== and hashCode distinguish colors, shape and tail', () {
      final o = fullBubble();
      final variants = <BubbleLayer>[
        o.copyWith(fillColor: const Color(0xFF010203)),
        o.copyWith(strokeColor: const Color(0xFF010203)),
        o.copyWith(textColor: const Color(0xFF010203)),
        o.copyWith(shape: BubbleShape.shout),
        o.copyWith(tail: const Offset(0.9, 0.9)),
      ];
      for (final v in variants) {
        expect(v, isNot(equals(o)));
        expect(v.hashCode, isNot(equals(o.hashCode)));
      }
      expect(fullBubble(), equals(o));
      expect(fullBubble().hashCode, equals(o.hashCode));
    });
  });

  group('Layer.fromJson dispatch', () {
    test('dispatches "image" / "text" / "bubble" to the right subtype', () {
      expect(Layer.fromJson(fullImage().toJson()), isA<ImageLayer>());
      expect(Layer.fromJson(fullText().toJson()), isA<TextLayer>());
      expect(Layer.fromJson(fullBubble().toJson()), isA<BubbleLayer>());
    });

    test('an unknown type throws FormatException', () {
      expect(
        () => Layer.fromJson(const {'type': 'sticker'}),
        throwsFormatException,
      );
    });
  });

  group('cellId (Photo Grid)', () {
    // Every variant can live inside a cell - a caption pinned into one photo of
    // the collage is as valid as the photo itself.
    final variants = <String, Layer>{
      'image': fullImage(),
      'text': fullText(),
      'bubble': fullBubble(),
    };

    Layer withCell(Layer layer, String? cellId, {bool clear = false}) =>
        switch (layer) {
          ImageLayer() => layer.copyWith(cellId: cellId, clearCell: clear),
          TextLayer() => layer.copyWith(cellId: cellId, clearCell: clear),
          BubbleLayer() => layer.copyWith(cellId: cellId, clearCell: clear),
        };

    for (final entry in variants.entries) {
      test('${entry.key}: defaults to null (a free layer)', () {
        expect(entry.value.cellId, isNull);
        // Absent, not null-valued: manifests of non-collage projects are
        // byte-identical to the pre-grid schema.
        expect(entry.value.toJson().containsKey('cellId'), isFalse);
      });

      test('${entry.key}: round-trips and clears through copyWith', () {
        final assigned = withCell(entry.value, 'c2');
        expect(assigned.cellId, 'c2');
        expect(assigned.toJson()['cellId'], 'c2');
        expect(Layer.fromJson(assigned.toJson()).cellId, 'c2');
        expect(assigned, isNot(entry.value)); // participates in ==
        expect(assigned.hashCode, isNot(entry.value.hashCode));

        expect(withCell(assigned, null, clear: true).cellId, isNull);
        // A bare copyWith must not silently drop the assignment.
        expect(withCell(assigned, null).cellId, 'c2');
      });
    }
  });
}
