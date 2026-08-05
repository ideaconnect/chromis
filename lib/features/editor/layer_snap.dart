import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../core/models/layer.dart';
import '../../core/models/layer_transform.dart';
import 'layer_scale_curve.dart';

/// How near two layers' angles have to be before one may take the other's, in
/// radians.
///
/// 4°, which is two things at once. It has to clear the case this exists for -
/// a layer at 26° brought against one at 28° - with enough margin that the
/// gesture does not have to be precise about the angle it is already at. And it
/// has to stay under a *deliberate* tilt: 5° is about the smallest slant anyone
/// applies on purpose, and a snap that ate it would be taking away an edit
/// rather than helping make one.
///
/// The real protection is not this number, though - see [snapTransform]. A move
/// may only take a neighbour's angle if it is also landing on that neighbour's
/// edge, so a tilted layer crossing the canvas is never quietly straightened.
const double kSnapRotationTolerance = 4 * math.pi / 180;

/// How much of a twist or a squeeze counts as MEANING to turn or resize.
///
/// These exist because `d.rotation != 0` and `d.scale != 1` are the wrong
/// question, and dangerously so. Flutter derives both from the line between two
/// pointers - a span ratio and an `atan2` difference - so with two fingers down
/// they are exactly 0 and 1 only when the fingers move perfectly parallel and
/// perfectly together, which no hand does. Read as intent, they say "yes, a
/// deliberate twist" and "yes, a deliberate resize" for the whole of every
/// two-finger gesture, and a plain two-finger MOVE would come out resized to a
/// neighbour's width and turned to its angle.
///
/// A synthetic pointer moves exactly, so a widget test cannot see any of this -
/// which is why the numbers are here with the reason rather than inline at the
/// call site as a cleverness.
const double kSnapTwistSlop = kSnapRotationTolerance;
const double kSnapPinchSlop = 0.02;

/// How far off square still counts as square to the canvas, in radians.
///
/// Half a degree of pinch wobble is not a decision to tilt something, and two
/// things turn on being square: the canvas's own edges are only an alignment
/// while the frame is parallel to them, and a level layer does not give up
/// being level just for being dragged past something tilted. 0.25° puts the far
/// corner of a 1080 canvas under two screen pixels off the true edge, so
/// treating it as square cannot be seen.
const double kSnapSquareSlop = 0.25 * math.pi / 180;

/// Which of the frame's two axes an alignment was found on. [x] is the frame's
/// own horizontal - the canvas's x only when the frame is the canvas's.
enum SnapAxis { x, y }

/// The axes alignment is measured along.
///
/// This is a real choice and not an implementation detail, because the two
/// callers cannot use the same one:
///
/// - [canvas] measures everything on the canvas's x and y. The placement
///   sliders must, because each of them moves the layer along ONE canvas axis:
///   an alignment found on any other direction would move it on the axis the
///   slider does not own, which is a two-axis control wearing a one-axis label.
///   A turned layer is therefore measured by its bounding box here - that is
///   genuinely what "how far left does it reach" means on the canvas's x.
/// - [layer] measures on the moving layer's OWN rotation, so a turned layer
///   aligns by the edges it actually draws rather than by a bounding box its
///   edges only touch at one corner. This is the frame a gesture uses, and the
///   only one in which two turned layers can be made flush.
enum SnapFrame { canvas, layer }

/// An alignment that fired, so the canvas can draw the line the layer landed
/// on. Without one a snap is a jump with no cause on screen, which reads as the
/// drag stuttering rather than as the layer being helped into place.
@immutable
class SnapGuide {
  const SnapGuide(this.axis, this.position, {this.angle = 0});

  final SnapAxis axis;

  /// Coordinate of the line along [axis], in the frame's coordinates - which
  /// are the canvas's own when [angle] is 0.
  final double position;

  /// The frame this was measured in. The guide is the line of points whose
  /// [axis] coordinate is [position], so it runs PERPENDICULAR to that axis:
  /// at angle 0 an [SnapAxis.x] guide is the familiar vertical line.
  final double angle;

  @override
  bool operator ==(Object other) =>
      other is SnapGuide &&
      other.axis == axis &&
      other.position == position &&
      other.angle == angle;

  @override
  int get hashCode => Object.hash(axis, position, angle);

  @override
  String toString() => 'SnapGuide($axis, $position, angle: $angle)';
}

/// What [snapTransform] decided: the transform to actually apply, plus what to
/// show for it.
@immutable
class SnapResult {
  const SnapResult(
    this.transform, {
    this.guides = const [],
    this.sizeMatchId,
    this.rotationMatchId,
  });

  final LayerTransform transform;

  /// The lines that fired - at most one per frame axis.
  final List<SnapGuide> guides;

  /// The layer this one was just sized to match, if the scale snapped.
  final String? sizeMatchId;

  /// The layer whose angle this one just took, if the rotation snapped.
  final String? rotationMatchId;

  /// The layers to point at. A size or angle match has no line to draw - the
  /// other layer is nowhere near, and the fact being reported is "you are now
  /// like THAT one" - so the canvas outlines them instead.
  Set<String> get matchIds => {?sizeMatchId, ?rotationMatchId};

  bool get isEmpty => guides.isEmpty && matchIds.isEmpty;
}

/// How big [layer] is in canvas-logical units at an explicit [scale] - i.e.
/// `layerLogicalSize`, which needs a photo's pixel dimensions and so has to be
/// supplied by whoever holds that cache.
typedef LayerMeasure = Size Function(Layer layer, double scale);

/// The rectangle [layer] is clipped to - its Photo Grid cell - or null when it
/// is drawn unclipped, which is every layer in an ordinary project.
typedef LayerClip = Rect? Function(Layer layer);

/// [radians] wrapped into (-pi, pi] - the shortest way round.
double wrapAngle(double radians) {
  const turn = 2 * math.pi;
  // Dart's % on doubles is non-negative for a positive divisor, so this lands
  // in [0, 2pi) and one comparison finishes the job.
  final a = radians % turn;
  return a > math.pi ? a - turn : a;
}

/// Whether [angle] is square to the canvas - a quarter turn or a multiple of
/// one, to within [kSnapSquareSlop].
bool isSquareToCanvas(double angle) {
  const quarter = math.pi / 2;
  final off = angle.abs() % quarter;
  return off < kSnapSquareSlop || quarter - off < kSnapSquareSlop;
}

/// The axis-aligned box a [size] box covers once turned by [rotation].
///
/// Used for the layers a gesture is measured AGAINST when they do not share its
/// frame, and for the moving layer itself in [SnapFrame.canvas]. A layer that
/// does share the frame needs none of this: in its own frame it is not turned
/// at all, which is exactly why matching two angles is what makes two edges
/// flush.
Size rotatedExtent(Size size, double rotation) {
  if (rotation == 0) return size;
  final c = math.cos(rotation).abs();
  final s = math.sin(rotation).abs();
  return Size(
    size.width * c + size.height * s,
    size.width * s + size.height * c,
  );
}

/// The nearest other layer's rotation to [proposed], within [tolerance]
/// radians, or null - expressed in the same turn as [proposed], so a layer the
/// canvas has wound to 400° does not jump back to 40° for taking a neighbour's
/// angle.
///
/// Ungated on purpose, unlike the rotation match inside [snapTransform]: this
/// serves the Rotation slider, where setting the angle IS the whole gesture, so
/// "make it the same angle as that one" is the request rather than a side
/// effect of one. It is the same trade the Scale slider makes with size.
double? nearestLayerRotation({
  required Layer moving,
  required double proposed,
  required List<Layer> others,
  required double tolerance,
}) {
  double? best;
  var bestDistance = tolerance;
  for (final layer in others) {
    if (layer.id == moving.id || !layer.visible) continue;
    final delta = wrapAngle(layer.transform.rotation - proposed);
    if (delta.abs() < bestDistance) {
      bestDistance = delta.abs();
      best = proposed + delta;
    }
  }
  return best;
}

/// Pulls [proposed] onto the nearest alignment with the other layers, within
/// [tolerance] canvas-logical units.
///
/// Three anchors per axis - leading edge, centre, trailing edge - on the moving
/// layer are matched against the same three on every other visible layer and on
/// the canvas itself, and the closest pair within [tolerance] wins. The axes are
/// independent: a layer can take a neighbour's left edge and the canvas's
/// vertical centre in one move.
///
/// All of that happens in a FRAME (see [SnapFrame]), which is what lets a
/// turned layer align by its own edges. Two layers at the same angle are not
/// turned at all relative to each other, so their edges are parallel and can be
/// made flush; two layers at different angles have no parallel edges, and the
/// best either can say about the other is where its corners reach.
///
/// [tolerance] is the caller's to choose because the two callers measure
/// "close" in different spaces and both are right to: a finger on the canvas is
/// a SCREEN-space thing (so the canvas converts a px radius through the zoom),
/// while a slider thumb is bar-space, and neither number means anything to the
/// other.
///
/// [snapScale] is off by default because a plain drag must never resize: during
/// a one-finger move the proposed scale is the layer's own, so a layer that
/// happened to sit near a neighbour's width would be quietly resized by being
/// moved. Only a gesture or a slider that IS a resize passes it.
///
/// [rotationTolerance] lets the layer TAKE a neighbour's angle, which is the
/// only way two turned layers ever become flush - but a move is not a request
/// to rotate, so a borrowed angle has to be paid for: it is kept only if the
/// alignment it produces is with the very layer it was borrowed from. That gate
/// is what stops a tilted caption being straightened by being carried past an
/// upright photo. [snapRotation] lifts it, and only a gesture that is ITSELF
/// turning the layer may pass it - there, matching a neighbour's angle is the
/// thing being asked for rather than a side effect.
///
/// [snapX] / [snapY] are separate because the Horizontal slider moves one axis,
/// and a snap that also nudged the other would make it a two-axis control.
SnapResult snapTransform({
  required Layer moving,
  required LayerTransform proposed,
  required List<Layer> others,
  required LayerMeasure measure,
  required Size canvas,
  required double tolerance,
  LayerClip? clipOf,
  double rotationTolerance = 0,
  bool snapRotation = false,
  bool snapScale = false,
  bool snapX = true,
  bool snapY = true,
  SnapFrame frame = SnapFrame.layer,
}) {
  if (tolerance <= 0) return SnapResult(proposed);
  final targets = [
    for (final layer in others)
      if (layer.id != moving.id && layer.visible) layer,
  ];
  // Measured once each, and OUTSIDE the frame loop, because measuring is the
  // expensive part: a text layer is laid out to be measured, and several
  // candidate frames may be tried per gesture frame. What a frame changes is
  // how a size is projected, never the size itself.
  //
  // The moving layer is measured at scale 1 because every branch of
  // `layerLogicalSize` is linear in the scale, and so is `rotatedExtent` - so
  // its box at any scale is this one multiplied.
  final unit = measure(moving, 1);
  final sizes = [
    for (final target in targets) measure(target, target.transform.scale),
  ];
  final clips = [for (final target in targets) clipOf?.call(target)];

  _Evaluation evaluate(double angle, String? borrowedFrom) => _evaluate(
    angle: angle,
    borrowedFrom: borrowedFrom,
    proposed: proposed,
    targets: targets,
    sizes: sizes,
    clips: clips,
    unit: unit,
    canvas: canvas,
    tolerance: tolerance,
    snapScale: snapScale,
    snapX: snapX,
    snapY: snapY,
  );

  final own = frame == SnapFrame.canvas ? 0.0 : proposed.rotation;

  // Angles worth trying, nearest first. Expressed as an offset from the layer's
  // own rotation rather than as the neighbour's absolute angle, so a layer the
  // canvas has wound past a full turn keeps its winding.
  final borrowable = <Layer>[];
  // A layer that is SQUARE to the canvas does not give up being square just for
  // being dragged past something tilted, and being square is not merely one
  // angle among many - it is the state a caption or a photo is in unless it was
  // deliberately turned. Arriving at level is a small surprise; leaving it is a
  // large one, so the asymmetry is the point. A deliberate twist may still take
  // any angle: by then the layer is no longer square anyway.
  final canBorrow =
      frame == SnapFrame.layer &&
      rotationTolerance > 0 &&
      (snapRotation || !isSquareToCanvas(proposed.rotation));
  if (canBorrow) {
    for (final target in targets) {
      final delta = wrapAngle(target.transform.rotation - proposed.rotation);
      if (delta != 0 && delta.abs() <= rotationTolerance) {
        borrowable.add(target);
      }
    }
    borrowable.sort((a, b) {
      final da = wrapAngle(a.transform.rotation - proposed.rotation).abs();
      final db = wrapAngle(b.transform.rotation - proposed.rotation).abs();
      return da.compareTo(db);
    });
  }

  // Computed up front rather than as a fallback, because it is EVIDENCE: a
  // borrowed angle that would abandon an alignment the layer already has with
  // somebody else is not worth having.
  final ownResult = evaluate(own, null);

  _Evaluation? chosen;
  for (final target in borrowable) {
    final angle =
        proposed.rotation +
        wrapAngle(target.transform.rotation - proposed.rotation);
    final candidate = evaluate(angle, target.id);
    if (snapRotation) {
      // The caller is turning the layer and is asking for exactly this, so the
      // nearest angle simply wins.
      chosen = candidate;
      break;
    }
    // Gated, the borrowed angle has to have earned itself twice over: by
    // landing the layer on that neighbour's edge, and by not costing it an
    // alignment with a DIFFERENT layer. Without the second half a borrow wins
    // on merely existing - an upright layer sitting exactly on the canvas edge
    // would tilt itself off it to take a seven-unit alignment with a neighbour
    // three degrees away.
    final abandonsAnother = ownResult.sponsors.any((id) => id != target.id);
    if (candidate.sponsors.contains(target.id) && !abandonsAnother) {
      chosen = candidate;
      break;
    }
  }

  return (chosen ?? ownResult).result;
}

/// One candidate frame's outcome, plus which layers actually sponsored the
/// alignments it found - the evidence a borrowed angle is judged on.
class _Evaluation {
  _Evaluation(this.result, this.sponsors);

  final SnapResult result;
  final Set<String> sponsors;
}

_Evaluation _evaluate({
  required double angle,
  required String? borrowedFrom,
  required LayerTransform proposed,
  required List<Layer> targets,
  required List<Size> sizes,
  required List<Rect?> clips,
  required Size unit,
  required Size canvas,
  required double tolerance,
  required bool snapScale,
  required bool snapX,
  required bool snapY,
}) {
  final cos = math.cos(angle);
  final sin = math.sin(angle);
  // Frame coordinates of a canvas point. At angle 0 these are cos 1 / sin 0
  // exactly, so the whole axis-aligned path stays bit-for-bit what it was.
  double u(Offset p) => p.dx * cos + p.dy * sin;
  double v(Offset p) => -p.dx * sin + p.dy * cos;
  Offset fromFrame(double a, double b) =>
      Offset(a * cos - b * sin, a * sin + b * cos);

  final rotation = borrowedFrom == null ? proposed.rotation : angle;
  // The moving layer's box in this frame. Zero turn - hence its true width and
  // height - whenever the frame is its own, which is every case but a turned
  // layer measured against the canvas's axes.
  final movingUnit = rotatedExtent(unit, rotation - angle);

  // What each target offers to line up with, which is what can be SEEN of it.
  //
  // A Photo Grid cell clips its layer, and a cell photo is cover-scaled, so
  // most of its box is behind the neighbouring cells: on a 2x2 collage a 3:2
  // photo reaches 135 units into the cell next door. Aligning to that edge
  // sticks the layer to a line with nothing on it and draws a guide across an
  // area where nothing is happening. `_hitTest` has always refused to let the
  // clipped part answer a tap; this is the same rule for the same reason.
  //
  // The intersection is taken on the AABB, so a clipped target is offered as an
  // upright box even if the layer inside it is turned. That is the honest
  // answer for the case that exists - a cover photo fills its cell exactly, so
  // the box IS the cell - and it is why the cell's own edges and centre become
  // targets, which is what a collage user is lining things up to anyway.
  final visible = <({String id, double centreU, double centreV, Size box})>[];
  for (var i = 0; i < targets.length; i++) {
    final target = targets[i];
    final clip = clips[i];
    if (clip == null) {
      visible.add((
        id: target.id,
        centreU: u(target.transform.position),
        centreV: v(target.transform.position),
        box: rotatedExtent(sizes[i], target.transform.rotation - angle),
      ));
      continue;
    }
    final drawn = rotatedExtent(sizes[i], target.transform.rotation);
    final full = Rect.fromCenter(
      center: target.transform.position,
      width: drawn.width,
      height: drawn.height,
    );
    final shown = full.intersect(clip);
    // Nothing of it is on screen, so there is nothing to line up with.
    if (shown.isEmpty) continue;
    final cut = shown != full;
    visible.add((
      id: target.id,
      centreU: u(cut ? shown.center : target.transform.position),
      centreV: v(cut ? shown.center : target.transform.position),
      box: cut
          ? rotatedExtent(shown.size, -angle)
          : rotatedExtent(sizes[i], target.transform.rotation - angle),
    ));
  }

  var scale = proposed.scale;
  String? sizeMatchId;
  if (snapScale) {
    double? bestScale;
    var bestDistance = tolerance;
    for (final target in visible) {
      // Compared as SIZES, not as scales: "the same width" is a fact about the
      // canvas, whereas a scale ratio means nothing between two layers whose
      // own sizes differ - matching a caption's scale to a photo's would put
      // them at wildly different widths.
      void consider(double unitExtent, double targetExtent) {
        if (unitExtent <= 0) return;
        // A match outside the range both resizers share is dropped rather than
        // clamped - clamping would stick the layer to the end of the range
        // while claiming a match it does not have - and it is dropped HERE
        // rather than after the search, or the nearest candidate could be an
        // impossible one and shadow a perfectly good match behind it.
        final candidate = targetExtent / unitExtent;
        if (candidate < kMinLayerScale || candidate > kMaxLayerScale) return;
        final distance = (unitExtent * proposed.scale - targetExtent).abs();
        if (distance < bestDistance) {
          bestDistance = distance;
          bestScale = candidate;
          sizeMatchId = target.id;
        }
      }

      consider(movingUnit.width, target.box.width);
      consider(movingUnit.height, target.box.height);
    }
    if (bestScale != null) scale = bestScale!;
  }

  final half = Offset(
    movingUnit.width * scale / 2,
    movingUnit.height * scale / 2,
  );
  // The canvas's own edges are only an alignment while the frame is square to
  // them. Turned, "the canvas's left edge" is a diagonal in frame coordinates -
  // the supporting line of the canvas's corner, which sits OUTSIDE the canvas
  // and would draw a guide nobody can see. Its CENTRE still counts at every
  // angle, because a point is a point whichever way the axes run.
  final square = isSquareToCanvas(angle);
  final canvasCentre = Offset(canvas.width / 2, canvas.height / 2);
  final canvasBox = rotatedExtent(canvas, angle);

  final guides = <SnapGuide>[];
  final sponsors = <String>{};
  var cu = u(proposed.position);
  var cv = v(proposed.position);

  ({double centre, double line, String? sponsor})? run({
    required double centre,
    required double halfExtent,
    required List<double> centres,
    required List<double> halves,
    required double canvasCentreOn,
    required double canvasHalf,
  }) {
    final anchors = _anchors(centre, halfExtent);
    var best = tolerance;
    double? delta;
    double? line;
    String? sponsor;
    void consider(double target, String? from) {
      for (final anchor in anchors) {
        final distance = (target - anchor).abs();
        if (distance < best) {
          best = distance;
          delta = target - anchor;
          line = target;
          sponsor = from;
        }
      }
    }

    // Layers before the canvas, so an exact tie goes to the layer - the thing
    // the user was lining up with.
    for (var i = 0; i < centres.length; i++) {
      for (final anchor in _anchors(centres[i], halves[i])) {
        consider(anchor, visible[i].id);
      }
    }
    consider(canvasCentreOn, null);
    if (square) {
      consider(canvasCentreOn - canvasHalf, null);
      consider(canvasCentreOn + canvasHalf, null);
    }
    final found = delta;
    return found == null
        ? null
        : (centre: centre + found, line: line!, sponsor: sponsor);
  }

  if (snapX) {
    final found = run(
      centre: cu,
      halfExtent: half.dx,
      centres: [for (final t in visible) t.centreU],
      halves: [for (final t in visible) t.box.width / 2],
      canvasCentreOn: u(canvasCentre),
      canvasHalf: canvasBox.width / 2,
    );
    if (found != null) {
      cu = found.centre;
      guides.add(SnapGuide(SnapAxis.x, found.line, angle: angle));
      if (found.sponsor != null) sponsors.add(found.sponsor!);
    }
  }
  if (snapY) {
    final found = run(
      centre: cv,
      halfExtent: half.dy,
      centres: [for (final t in visible) t.centreV],
      halves: [for (final t in visible) t.box.height / 2],
      canvasCentreOn: v(canvasCentre),
      canvasHalf: canvasBox.height / 2,
    );
    if (found != null) {
      cv = found.centre;
      guides.add(SnapGuide(SnapAxis.y, found.line, angle: angle));
      if (found.sponsor != null) sponsors.add(found.sponsor!);
    }
  }

  return _Evaluation(
    SnapResult(
      proposed.copyWith(
        position: fromFrame(cu, cv),
        scale: scale,
        rotation: rotation,
      ),
      guides: guides,
      sizeMatchId: sizeMatchId,
      rotationMatchId: borrowedFrom,
    ),
    sponsors,
  );
}

/// A box's three anchors along one axis, centre first.
///
/// The order is the tie-break: [_evaluate]'s search takes strictly-nearer only,
/// and offers the moving box's centre first, so an equidistant tie goes to
/// centre-on-centre - the alignment a user reads as deliberate. Two layers of
/// the same size give exactly that tie: their centres and both pairs of edges
/// are all the same distance apart.
List<double> _anchors(double centre, double half) => [
  centre,
  centre - half,
  centre + half,
];
