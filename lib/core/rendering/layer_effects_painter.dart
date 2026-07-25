/// Canvas-level painting of the layer effects that are NOT a colour matrix:
/// the photo pipeline (filter → HDR → mask → vignette → contour) and the drop
/// shadow cast by any layer's silhouette.
///
/// Everything here is plain [Canvas] code with no widget dependency, which is
/// the point: the on-canvas preview (`ProjectCanvas`, through a `CustomPainter`)
/// and the headless export renderer (`ProjectRenderer`) both call these
/// functions, so the two surfaces cannot drift apart. The parity test in
/// `test/rendering/` is what holds that claim honest.
library;

import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../models/image_adjustments.dart';
import '../models/layer_effects.dart';
import 'color_matrix.dart';

/// Greyscale + invert, used to build the high-pass copy behind the HDR effect.
const List<double> _invertedLuma = [
  -0.2126, -0.7152, -0.0722, 0, 255, //
  -0.2126, -0.7152, -0.0722, 0, 255, //
  -0.2126, -0.7152, -0.0722, 0, 255, //
  0, 0, 0, 1, 0,
];

/// Blur radius of the HDR local-contrast pass, as a fraction of the photo's
/// shorter side. Large on purpose: a small radius sharpens edges, a large one
/// lifts *regions*, which is what reads as "HDR" rather than "sharpened".
const double _hdrBlurFraction = 0.06;

/// How strongly the high-pass copy is blended back at `hdr == 1`.
const double _hdrMaxStrength = 0.85;

/// Paints one image layer's content into [dest], applying every pixel-level
/// effect in the order the model defines: the contour first (behind), then the
/// photo with its filter/adjustment matrix, the HDR local-contrast pass, the
/// cut-out mask, and finally the vignette shaped by whatever alpha survived.
///
/// [dest] and [strokeWidthPx] are already in the target canvas's pixel space;
/// the caller owns the layer transform.
void paintImageLayer(
  Canvas canvas, {
  required ui.Image base,
  ui.Image? mask,
  required Rect srcRect,
  Rect? maskSrc,
  required Rect dest,
  ImageAdjustments adjustments = ImageAdjustments.identity,
  Vignette vignette = Vignette.none,
  LayerStroke stroke = LayerStroke.none,
  double strokeWidthPx = 0,
  FilterQuality quality = FilterQuality.medium,
}) {
  if (stroke.isVisible && strokeWidthPx > 0) {
    _paintStroke(
      canvas,
      base: base,
      mask: mask,
      srcRect: srcRect,
      maskSrc: maskSrc,
      dest: dest,
      stroke: stroke,
      widthPx: strokeWidthPx,
      quality: quality,
    );
  }

  final basePaint = Paint()..filterQuality = quality;
  if (!adjustments.isIdentity) {
    basePaint.colorFilter = ColorFilter.matrix(adjustments.toColorMatrix());
  }

  final hdr = adjustments.hdr;
  final needsGroup = mask != null || vignette.isVisible || hdr > 0;
  if (!needsGroup) {
    canvas.drawImageRect(base, srcRect, dest, basePaint);
    return;
  }

  canvas.saveLayer(dest, Paint());
  canvas.drawImageRect(base, srcRect, dest, basePaint);
  if (hdr > 0) {
    _paintLocalContrast(canvas, base, srcRect, dest, hdr, quality);
  }
  if (mask != null) {
    canvas.drawImageRect(
      mask,
      maskSrc ??
          Rect.fromLTWH(0, 0, mask.width.toDouble(), mask.height.toDouble()),
      dest,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..filterQuality = quality,
    );
  }
  if (vignette.isVisible) {
    canvas.drawRect(
      dest,
      Paint()
        ..shader = vignetteShader(dest, vignette)
        // srcATop keeps the falloff inside whatever alpha is already there, so
        // a cut-out subject is vignetted along its own silhouette instead of
        // getting a rectangle of shade behind it.
        ..blendMode = BlendMode.srcATop,
    );
  }
  canvas.restore();
}

/// The radial falloff for [v] across [dest]. The radius is the rect's
/// half-diagonal, so the corners - and only the corners - reach full [amount].
ui.Shader vignetteShader(Rect dest, Vignette v) {
  final radius = dest.bottomRight.distance == 0
      ? 1.0
      : (Offset(dest.width, dest.height).distance / 2);
  final start = v.size.clamp(0.05, 0.95);
  final soft = v.softness.clamp(0.0, 1.0);
  // Where the ramp is half-spent: late for a hard ring, early for a long fade.
  final mid = start + (1 - start) * (0.75 - 0.45 * soft);
  final amount = v.amount.clamp(0.0, 1.0);
  return ui.Gradient.radial(
    dest.center,
    radius <= 0 ? 1 : radius,
    [
      v.color.withValues(alpha: 0),
      v.color.withValues(alpha: amount * 0.28),
      v.color.withValues(alpha: amount),
    ],
    [start, mid, 1.0],
  );
}

/// Blends a high-pass copy of the photo back over itself in Overlay - the
/// texture half of the HDR look. The high-pass is built the cheap way, by
/// averaging the photo with a large-radius blurred *inverse* of itself, which
/// is algebraically `0.5 + (photo - blur)/2`.
void _paintLocalContrast(
  Canvas canvas,
  ui.Image base,
  Rect srcRect,
  Rect dest,
  double amount,
  FilterQuality quality,
) {
  final sigma = dest.shortestSide * _hdrBlurFraction;
  if (sigma <= 0) return;
  final strength = (_hdrMaxStrength * amount).clamp(0.0, 1.0);
  canvas.saveLayer(
    dest,
    Paint()
      ..blendMode = BlendMode.overlay
      ..color = Color.fromRGBO(0, 0, 0, strength),
  );
  canvas.drawImageRect(base, srcRect, dest, Paint()..filterQuality = quality);
  canvas.saveLayer(dest, Paint()..color = const Color(0x80000000));
  canvas.drawImageRect(
    base,
    srcRect,
    dest,
    Paint()
      ..filterQuality = quality
      ..colorFilter = const ColorFilter.matrix(_invertedLuma)
      ..imageFilter = ui.ImageFilter.blur(
        sigmaX: sigma,
        sigmaY: sigma,
        tileMode: TileMode.decal,
      ),
  );
  canvas.restore();
  canvas.restore();
}

/// A solid contour grown out of the layer's silhouette, painted *behind* it.
/// With a cut-out mask the silhouette is the subject, so the stroke hugs it
/// (the sticker die-cut); without one it is the photo's rectangle, so the
/// stroke reads as a picture frame.
void _paintStroke(
  Canvas canvas, {
  required ui.Image base,
  ui.Image? mask,
  required Rect srcRect,
  Rect? maskSrc,
  required Rect dest,
  required LayerStroke stroke,
  required double widthPx,
  required FilterQuality quality,
}) {
  final color = stroke.color.withValues(
    alpha: stroke.color.a * stroke.opacity.clamp(0.0, 1.0),
  );
  if (mask == null) {
    canvas.drawRect(dest.inflate(widthPx), Paint()..color = color);
    return;
  }
  final inflated = dest.inflate(widthPx + 2);
  canvas.saveLayer(
    inflated,
    Paint()
      ..imageFilter = ui.ImageFilter.dilate(radiusX: widthPx, radiusY: widthPx)
      ..color = Color.fromRGBO(0, 0, 0, stroke.opacity.clamp(0.0, 1.0)),
  );
  // Subject alpha silhouette (base ∩ mask), flattened to the stroke colour.
  canvas.saveLayer(dest, Paint());
  canvas.drawImageRect(base, srcRect, dest, Paint()..filterQuality = quality);
  canvas.drawImageRect(
    mask,
    maskSrc ??
        Rect.fromLTWH(0, 0, mask.width.toDouble(), mask.height.toDouble()),
    dest,
    Paint()
      ..blendMode = BlendMode.dstIn
      ..filterQuality = quality,
  );
  canvas.drawRect(
    dest,
    Paint()
      ..color = stroke.color.withValues(alpha: stroke.color.a)
      ..blendMode = BlendMode.srcIn,
  );
  canvas.restore();
  canvas.restore();
}

/// The blur (and optional thickening) a drop shadow's silhouette goes through,
/// at canvas [scale]. Null when the shadow is hard-edged and unspread.
///
/// Returned as a single [ui.ImageFilter] so the widget path can hand the very
/// same object to `ImageFiltered` - identical filters, identical pixels.
ui.ImageFilter? shadowImageFilter(LayerShadow shadow, double scale) {
  final blur = shadow.blur * scale;
  final density = shadow.density * scale;
  ui.ImageFilter? filter;
  if (density > 0.01) {
    filter = ui.ImageFilter.dilate(radiusX: density, radiusY: density);
  }
  if (blur > 0.01) {
    final gaussian = ui.ImageFilter.blur(
      sigmaX: blur,
      sigmaY: blur,
      tileMode: TileMode.decal,
    );
    filter = filter == null
        ? gaussian
        : ui.ImageFilter.compose(outer: gaussian, inner: filter);
  }
  return filter;
}

/// Draws [paintContent] twice: once recoloured, blurred and offset (the drop
/// shadow), then once for real on top. The offset is applied in the *current*
/// canvas space, i.e. after the layer's rotation and scale - the shadow travels
/// with the layer instead of sliding out from under a rotated sticker.
///
/// The nesting (alpha → image filter → colour filter → content) mirrors the
/// widget path's `Opacity(ImageFiltered(ColorFiltered(child)))` exactly.
void paintLayerShadow(
  Canvas canvas,
  LayerShadow shadow,
  double scale,
  void Function() paintContent,
) {
  if (!shadow.isVisible) return;
  final offset = shadow.offset * scale;
  canvas.save();
  canvas.translate(offset.dx, offset.dy);
  canvas.saveLayer(
    null,
    Paint()..color = Color.fromRGBO(0, 0, 0, shadow.opacity.clamp(0.0, 1.0)),
  );
  final filter = shadowImageFilter(shadow, scale);
  if (filter != null) {
    canvas.saveLayer(null, Paint()..imageFilter = filter);
  }
  canvas.saveLayer(
    null,
    Paint()..colorFilter = ColorFilter.mode(shadow.color, BlendMode.srcIn),
  );
  paintContent();
  canvas.restore();
  if (filter != null) canvas.restore();
  canvas.restore();
  canvas.restore();
}

/// Whether [matrix] leaves colours untouched - lets callers skip a
/// [ColorFilter] entirely.
bool isIdentityMatrix(List<double> matrix) {
  for (var i = 0; i < 20; i++) {
    if (matrix[i] != ColorMatrix.identity[i]) return false;
  }
  return true;
}
