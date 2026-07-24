import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:photo_editor_ai/features/segmentation/engines/bundled/mask_tensor.dart';

/// Pure tensor <-> mask conversions around the native inference seam: guards the
/// NCHW planar pack recipe (`((px/255) - mean) / std`, R then G then B), the
/// min-max unpack with its low-range guard + bilinear upscale, and the model
/// config defaults. No dart:ui, so it runs as a plain host unit test.
void main() {
  group('ModelConfig', () {
    test('defaults are the ImageNet recipe at 320px', () {
      const c = ModelConfig(assetPath: 'assets/models/x.onnx');
      expect(c.assetPath, 'assets/models/x.onnx');
      expect(c.inputSize, 320);
      expect(c.mean, const [0.485, 0.456, 0.406]);
      expect(c.std, const [0.229, 0.224, 0.225]);
      expect(c.scale, 1 / 255.0);
    });

    test(
      'u2netpConfig points at the bundled weights with the default recipe',
      () {
        expect(u2netpConfig.assetPath, 'assets/models/u2netp.onnx');
        expect(u2netpConfig.inputSize, 320);
        expect(u2netpConfig.mean, const [0.485, 0.456, 0.406]);
        expect(u2netpConfig.std, const [0.229, 0.224, 0.225]);
        expect(u2netpConfig.scale, 1 / 255.0);
      },
    );
  });

  group('packTensor', () {
    const config = ModelConfig(assetPath: 'x');
    // 2x2 RGB, row-major, distinct per-channel bytes so a planar-vs-interleaved
    // or channel-order bug cannot pass.
    final rgb = Uint8List.fromList([
      255, 10, 20, // p0
      30, 200, 40, // p1
      50, 60, 180, // p2
      128, 64, 32, // p3
    ]);
    const r = [255, 30, 50, 128];
    const g = [10, 200, 60, 64];
    const b = [20, 40, 180, 32];

    double recipe(int px, int ch, ModelConfig c) =>
        (px * c.scale - c.mean[ch]) / c.std[ch];

    test('emits a planar NCHW [1,3,H,W] Float32List (R plane, G, then B)', () {
      final t = MaskTensor.packTensor(rgb, 2, config);
      expect(t, isA<Float32List>());
      expect(t.length, 3 * 2 * 2); // 3 planes * size * size
      const n = 4;
      for (var i = 0; i < n; i++) {
        expect(
          t[i],
          closeTo(recipe(r[i], 0, config), 1e-4),
          reason: 'R plane[$i]',
        );
        expect(
          t[n + i],
          closeTo(recipe(g[i], 1, config), 1e-4),
          reason: 'G plane[$i]',
        );
        expect(
          t[2 * n + i],
          closeTo(recipe(b[i], 2, config), 1e-4),
          reason: 'B plane[$i]',
        );
      }
    });

    test('honors the config recipe (identity scale/mean/std => raw bytes)', () {
      const identity = ModelConfig(
        assetPath: 'x',
        mean: [0.0, 0.0, 0.0],
        std: [1.0, 1.0, 1.0],
        scale: 1.0,
      );
      final t = MaskTensor.packTensor(rgb, 2, identity);
      // ((px*1) - 0) / 1 == px, still planar R|G|B.
      expect(t.sublist(0, 4), const [255.0, 30.0, 50.0, 128.0]);
      expect(t.sublist(4, 8), const [10.0, 200.0, 60.0, 64.0]);
      expect(t.sublist(8, 12), const [20.0, 40.0, 180.0, 32.0]);
    });

    test('throws when rgb length != size*size*3', () {
      expect(
        () => MaskTensor.packTensor(Uint8List(11), 2, config), // needs 12
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('unpackMask', () {
    test(
      'low-range guard: near-flat map with mean >= 0.5 collapses to 255',
      () {
        final out = Float32List.fromList([0.8, 0.8, 0.8, 0.8]);
        final m = MaskTensor.unpackMask(out, 2, 2, 2);
        expect(m.width, 2);
        expect(m.height, 2);
        expect(m.alpha, everyElement(255));
      },
    );

    test('low-range guard: near-flat map with mean < 0.5 collapses to 0', () {
      final out = Float32List.fromList([0.3, 0.3, 0.3, 0.3]);
      final m = MaskTensor.unpackMask(out, 2, 2, 2);
      expect(m.alpha, everyElement(0));
    });

    test('low-range guard: mean exactly 0.5 counts as foreground (>=)', () {
      final out = Float32List.fromList([0.5, 0.5, 0.5, 0.5]);
      final m = MaskTensor.unpackMask(out, 2, 2, 2);
      expect(m.alpha, everyElement(255));
    });

    test('lowRangeGuard threshold selects the branch', () {
      // range == 0.1: normal branch under the default guard, guard branch once
      // the guard is raised above the range.
      final out = Float32List.fromList([0.4, 0.4, 0.4, 0.5]);
      final normal = MaskTensor.unpackMask(out, 2, 2, 2);
      expect(normal.alpha.reduce(math.min), 0, reason: 'min-max stretches');
      expect(normal.alpha.reduce(math.max), 255, reason: 'min-max stretches');
      final guarded = MaskTensor.unpackMask(out, 2, 2, 2, lowRangeGuard: 0.2);
      // mean == 0.425 < 0.5 => uniform background.
      expect(guarded.alpha, everyElement(0));
    });

    test('normal branch min-max normalizes + quantizes (dst == size)', () {
      final out = Float32List.fromList([0.0, 0.25, 0.5, 1.0]);
      final m = MaskTensor.unpackMask(out, 2, 2, 2);
      expect(m.width, 2);
      expect(m.height, 2);
      // dst == size => direct sample: min->0, max->255, mids quantized to 8-bit.
      expect(m.alpha, [0, 64, 128, 255]);
    });

    test('min always maps to 0 and max to 255 regardless of input scale', () {
      final out = Float32List.fromList([2.0, 3.0, 5.0, 9.0]);
      final m = MaskTensor.unpackMask(out, 2, 2, 2);
      expect(m.alpha.reduce(math.min), 0);
      expect(m.alpha.reduce(math.max), 255);
    });

    test(
      'bilinearly upscales when dst != size (monotonic, endpoints kept)',
      () {
        // Horizontal ramp: left column 0, right column 1 (row-major, size 2).
        final out = Float32List.fromList([0.0, 1.0, 0.0, 1.0]);
        final m = MaskTensor.unpackMask(out, 2, 5, 1);
        expect(m.width, 5);
        expect(m.height, 1);
        expect(m.length, 5 * 1);
        expect(m.alpha.first, 0);
        expect(m.alpha.last, 255);
        for (var i = 1; i < m.alpha.length; i++) {
          expect(
            m.alpha[i],
            greaterThanOrEqualTo(m.alpha[i - 1]),
            reason: 'ramp must be non-decreasing',
          );
        }
        // Interior sample lies strictly between the ends: real interpolation,
        // not nearest-neighbor.
        expect(m.alpha[2], allOf(greaterThan(0), lessThan(255)));
      },
    );
  });
}
