import '../../core/models/grid.dart';

/// The curated Photo Grid layouts offered per photo count.
///
/// Pure data: counts and layouts are a registry, not code, so adding a 6-photo
/// row later is an edit here and nothing else. Every template normalizes its
/// leaf ids through [GridNode.withCanonicalIds], so cells are always `c0..cN-1`
/// in depth-first order and swapping template at the same count keeps photo N
/// in cell N.

/// The photo counts Photo Grid offers.
const int kMinGridPhotos = 2;
const int kMaxGridPhotos = 5;

/// One named layout, ready to drop into a [GridSpec].
class GridTemplate {
  /// Canonicalizes [root] so callers cannot hand out mis-numbered cell ids.
  GridTemplate(this.label, GridNode root) : root = root.withCanonicalIds();

  final String label;
  final GridNode root;

  int get cellCount => root.cellCount;

  /// Cells in canonical order - `c0`, `c1`, ...
  List<String> get cellIds => root.cellIds;
}

GridNode _leaf() => const GridLeaf('');

GridNode _cols(List<double> weights, List<GridNode> children) =>
    GridSplit(GridAxis.columns, weights, children);

GridNode _rows(List<double> weights, List<GridNode> children) =>
    GridSplit(GridAxis.rows, weights, children);

/// [count] equal children along [axis].
GridNode _even(GridAxis axis, int count) => GridSplit(
  axis,
  List.filled(count, 1),
  List.generate(count, (_) => _leaf()),
);

/// Layouts for [count] photos, most conventional first (the first entry is what
/// a new collage of that size starts on). Returns an empty list outside
/// [kMinGridPhotos]..[kMaxGridPhotos].
List<GridTemplate> gridTemplatesFor(int count) => switch (count) {
  2 => [
    GridTemplate('Side by side', _even(GridAxis.columns, 2)),
    GridTemplate('Stacked', _even(GridAxis.rows, 2)),
    GridTemplate('Wide left', _cols([0.62, 0.38], [_leaf(), _leaf()])),
    GridTemplate('Tall top', _rows([0.62, 0.38], [_leaf(), _leaf()])),
  ],
  3 => [
    GridTemplate('Columns', _even(GridAxis.columns, 3)),
    GridTemplate('Rows', _even(GridAxis.rows, 3)),
    GridTemplate(
      'Big left',
      _cols([0.6, 0.4], [_leaf(), _even(GridAxis.rows, 2)]),
    ),
    GridTemplate(
      'Big top',
      _rows([0.6, 0.4], [_leaf(), _even(GridAxis.columns, 2)]),
    ),
  ],
  4 => [
    GridTemplate(
      '2 x 2',
      _rows([1, 1], [_even(GridAxis.columns, 2), _even(GridAxis.columns, 2)]),
    ),
    GridTemplate('Columns', _even(GridAxis.columns, 4)),
    GridTemplate('Rows', _even(GridAxis.rows, 4)),
    GridTemplate(
      'Big left',
      _cols([0.6, 0.4], [_leaf(), _even(GridAxis.rows, 3)]),
    ),
    GridTemplate(
      'Big top',
      _rows([0.55, 0.45], [_leaf(), _even(GridAxis.columns, 3)]),
    ),
  ],
  5 => [
    GridTemplate(
      '2 over 3',
      _rows(
        [0.5, 0.5],
        [_even(GridAxis.columns, 2), _even(GridAxis.columns, 3)],
      ),
    ),
    GridTemplate(
      '3 over 2',
      _rows(
        [0.5, 0.5],
        [_even(GridAxis.columns, 3), _even(GridAxis.columns, 2)],
      ),
    ),
    GridTemplate(
      'Big left',
      _cols([0.58, 0.42], [_leaf(), _even(GridAxis.rows, 4)]),
    ),
    GridTemplate(
      'Big top',
      _rows([0.55, 0.45], [_leaf(), _even(GridAxis.columns, 4)]),
    ),
    GridTemplate(
      '2 left, 3 right',
      _cols([0.5, 0.5], [_even(GridAxis.rows, 2), _even(GridAxis.rows, 3)]),
    ),
  ],
  _ => const [],
};

/// The layout a new collage of [count] photos starts on.
GridTemplate defaultGridTemplate(int count) =>
    gridTemplatesFor(count.clamp(kMinGridPhotos, kMaxGridPhotos)).first;

/// A fresh [GridSpec] for [count] photos on the default layout.
GridSpec defaultGridSpec(int count) =>
    GridSpec(root: defaultGridTemplate(count).root);

/// The registry entry [root] is closest to, or null when no layout shares its
/// shape.
///
/// Shape is the primary key - weights are not - so a layout whose dividers the
/// user has dragged still reads as a template rather than going blank on the
/// first drag. Some entries differ only in weights ("Side by side" and "Wide
/// left" are both two columns), so among same-shape candidates the nearest
/// weights win: a freshly applied template matches itself exactly, and a
/// dragged one reports whichever layout it now sits closest to.
GridTemplate? matchGridTemplate(GridNode root) {
  GridTemplate? best;
  var bestDistance = double.infinity;
  for (final template in gridTemplatesFor(root.cellCount)) {
    final distance = _weightDistance(template.root, root);
    if (distance != null && distance < bestDistance) {
      best = template;
      bestDistance = distance;
    }
  }
  return best;
}

/// Total absolute weight difference between two same-shaped trees, or null when
/// their shapes differ.
double? _weightDistance(GridNode a, GridNode b) {
  if (a is GridLeaf) return b is GridLeaf ? 0 : null;
  a as GridSplit;
  if (b is! GridSplit ||
      a.axis != b.axis ||
      a.children.length != b.children.length) {
    return null;
  }
  var total = 0.0;
  for (var i = 0; i < a.children.length; i++) {
    final child = _weightDistance(a.children[i], b.children[i]);
    if (child == null) return null;
    total += child + (a.weights[i] - b.weights[i]).abs();
  }
  return total;
}
