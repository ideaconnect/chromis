import 'dart:ui';

import 'package:chromis/core/models/frame.dart';
import 'package:chromis/core/models/grid.dart';
import 'package:chromis/core/models/layer.dart';
import 'package:chromis/core/models/layer_transform.dart';
import 'package:chromis/core/models/project.dart';
import 'package:chromis/features/grid/grid_refit.dart';
import 'package:chromis/features/grid/grid_templates.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cell content following its cell: the cover mapping used by every reshape
/// (template swap, photo count change, divider drag), the drop of content whose
/// cell disappears, and the deterministic shuffle.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const canvas = Size(1000, 1000);

  GridSpec specFor(int count, [int template = 0]) =>
      GridSpec(root: gridTemplatesFor(count)[template].root);

  Map<String, Rect> cellsOf(GridSpec spec) => layoutGrid(spec, canvas).cells;

  Project collage(GridSpec grid, {List<Layer> layers = const []}) => Project(
    id: 'p',
    name: 'Collage',
    canvasWidth: 1000,
    canvasHeight: 1000,
    grid: grid,
    frames: [Frame(id: 'p_f0', layers: layers)],
  );

  /// A photo centred on its cell, scaled to cover it.
  ImageLayer photoIn(String cellId, GridSpec grid, {double scale = 2}) {
    final rect = cellsOf(grid)[cellId]!;
    return ImageLayer(
      id: 'l_$cellId',
      name: cellId,
      assetPath: '/fake/$cellId.png',
      cellId: cellId,
      transform: LayerTransform(position: rect.center, scale: scale),
    );
  }

  group('refitToCell', () {
    test('keeps a centred layer centred and scales by the cover factor', () {
      const from = Rect.fromLTWH(0, 0, 100, 100);
      const to = Rect.fromLTWH(200, 200, 150, 100);
      const t = LayerTransform(position: Offset(50, 50), scale: 2);

      final moved = refitToCell(t, from, to);
      expect(moved.position, to.center);
      // max(150/100, 100/100) = 1.5 - cover, so the layer still fills the cell.
      expect(moved.scale, 3);
    });

    test('preserves a pan the user made inside the cell', () {
      const from = Rect.fromLTWH(0, 0, 100, 100);
      const to = Rect.fromLTWH(0, 0, 200, 200);
      // Off-centre by (10, -5) in a 100-wide cell.
      const t = LayerTransform(position: Offset(60, 45));

      final moved = refitToCell(t, from, to);
      // The same offset, scaled with the cell: still 10% right, 5% up.
      expect(moved.position, const Offset(120, 90));
      expect(moved.scale, 2);
    });

    test('is exact under composition - two steps equal one', () {
      const a = Rect.fromLTWH(0, 0, 100, 100);
      const b = Rect.fromLTWH(10, 10, 150, 120);
      const c = Rect.fromLTWH(40, 0, 220, 90);
      const t = LayerTransform(position: Offset(70, 30), scale: 1.3);

      final stepwise = refitToCell(refitToCell(t, a, b), b, c);
      final direct = refitToCell(t, a, c);
      // Guards the snapshot-based drag: re-fitting from the drag start must
      // land where an incremental chain would, with no drift.
      expect(stepwise.position.dx, closeTo(direct.position.dx, 1e-9));
      expect(stepwise.position.dy, closeTo(direct.position.dy, 1e-9));
      expect(stepwise.scale, closeTo(direct.scale, 1e-9));
    });

    test('a degenerate source rect leaves the transform alone', () {
      const t = LayerTransform(position: Offset(5, 5));
      expect(refitToCell(t, Rect.zero, const Rect.fromLTWH(0, 0, 10, 10)), t);
    });
  });

  group('applyGridSpec', () {
    test('carries each photo into its cell new rect', () {
      final from = specFor(3); // 3 columns
      final to = specFor(3, 2); // big left + 2 stacked
      final project = collage(
        from,
        layers: [photoIn('c0', from), photoIn('c1', from)],
      );

      final next = applyGridSpec(project, to);
      final rects = cellsOf(to);
      expect(next.grid, to);
      for (final layer in next.frames.single.layers) {
        expect(layer.transform.position, rects[layer.cellId]!.center);
      }
    });

    test('drops content whose cell no longer exists', () {
      final from = specFor(4);
      final to = specFor(2);
      final project = collage(
        from,
        layers: [
          photoIn('c0', from),
          photoIn('c1', from),
          photoIn('c2', from),
          photoIn('c3', from),
          // A free layer is not part of the partition and always survives.
          const TextLayer(
            id: 'free',
            name: 'Caption',
            text: 'hi',
            fontFamily: 'Manrope',
          ),
        ],
      );

      final next = applyGridSpec(project, to);
      expect(next.frames.single.layers.map((l) => l.id), [
        'l_c0',
        'l_c1',
        'free',
      ]);
    });

    test('growing the count keeps every photo and adds empty cells', () {
      final from = specFor(2);
      final to = specFor(5);
      final project = collage(
        from,
        layers: [photoIn('c0', from), photoIn('c1', from)],
      );

      final next = applyGridSpec(project, to);
      expect(next.frames.single.layers, hasLength(2));
      expect(next.grid!.cellCount, 5);
    });

    test('a styling-only change leaves every layer untouched', () {
      // Border width arrives as a stream of slider ticks; re-fitting each one
      // would walk the content across the canvas.
      final grid = specFor(2);
      final project = collage(grid, layers: [photoIn('c0', grid)]);

      final next = applyGridSpec(project, grid.copyWith(borderWidth: 60));
      expect(next.frames.single.layers, project.frames.single.layers);
      expect(next.grid!.borderWidth, 60);
    });

    test('a project with no grid simply gains one', () {
      final plain = Project.empty(id: 'p');
      final next = applyGridSpec(plain, specFor(2));
      expect(next.grid!.cellCount, 2);
      expect(next.frames, plain.frames);
    });
  });

  group('shuffleGridCells', () {
    test('rotates photos one cell forward and re-fits them', () {
      final grid = specFor(3, 2); // cells of different sizes
      final project = collage(
        grid,
        layers: [photoIn('c0', grid), photoIn('c1', grid)],
      );

      final next = shuffleGridCells(project);
      final rects = cellsOf(grid);
      final layers = next.frames.single.layers;
      expect(layers.map((l) => l.cellId), ['c1', 'c2']);
      // Each photo is re-centred on the cell it moved into.
      expect(layers[0].transform.position, rects['c1']!.center);
      expect(layers[1].transform.position, rects['c2']!.center);
    });

    test('wraps the last cell around to the first', () {
      final grid = specFor(2);
      final project = collage(grid, layers: [photoIn('c1', grid)]);
      expect(
        shuffleGridCells(project).frames.single.layers.single.cellId,
        'c0',
      );
    });

    test('leaves free layers and non-collage projects alone', () {
      const free = TextLayer(
        id: 'free',
        name: 'Caption',
        text: 'hi',
        fontFamily: 'Manrope',
      );
      final grid = specFor(2);
      expect(
        shuffleGridCells(
          collage(grid, layers: const [free]),
        ).frames.single.layers.single,
        free,
      );
      final plain = Project.empty(id: 'p');
      expect(shuffleGridCells(plain), plain);
    });
  });
}
