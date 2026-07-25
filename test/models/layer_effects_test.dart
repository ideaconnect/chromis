import 'dart:convert';
import 'dart:ui';

import 'package:chromis/core/models/layer.dart';
import 'package:chromis/core/models/layer_effects.dart';
import 'package:chromis/core/models/layer_transform.dart';
import 'package:flutter_test/flutter_test.dart';

/// Value semantics and the JSON contract for the layer-effect models. These are
/// what the undo stack compares and what a saved project has to survive, so the
/// interesting cases are: defaults, "is this effect even on", the shadow's
/// angle maths, and - most of all - that a manifest written before effects
/// existed still loads.
void main() {
  group('LayerBlend', () {
    test('normal is the default and maps to srcOver', () {
      expect(const LayerEffects().blend, LayerBlend.normal);
      expect(LayerBlend.normal.mode, BlendMode.srcOver);
      expect(LayerBlend.normal.isNormal, isTrue);
      expect(LayerBlend.multiply.isNormal, isFalse);
    });

    test('every mode carries a distinct label and Skia mode', () {
      expect(
        LayerBlend.values.map((b) => b.label).toSet().length,
        LayerBlend.values.length,
      );
      expect(
        LayerBlend.values.map((b) => b.mode).toSet().length,
        LayerBlend.values.length,
      );
    });

    test('fromName round-trips and falls back to normal', () {
      for (final b in LayerBlend.values) {
        expect(LayerBlend.fromName(b.name), b);
      }
      // Persisted by NAME, so a reordered enum can never repaint old projects.
      expect(LayerBlend.fromName('not-a-mode'), LayerBlend.normal);
      expect(LayerBlend.fromName(null), LayerBlend.normal);
    });
  });

  group('LayerShadow', () {
    test('is off by default and needs both a flag and opacity to show', () {
      expect(LayerShadow.none.enabled, isFalse);
      expect(LayerShadow.none.isVisible, isFalse);
      expect(
        const LayerShadow(enabled: true, opacity: 0).isVisible,
        isFalse,
        reason: 'an enabled but fully transparent shadow paints nothing',
      );
      expect(const LayerShadow(enabled: true).isVisible, isTrue);
    });

    test('angle is degrees clockwise from east', () {
      Offset at(double deg) => LayerShadow(angle: deg, distance: 10).offset;
      expect(at(0).dx, closeTo(10, 0.001));
      expect(at(0).dy, closeTo(0, 0.001));
      // 90 drops it straight down - the default, and what the panel implies.
      expect(at(90).dx, closeTo(0, 0.001));
      expect(at(90).dy, closeTo(10, 0.001));
      expect(at(180).dx, closeTo(-10, 0.001));
      expect(at(270).dy, closeTo(-10, 0.001));
    });

    test('a zero distance puts the shadow directly under the layer', () {
      expect(const LayerShadow(angle: 33, distance: 0).offset, Offset.zero);
    });

    test('round-trips through JSON', () {
      const s = LayerShadow(
        enabled: true,
        angle: 210,
        distance: 33,
        blur: 7,
        density: 2,
        color: Color(0xFF102030),
        opacity: 0.3,
      );
      expect(
        LayerShadow.fromJson(
          jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>,
        ),
        s,
      );
    });
  });

  group('LayerStroke', () {
    test('needs both width and opacity to be visible', () {
      expect(LayerStroke.none.isVisible, isFalse);
      expect(const LayerStroke(width: 4).isVisible, isTrue);
      expect(const LayerStroke(width: 4, opacity: 0).isVisible, isFalse);
      // A hairline below the epsilon is "no stroke", not a 1-px one.
      expect(const LayerStroke(width: 0.005).isVisible, isFalse);
    });

    test('round-trips through JSON', () {
      const s = LayerStroke(width: 9, color: Color(0xFF445566), opacity: 0.6);
      expect(
        LayerStroke.fromJson(
          jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>,
        ),
        s,
      );
    });
  });

  group('Vignette', () {
    test('is off until it has an amount', () {
      expect(Vignette.none.isVisible, isFalse);
      expect(const Vignette(amount: 0.2).isVisible, isTrue);
    });

    test('round-trips through JSON', () {
      const v = Vignette(
        amount: 0.8,
        color: Color(0xFF223344),
        size: 0.3,
        softness: 0.9,
      );
      expect(
        Vignette.fromJson(
          jsonDecode(jsonEncode(v.toJson())) as Map<String, dynamic>,
        ),
        v,
      );
    });
  });

  group('LayerEffects', () {
    test('none is the all-default value', () {
      expect(const LayerEffects(), LayerEffects.none);
      expect(LayerEffects.none.isNone, isTrue);
      expect(const LayerEffects(blend: LayerBlend.screen).isNone, isFalse);
    });

    test('serializes only what is set', () {
      expect(LayerEffects.none.toJson(), isEmpty);
      expect(const LayerEffects(blend: LayerBlend.screen).toJson().keys, [
        'blend',
      ]);
      expect(const LayerEffects(stroke: LayerStroke(width: 2)).toJson().keys, [
        'stroke',
      ]);
    });

    test('round-trips through JSON with every part set', () {
      const e = LayerEffects(
        blend: LayerBlend.softLight,
        shadow: LayerShadow(enabled: true, angle: 12),
        stroke: LayerStroke(width: 3),
      );
      expect(
        LayerEffects.fromJson(
          jsonDecode(jsonEncode(e.toJson())) as Map<String, dynamic>,
        ),
        e,
      );
    });

    test('== and hashCode distinguish each part', () {
      const base = LayerEffects();
      for (final v in const [
        LayerEffects(blend: LayerBlend.darken),
        LayerEffects(shadow: LayerShadow(enabled: true)),
        LayerEffects(stroke: LayerStroke(width: 1)),
      ]) {
        expect(v, isNot(equals(base)));
        expect(v.hashCode, isNot(equals(base.hashCode)));
      }
    });
  });

  group('legacy manifests', () {
    Map<String, dynamic> imageJson(Map<String, dynamic> extra) => {
      'type': 'image',
      'id': 'i',
      'name': 'n',
      'transform': const LayerTransform().toJson(),
      'assetPath': '/p',
      ...extra,
    };

    test('a pre-effects die-cut outline becomes a layer stroke', () {
      // The outline used to be two fields of ImageLayer's own; projects saved
      // then must keep their contour rather than silently losing it.
      final l = ImageLayer.fromJson(
        imageJson({'outlineWidth': 6.0, 'outlineColor': 0xFF00FF00}),
      );
      expect(l.effects.stroke.width, 6);
      expect(l.effects.stroke.color, const Color(0xFF00FF00));
      expect(l.effects.stroke.opacity, 1.0);
    });

    test('a legacy outline of zero stays off', () {
      final l = ImageLayer.fromJson(imageJson({'outlineWidth': 0.0}));
      expect(l.effects, LayerEffects.none);
    });

    test('a modern effects block wins over stale legacy keys', () {
      final l = ImageLayer.fromJson(
        imageJson({
          'outlineWidth': 6.0,
          'effects': const LayerEffects(stroke: LayerStroke(width: 2)).toJson(),
        }),
      );
      expect(l.effects.stroke.width, 2);
    });

    test('a layer with no effects key loads with none', () {
      expect(ImageLayer.fromJson(imageJson({})).effects, LayerEffects.none);
    });

    test('text and bubble layers read the shared effects block', () {
      final text = TextLayer.fromJson({
        'type': 'text',
        'id': 't',
        'name': 'n',
        'transform': const LayerTransform().toJson(),
        'text': 'hi',
        'fontFamily': 'Bangers',
        'color': 0xFFFFFFFF,
        'effects': const LayerEffects(blend: LayerBlend.overlay).toJson(),
      });
      expect(text.effects.blend, LayerBlend.overlay);

      final bubble = BubbleLayer.fromJson({
        'type': 'bubble',
        'id': 'b',
        'name': 'n',
        'transform': const LayerTransform().toJson(),
        'effects': const LayerEffects(blend: LayerBlend.screen).toJson(),
      });
      expect(bubble.effects.blend, LayerBlend.screen);
    });
  });

  group('TextLayer stroke', () {
    TextLayer caption({
      double width = TextLayer.defaultStrokeWidth,
      Color? color,
      double opacity = 1,
      bool decorative = false,
    }) => TextLayer(
      id: 't',
      name: 'n',
      text: 'hi',
      fontFamily: 'Bangers',
      strokeWidth: width,
      strokeColor: color,
      strokeOpacity: opacity,
      decorative: decorative,
    );

    test('defaults to the design outline, on and automatic', () {
      final l = caption();
      expect(l.strokeWidth, TextLayer.defaultStrokeWidth);
      expect(l.strokeColor, isNull);
      expect(l.strokeOpacity, 1.0);
      expect(l.hasStroke, isTrue);
    });

    test('hasStroke is off for a zero width, no opacity, or a glyph', () {
      expect(caption(width: 0).hasStroke, isFalse);
      expect(caption(opacity: 0).hasStroke, isFalse);
      expect(
        caption(decorative: true).hasStroke,
        isFalse,
        reason: 'an emoji keeps its own colours - no caption outline',
      );
    });

    test('copyWith can return the colour to automatic', () {
      final explicit = caption(color: const Color(0xFF123456));
      expect(explicit.copyWith(autoStrokeColor: true).strokeColor, isNull);
      expect(
        explicit.copyWith(autoStrokeColor: true).strokeWidth,
        explicit.strokeWidth,
      );
    });

    test('stroke fields are written only when they differ from the design', () {
      expect(caption().toJson().containsKey('strokeWidth'), isFalse);
      expect(caption().toJson().containsKey('strokeColor'), isFalse);
      expect(caption().toJson().containsKey('strokeOpacity'), isFalse);
      final custom = caption(
        width: 8,
        color: const Color(0xFF123456),
        opacity: 0.5,
      );
      final json = custom.toJson();
      expect(json['strokeWidth'], 8);
      expect(json['strokeColor'], 0xFF123456);
      expect(json['strokeOpacity'], 0.5);
      expect(TextLayer.fromJson(json), custom);
    });

    test('a pre-stroke caption loads with the design outline', () {
      final l = TextLayer.fromJson({
        'type': 'text',
        'id': 't',
        'name': 'n',
        'transform': const LayerTransform().toJson(),
        'text': 'hi',
        'fontFamily': 'Bangers',
        'color': 0xFFFFFFFF,
      });
      expect(l.strokeWidth, TextLayer.defaultStrokeWidth);
      expect(l.strokeColor, isNull);
      expect(l.hasStroke, isTrue);
    });
  });
}
