import 'dart:convert';
import 'dart:ui';

import 'package:chromis/core/models/frame.dart';
import 'package:chromis/core/models/image_adjustments.dart';
import 'package:chromis/core/models/layer.dart';
import 'package:chromis/core/models/layer_effects.dart';
import 'package:chromis/core/models/layer_transform.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards [Frame]'s value semantics: copyWith field-swaps, a JSON round-trip
/// over a mix of layer variants, and the order-sensitive == / hashCode that
/// come from comparing [layers] with `listEquals` / `Object.hashAll`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const image = ImageLayer(
    id: 'img-1',
    name: 'Photo',
    assetPath: '/data/photo.png',
    transform: LayerTransform(
      position: Offset(100, 120),
      scale: 1.5,
      rotation: 0.3,
    ),
    visible: false,
    opacity: 0.8,
    maskPath: '/data/mask.png',
    adjustments: ImageAdjustments(
      brightness: 1.1,
      contrast: 0.9,
      saturation: 1.2,
      hue: 30,
    ),
    effects: LayerEffects(
      stroke: LayerStroke(width: 4, color: Color(0xFF00FF00)),
    ),
    cropRect: Rect.fromLTRB(0.1, 0.1, 0.9, 0.9),
  );

  const text = TextLayer(
    id: 'txt-1',
    name: 'Caption',
    text: 'Hello',
    fontFamily: 'Manrope',
    transform: LayerTransform(position: Offset(200, 40)),
    fontSize: 32,
    color: Color(0xFFFF0000),
    decorative: true,
  );

  const bubble = BubbleLayer(
    id: 'bub-1',
    name: 'Bubble',
    text: 'Pow!',
    shape: BubbleShape.shout,
    fontSize: 28,
    fillColor: Color(0xFFFFFF00),
    strokeColor: Color(0xFF000000),
    textColor: Color(0xFF111111),
    tail: Offset(0.2, 0.9),
  );

  test('defaults to an empty const layer list', () {
    const f = Frame(id: 'solo');
    expect(f.layers, isEmpty);
    // Source default is `const []`: the canonical const empty list instance.
    expect(identical(f.layers, const <Layer>[]), isTrue);
  });

  test('copyWith replaces id and keeps the same layers instance', () {
    final layers = [image, text];
    final base = Frame(id: 'f0', layers: layers);
    final renamed = base.copyWith(id: 'f1');
    expect(renamed.id, 'f1');
    expect(renamed.layers, same(layers));
    expect(renamed, Frame(id: 'f1', layers: layers));
  });

  test('copyWith replaces layers and keeps the id', () {
    final layers = [image, text];
    final base = Frame(id: 'f0', layers: layers);
    final newLayers = [bubble];
    final swapped = base.copyWith(layers: newLayers);
    expect(swapped.id, 'f0');
    expect(swapped.layers, same(newLayers));
  });

  test('copyWith() returns an equal frame', () {
    final layers = [image, text, bubble];
    final base = Frame(id: 'f0', layers: layers);
    expect(base.copyWith(), base);
  });

  test(
    'toJson/fromJson round-trips a mix of image, text and bubble layers',
    () {
      final layers = [image, text, bubble];
      final frame = Frame(id: 'frame-9', layers: layers);
      // Through real JSON to prove every nested field is serialisable.
      final decoded =
          jsonDecode(jsonEncode(frame.toJson())) as Map<String, dynamic>;
      expect(Frame.fromJson(decoded), frame);
      // And the direct map path.
      expect(Frame.fromJson(frame.toJson()), frame);
    },
  );

  test('equality and hashCode are order-sensitive', () {
    // Distinct list instances so equality is structural, not identity.
    final forward = [image, text];
    final forwardCopy = [image, text];
    final reversed = [text, image];
    final ab = Frame(id: 'f', layers: forward);
    final abAgain = Frame(id: 'f', layers: forwardCopy);
    final ba = Frame(id: 'f', layers: reversed);

    // Same id + same layers in the same order → equal.
    expect(ab, abAgain);
    expect(ab.hashCode, abAgain.hashCode);

    // Reordering the layers breaks equality (listEquals is order-sensitive).
    expect(ab, isNot(ba));
    expect(ab.hashCode, isNot(ba.hashCode));

    // A different id also breaks equality.
    expect(ab, isNot(Frame(id: 'other', layers: forward)));
  });
}
