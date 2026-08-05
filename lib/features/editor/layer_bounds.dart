import 'package:flutter/painting.dart';

import '../../core/models/layer.dart';
import '../../core/rendering/canvas_geometry.dart';
import 'widgets/bubble_view.dart';

/// How big a layer is on the canvas, in canvas-logical units, with its own
/// scale already applied.
///
/// Two surfaces need this and they must not disagree: the canvas hit-tests and
/// draws the selection frame with it, and the Adjust panel's placement sliders
/// derive their travel from it (100% of the Horizontal slider is the offset
/// that puts the layer exactly outside the canvas, which is half the canvas
/// plus half of THIS). A hit box and a slider that measured the layer
/// differently would be two answers to "how big is it" with nothing to reconcile
/// them.
///
/// [imagePixels] is the source photo's pixel size, which decides the aspect a
/// photo is fitted into its [kLayerFitBoxSide] box at. It is read from the file
/// header asynchronously by both callers, so it is optional: until it lands -
/// or for a file that will not decode - a photo falls back to the full square,
/// which is the largest it could be. Rounding UP is the safe direction for both
/// callers: a hit box that is too big is still grabbable, and slider travel
/// that is too long still reaches off-canvas.
Size layerLogicalSize(Layer layer, {Size? imagePixels}) {
  final s = layer.transform.scale;
  return switch (layer) {
    ImageLayer(:final cropRect) => () {
      const box = kLayerFitBoxSide;
      if (imagePixels == null ||
          imagePixels.width <= 0 ||
          imagePixels.height <= 0) {
        return Size(box * s, box * s);
      }
      // Aspect of the visible (cropped) content, so hit-box + selection frame
      // track a per-layer crop (full crop → the source aspect, unchanged).
      final ar =
          (cropRect.width * imagePixels.width) /
          (cropRect.height * imagePixels.height);
      return ar >= 1
          ? Size(box * s, box / ar * s)
          : Size(box * ar * s, box * s);
    }(),
    BubbleLayer() => kBubbleBaseSize * s,
    TextLayer() => () {
      final tp = TextPainter(
        text: TextSpan(
          text: layer.text.isEmpty ? ' ' : layer.text,
          style: TextStyle(
            fontFamily: layer.fontFamily,
            fontSize: layer.fontSize,
            height: 1,
            letterSpacing: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final size = Size(tp.width * s, tp.height * s);
      tp.dispose();
      return size;
    }(),
  };
}

/// What 100% means on a placement slider, along one axis: the distance from the
/// canvas centre at which a layer of [layerExtent] has just left a canvas of
/// [canvasExtent].
///
/// Half the canvas plus half the layer, because `LayerTransform.position` is
/// the layer's CENTRE - at that offset its trailing edge sits exactly on the
/// canvas edge. Anything shorter would make "100%" a position the user can see,
/// which is the one reading the slider promises it is not; anything longer
/// spends bar travel on offsets that are all equally invisible.
///
/// It has to include the layer because the layer is the thing being moved: a
/// caption needs a few percent past the edge to be gone, a full-bleed photo
/// needs nearly a whole canvas more.
double placementTravel(double canvasExtent, double layerExtent) =>
    (canvasExtent + layerExtent) / 2;
