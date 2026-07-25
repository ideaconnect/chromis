/// Geometry constants shared by the two WYSIWYG rendering surfaces - the
/// on-canvas preview (`ProjectCanvas`) and the headless export renderer
/// (`ProjectRenderer`) - so the two painters cannot silently drift apart.
library;

import 'dart:math' as math;
import 'dart:ui';

/// Side length, in 512-logical canvas units, of the square box an image layer
/// is fitted (`BoxFit.contain`) into - ~0.86 of the canvas. Both painters scale
/// this by the canvas scale (target size / 512) before drawing and apply the
/// layer's own zoom on top.
///
/// This used to be a bare `440.0` literal duplicated in both painters; hoisting
/// it to one symbol is what lets the export/canvas parity test assert the two
/// paths agree by construction rather than by coincidence.
const double kLayerFitBoxSide = 440.0;

/// The layer scale that fits a [pixels]-sized photo inside a
/// [canvasWidth]×[canvasHeight] canvas (BoxFit.contain). An image layer renders
/// into a [kLayerFitBoxSide]-square box at scale 1, so we scale that fitted box
/// to fit the canvas. Used whenever the canvas size is FIXED - placing a photo
/// into a blank canvas that keeps its size, or filling a photo-sized canvas.
double photoFitScale(Size pixels, int canvasWidth, int canvasHeight) {
  if (pixels.width <= 0 || pixels.height <= 0) return 1;
  final rendered = _renderedSize(pixels);
  return math.min(canvasWidth / rendered.width, canvasHeight / rendered.height);
}

/// The layer scale that makes a [pixels]-sized photo **cover** a
/// [width]×[height] box (in canvas-logical units), i.e. fill it completely with
/// the overflow clipped away.
///
/// The cover counterpart to [photoFitScale] (max instead of min): a Photo Grid
/// cell wants its photo to fill it edge to edge, and the cell clip hides the
/// spill. Used when placing a photo into a cell and when re-fitting a cell's
/// content after a divider drag, so both paths agree on what "fills the cell"
/// means.
double photoCoverScale(Size pixels, double width, double height) {
  if (pixels.width <= 0 || pixels.height <= 0 || width <= 0 || height <= 0) {
    return 1;
  }
  final rendered = _renderedSize(pixels);
  return math.max(width / rendered.width, height / rendered.height);
}

/// The logical size a [pixels]-sized photo occupies at layer scale 1 - its
/// aspect fitted (contain) into the [kLayerFitBoxSide] square both painters
/// draw image layers into.
Size _renderedSize(Size pixels) {
  final ar = pixels.width / pixels.height;
  return ar >= 1
      ? Size(kLayerFitBoxSide, kLayerFitBoxSide / ar)
      : Size(kLayerFitBoxSide * ar, kLayerFitBoxSide);
}

/// [rect] scaled about the origin - maps canvas-logical geometry (cell rects,
/// divider bands) into a painter's pixel space.
Rect scaleRect(Rect rect, double scale) => Rect.fromLTRB(
  rect.left * scale,
  rect.top * scale,
  rect.right * scale,
  rect.bottom * scale,
);
