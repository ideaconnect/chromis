import 'dart:math' as math;

/// How a layer's scale maps onto the Adjust panel's Scale slider, and the
/// range both ways of resizing a layer share.
///
/// The range lives here rather than in either caller because the pinch gesture
/// (`EditorCanvas._onScaleUpdate`) and the slider must not disagree about how
/// small or large a layer may get: one of them being more permissive is a way
/// to reach a state the other cannot undo.
const double kMinLayerScale = 0.2;
const double kMaxLayerScale = 6.0;

/// Where 100% sits on the slider, as a fraction of the bar.
///
/// A linear 20…600% put it at 14%, which is the whole reason this curve
/// exists: everything between "as small as it goes" and "actual size" was
/// squeezed into a strip narrower than the thumb, so shrinking a layer by a
/// controlled amount was guesswork - while four fifths of the bar was spent on
/// enlarging, the direction a finger can already do comfortably by pinching.
/// A quarter of the way along gives the shrink range real travel and gives up
/// none of the top end.
const double kScaleUnityAt = 0.25;

/// The exponent that lands [kScaleUnityAt] on exactly 1.0. Derived rather than
/// tuned by hand, so the range and the unity point cannot drift apart if either
/// is ever changed.
final double _curve =
    math.log((1 - kMinLayerScale) / (kMaxLayerScale - kMinLayerScale)) /
    math.log(kScaleUnityAt);

/// Slider position (0…1) → layer scale.
///
/// Flattest at the bottom, so the small end - where a few percent is the
/// difference between legible and gone - gets the finest control, and the top
/// end, where it is not, gets the coarsest.
double layerScaleFromSlider(double position) =>
    kMinLayerScale +
    (kMaxLayerScale - kMinLayerScale) *
        math.pow(position.clamp(0.0, 1.0), _curve);

/// The inverse, for putting the thumb where the layer already is.
///
/// A layer can sit outside the range - pinched to nothing before it was
/// clamped, or loaded from a project that predates the clamp - so this clamps
/// rather than returning a position off the bar.
double sliderFromLayerScale(double scale) {
  final t = ((scale - kMinLayerScale) / (kMaxLayerScale - kMinLayerScale))
      .clamp(0.0, 1.0);
  return math.pow(t, 1 / _curve).toDouble();
}
