import 'dart:math' as math;
import 'dart:ui';

import '../../core/models/grid.dart';
import '../../core/models/layer.dart';
import '../../core/models/layer_transform.dart';
import '../../core/models/project.dart';

/// Moving a layer's content with its cell.
///
/// Every path that reshapes a Photo Grid - swapping template, changing the
/// photo count, dragging a divider - goes through [applyGridSpec], so cell
/// content follows its cell by one definition instead of three.
///
/// The mapping is computed from the rects BEFORE and AFTER the change, never
/// incrementally, so repeated changes cannot accumulate float drift or slowly
/// distort a pan/zoom the user made inside the cell. Callers holding a drag
/// snapshot (PG-6) get that for free by passing the project as it was when the
/// drag started.

/// [transform] carried from cell rect [from] to cell rect [to]: the layer keeps
/// its relative placement in the cell and stays covering it.
///
/// Scale changes by the COVER factor (max of the two axis ratios), and the
/// position is mapped about the cell centre by that same uniform factor, so a
/// centred photo stays centred and nothing is squashed.
LayerTransform refitToCell(LayerTransform transform, Rect from, Rect to) {
  if (from.width <= 0 || from.height <= 0) return transform;
  final factor = math.max(to.width / from.width, to.height / from.height);
  return transform.copyWith(
    position: to.center + (transform.position - from.center) * factor,
    scale: transform.scale * factor,
  );
}

/// [project] re-partitioned by [next]: every layer assigned to a cell follows
/// that cell from its old rect to its new one.
///
/// Layers in a cell [next] no longer has (the photo count went down) are
/// removed - one undoable step together with the reshape, so an undo brings
/// them back. Free layers are untouched.
///
/// Note that a pure styling change (border width, outer margin, corner radius)
/// deliberately does NOT re-fit: those arrive as a stream of slider ticks, and
/// re-fitting each one would drift the content. Cells only shrink or grow
/// slightly around their photos instead.
Project applyGridSpec(Project project, GridSpec next) {
  final current = project.grid;
  if (current == null) return project.copyWith(grid: next);

  final canvas = Size(
    project.canvasWidth.toDouble(),
    project.canvasHeight.toDouble(),
  );
  final before = layoutGrid(current, canvas).cells;
  final after = layoutGrid(next, canvas).cells;
  // A styling-only change leaves every cell in place; skip the walk entirely.
  if (current.root == next.root) return project.copyWith(grid: next);

  return project.copyWith(
    grid: next,
    frames: [
      for (final frame in project.frames)
        frame.copyWith(
          layers: [
            for (final layer in frame.layers) ?_refit(layer, before, after),
          ],
        ),
    ],
  );
}

/// [project] with each cell's photos rotated one cell forward (c0 -> c1 -> ...
/// -> c0), re-fitted into their new cells. Deterministic on purpose: a random
/// shuffle would be untestable and could return the same arrangement.
Project shuffleGridCells(Project project) {
  final grid = project.grid;
  if (grid == null || grid.cellCount < 2) return project;
  final ids = grid.cellIds;
  final rects = layoutGrid(
    grid,
    Size(project.canvasWidth.toDouble(), project.canvasHeight.toDouble()),
  ).cells;

  String? nextCell(String? id) {
    final i = ids.indexOf(id ?? '');
    return i < 0 ? null : ids[(i + 1) % ids.length];
  }

  return project.copyWith(
    frames: [
      for (final frame in project.frames)
        frame.copyWith(
          layers: [
            for (final layer in frame.layers)
              if (nextCell(layer.cellId) case final target?)
                _withCell(
                  layer,
                  target,
                  refitToCell(
                    layer.transform,
                    rects[layer.cellId]!,
                    rects[target]!,
                  ),
                )
              else
                layer,
          ],
        ),
    ],
  );
}

/// [layer] carried to its cell's new rect, or null when that cell is gone.
Layer? _refit(Layer layer, Map<String, Rect> before, Map<String, Rect> after) {
  final id = layer.cellId;
  if (id == null) return layer; // free layer - unaffected by the partition
  final from = before[id];
  final to = after[id];
  if (to == null) return null; // the cell no longer exists - drop the content
  if (from == null) return layer;
  return _withTransform(layer, refitToCell(layer.transform, from, to));
}

Layer _withTransform(Layer layer, LayerTransform transform) => switch (layer) {
  ImageLayer() => layer.copyWith(transform: transform),
  TextLayer() => layer.copyWith(transform: transform),
  BubbleLayer() => layer.copyWith(transform: transform),
};

/// [layer] reassigned to [cellId] with [transform]. Shared with the controller
/// so cell reassignment has one definition.
Layer assignCell(Layer layer, String cellId, LayerTransform transform) =>
    _withCell(layer, cellId, transform);

Layer _withCell(Layer layer, String cellId, LayerTransform transform) =>
    switch (layer) {
      ImageLayer() => layer.copyWith(cellId: cellId, transform: transform),
      TextLayer() => layer.copyWith(cellId: cellId, transform: transform),
      BubbleLayer() => layer.copyWith(cellId: cellId, transform: transform),
    };
