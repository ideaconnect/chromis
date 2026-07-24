import 'dart:math' as math;
import 'dart:ui';

/// Maps points from the editor's 512-logical canvas space into an image layer's
/// mask-pixel space, inverting the same transform the renderer applies: the
/// layer sits centred at [position], its content is a [boxSize]-logical square
/// scaled by [layerScale] and rotated by [rotation], and the photo is fit
/// (BoxFit.contain) inside that square.
///
/// Pure and self-contained so the fiddly geometry can be unit-tested without a
/// device (see ProjectCanvas `_MaskedImagePainter` for the forward direction).
class MaskMapper {
  const MaskMapper({
    required this.imageSize,
    required this.position,
    required this.layerScale,
    required this.rotation,
    this.cropRect = const Rect.fromLTRB(0, 0, 1, 1),
    this.boxSize = 440,
  });

  /// Source image (== mask) size in pixels.
  final Size imageSize;

  /// Layer centre in 512-logical units.
  final Offset position;

  /// Layer's own scale and rotation (radians).
  final double layerScale;
  final double rotation;

  /// The visible source sub-rect (normalized 0..1); the whole image by default.
  /// The renderer fits *this* sub-rect into the box, so the inverse must too.
  final Rect cropRect;

  /// The logical square the photo is fit into (matches the renderer's 440).
  final double boxSize;

  /// Visible (cropped) source size in pixels.
  Size get _srcSize => Size(
    cropRect.width * imageSize.width,
    cropRect.height * imageSize.height,
  );

  /// The uniform BoxFit.contain factor (cropped image px -> box logical).
  double get _containScale =>
      math.min(boxSize / _srcSize.width, boxSize / _srcSize.height);

  Size get _fitSize =>
      Size(_srcSize.width * _containScale, _srcSize.height * _containScale);

  /// A logical canvas point -> full-source mask pixel coordinate, or null when
  /// the point falls outside the visible (cropped) photo.
  Offset? canvasToMask(Offset canvasLogical) {
    final rel = canvasLogical - position;
    // Undo the layer rotation.
    final a = -rotation;
    final cosA = math.cos(a);
    final sinA = math.sin(a);
    final unrot = Offset(
      rel.dx * cosA - rel.dy * sinA,
      rel.dx * sinA + rel.dy * cosA,
    );
    // Undo the layer scale, into the centred box frame.
    final box = unrot / layerScale;
    final bx = box.dx + boxSize / 2;
    final by = box.dy + boxSize / 2;
    // Undo the contain letterbox → fraction across the cropped region (0..1).
    final fit = _fitSize;
    final fx = (bx - (boxSize - fit.width) / 2) / fit.width;
    final fy = (by - (boxSize - fit.height) / 2) / fit.height;
    if (fx < 0 || fy < 0 || fx >= 1 || fy >= 1) return null;
    // Crop origin + fraction of the cropped span → full-source pixels.
    final ix = (cropRect.left + fx * cropRect.width) * imageSize.width;
    final iy = (cropRect.top + fy * cropRect.height) * imageSize.height;
    return Offset(ix, iy);
  }

  /// A brush radius in logical canvas units -> mask pixels.
  double radiusToMask(double logicalRadius) =>
      logicalRadius / layerScale / _containScale;
}
