import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// How a layer's scale maps onto the Adjust panel's Scale slider, and the
/// range both ways of resizing a layer share.
///
/// The range lives here rather than in either caller because the pinch gesture
/// (`EditorCanvas._onScaleUpdate`) and the slider must not disagree about how
/// small or large a layer may get: one of them being more permissive is a way
/// to reach a state the other cannot undo.
///
/// These two are the range on the canvas it was tuned on, [kLayerScaleRefSide];
/// [LayerScaleRange.forCanvas] is what the callers read.
const double kMinLayerScale = 0.2;
const double kMaxLayerScale = 6.0;

/// The canvas side the base range was tuned on - the default 1080 square.
///
/// A layer's scale is relative to the fixed `kLayerFitBoxSide` box, not to the
/// canvas, so a fixed range means something different on every canvas: 6x is
/// 2.4 canvas widths at 1080, but on a 4096 photo-sized canvas a full-bleed
/// photo already sits at 9.3x. A fixed cap there clamped the first pinch down
/// to 6x - the photo jumped to two thirds of its size - and once below it, the
/// slider could never bring it back to full bleed.
const double kLayerScaleRefSide = 1080;

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

/// The scales a layer may be given on one canvas, and the Scale slider's curve
/// across them.
@immutable
class LayerScaleRange {
  const LayerScaleRange(this.min, this.max);

  /// The range on a [kLayerScaleRefSide] canvas.
  static const base = LayerScaleRange(kMinLayerScale, kMaxLayerScale);

  /// The range on a [canvas]-sized canvas: the base range, stretched by how
  /// much bigger or smaller the canvas is than [kLayerScaleRefSide] - and only
  /// ever WIDENED by it.
  ///
  /// The top grows on a bigger canvas and the bottom shrinks on a smaller one;
  /// neither end ever moves inward. Proportional at both ends would keep a
  /// resized composition exactly in range, but it would also pull the top of a
  /// 512 canvas down to 2.8x and push the bottom of a 4096 one up to 0.76x -
  /// and every layer already sitting outside that would jump on its next pinch.
  /// Widening only cannot strand anything that was in range before.
  factory LayerScaleRange.forCanvas(Size canvas) {
    final side = math.max(canvas.width, canvas.height);
    if (side <= 0) return base;
    final ratio = side / kLayerScaleRefSide;
    return LayerScaleRange(
      kMinLayerScale * math.min(1, ratio),
      kMaxLayerScale * math.max(1, ratio),
    );
  }

  final double min;
  final double max;

  bool contains(double scale) => scale >= min && scale <= max;

  /// [proposed] clamped to the range - widened, if need be, to take in
  /// [start], where the gesture began.
  ///
  /// A layer can be outside the range without anyone having pinched it there:
  /// a Resize image shrinks every layer with the canvas, and a project can
  /// predate the range. A plain clamp would make such a layer JUMP on the first
  /// frame of a pinch. Widened to its starting scale, the gesture can bring it
  /// back toward the range but never push it further out.
  double clampGesture(double proposed, {required double start}) {
    final lo = start < min ? start : min;
    final hi = start > max ? start : max;
    return proposed < lo ? lo : (proposed > hi ? hi : proposed);
  }

  /// The exponent that lands [kScaleUnityAt] on exactly 1.0. Derived rather
  /// than tuned by hand, so the range and the unity point cannot drift apart
  /// when the range moves with the canvas.
  double get _curve =>
      math.log((1 - min) / (max - min)) / math.log(kScaleUnityAt);

  /// Slider position (0…1) → layer scale.
  ///
  /// Flattest at the bottom, so the small end - where a few percent is the
  /// difference between legible and gone - gets the finest control, and the
  /// top end, where it is not, gets the coarsest.
  double fromSlider(double position) =>
      min + (max - min) * math.pow(position.clamp(0.0, 1.0), _curve);

  /// The inverse, for putting the thumb where the layer already is.
  ///
  /// A layer can sit outside the range - see [clampGesture] - so this clamps
  /// rather than returning a position off the bar.
  double toSlider(double scale) {
    final t = ((scale - min) / (max - min)).clamp(0.0, 1.0);
    return math.pow(t, 1 / _curve).toDouble();
  }

  @override
  bool operator ==(Object other) =>
      other is LayerScaleRange && other.min == min && other.max == max;

  @override
  int get hashCode => Object.hash(min, max);

  @override
  String toString() => 'LayerScaleRange($min, $max)';
}
