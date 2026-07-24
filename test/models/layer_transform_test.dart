import 'dart:convert';

import 'package:chromis/core/models/layer_transform.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards [LayerTransform]: the documented identity defaults, per-field
/// copyWith invariants, the x/y/scale/rotation JSON round-trip, value
/// == / hashCode, and the fact that fromJson requires every numeric key.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('identity has the documented defaults', () {
    expect(LayerTransform.identity.position, const Offset(256, 256));
    expect(LayerTransform.identity.scale, 1.0);
    expect(LayerTransform.identity.rotation, 0.0);
    // The default constructor is the identity.
    expect(const LayerTransform(), LayerTransform.identity);
  });

  test('copyWith replaces one field and leaves the others unchanged', () {
    const base = LayerTransform(
      position: Offset(10, 20),
      scale: 2,
      rotation: 0.5,
    );
    const p = Offset(99, 88);

    expect(base.copyWith(position: p).position, p);
    expect(base.copyWith(position: p).scale, base.scale);
    expect(base.copyWith(position: p).rotation, base.rotation);

    expect(base.copyWith(scale: 3).scale, 3);
    expect(base.copyWith(scale: 3).position, base.position);
    expect(base.copyWith(scale: 3).rotation, base.rotation);

    expect(base.copyWith(rotation: 1.25).rotation, 1.25);
    expect(base.copyWith(rotation: 1.25).position, base.position);
    expect(base.copyWith(rotation: 1.25).scale, base.scale);

    // No-op copyWith yields an equal value.
    expect(base.copyWith(), base);
  });

  test('toJson emits x/y/scale/rotation and round-trips through fromJson', () {
    const t = LayerTransform(
      position: Offset(12.5, -3.25),
      scale: 2.5,
      rotation: 1.1,
    );
    final json = t.toJson();
    expect(json['x'], 12.5);
    expect(json['y'], -3.25);
    expect(json['scale'], 2.5);
    expect(json['rotation'], 1.1);

    expect(LayerTransform.fromJson(json), t);
    // Also survives a real JSON encode/decode.
    expect(
      LayerTransform.fromJson(
        jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
      ),
      t,
    );
  });

  test('value equality and hashCode', () {
    const a = LayerTransform(position: Offset(1, 2), scale: 1.5, rotation: 0.2);
    const b = LayerTransform(position: Offset(1, 2), scale: 1.5, rotation: 0.2);
    const c = LayerTransform(position: Offset(1, 2), scale: 1.5, rotation: 0.9);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(c));
  });

  test('fromJson requires every key — a missing one throws', () {
    // x/y/scale/rotation are read as non-nullable `num`; a missing key casts
    // null → num, which throws a TypeError.
    expect(
      () => LayerTransform.fromJson(const {'y': 1, 'scale': 1, 'rotation': 0}),
      throwsA(isA<TypeError>()),
    );
    expect(
      () => LayerTransform.fromJson(const {'x': 1, 'y': 1, 'scale': 1}),
      throwsA(isA<TypeError>()),
    );
  });
}
