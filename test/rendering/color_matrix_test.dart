import 'package:chromis/core/models/image_adjustments.dart';
import 'package:chromis/core/rendering/color_matrix.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the Adjust tool's colour maths: the individual 4×5 factories must
/// reduce to the identity at their neutral value, use the documented contrast
/// translation and Rec.709 luma weights, and [ImageAdjustmentsMatrix.toColorMatrix]
/// must compose brightness∘contrast∘saturation∘hue in the fixed source order.
void main() {
  // Rec. 709 luma coefficients, as hard-coded in color_matrix.dart.
  const lr = 0.2126;
  const lg = 0.7152;
  const lb = 0.0722;

  /// Element-wise close comparison for two 4×5 (length-20) matrices.
  void expectMatrix(
    List<double> actual,
    List<double> expected, {
    double tol = 1e-9,
  }) {
    expect(actual.length, expected.length, reason: 'length');
    for (var i = 0; i < expected.length; i++) {
      expect(actual[i], closeTo(expected[i], tol), reason: 'cell $i');
    }
  }

  group('ColorMatrix.identity', () {
    test('is the canonical 4×5 identity matrix', () {
      expect(ColorMatrix.identity, hasLength(20));
      expect(ColorMatrix.identity, <double>[
        1, 0, 0, 0, 0, //
        0, 1, 0, 0, 0, //
        0, 0, 1, 0, 0, //
        0, 0, 0, 1, 0,
      ]);
    });
  });

  group('unit-valued factories reduce to identity', () {
    test('brightness(1) equals identity', () {
      expectMatrix(ColorMatrix.brightness(1), ColorMatrix.identity);
    });

    test('contrast(1) equals identity (zero translation)', () {
      expectMatrix(ColorMatrix.contrast(1), ColorMatrix.identity);
    });

    test('saturation(1) equals identity', () {
      expectMatrix(ColorMatrix.saturation(1), ColorMatrix.identity);
    });

    test('hueRotate(0) equals identity', () {
      expectMatrix(ColorMatrix.hueRotate(0), ColorMatrix.identity);
    });
  });

  group('contrast', () {
    test('places translation t = 127.5*(1-c) in the RGB rows only', () {
      const c = 0.5;
      const t = 127.5 * (1 - c); // 63.75
      final m = ColorMatrix.contrast(c);
      // Diagonal RGB scale is c.
      expect(m[0], closeTo(c, 1e-9)); // R row, R col
      expect(m[6], closeTo(c, 1e-9)); // G row, G col
      expect(m[12], closeTo(c, 1e-9)); // B row, B col
      // 5th column (translation) is t for R/G/B rows...
      expect(m[4], closeTo(t, 1e-9));
      expect(m[9], closeTo(t, 1e-9));
      expect(m[14], closeTo(t, 1e-9));
      // ...and 0 for the alpha row.
      expect(m[19], closeTo(0, 1e-9));
    });

    test('translation grows as contrast drops below 1', () {
      // t = 127.5*(1-c) is monotonically decreasing in c.
      final low = ColorMatrix.contrast(0.2)[4];
      final mid = ColorMatrix.contrast(0.8)[4];
      expect(low, greaterThan(mid));
      expect(mid, greaterThan(0));
    });
  });

  group('saturation', () {
    test('saturation(0) is luma-weighted greyscale with Rec.709 weights', () {
      final m = ColorMatrix.saturation(0);
      // Each RGB output row collapses to the same [lr, lg, lb] luma weights.
      for (final rowStart in [0, 5, 10]) {
        expect(m[rowStart + 0], closeTo(lr, 1e-9), reason: 'row $rowStart R');
        expect(m[rowStart + 1], closeTo(lg, 1e-9), reason: 'row $rowStart G');
        expect(m[rowStart + 2], closeTo(lb, 1e-9), reason: 'row $rowStart B');
        expect(m[rowStart + 3], closeTo(0, 1e-9)); // alpha col
        expect(m[rowStart + 4], closeTo(0, 1e-9)); // translation col
      }
      // Alpha row is passthrough.
      expectMatrix(m.sublist(15), <double>[0, 0, 0, 1, 0]);
      // Weights sum to 1 (energy preserving greyscale).
      expect(lr + lg + lb, closeTo(1.0, 1e-9));
    });
  });

  group('multiply', () {
    // A concrete non-trivial matrix (has scale + translation terms).
    final sample = ColorMatrix.contrast(1.4);

    test('identity is a left and right identity element', () {
      expectMatrix(ColorMatrix.multiply(ColorMatrix.identity, sample), sample);
      expectMatrix(ColorMatrix.multiply(sample, ColorMatrix.identity), sample);
    });

    test('is associative on a small example', () {
      final a = ColorMatrix.brightness(1.2);
      final b = ColorMatrix.contrast(0.9);
      final c = ColorMatrix.saturation(1.5);
      expectMatrix(
        ColorMatrix.multiply(ColorMatrix.multiply(a, b), c),
        ColorMatrix.multiply(a, ColorMatrix.multiply(b, c)),
        tol: 1e-6,
      );
    });
  });

  group('ImageAdjustmentsMatrix.toColorMatrix', () {
    test('identity adjustments short-circuit to ColorMatrix.identity', () {
      expectMatrix(
        ImageAdjustments.identity.toColorMatrix(),
        ColorMatrix.identity,
      );
    });

    test('composes brightness∘contrast∘saturation∘hue in source order', () {
      const adj = ImageAdjustments(
        brightness: 1.2,
        contrast: 0.9,
        saturation: 1.5,
        hue: 30,
      );
      expect(adj.isIdentity, isFalse);

      // Replicate the exact fold from toColorMatrix():
      //   m = brightness · contrast · saturation · hue · identity
      var expected = ColorMatrix.identity;
      expected = ColorMatrix.multiply(ColorMatrix.hueRotate(adj.hue), expected);
      expected = ColorMatrix.multiply(
        ColorMatrix.saturation(adj.saturation),
        expected,
      );
      expected = ColorMatrix.multiply(
        ColorMatrix.contrast(adj.contrast),
        expected,
      );
      expected = ColorMatrix.multiply(
        ColorMatrix.brightness(adj.brightness),
        expected,
      );

      expectMatrix(adj.toColorMatrix(), expected, tol: 1e-6);
    });

    test('a non-identity adjustment does not reduce to identity', () {
      const adj = ImageAdjustments(brightness: 1.3);
      final m = adj.toColorMatrix();
      // The brightness scale must differ from the identity diagonal.
      expect(m[0], isNot(closeTo(1.0, 1e-6)));
      expect(m[0], closeTo(1.3, 1e-6));
    });
  });
}
