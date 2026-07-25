import 'dart:typed_data';
import 'dart:ui';

import '../../../core/models/frame.dart';
import '../../../core/models/layer.dart';
import '../../../core/models/project.dart';
import '../../../core/rendering/canvas_geometry.dart';
import '../../export/project_renderer.dart';

/// Merging layers = rendering them exactly as they are composited today and
/// keeping the pixels instead of the recipe.
///
/// Reusing [ProjectRenderer] rather than writing a second compositor is the
/// whole point: a merge that dropped a blend mode, a shadow or a filter would
/// silently change the picture, and here it cannot - the bytes come out of the
/// same code path the export does.
abstract final class LayerFlattener {
  LayerFlattener._();

  /// Which layers a "Flatten" would fold together, in z-order.
  ///
  /// Grouped by [Layer.cellId], so a Photo Grid flattens **per cell** and keeps
  /// its partition: the alternative - baking the whole collage into one image -
  /// would silently stop it being a collage. Groups of one are skipped (there
  /// is nothing to merge), as are hidden layers, which a flatten must not
  /// resurrect.
  static List<List<Layer>> flattenGroups(Frame frame) {
    final groups = <String?, List<Layer>>{};
    for (final layer in frame.layers) {
      if (!layer.visible) continue;
      groups.putIfAbsent(layer.cellId, () => []).add(layer);
    }
    return [
      for (final group in groups.values)
        if (group.length > 1) group,
    ];
  }

  /// The layer directly beneath [id] that shares its cell - what "Merge down"
  /// folds it into - or null when there is nothing below it in that cell.
  static Layer? mergeDownTarget(Frame frame, String id) {
    final layers = frame.layers;
    final index = layers.indexWhere((l) => l.id == id);
    if (index <= 0) return null;
    final cell = layers[index].cellId;
    for (var i = index - 1; i >= 0; i--) {
      if (layers[i].cellId == cell && layers[i].visible) return layers[i];
    }
    return null;
  }

  /// Renders [layers] (in the given z-order) at the project's canvas size and
  /// returns the PNG bytes. The grid is deliberately NOT applied: cell clipping
  /// is re-applied by the merged layer keeping its `cellId`, and baking the
  /// border in would double it on the next render.
  static Future<Uint8List> renderPng(
    List<Layer> layers, {
    required int canvasWidth,
    required int canvasHeight,
  }) {
    return ProjectRenderer.renderPngSized(
      Frame(id: 'merge', layers: layers),
      canvasWidth: canvasWidth,
      canvasHeight: canvasHeight,
    );
  }

  /// The layer scale that maps a canvas-sized image back onto the canvas 1:1.
  ///
  /// An image layer is drawn contain-fitted into a [kLayerFitBoxSide] square,
  /// so a freshly flattened canvas-shaped PNG needs exactly the scale that
  /// makes that box cover the canvas again - otherwise the merge would resize
  /// the composition it just captured.
  static double canvasCoverScale(int canvasWidth, int canvasHeight) =>
      photoFitScale(
        Size(canvasWidth.toDouble(), canvasHeight.toDouble()),
        canvasWidth,
        canvasHeight,
      );

  /// A name for the merged result: the bottom layer's, marked as merged.
  static String mergedName(List<Layer> layers) =>
      layers.isEmpty ? 'Merged' : '${layers.first.name} (merged)';

  /// Whether flattening [project]'s current frame would do anything.
  static bool canFlatten(Project project) =>
      flattenGroups(project.currentFrame).isNotEmpty;
}
