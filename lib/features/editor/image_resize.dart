/// Resize image: the whole picture scaled to a new pixel size, as opposed to
/// Canvas size, which changes the canvas around the layers.
///
/// Split in two because only half of it is a document edit. The geometry -
/// canvas, transforms, grid - is pure and lives here, so the controller that
/// commits it and the editor that plans the resampling read ONE answer. The
/// pixels are async I/O and live in `services/photo_resampler.dart`.
library;

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../core/models/grid.dart';
import '../../core/models/layer.dart';
import '../../core/models/project.dart';
import '../../core/rendering/canvas_geometry.dart';
import '../grid/grid_refit.dart';
import 'layer_bounds.dart';

/// [project] scaled to [width] x [height]: every layer's position follows the
/// canvas and its scale grows or shrinks with it, so the composition comes out
/// exactly as it was, only bigger or smaller. Photos are NOT touched here - see
/// [photoResampleTarget] for what their pixels should become.
///
/// Text and bubbles need nothing more than this, because they are drawn from
/// their description at whatever size they are shown: scaled up, they stay
/// sharp. The same holds for every effect (stroke, shadow), which is measured
/// in the layer's own units and so rides on its scale.
///
/// A collage's gaps, margin and corner radius are canvas-logical px, so they
/// scale too - up to their caps, past which the cells come out a little bigger
/// than proportional; content in a cell is re-fitted to its new rect, so a cell
/// photo still covers it.
Project resizeProjectGeometry(Project project, int width, int height) {
  final w = width.clamp(Project.minCanvasDimension, Project.maxCanvasDimension);
  final h = height.clamp(
    Project.minCanvasDimension,
    Project.maxCanvasDimension,
  );
  final sx = w / project.canvasWidth;
  final sy = h / project.canvasHeight;
  // The two differ only by rounding: the sheet keeps the aspect, so this is
  // one factor in all but the last half pixel.
  final k = (sx + sy) / 2;

  final grid = project.grid;
  final nextGrid = grid?.copyWith(
    borderWidth: (grid.borderWidth * k).clamp(0, GridSpec.maxBorderWidth),
    outerMargin: (grid.outerMargin * k).clamp(0, GridSpec.maxOuterMargin),
    cornerRadius: (grid.cornerRadius * k).clamp(0, GridSpec.maxCornerRadius),
  );
  final before = grid == null
      ? null
      : layoutGrid(
          grid,
          Size(project.canvasWidth.toDouble(), project.canvasHeight.toDouble()),
        ).cells;
  final after = nextGrid == null
      ? null
      : layoutGrid(nextGrid, Size(w.toDouble(), h.toDouble())).cells;

  Layer scaled(Layer layer) {
    final t = layer.transform;
    var next = t.copyWith(
      position: Offset(t.position.dx * sx, t.position.dy * sy),
      scale: t.scale * k,
    );
    final from = before?[layer.cellId];
    final to = after?[layer.cellId];
    if (from != null && to != null) {
      // Where the cell WOULD be had every border scaled exactly, refitted to
      // where it is - the identity unless a border hit its cap.
      next = refitToCell(
        next,
        Rect.fromLTRB(
          from.left * sx,
          from.top * sy,
          from.right * sx,
          from.bottom * sy,
        ),
        to,
      );
    }
    return switch (layer) {
      ImageLayer() => layer.copyWith(transform: next),
      TextLayer() => layer.copyWith(transform: next),
      BubbleLayer() => layer.copyWith(transform: next),
    };
  }

  return project.copyWith(
    canvasWidth: w,
    canvasHeight: h,
    grid: nextGrid,
    frames: [
      for (final frame in project.frames)
        frame.copyWith(layers: frame.layers.map(scaled).toList()),
    ],
  );
}

/// The pixel size [layer]'s photo should be resampled to, given its source is
/// [sourcePixels] - or null when it already has that size.
///
/// That size is the photo's FOOTPRINT: the pixels it covers on the canvas at
/// its own (already resized) scale, so the export then draws it at 1:1 and the
/// method the user chose is the only resampling it ever gets. Resampling by the
/// resize factor instead would leave a 2048 px photo on a 1080 canvas still
/// twice the size it is drawn at - and the GPU's filter, not the user's, would
/// do the rest. For nearest neighbour that is the whole point lost: blocky
/// pixels downscaled by a bilinear draw are not blocky.
///
/// The footprint is the whole source, not just a cropped part of it, because
/// a crop is stored normalised and has to keep meaning the same region. It is
/// capped at [maxSide] - a photo zoomed far past the canvas edge would
/// otherwise ask for a bitmap bigger than anything the import would accept.
({int width, int height})? photoResampleTarget(
  ImageLayer layer,
  Size sourcePixels, {
  int maxSide = kMaxPhotoSide,
}) {
  if (sourcePixels.width <= 0 || sourcePixels.height <= 0) return null;
  final crop = layer.cropRect;
  if (crop.width <= 0 || crop.height <= 0) return null;
  // The same measure the hit box and the placement sliders use - see
  // layer_bounds.dart - divided back out of the crop.
  final shown = layerLogicalSize(layer, imagePixels: sourcePixels);
  var w = shown.width / crop.width;
  var h = shown.height / crop.height;
  final longest = math.max(w, h);
  if (longest > maxSide) {
    w *= maxSide / longest;
    h *= maxSide / longest;
  }
  final target = (
    width: math.max(1, w.round()),
    height: math.max(1, h.round()),
  );
  if (target.width == sourcePixels.width.round() &&
      target.height == sourcePixels.height.round()) {
    return null;
  }
  return target;
}

/// One photo's new pixels, for [EditorController.resizeImage].
///
/// Carries the paths it was made FROM, because the resampling takes seconds
/// and the dock stays live meanwhile: a layer whose photo or mask changed
/// under it is left on its old pixels, which still draw correctly - only not
/// at 1:1 - rather than being handed a bitmap of something it no longer shows.
@immutable
class ResampledPhoto {
  const ResampledPhoto({
    required this.fromAsset,
    required this.fromMask,
    required this.assetPath,
    required this.maskPath,
  });

  final String fromAsset;
  final String? fromMask;
  final String assetPath;

  /// Resampled with the photo, since a mask has to match its photo pixel for
  /// pixel: the brush and the AI tools address both with one coordinate.
  final String? maskPath;

  @override
  bool operator ==(Object other) =>
      other is ResampledPhoto &&
      other.fromAsset == fromAsset &&
      other.fromMask == fromMask &&
      other.assetPath == assetPath &&
      other.maskPath == maskPath;

  @override
  int get hashCode => Object.hash(fromAsset, fromMask, assetPath, maskPath);
}
