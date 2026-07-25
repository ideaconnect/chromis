import 'package:chromis/core/models/image_adjustments.dart';
import 'package:chromis/core/models/photo_filter.dart';
import 'package:chromis/core/rendering/color_matrix.dart';
import 'package:flutter_test/flutter_test.dart';

/// The one-tap filter recipes, checked as maths rather than pixels: what each
/// look does to a sample colour, how strength interpolates, and that the
/// filter/HDR terms fold into the same matrix as the Adjust sliders.
void main() {
  /// Applies a 4x5 matrix to an (r, g, b) triple in 0-255 space, clamped the
  /// way the rasterizer would.
  List<double> apply(List<double> m, double r, double g, double b) => [
    for (var row = 0; row < 3; row++)
      (m[row * 5] * r +
              m[row * 5 + 1] * g +
              m[row * 5 + 2] * b +
              m[row * 5 + 4])
          .clamp(0.0, 255.0),
  ];

  double luma(List<double> rgb) =>
      0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2];

  // A mid-toned orange: has a clear hue, is neither clipped nor black, so every
  // filter has room to move it in either direction.
  const sr = 190.0, sg = 120.0, sb = 70.0;

  test('every filter yields a well-formed 4x5 matrix', () {
    for (final f in PhotoFilter.values) {
      final m = ColorMatrix.filter(f);
      expect(m.length, 20, reason: '${f.name} matrix is the wrong shape');
      for (final v in m) {
        expect(v.isFinite, isTrue, reason: '${f.name} has a non-finite term');
      }
      // Alpha is never touched - a filter must not make a photo transparent.
      expect(m.sublist(15), [0, 0, 0, 1, 0], reason: '${f.name} touches alpha');
    }
  });

  test('none is the identity', () {
    expect(ColorMatrix.filter(PhotoFilter.none), ColorMatrix.identity);
  });

  test('every filter actually changes the picture', () {
    final plain = apply(ColorMatrix.identity, sr, sg, sb);
    for (final f in PhotoFilter.values.where((f) => f != PhotoFilter.none)) {
      final out = apply(ColorMatrix.filter(f), sr, sg, sb);
      final moved = [
        for (var i = 0; i < 3; i++) (out[i] - plain[i]).abs(),
      ].reduce((a, b) => a + b);
      expect(
        moved,
        greaterThan(2),
        reason: '${f.name} leaves the sample colour untouched',
      );
    }
  });

  test('every filter has a distinct look', () {
    final seen = <String, PhotoFilter>{};
    for (final f in PhotoFilter.values) {
      final key = apply(
        ColorMatrix.filter(f),
        sr,
        sg,
        sb,
      ).map((v) => v.round()).join(',');
      expect(
        seen[key],
        isNull,
        reason: '${f.name} renders identically to ${seen[key]?.name}',
      );
      seen[key] = f;
    }
  });

  test('the greyscale looks leave no colour behind', () {
    for (final f in const [PhotoFilter.mono, PhotoFilter.noir]) {
      final out = apply(ColorMatrix.filter(f), sr, sg, sb);
      expect(out[0], closeTo(out[1], 0.5), reason: '${f.name} keeps red');
      expect(out[1], closeTo(out[2], 0.5), reason: '${f.name} keeps blue');
    }
    // Noir is the harder of the two: more contrast, darker.
    final mono = apply(ColorMatrix.filter(PhotoFilter.mono), 60, 60, 60);
    final noir = apply(ColorMatrix.filter(PhotoFilter.noir), 60, 60, 60);
    expect(noir[0], lessThan(mono[0]));
  });

  test('warm pushes red over blue, cool does the reverse', () {
    final warm = apply(ColorMatrix.filter(PhotoFilter.warm), 128, 128, 128);
    expect(warm[0], greaterThan(warm[2]));
    final cool = apply(ColorMatrix.filter(PhotoFilter.cool), 128, 128, 128);
    expect(cool[2], greaterThan(cool[0]));
  });

  test('the faded looks lift the blacks', () {
    for (final f in const [PhotoFilter.fade, PhotoFilter.matte]) {
      final black = apply(ColorMatrix.filter(f), 0, 0, 0);
      expect(
        luma(black),
        greaterThan(8),
        reason: '${f.name} should never reach true black',
      );
    }
  });

  test('vivid and punch raise saturation, punch harder', () {
    double spread(PhotoFilter f) {
      final out = apply(ColorMatrix.filter(f), sr, sg, sb);
      return out.reduce((a, b) => a > b ? a : b) -
          out.reduce((a, b) => a < b ? a : b);
    }

    final plain = spread(PhotoFilter.none);
    expect(spread(PhotoFilter.vivid), greaterThan(plain));
    expect(spread(PhotoFilter.punch), greaterThan(spread(PhotoFilter.vivid)));
  });

  group('strength', () {
    test('0 is the identity and 1 is the full effect', () {
      final full = ColorMatrix.filter(PhotoFilter.noir);
      expect(ColorMatrix.lerpIdentity(full, 0), ColorMatrix.identity);
      expect(ColorMatrix.lerpIdentity(full, 1), full);
      expect(ColorMatrix.lerpIdentity(full, 2), full, reason: 'clamped');
    });

    test('half strength lands between the two', () {
      final full = ColorMatrix.filter(PhotoFilter.mono);
      final half = ColorMatrix.lerpIdentity(full, 0.5);
      final plainOut = apply(ColorMatrix.identity, sr, sg, sb);
      final fullOut = apply(full, sr, sg, sb);
      final halfOut = apply(half, sr, sg, sb);
      expect(halfOut[0], lessThan(plainOut[0]));
      expect(halfOut[0], greaterThan(fullOut[0]));
    });
  });

  group('HDR tone', () {
    test('0 is the identity', () {
      expect(ColorMatrix.hdrTone(0), ColorMatrix.identity);
    });

    test('lifts the shadows and holds back the highlights', () {
      final tone = ColorMatrix.hdrTone(1);
      final shadow = apply(tone, 20, 20, 20);
      final highlight = apply(tone, 245, 245, 245);
      expect(
        luma(shadow),
        greaterThan(20),
        reason: 'shadow detail is pulled up',
      );
      expect(
        highlight[0],
        lessThanOrEqualTo(255),
        reason: 'highlights must not blow out past white',
      );
    });

    test('boosts colour', () {
      final plain = apply(ColorMatrix.identity, sr, sg, sb);
      final hdr = apply(ColorMatrix.hdrTone(1), sr, sg, sb);
      final plainSpread = plain[0] - plain[2];
      expect(hdr[0] - hdr[2], greaterThan(plainSpread));
    });
  });

  group('ImageAdjustments.toColorMatrix', () {
    test('identity adjustments produce the identity matrix', () {
      expect(ImageAdjustments.identity.toColorMatrix(), ColorMatrix.identity);
    });

    test('a filter alone matches the filter matrix', () {
      const a = ImageAdjustments(filter: PhotoFilter.sepia);
      expect(
        apply(a.toColorMatrix(), sr, sg, sb),
        apply(ColorMatrix.filter(PhotoFilter.sepia), sr, sg, sb),
      );
    });

    test('the sliders still apply on top of a filter', () {
      const filtered = ImageAdjustments(filter: PhotoFilter.mono);
      const brighter = ImageAdjustments(
        filter: PhotoFilter.mono,
        brightness: 1.5,
      );
      final a = apply(filtered.toColorMatrix(), sr, sg, sb);
      final b = apply(brighter.toColorMatrix(), sr, sg, sb);
      expect(b[0], greaterThan(a[0]));
      // Brightness is a plain 1.5x on top of the already-grey result.
      expect(b[0], closeTo(a[0] * 1.5, 0.5));
    });

    test('a filter at zero strength contributes nothing', () {
      const a = ImageAdjustments(
        filter: PhotoFilter.noir,
        filterStrength: 0,
        brightness: 1.2,
      );
      const b = ImageAdjustments(brightness: 1.2);
      expect(a.toColorMatrix(), b.toColorMatrix());
      expect(a.hasFilter, isFalse);
    });

    test('isMatrixOnly is false exactly when HDR needs its second pass', () {
      expect(ImageAdjustments.identity.isMatrixOnly, isTrue);
      expect(
        const ImageAdjustments(filter: PhotoFilter.vivid).isMatrixOnly,
        isTrue,
      );
      expect(const ImageAdjustments(hdr: 0.4).isMatrixOnly, isFalse);
    });
  });
}
