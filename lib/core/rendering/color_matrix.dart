import 'dart:math' as math;

import '../models/image_adjustments.dart';
import '../models/photo_filter.dart';

/// Builds 4×5 color matrices (the format [ColorFilter.matrix] expects) for the
/// Adjust tool, and composes them into a single matrix for an
/// [ImageAdjustments]. Matrices operate on 0-255 channel values; the 5th column
/// is a constant translation in the same range.
abstract final class ColorMatrix {
  ColorMatrix._();

  /// Rec. 709 luma coefficients.
  static const double _lr = 0.2126;
  static const double _lg = 0.7152;
  static const double _lb = 0.0722;

  static const List<double> identity = [
    1, 0, 0, 0, 0, //
    0, 1, 0, 0, 0, //
    0, 0, 1, 0, 0, //
    0, 0, 0, 1, 0,
  ];

  /// Multiplicative RGB scale (1.0 = unchanged).
  static List<double> brightness(double b) => [
    b, 0, 0, 0, 0, //
    0, b, 0, 0, 0, //
    0, 0, b, 0, 0, //
    0, 0, 0, 1, 0,
  ];

  /// Contrast around mid-grey (1.0 = unchanged).
  static List<double> contrast(double c) {
    final t = 127.5 * (1 - c);
    return [
      c, 0, 0, 0, t, //
      0, c, 0, 0, t, //
      0, 0, c, 0, t, //
      0, 0, 0, 1, 0,
    ];
  }

  /// Saturation (0 = greyscale, 1 = unchanged, >1 = more saturated).
  static List<double> saturation(double s) {
    final ir = (1 - s) * _lr;
    final ig = (1 - s) * _lg;
    final ib = (1 - s) * _lb;
    return [
      ir + s, ig, ib, 0, 0, //
      ir, ig + s, ib, 0, 0, //
      ir, ig, ib + s, 0, 0, //
      0, 0, 0, 1, 0,
    ];
  }

  /// Hue rotation in degrees.
  static List<double> hueRotate(double degrees) {
    final rad = degrees * math.pi / 180.0;
    final c = math.cos(rad);
    final s = math.sin(rad);
    return [
      _lr + c * (1 - _lr) + s * (-_lr),
      _lg + c * (-_lg) + s * (-_lg),
      _lb + c * (-_lb) + s * (1 - _lb),
      0,
      0,
      _lr + c * (-_lr) + s * 0.143,
      _lg + c * (1 - _lg) + s * 0.140,
      _lb + c * (-_lb) + s * (-0.283),
      0,
      0,
      _lr + c * (-_lr) + s * (-(1 - _lr)),
      _lg + c * (-_lg) + s * _lg,
      _lb + c * (1 - _lb) + s * _lb,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  /// Independent per-channel gain - the knob behind "warmer" / "cooler" looks.
  static List<double> channels(double r, double g, double b) => [
    r, 0, 0, 0, 0, //
    0, g, 0, 0, 0, //
    0, 0, b, 0, 0, //
    0, 0, 0, 1, 0,
  ];

  /// Adds a constant to each channel (0-255 range). A positive red/green/blue
  /// lift is what gives faded film its milky, never-quite-black shadows.
  static List<double> lift(double r, double g, double b) => [
    1, 0, 0, 0, r, //
    0, 1, 0, 0, g, //
    0, 0, 1, 0, b, //
    0, 0, 0, 1, 0,
  ];

  /// The classic sepia tone (the toned-photograph coefficients).
  static const List<double> sepiaTone = [
    0.393, 0.769, 0.189, 0, 0, //
    0.349, 0.686, 0.168, 0, 0, //
    0.272, 0.534, 0.131, 0, 0, //
    0, 0, 0, 1, 0,
  ];

  /// Composes a list of matrices, **first listed applied first** to the pixel.
  static List<double> compose(List<List<double>> steps) {
    var m = identity;
    for (final step in steps) {
      m = multiply(step, m);
    }
    return m;
  }

  /// Blends [m] towards [identity]; `t == 1` is the full effect. Linear
  /// interpolation of the coefficients, which is exactly how a "filter
  /// strength" slider is expected to behave.
  static List<double> lerpIdentity(List<double> m, double t) {
    if (t >= 1) return m;
    final k = t.clamp(0.0, 1.0);
    return [
      for (var i = 0; i < 20; i++) identity[i] + (m[i] - identity[i]) * k,
    ];
  }

  /// The color transform for a one-tap [PhotoFilter]. Each look is written as a
  /// short recipe of the primitives above rather than 20 opaque numbers, so it
  /// can be read and tuned.
  static List<double> filter(PhotoFilter f) => switch (f) {
    PhotoFilter.none => identity,
    PhotoFilter.vivid => compose([saturation(1.35), contrast(1.12)]),
    PhotoFilter.punch => compose([
      saturation(1.5),
      contrast(1.3),
      brightness(1.02),
    ]),
    PhotoFilter.chrome => compose([
      saturation(1.2),
      contrast(1.22),
      brightness(1.04),
    ]),
    PhotoFilter.warm => compose([channels(1.10, 1.02, 0.90), saturation(1.08)]),
    PhotoFilter.cool => compose([channels(0.92, 1.0, 1.13), saturation(1.06)]),
    PhotoFilter.sunset => compose([
      channels(1.18, 1.02, 0.86),
      saturation(1.15),
      contrast(1.06),
      lift(10, 2, 0),
    ]),
    PhotoFilter.dawn => compose([
      channels(1.10, 1.0, 1.06),
      saturation(1.10),
      lift(12, 6, 10),
      contrast(0.96),
    ]),
    PhotoFilter.dusk => compose([
      channels(0.94, 0.98, 1.16),
      contrast(1.10),
      lift(0, 2, 16),
    ]),
    PhotoFilter.fade => compose([
      contrast(0.82),
      saturation(0.78),
      lift(24, 22, 20),
    ]),
    PhotoFilter.matte => compose([
      contrast(0.88),
      saturation(0.92),
      lift(14, 14, 20),
      channels(1.0, 1.0, 1.04),
    ]),
    PhotoFilter.retro => compose([
      saturation(0.85),
      channels(1.08, 1.0, 0.90),
      contrast(1.06),
      lift(18, 12, 6),
    ]),
    PhotoFilter.sepia => compose([saturation(0.2), sepiaTone, contrast(1.05)]),
    PhotoFilter.mono => compose([saturation(0), contrast(1.12)]),
    PhotoFilter.noir => compose([
      saturation(0),
      contrast(1.5),
      brightness(0.94),
      lift(-8, -8, -8),
    ]),
  };

  /// The tonal half of the HDR effect ([amount] 0…1): shadows lifted, overall
  /// gain pulled back so highlights do not clip, and colour pushed - the look a
  /// phone camera's HDR mode produces. The texture half (local contrast) cannot
  /// be expressed as a matrix and is painted separately.
  static List<double> hdrTone(double amount) {
    if (amount <= 0) return identity;
    final a = amount.clamp(0.0, 1.0);
    return compose([
      lift(26 * a, 26 * a, 26 * a),
      brightness(1 - 0.13 * a),
      contrast(1 + 0.10 * a),
      saturation(1 + 0.28 * a),
    ]);
  }

  /// Composes `a` after `b` (i.e. `a · b`), treating each 4×5 matrix as a 5×5
  /// affine matrix with an implicit `[0,0,0,0,1]` bottom row.
  static List<double> multiply(List<double> a, List<double> b) {
    double at(List<double> m, int r, int col) =>
        r < 4 ? m[r * 5 + col] : (col == 4 ? 1.0 : 0.0);
    final out = List<double>.filled(20, 0);
    for (var i = 0; i < 4; i++) {
      for (var j = 0; j < 5; j++) {
        var sum = 0.0;
        for (var k = 0; k < 5; k++) {
          sum += at(a, i, k) * at(b, k, j);
        }
        out[i * 5 + j] = sum;
      }
    }
    return out;
  }
}

extension ImageAdjustmentsMatrix on ImageAdjustments {
  /// The combined 4×5 color matrix for these adjustments: the one-tap filter
  /// and the HDR tone curve first (they define the look), then the manual
  /// sliders on top - so nudging Brightness after picking a filter behaves the
  /// same way it does on an untouched photo.
  List<double> toColorMatrix() {
    if (isIdentity) return ColorMatrix.identity;
    var m = ColorMatrix.identity;
    if (hasFilter) {
      m = ColorMatrix.multiply(
        ColorMatrix.lerpIdentity(ColorMatrix.filter(filter), filterStrength),
        m,
      );
    }
    if (hdr > 0) m = ColorMatrix.multiply(ColorMatrix.hdrTone(hdr), m);
    m = ColorMatrix.multiply(ColorMatrix.hueRotate(hue), m);
    m = ColorMatrix.multiply(ColorMatrix.saturation(saturation), m);
    m = ColorMatrix.multiply(ColorMatrix.contrast(contrast), m);
    m = ColorMatrix.multiply(ColorMatrix.brightness(brightness), m);
    return m;
  }
}
