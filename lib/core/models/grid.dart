/// Photo Grid (collage) geometry: a canvas partition described as a tree of
/// splits, plus the frame/gap styling drawn around the cells.
///
/// A grid is NOT a document type and NOT a layer type - it is a partition of the
/// canvas that layers get assigned to via [Layer.cellId]. Layer transforms stay
/// in canvas-logical units; cells only clip. That is what lets every existing
/// editor tool keep working inside a cell unchanged.
///
/// Cells are described as a tree rather than a flat rect list because a flat
/// list cannot answer "which cells share this divider" without float-comparing
/// edges. In the tree, dragging one divider exchanges weight between exactly two
/// siblings of one [GridSplit], so every other cell keeps its rect by
/// construction (see [moveDivider]).
///
/// The trade-off: only guillotine layouts are representable, so a 4-cell
/// pinwheel (three rects meeting at a point with no full-width cut) is out of
/// reach. Every 2-5 photo template we ship is a guillotine layout.
library;

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// How a [GridSplit] lays its children out. [columns] places them side by side
/// (dividers are vertical lines); [rows] stacks them (dividers are horizontal).
enum GridAxis { columns, rows }

/// A node of the partition tree: either a cell ([GridLeaf]) or a split of the
/// available rect among children ([GridSplit]).
@immutable
sealed class GridNode {
  const GridNode();

  /// Leaf ids in depth-first order - the canonical cell order (`c0`, `c1`, ...).
  List<String> get cellIds {
    final out = <String>[];
    void walk(GridNode node) {
      switch (node) {
        case GridLeaf(:final id):
          out.add(id);
        case GridSplit(:final children):
          for (final child in children) {
            walk(child);
          }
      }
    }

    walk(this);
    return out;
  }

  int get cellCount => cellIds.length;

  /// A copy with leaf ids renumbered `c0..cN-1` in depth-first order. Templates
  /// declare structure only and normalize through this, so ids can never be
  /// mis-numbered by hand and a template swap maps photo N to cell N.
  GridNode withCanonicalIds() {
    var next = 0;
    GridNode walk(GridNode node) => switch (node) {
      GridLeaf() => GridLeaf('c${next++}'),
      GridSplit(:final axis, :final weights, :final children) => GridSplit(
        axis,
        weights,
        children.map(walk).toList(),
      ),
    };
    return walk(this);
  }

  /// Whether [other] has the same structure - the same splits, axes and child
  /// counts - ignoring weights and leaf ids. Dragging a divider changes weights
  /// but never the shape, so this is how a layout stays recognizable as "the
  /// template it came from" after the user has resized its cells.
  bool hasSameShapeAs(GridNode other) {
    final self = this;
    if (self is GridLeaf) return other is GridLeaf;
    self as GridSplit;
    if (other is! GridSplit ||
        other.axis != self.axis ||
        other.children.length != self.children.length) {
      return false;
    }
    for (var i = 0; i < self.children.length; i++) {
      if (!self.children[i].hasSameShapeAs(other.children[i])) return false;
    }
    return true;
  }

  Map<String, dynamic> toJson();

  factory GridNode.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    return switch (type) {
      'leaf' => GridLeaf(json['id'] as String),
      'split' => GridSplit(
        json['axis'] == 'rows' ? GridAxis.rows : GridAxis.columns,
        ((json['weights'] as List?) ?? const [])
            .map((w) => (w as num).toDouble())
            .toList(),
        ((json['children'] as List?) ?? const [])
            .map((c) => GridNode.fromJson((c as Map).cast<String, dynamic>()))
            .toList(),
      ),
      _ => throw FormatException('Unknown grid node type: $type'),
    };
  }
}

/// One cell of the grid. Layers carrying this [id] as their `cellId` are clipped
/// to it and follow it when it resizes.
final class GridLeaf extends GridNode {
  const GridLeaf(this.id);

  final String id;

  @override
  Map<String, dynamic> toJson() => {'type': 'leaf', 'id': id};

  @override
  bool operator ==(Object other) => other is GridLeaf && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Splits its rect among [children] along [axis] in proportion to [weights].
///
/// N-ary rather than binary on purpose: in a 3-column row built from nested
/// binary splits, dragging the outer divider would move two cells at once.
/// With one n-ary node, divider `k` moves weight between children `k` and `k+1`
/// only, which is what the user expects.
final class GridSplit extends GridNode {
  /// Validates and normalizes [weights] to sum to 1, so an out-of-range or
  /// unnormalized template cannot reach the layout pass.
  factory GridSplit(
    GridAxis axis,
    List<double> weights,
    List<GridNode> children,
  ) {
    if (children.length < 2) {
      throw ArgumentError.value(
        children.length,
        'children',
        'a split needs at least 2 children',
      );
    }
    if (weights.length != children.length) {
      throw ArgumentError.value(
        weights.length,
        'weights',
        'must match children (${children.length})',
      );
    }
    if (weights.any((w) => !w.isFinite || w <= 0)) {
      throw ArgumentError.value(weights, 'weights', 'must all be positive');
    }
    final total = weights.reduce((a, b) => a + b);
    return GridSplit._(
      axis,
      List.unmodifiable(weights.map((w) => w / total)),
      List.unmodifiable(children),
    );
  }

  const GridSplit._(this.axis, this.weights, this.children);

  final GridAxis axis;

  /// Normalized to sum to 1. The only thing a divider drag mutates.
  final List<double> weights;

  final List<GridNode> children;

  /// The smallest share a child may be dragged down to, so a cell can never
  /// collapse to nothing. With 5 children the floor still leaves 0.4 to
  /// distribute, so every split stays draggable.
  static const double minWeight = 0.12;

  GridSplit withWeights(List<double> weights) =>
      GridSplit(axis, weights, children);

  @override
  Map<String, dynamic> toJson() => {
    'type': 'split',
    'axis': axis.name,
    'weights': weights,
    'children': children.map((c) => c.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      other is GridSplit &&
      other.axis == axis &&
      listEquals(other.weights, weights) &&
      listEquals(other.children, children);

  @override
  int get hashCode =>
      Object.hash(axis, Object.hashAll(weights), Object.hashAll(children));
}

/// The partition plus its frame styling. Lives on `Project.grid`; null there
/// means an ordinary (non-collage) project.
@immutable
class GridSpec {
  const GridSpec({
    required this.root,
    this.borderColor = const Color(0xFFFFFFFF),
    this.borderWidth = defaultBorderWidth,
    this.outerMargin = defaultBorderWidth,
    this.cornerRadius = 0,
  });

  /// Gap between two adjacent cells, in canvas-logical px. Rendered as the
  /// background showing through, not as a stroke over the photos.
  final double borderWidth;

  /// Frame between the outermost cells and the canvas edge, in logical px.
  final double outerMargin;

  /// Per-cell corner rounding, in logical px.
  final double cornerRadius;

  final Color borderColor;
  final GridNode root;

  static const double defaultBorderWidth = 12;
  static const double maxBorderWidth = 80;
  static const double maxOuterMargin = 80;
  static const double maxCornerRadius = 60;

  int get cellCount => root.cellCount;

  /// Cell ids in canonical (depth-first) order.
  List<String> get cellIds => root.cellIds;

  GridSpec copyWith({
    GridNode? root,
    Color? borderColor,
    double? borderWidth,
    double? outerMargin,
    double? cornerRadius,
  }) {
    return GridSpec(
      root: root ?? this.root,
      borderColor: borderColor ?? this.borderColor,
      borderWidth: borderWidth ?? this.borderWidth,
      outerMargin: outerMargin ?? this.outerMargin,
      cornerRadius: cornerRadius ?? this.cornerRadius,
    );
  }

  Map<String, dynamic> toJson() => {
    'root': root.toJson(),
    'borderColor': borderColor.toARGB32(),
    'borderWidth': borderWidth,
    'outerMargin': outerMargin,
    'cornerRadius': cornerRadius,
  };

  /// Styling values are clamped on the way in - a hand-edited or corrupt
  /// manifest must not be able to produce a canvas-swallowing frame.
  factory GridSpec.fromJson(Map<String, dynamic> json) {
    double read(String key, double fallback, double max) =>
        ((json[key] as num?)?.toDouble() ?? fallback).clamp(0.0, max);
    return GridSpec(
      root: GridNode.fromJson((json['root'] as Map).cast<String, dynamic>()),
      borderColor: Color(json['borderColor'] as int? ?? 0xFFFFFFFF),
      borderWidth: read('borderWidth', defaultBorderWidth, maxBorderWidth),
      outerMargin: read('outerMargin', defaultBorderWidth, maxOuterMargin),
      cornerRadius: read('cornerRadius', 0, maxCornerRadius),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GridSpec &&
      other.root == root &&
      other.borderColor == borderColor &&
      other.borderWidth == borderWidth &&
      other.outerMargin == outerMargin &&
      other.cornerRadius == cornerRadius;

  @override
  int get hashCode =>
      Object.hash(root, borderColor, borderWidth, outerMargin, cornerRadius);
}

/// A draggable boundary between two siblings of one [GridSplit].
@immutable
class GridDivider {
  const GridDivider({
    required this.path,
    required this.index,
    required this.axis,
    required this.band,
    required this.parentExtent,
  });

  /// Child indices from the root down to the owning [GridSplit].
  final List<int> path;

  /// Sits between children [index] and `index + 1` of that split.
  final int index;

  final GridAxis axis;

  /// The gap rect between the two cells, in canvas-logical units. Zero-thickness
  /// when `borderWidth` is 0 - callers inflate it for hit-testing / handles.
  final Rect band;

  /// The owning split's extent along [axis], in logical px. Divide a drag in px
  /// by this to get the weight delta.
  final double parentExtent;

  /// Stable identity for undo coalescing and widget keys.
  String get key => 'div:${path.join('/')}:$index';

  @override
  bool operator ==(Object other) =>
      other is GridDivider &&
      listEquals(other.path, path) &&
      other.index == index &&
      other.axis == axis &&
      other.band == band &&
      other.parentExtent == parentExtent;

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(path), index, axis, band, parentExtent);
}

/// The result of [layoutGrid]: where every cell lands and which dividers can be
/// dragged. Both painters and the hit-tester read this, so cell geometry has a
/// single definition.
@immutable
class GridLayout {
  const GridLayout({required this.cells, required this.dividers});

  /// Cell id -> rect in canvas-logical units, gaps already applied.
  final Map<String, Rect> cells;

  final List<GridDivider> dividers;

  Rect? rectOf(String? cellId) => cellId == null ? null : cells[cellId];

  /// The cell containing [point], or null when it falls in a gap / the frame.
  String? cellAt(Offset point) {
    for (final entry in cells.entries) {
      if (entry.value.contains(point)) return entry.key;
    }
    return null;
  }
}

/// Which sides of a rect sit on the outer boundary of the grid. Interior edges
/// get half the gap; outer edges get none, so the frame stays exactly
/// `outerMargin` instead of `outerMargin + borderWidth / 2`.
class _Edges {
  const _Edges(this.left, this.top, this.right, this.bottom);
  static const all = _Edges(true, true, true, true);

  final bool left, top, right, bottom;
}

/// Cell rects and dividers for [spec] over a [canvas]-sized document.
///
/// Pure and O(cells): the content rect is the canvas deflated by
/// `outerMargin`, split recursively by weights, and each leaf then deflated by
/// half the gap on its interior edges only. Neighbours therefore end up exactly
/// `borderWidth` apart and the outer frame is exactly `outerMargin`.
GridLayout layoutGrid(GridSpec spec, Size canvas) {
  final cells = <String, Rect>{};
  final dividers = <GridDivider>[];
  final margin = math.min(
    spec.outerMargin,
    math.min(canvas.width, canvas.height) / 4,
  );
  final content = Rect.fromLTWH(
    0,
    0,
    canvas.width,
    canvas.height,
  ).deflate(margin);
  _walk(spec, spec.root, content, const <int>[], _Edges.all, cells, dividers);
  return GridLayout(cells: Map.unmodifiable(cells), dividers: dividers);
}

void _walk(
  GridSpec spec,
  GridNode node,
  Rect rect,
  List<int> path,
  _Edges edges,
  Map<String, Rect> cells,
  List<GridDivider> dividers,
) {
  switch (node) {
    case GridLeaf(:final id):
      final half = spec.borderWidth / 2;
      final inset = Rect.fromLTRB(
        rect.left + (edges.left ? 0 : half),
        rect.top + (edges.top ? 0 : half),
        rect.right - (edges.right ? 0 : half),
        rect.bottom - (edges.bottom ? 0 : half),
      );
      // A huge gap on a small canvas could invert the rect - keep it degenerate
      // but valid rather than negative-sized.
      cells[id] = Rect.fromLTRB(
        inset.left,
        inset.top,
        math.max(inset.left, inset.right),
        math.max(inset.top, inset.bottom),
      );
    case GridSplit(:final axis, :final weights, :final children):
      final horizontal = axis == GridAxis.columns;
      final extent = horizontal ? rect.width : rect.height;
      final end = horizontal ? rect.right : rect.bottom;
      var offset = horizontal ? rect.left : rect.top;
      final last = children.length - 1;
      for (var i = 0; i <= last; i++) {
        // The last child absorbs the float remainder, so the children tile the
        // parent rect exactly instead of leaving a sub-pixel sliver.
        final size = i == last ? end - offset : extent * weights[i];
        final childRect = horizontal
            ? Rect.fromLTWH(offset, rect.top, size, rect.height)
            : Rect.fromLTWH(rect.left, offset, rect.width, size);
        final childEdges = horizontal
            ? _Edges(
                edges.left && i == 0,
                edges.top,
                edges.right && i == last,
                edges.bottom,
              )
            : _Edges(
                edges.left,
                edges.top && i == 0,
                edges.right,
                edges.bottom && i == last,
              );
        _walk(
          spec,
          children[i],
          childRect,
          [...path, i],
          childEdges,
          cells,
          dividers,
        );
        offset += size;
        if (i == last) break;
        final half = spec.borderWidth / 2;
        dividers.add(
          GridDivider(
            path: path,
            index: i,
            axis: axis,
            band: horizontal
                ? Rect.fromLTRB(
                    offset - half,
                    rect.top,
                    offset + half,
                    rect.bottom,
                  )
                : Rect.fromLTRB(
                    rect.left,
                    offset - half,
                    rect.right,
                    offset + half,
                  ),
            parentExtent: extent,
          ),
        );
      }
  }
}

/// [spec] with [divider] moved by [deltaPx] along its axis.
///
/// Weight moves between the two adjacent children only, their sum preserved and
/// each clamped to [GridSplit.minWeight]: every other cell in the tree keeps its
/// rect by construction. Call with the delta from the drag START (not the
/// previous frame) so a drag cannot accumulate float drift.
GridSpec moveDivider(GridSpec spec, GridDivider divider, double deltaPx) {
  if (divider.parentExtent <= 0) return spec;
  final delta = deltaPx / divider.parentExtent;
  final root = _replaceSplit(spec.root, divider.path, (split) {
    final k = divider.index;
    if (k < 0 || k + 1 >= split.weights.length) return split;
    final weights = [...split.weights];
    final sum = weights[k] + weights[k + 1];
    const floor = GridSplit.minWeight;
    // A split so tight that both children are already at the floor cannot move.
    if (sum <= floor * 2) return split;
    weights[k] = (weights[k] + delta).clamp(floor, sum - floor);
    weights[k + 1] = sum - weights[k];
    return split.withWeights(weights);
  });
  return root == null ? spec : spec.copyWith(root: root);
}

/// Rewrites the [GridSplit] at [path] through [transform], rebuilding the spine
/// above it. Returns null when the path does not resolve to a split.
GridNode? _replaceSplit(
  GridNode node,
  List<int> path,
  GridSplit Function(GridSplit) transform,
) {
  if (path.isEmpty) {
    return node is GridSplit ? transform(node) : null;
  }
  if (node is! GridSplit) return null;
  final index = path.first;
  if (index < 0 || index >= node.children.length) return null;
  final child = _replaceSplit(node.children[index], path.sublist(1), transform);
  if (child == null) return null;
  final children = [...node.children]..[index] = child;
  return GridSplit(node.axis, node.weights, children);
}
