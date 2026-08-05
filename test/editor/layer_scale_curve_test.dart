import 'package:chromis/features/editor/layer_scale_curve.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Scale slider's mapping.
///
/// Tested as pure functions rather than by dragging the widget, because the
/// thing worth pinning is a number - where 100% falls on the bar - and a drag
/// test measures Material's track insets as much as it measures the curve.
void main() {
  test('100% sits a quarter of the way along, not a seventh', () {
    // The complaint this exists to fix: linear over 20…600% put unity at
    // (1 - 0.2) / (6 - 0.2) = 13.8% of the bar, so the entire shrink range was
    // narrower than the thumb.
    expect(layerScaleFromSlider(kScaleUnityAt), closeTo(1.0, 1e-9));
    expect(sliderFromLayerScale(1.0), closeTo(kScaleUnityAt, 1e-9));
    expect(
      kScaleUnityAt,
      greaterThan((1 - kMinLayerScale) / (kMaxLayerScale - kMinLayerScale)),
    );
  });

  test('the ends are exact, so the slider reaches the pinch clamp', () {
    expect(layerScaleFromSlider(0), kMinLayerScale);
    expect(layerScaleFromSlider(1), kMaxLayerScale);
    expect(sliderFromLayerScale(kMinLayerScale), 0);
    expect(sliderFromLayerScale(kMaxLayerScale), 1);
  });

  test('it round-trips across the range', () {
    for (final scale in const [0.2, 0.35, 0.5, 0.75, 1.0, 1.5, 3.0, 4.5, 6.0]) {
      expect(
        layerScaleFromSlider(sliderFromLayerScale(scale)),
        closeTo(scale, 1e-9),
        reason: 'scale $scale',
      );
    }
  });

  test('it only ever goes up', () {
    var previous = double.negativeInfinity;
    for (var i = 0; i <= 100; i++) {
      final scale = layerScaleFromSlider(i / 100);
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
    final low = layerScaleFromSlider(0.10 + nudge) - layerScaleFromSlider(0.10);
    final high =
        layerScaleFromSlider(0.90 + nudge) - layerScaleFromSlider(0.90);
    expect(low, lessThan(high / 2));
  });

  test('a layer outside the range still lands on the bar', () {
    // Pinched to nothing before the clamp existed, or loaded from an old
    // project. Slider asserts on an out-of-range value, so this must not be
    // one - and it must be at the end the layer is actually past.
    expect(sliderFromLayerScale(0.01), 0);
    expect(sliderFromLayerScale(99), 1);
    expect(layerScaleFromSlider(-5), kMinLayerScale);
    expect(layerScaleFromSlider(5), kMaxLayerScale);
  });
}
