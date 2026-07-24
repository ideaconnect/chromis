import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:photo_editor_ai/core/models/image_adjustments.dart';

/// Guards [ImageAdjustments]: the identity value (all multipliers 1.0, hue 0),
/// the isIdentity flag, per-field copyWith invariants, the JSON round-trip and
/// its per-field defaults, plus value == / hashCode.
void main() {
  test('identity has all multipliers at 1.0 and hue 0', () {
    const id = ImageAdjustments.identity;
    expect(id.brightness, 1.0);
    expect(id.contrast, 1.0);
    expect(id.saturation, 1.0);
    expect(id.hue, 0.0);
    expect(const ImageAdjustments(), id);
    expect(id.isIdentity, isTrue);
  });

  test('isIdentity is false when any single field differs', () {
    const id = ImageAdjustments.identity;
    expect(id.copyWith(brightness: 0.5).isIdentity, isFalse);
    expect(id.copyWith(contrast: 1.5).isIdentity, isFalse);
    expect(id.copyWith(saturation: 0.0).isIdentity, isFalse);
    expect(id.copyWith(hue: 10).isIdentity, isFalse);
  });

  test('copyWith replaces one field and leaves the others unchanged', () {
    const base = ImageAdjustments(
      brightness: 1.1,
      contrast: 0.9,
      saturation: 1.2,
      hue: 30,
    );

    expect(base.copyWith(brightness: 2).brightness, 2);
    expect(base.copyWith(brightness: 2).contrast, base.contrast);
    expect(base.copyWith(brightness: 2).saturation, base.saturation);
    expect(base.copyWith(brightness: 2).hue, base.hue);

    expect(base.copyWith(contrast: 2).contrast, 2);
    expect(base.copyWith(contrast: 2).brightness, base.brightness);

    expect(base.copyWith(saturation: 2).saturation, 2);
    expect(base.copyWith(saturation: 2).brightness, base.brightness);

    expect(base.copyWith(hue: -45).hue, -45);
    expect(base.copyWith(hue: -45).brightness, base.brightness);

    // No-op copyWith yields an equal value.
    expect(base.copyWith(), base);
  });

  test('toJson round-trips through fromJson', () {
    const a = ImageAdjustments(
      brightness: 1.2,
      contrast: 0.8,
      saturation: 1.5,
      hue: 45,
    );
    expect(ImageAdjustments.fromJson(a.toJson()), a);
    expect(
      ImageAdjustments.fromJson(
        jsonDecode(jsonEncode(a.toJson())) as Map<String, dynamic>,
      ),
      a,
    );
  });

  test(
    'fromJson fills missing fields with source defaults (1.0 / hue 0.0)',
    () {
      // An empty map decodes straight back to the identity.
      expect(ImageAdjustments.fromJson(const {}), ImageAdjustments.identity);

      // A partial map keeps the given field and defaults the rest.
      final partial = ImageAdjustments.fromJson(const {'hue': 30});
      expect(partial.hue, 30.0);
      expect(partial.brightness, 1.0);
      expect(partial.contrast, 1.0);
      expect(partial.saturation, 1.0);
    },
  );

  test('value equality and hashCode', () {
    const a = ImageAdjustments(
      brightness: 1.1,
      contrast: 0.9,
      saturation: 1.2,
      hue: 30,
    );
    const b = ImageAdjustments(
      brightness: 1.1,
      contrast: 0.9,
      saturation: 1.2,
      hue: 30,
    );
    const c = ImageAdjustments(
      brightness: 1.1,
      contrast: 0.9,
      saturation: 1.2,
      hue: 31,
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(c));
  });
}
