# Photo Grid (Collage) mode - design & implementation plan

Status: proposal, not implemented. Target milestone: **M10 · Photo Grid (collage)**.

## 1. The concept, reviewed

Requested behaviour:

1. "New project" asks whether this is a Photo Grid (collage).
2. If yes, ask "How many photos?" (2-5).
3. Show a horizontal scroll of cell layouts for that count, several per count.
4. Each cell is an internal viewport that accepts layers.
5. Column/row dividers are draggable; neighbouring cells resize automatically.
6. The bottom menu always exposes: photo count, template, border color, border width.

It fits the existing document model well, with one important framing change: **a grid
is not a new document type and not a new layer type - it is a partition of the canvas
that layers get assigned to.** Everything the editor already does (transform gestures,
crop, adjust, AI cut-out, erase, text, bubbles, undo, autosave, export) then keeps
working inside cells for free, because layer coordinates never leave canvas-logical
space.

The two things worth deciding up front, because they drive the whole model:

- **How cells are described.** A flat list of rects cannot answer "which cells share
  this divider", so divider dragging degenerates into float-compare adjacency
  guessing. A **split tree** answers it structurally: one divider is one weight
  exchange inside one node, and every other cell is untouched by construction. This
  is the single decision that makes requirement 5 cheap instead of painful.
- **Where layer coordinates live.** Cell-local normalized coordinates would fork the
  coordinate space and break `mask_mapper`, `crop_overlay`, `editor_canvas`
  hit-testing and both painters, all of which assume canvas-logical units. Layers
  stay canvas-absolute; cells only clip.

Known limitation of the split-tree model: it expresses guillotine layouts only, so a
4-cell pinwheel/windmill (three rects meeting at a point with no full-width cut) is
not representable. Every layout in the requested 2-5 range that we actually want is a
guillotine layout, so this is worth the trade. If a pinwheel is wanted later, add a
second `GridSpec` variant holding fixed rects with non-draggable dividers.

## 2. Model

### 2.1 The split tree

`lib/core/models/grid.dart`

```dart
/// Which way a split lays its children out. `columns` puts them side by side
/// (dividers are vertical); `rows` stacks them (dividers are horizontal).
enum GridAxis { columns, rows }

@immutable
sealed class GridNode {}

/// One cell. [id] is canonical (`c0`, `c1`, ...) and assigned by depth-first
/// order, so a template swap maps photo N to cell N with no bookkeeping.
final class GridLeaf extends GridNode {
  const GridLeaf(this.id);
  final String id;
}

/// [weights] are normalized to sum to 1 and are the only thing a divider drag
/// mutates. `weights.length == children.length`, minimum 2 children.
final class GridSplit extends GridNode {
  const GridSplit(this.axis, this.weights, this.children);
  final GridAxis axis;
  final List<double> weights;
  final List<GridNode> children;
}
```

### 2.2 The spec on the project

```dart
@immutable
class GridSpec {
  const GridSpec({
    required this.root,
    this.borderColor = const Color(0xFFFFFFFF),
    this.borderWidth = 12,     // logical px of gap BETWEEN cells
    this.outerMargin = 12,     // logical px of frame around the whole grid
    this.cornerRadius = 0,     // logical px, per cell
  });
  ...
  int get cellCount;                 // leaf count
  List<String> get cellIds;          // depth-first order: c0, c1, ...
}
```

`Project` gains `final GridSpec? grid;` - null means an ordinary project, non-null
means collage mode. Nothing else about `Project` changes.

### 2.3 Layer assignment

`Layer` gains `final String? cellId;`:

- non-null: the layer is clipped to that cell and follows it when the cell resizes;
- null: a **free layer** drawn above the whole grid, unclipped. This is how a caption
  or sticker spans the collage.

It belongs on the sealed base (`baseJson`/`fromJson`/`copyWith`/`==`/`hashCode` in all
three variants) rather than in a side map on `GridSpec`, so that `duplicateLayer`,
`_cloneWithNewId`, `removeLayer` and `duplicate()` keep it correct with no extra code
and no stale entries.

### 2.4 Layout pass

```dart
/// Cell rects and draggable dividers for [spec] over a canvas of [size].
/// Pure function, O(cells); the border gap is applied here so both painters and
/// the hit-tester agree by construction.
GridLayout layoutGrid(GridSpec spec, Size canvas);

class GridLayout {
  final Map<String, Rect> cells;      // after outerMargin + borderWidth deflation
  final List<GridDivider> dividers;
}

class GridDivider {
  final List<int> path;   // child indices from the root to the GridSplit
  final int index;        // divider k sits between children k and k+1
  final GridAxis axis;
  final Rect band;        // the draggable band, in canvas-logical units
  final double parentExtent; // px per 1.0 of weight, for the drag math
}
```

Rect derivation: start from `canvas.deflate(outerMargin)`, recurse splitting the rect
by weights, then deflate each leaf rect by `borderWidth / 2`. That yields exactly
`borderWidth` between neighbours and `outerMargin` at the edges.

### 2.5 Divider drag math

Dragging divider `k` of a split moves weight between children `k` and `k+1` only,
keeping their sum constant:

```dart
final delta = dragPx / divider.parentExtent;
final sum = w[k] + w[k + 1];
w[k]     = (w[k] + delta).clamp(kMinWeight, sum - kMinWeight);
w[k + 1] = sum - w[k];
```

`kMinWeight` (0.12 of the parent extent) stops a cell collapsing to nothing. Every
other cell in the tree is untouched, which is precisely "automatically change size of
the others related".

## 3. Templates

`lib/features/grid/grid_templates.dart` - a pure data registry, `count -> templates`.
Leaf ids are assigned by depth-first walk, so a template only declares structure:

```dart
GridTemplate('Big left', cols([.6, .4], [leaf(), rows([.5, .5], [leaf(), leaf()])]))
```

| Count | Templates |
| --- | --- |
| 2 | Side by side; Stacked; Wide left (.62/.38); Tall top (.62/.38) |
| 3 | 3 columns; 3 rows; Big left (.6 + 2 stacked); Big top (.6 + 2 side by side) |
| 4 | 2 x 2; 4 columns; 4 rows; Big left (.6 + 3 stacked); Big top (.55 + 3 across) |
| 5 | 2 over 3; 3 over 2; Big left (.58 + 4 stacked); Big top (.55 + 4 across); 2 left / 3 right |

Counts are data, not code: adding 6-photo layouts later is a registry edit.

`GridTemplateStrip` (horizontal `ListView`) + `GridTemplatePreview` (a small
`CustomPainter` that draws `layoutGrid` output as filled rounded rects) are **one
widget pair used in two places**: the create sheet and the editor's Grid panel. That
is exactly the "horizontal scroll of different setups" the request asks for, and it
stays consistent between the two entry points.

## 4. Rendering

Both painters must change together - the repo's WYSIWYG parity invariant depends on
`ProjectCanvas` and `ProjectRenderer` agreeing, and `canvas_geometry.dart` exists
specifically to stop them drifting.

The border is painted as a **background fill, not a stroke**: fill the whole canvas
with `borderColor`, then draw each cell's content clipped to its (already deflated)
rect on top. Gaps and the outer frame fall out of the geometry with no seam maths, and
no photo pixels are covered by a stroke. A fully transparent `borderColor` simply skips
the fill, leaving real transparency between cells.

`ProjectCanvas` (widget tree):

```dart
Stack(children: [
  if (grid != null) Positioned.fill(child: ColoredBox(color: grid.borderColor)),
  for (final cell in layout.cells.entries)
    Positioned.fill(
      child: ClipRRect(
        clipper: _CellClipper(cell.value * scale, grid.cornerRadius * scale),
        // Full-canvas Stack: the existing absolute _positioned() math is reused
        // verbatim, so no coordinate-space change.
        child: Stack(children: [for (final l in layersOf(cell.key)) _positioned(l, ...)]),
      ),
    ),
  if (showCellPlaceholders) ...emptyCellHints,   // editor chrome only, never exported
  for (final l in freeLayers) _positioned(l, ...),
]);
```

`ProjectRenderer` gains an optional `GridSpec? grid` on `renderImageSized` /
`renderPngSized` / `renderJpgSized` / `renderWebpSized` (default null keeps every
existing call site behaving identically) and mirrors the above with
`canvas.save() / clipRRect / restore`.

`showCellPlaceholders` defaults to false so Home thumbnails and exports never show the
"tap to add a photo" hint; `EditorCanvas` passes true.

## 5. Interaction

### 5.1 Divider dragging

Handles are drawn by `EditorCanvas` when `project.grid != null`: a short rounded pill
centred on each divider band, in the cyan accent.

Gesture priority: in `_onScaleStart`, if the focal point is within ~14 logical px of a
divider band, the gesture grabs the divider instead of a layer. This is armed for the
tools where a canvas gesture already means "manipulate", not "paint":
`{grid, layers, adjust, text}` - the same gating pattern already used for the on-canvas
delete handle (`editor_canvas.dart:163`). Erase and Cut-out keep their brush/tap
semantics untouched.

Undo: one coalesce key per divider (`grid:div:<path>:<k>`), so a whole drag collapses
into a single history step, matching how transforms and sliders already coalesce.

### 5.2 Cell content follows its cell

When a divider moves, the layers of the affected cells must move with it. Compute from
a **snapshot taken at drag start**, never incrementally, so repeated drags cannot
accumulate float drift or distort a user's own pan/zoom inside a cell (the same
technique `_onScaleStart` already uses with `_startTransform`):

```dart
// cell rect R0 -> R1, layer transform t0 -> t1
final s = math.max(R1.width / R0.width, R1.height / R0.height); // cover
t1 = t0.copyWith(
  position: R1.center + (t0.position - R0.center) * s,
  scale: t0.scale * s,
);
```

`max` (cover) rather than `min` (contain) is what keeps a photo filling its cell. This
needs a companion to the existing `photoFitScale`:

```dart
/// The layer scale that makes a [pixels]-sized photo COVER a w x h cell.
double photoCoverScale(Size pixels, double w, double h);
```

in `canvas_geometry.dart`, next to `photoFitScale`, so both painters and the editor
share one definition.

### 5.3 Cells as viewports

- Tapping an **empty** cell opens the picker and adds an `ImageLayer` with that
  `cellId`, centred and cover-scaled.
- Tapping a **filled** cell selects its topmost layer. `_hitTest` additionally
  requires the point to be inside the layer's cell rect, so a photo overflowing its
  cell is not tappable outside it.
- Pan/pinch inside a cell is the existing gesture, plus a clamp: position is
  constrained so the layer keeps covering the cell (centred on any axis where the
  layer is smaller than the cell). Without this, a photo can be dragged out of its
  own cell leaving a hole, which reads as a bug.
- "Add layer" from the dock assigns to the selected cell (or the first empty one);
  text and bubbles default to free layers.
- Dragging a layer and releasing with its centre over a different cell reassigns it,
  swapping content if that cell is occupied.

### 5.4 Count and template changes

- **Template change, same count**: cell ids are stable (`c0..cN-1`), so layers keep
  their `cellId`; only the rects change and each cell's layers re-fit through the same
  snapshot mapping as a divider drag.
- **Count increase**: new trailing cells are empty and show the add hint.
- **Count decrease**: layers of the removed trailing cells are deleted as part of the
  same single undo step, with a toast ("2 photos removed"). Alternatives (silently
  re-homing them into a surviving cell, or a hidden spare pool) are worse: both hide
  content in a place the user did not put it. Undo restores everything.

## 6. Entry points

### 6.1 Create flow

The current Home card "New blank project" calls `showCanvasSizeSheet` directly. Insert
the mode question ahead of it, as asked:

```
New project  ->  What are you making?
                 [ Blank canvas ]   [ Photo grid ]
                        |                  |
             showCanvasSizeSheet   showGridSetupSheet
```

`showGridSetupSheet` = aspect chips (Square / Portrait / Story / Landscape, reusing
`CanvasPreset`) + "How many photos?" segmented 2/3/4/5 + the horizontal
`GridTemplateStrip` + Create. On Create it builds the project, then immediately opens a
**multi-photo pick** so the user fills the whole collage in one gesture; picked photos
land in cells in order, cover-scaled. This needs `pickMultiImage` added to
`ImageImportService` (it currently only has single-image pick).

"Open a photo" is untouched.

### 6.2 Grid tool (the always-available menu)

New `EditorTool.grid` ("Grid", `Icons.grid_view`, its own accent). Its dock button is
shown only when `project.grid != null`, and it is the tool a collage opens on. Panel
contents, top to bottom:

- **PHOTOS** - segmented 2 3 4 5
- **LAYOUT** - `GridTemplateStrip`, current template highlighted
- **BORDER** - width slider (0-80 logical px), colour swatch row (reusing the existing
  `_swatchRow` incl. a transparent option), corner radius slider (0-60)
- **Shuffle** - rotate which photo sits in which cell

## 7. Persistence

- `Project.schemaVersion` 2 -> **3**. v3 adds `grid` (nullable) and per-layer `cellId`
  (nullable). Older manifests read back with `grid: null`, so existing projects are
  untouched; the existing "newer than supported" guard still protects downgrades.
- **Bug to fix as part of PG-1**: `ProjectRepository.duplicate()`
  ([project_repository.dart:115-128](../lib/features/home/project_repository.dart#L115-L128))
  rebuilds the `Project` without `canvasWidth`, `canvasHeight` or `fps`, so duplicating
  any non-square project today silently resets it to 512 x 512 at 8 fps. Collages would
  additionally lose their `grid`. Fix it to `copyWith` from the source rather than
  re-listing fields.
- `sweepOrphanAssets` is schema-agnostic (it walks for `assetPath`/`maskPath` keys), so
  it needs no change.

## 8. Work breakdown (M10 · Photo Grid (collage))

| # | Issue | Substance |
| --- | --- | --- |
| PG-1 | Grid model + schema v3 | `GridNode`/`GridSpec`/`layoutGrid`/divider maths, `Project.grid`, `Layer.cellId`, JSON round-trip + migration, `duplicate()` fix |
| PG-2 | Template registry + preview strip | 2-5 templates, DFS id assignment, `GridTemplatePreview` painter, `GridTemplateStrip` |
| PG-3 | Rendering | Cell clipping + border-as-background in `ProjectCanvas` and `ProjectRenderer`, `photoCoverScale`, canvas/export parity test on a collage |
| PG-4 | Create flow | Mode question, `showGridSetupSheet`, `pickMultiImage`, fill cells in order |
| PG-5 | Grid tool panel | `EditorTool.grid`, conditional dock button, count / template / border colour / border width / radius / shuffle |
| PG-6 | Divider dragging | Handle overlay, gesture priority, snapshot re-fit of affected cells, coalesced undo |
| PG-7 | Cell viewport behaviour | Tap-empty-to-add, cell-scoped hit test, cover clamp on pan/zoom, drag-to-swap between cells |
| PG-8 | Tests, E2E, docs | BDD steps + collage scenario, count-change semantics, CLAUDE.md architecture note |

Dependencies: PG-1 -> PG-2 -> PG-3 gate everything; PG-4/PG-5 are parallel once PG-3
lands; PG-6/PG-7 are parallel after PG-5; PG-8 last.

**Device checkpoints** (per the milestone workflow): stop for an on-device test after
PG-4 (create a collage, see it render and export correctly) and again after PG-7 (the
full interaction set), rather than only at the end of the milestone.

## 9. Test plan

- `layoutGrid`: cell rects tile the content rect with no overlap, gaps equal
  `borderWidth`, outer frame equals `outerMargin`, for every template at square,
  portrait and landscape aspects.
- Divider maths: weight exchange affects exactly two children; `kMinWeight` clamp holds
  at both ends; a drag then its inverse returns the original weights.
- Registry: every template of count N has exactly N leaves, ids `c0..cN-1` in DFS
  order.
- Round-trip: `GridSpec`/`GridNode` JSON symmetry; a v2 manifest loads with
  `grid == null`; a v3 manifest survives save -> load -> save byte-identically.
- Re-fit: after a divider drag the photo still covers its cell; two successive drags
  are equivalent to one combined drag (no drift).
- Parity: extend the existing canvas/export parity coverage to a collage project -
  clipping and border must match between `ProjectCanvas` and `ProjectRenderer`.
- Widget: Grid panel changes count/template/border and commits one undo step each;
  tapping an empty cell invokes the picker; divider drag updates weights.
- E2E (bdd_widget_test): "create a 3-photo grid, drag the middle divider, change the
  border colour, export".

## 10. Out of scope for M10

- Non-guillotine (pinwheel/mosaic) layouts.
- Per-cell aspect locking, cell rotation, freeform/scrapbook collages.
- More than 5 photos - the registry supports it, the templates just are not drawn yet.
- Grid-aware animation (frames already work; nothing extra is planned).
