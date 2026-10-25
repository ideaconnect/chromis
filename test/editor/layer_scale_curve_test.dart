import 'dart:ui';

import 'package:chromis/core/rendering/canvas_geometry.dart';
import 'package:chromis/features/editor/layer_scale_curve.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Scale slider's mapping.
///
/// Tested as pure functions rather than by dragging the widget, because the
/// thing worth pinning is a number - where 100% falls on the bar - and a drag
/// test measures Material's track insets as much as it measures the curve.
void main() {
  const base = LayerScaleRange.base;

  test('100% sits a quarter of the way along, not a seventh', () {
    // The complaint this exists to fix: linear over 20…600% put unity at
    // (1 - 0.2) / (6 - 0.2) = 13.8% of the bar, so the entire shrink range was
    // narrower than the thumb.
    expect(base.fromSlider(kScaleUnityAt), closeTo(1.0, 1e-9));
    expect(base.toSlider(1.0), closeTo(kScaleUnityAt, 1e-9));
    expect(
      kScaleUnityAt,
      greaterThan((1 - kMinLayerScale) / (kMaxLayerScale - kMinLayerScale)),
    );
  });

  test('the ends are exact, so the slider reaches the pinch clamp', () {
    expect(base.fromSlider(0), kMinLayerScale);
    expect(base.fromSlider(1), kMaxLayerScale);
    expect(base.toSlider(kMinLayerScale), 0);
    expect(base.toSlider(kMaxLayerScale), 1);
  });

  test('it round-trips across the range', () {
    for (final scale in const [0.2, 0.35, 0.5, 0.75, 1.0, 1.5, 3.0, 4.5, 6.0]) {
      expect(
        base.fromSlider(base.toSlider(scale)),
        closeTo(scale, 1e-9),
        reason: 'scale $scale',
      );
    }
  });

  test('it only ever goes up', () {
    var previous = double.negativeInfinity;
    for (var i = 0; i <= 100; i++) {
      final scale = base.fromSlider(i / 100);
      expect(scale, greaterThan(previous), reason: 'at $i% of the bar');
      previous = scale;
    }
  });

  test('the small end gets the finer control', () {
    // The point of the curve, stated as the property that matters: the same
    // nudge of the thumb changes a small layer by less than a large one. The
    // ratio is about 2.5x, which is the exponent doing its job rather than a
    // number anyone chose - it falls out of putting unity at a quarter.
    const nudge = 0.02;
    final low = base.fromSlider(0.10 + nudge) - base.fromSlider(0.10);
    final high = base.fromSlider(0.90 + nudge) - base.fromSlider(0.90);
    expect(low, lessThan(high / 2));
  });

  test('a layer outside the range still lands on the bar', () {
    // Pinched to nothing before the clamp existed, or loaded from an old
    // project. Slider asserts on an out-of-range value, so this must not be
    // one - and it must be at the end the layer is actually past.
    expect(base.toSlider(0.01), 0);
    expect(base.toSlider(99), 1);
    expect(base.fromSlider(-5), kMinLayerScale);
    expect(base.fromSlider(5), kMaxLayerScale);
  });

  group('on a given canvas', () {
    test('the default canvas gets exactly the base range', () {
      expect(
        LayerScaleRange.forCanvas(const Size(1080, 1080)),
        LayerScaleRange.base,
      );
      // Portrait or landscape, the longer side is what counts.
      expect(
        LayerScaleRange.forCanvas(const Size(1080, 864)),
        LayerScaleRange.base,
      );
    });

    test('a full-bleed photo on the largest import is inside the range', () {
      // The reason the range moves at all. Opening a 4096 x 3072 photo makes a
      // canvas of exactly that size, with the photo at the scale that fills
      // it - 9.3x, past the old fixed 6x. The first pinch then clamped it to
      // two thirds of its size, and the slider could never bring it back.
      const canvas = Size(4096, 3072);
      final fill = photoFitScale(canvas, 4096, 3072);
      expect(fill, greaterThan(kMaxLayerScale));
      final range = LayerScaleRange.forCanvas(canvas);
      expect(range.contains(fill), isTrue);
      expect(range.fromSlider(range.toSlider(fill)), closeTo(fill, 1e-9));
    });

    test('the range only ever widens', () {
      // Nothing that was in range before can find itself outside it: a
      // bigger canvas raises the top and leaves the bottom alone, a smaller
      // one lowers the bottom and leaves the top.
      for (final side in const [16.0, 512.0, 1080.0, 2048.0, 4096.0, 8192.0]) {
        final range = LayerScaleRange.forCanvas(Size(side, side));
        expect(range.min, lessThanOrEqualTo(kMinLayerScale), reason: '$side');
        expect(
          range.max,
          greaterThanOrEqualTo(kMaxLayerScale),
          reason: '$side',
        );
      }
      expect(
        LayerScaleRange.forCanvas(const Size(512, 512)).max,
        kMaxLayerScale,
      );
      expect(
        LayerScaleRange.forCanvas(const Size(4096, 4096)).min,
        kMinLayerScale,
      );
    });

    test('100% stays a quarter of the way along on every canvas', () {
      for (final side in const [64.0, 512.0, 2048.0, 4096.0, 8192.0]) {
        final range = LayerScaleRange.forCanvas(Size(side, side));
        expect(range.fromSlider(kScaleUnityAt), closeTo(1.0, 1e-9));
        expect(range.fromSlider(0), range.min);
        expect(range.fromSlider(1), range.max);
      }
    });
  });

  group('clampGesture', () {
    test('clamps an in-range pinch exactly like a plain clamp', () {
      expect(base.clampGesture(10, start: 2), kMaxLayerScale);
      expect(base.clampGesture(0.01, start: 2), kMinLayerScale);
      expect(base.clampGesture(3, start: 2), 3);
    });

    test('a layer outside the range does not jump when a pinch starts', () {
      // Shrunk past the bottom by a Resize image: the first frame of a pinch
      // (scale factor 1) must leave it where it is, not snap it 4x bigger.
      expect(base.clampGesture(0.05, start: 0.05), 0.05);
      // It can still be brought back toward the range...
      expect(base.clampGesture(0.1, start: 0.05), 0.1);
      // ...but never pushed further out than it started.
      expect(base.clampGesture(0.01, start: 0.05), 0.05);
      // The same at the top.
      expect(base.clampGesture(12, start: 12), 12);
      expect(base.clampGesture(20, start: 12), 12);
      expect(base.clampGesture(8, start: 12), 8);
    });
  });
}
