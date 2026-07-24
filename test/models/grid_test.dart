import 'dart:convert';
import 'dart:ui';

import 'package:chromis/core/models/grid.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the Photo Grid partition model: canonical cell ids, the layout pass
/// (exact tiling, gaps equal to `borderWidth`, frame equal to `outerMargin`),
/// the divider drag contract (exactly two cells move, floor clamp, no drift)
/// and the JSON round-trip with its clamping.

/// Two equal columns.
GridNode _twoColumns() => GridSplit(
  GridAxis.columns,
  [1, 1],
  const [GridLeaf('a'), GridLeaf('b')],
).withCanonicalIds();

/// Three equal columns.
GridNode _threeColumns() => GridSplit(
  GridAxis.columns,
  [1, 1, 1],
  const [GridLeaf('a'), GridLeaf('b'), GridLeaf('c')],
).withCanonicalIds();

/// Big cell on the left, two stacked on the right - the user's own example.
GridNode _bigLeft() => GridSplit(
  GridAxis.columns,
  [0.6, 0.4],
  [
    const GridLeaf('a'),
    GridSplit(GridAxis.rows, [1, 1], const [GridLeaf('b'), GridLeaf('c')]),
  ],
).withCanonicalIds();

void main() {
  const canvas = Size(1000, 1000);

  GridSpec spec(GridNode root, {double border = 10, double margin = 20}) =>
      GridSpec(root: root, borderWidth: border, outerMargin: margin);

  group('cell ids', () {
    test('are renumbered c0..cN-1 in depth-first order', () {
      expect(_bigLeft().cellIds, ['c0', 'c1', 'c2']);
      expect(_threeColumns().cellIds, ['c0', 'c1', 'c2']);
      expect(_bigLeft().cellCount, 3);
    });

    test('depth-first order is stable across template shapes of one count', () {
      // Same count -> same ids, which is what lets a template swap keep photo
      // N in cell N with no remapping.
      expect(_bigLeft().cellIds, _threeColumns().cellIds);
    });
  });

  group('GridSplit validation', () {
    test('normalizes weights to sum to 1', () {
      final split = GridSplit(
        GridAxis.rows,
        [3, 1],
        const [GridLeaf('a'), GridLeaf('b')],
      );
      expect(split.weights[0], closeTo(0.75, 1e-12));
      expect(split.weights[1], closeTo(0.25, 1e-12));
    });

    test('rejects a single child, mismatched or non-positive weights', () {
      expect(
        () => GridSplit(GridAxis.rows, [1], const [GridLeaf('a')]),
        throwsArgumentError,
      );
      expect(
        () =>
            GridSplit(GridAxis.rows, [1], const [GridLeaf('a'), GridLeaf('b')]),
        throwsArgumentError,
      );
      expect(
        () => GridSplit(
          GridAxis.rows,
          [1, 0],
          const [GridLeaf('a'), GridLeaf('b')],
        ),
        throwsArgumentError,
      );
    });
  });

  group('layoutGrid', () {
    test('gaps equal borderWidth and the frame equals outerMargin', () {
      final layout = layoutGrid(spec(_twoColumns()), canvas);
      final left = layout.cells['c0']!;
      final right = layout.cells['c1']!;

      // Interior edge: exactly one borderWidth between the two cells.
      expect(right.left - left.right, closeTo(10, 1e-9));
      // Outer edges: exactly outerMargin from the canvas, NOT margin + gap/2.
      expect(left.left, closeTo(20, 1e-9));
      expect(left.top, closeTo(20, 1e-9));
      expect(right.right, closeTo(canvas.width - 20, 1e-9));
      expect(right.bottom, closeTo(canvas.height - 20, 1e-9));
    });

    test('cells tile the content rect exactly and never overlap', () {
      for (final root in [_twoColumns(), _threeColumns(), _bigLeft()]) {
        for (final size in const [
          Size(1000, 1000),
          Size(1080, 1920),
          Size(1920, 1080),
        ]) {
          final layout = layoutGrid(spec(root), size);
          final content = Rect.fromLTWH(
            0,
            0,
            size.width,
            size.height,
          ).deflate(20);
          final rects = layout.cells.values.toList();

          for (final rect in rects) {
            expect(rect.width, greaterThan(0));
            expect(rect.height, greaterThan(0));
            expect(content.contains(rect.topLeft), isTrue);
            expect(
              content.inflate(1e-9).contains(rect.bottomRight),
              isTrue,
              reason: '$rect escapes $content',
            );
          }
          for (var i = 0; i < rects.length; i++) {
            for (var j = i + 1; j < rects.length; j++) {
              expect(
                rects[i].overlaps(rects[j]),
                isFalse,
                reason: '${rects[i]} overlaps ${rects[j]}',
              );
            }
          }
        }
      }
    });

    test('a zero border makes cells share their edges exactly', () {
      final layout = layoutGrid(
        spec(_threeColumns(), border: 0, margin: 0),
        canvas,
      );
      expect(
        layout.cells['c0']!.right,
        closeTo(layout.cells['c1']!.left, 1e-9),
      );
      expect(
        layout.cells['c1']!.right,
        closeTo(layout.cells['c2']!.left, 1e-9),
      );
      // The last child absorbs the float remainder, so the row ends exactly.
      expect(layout.cells['c2']!.right, closeTo(canvas.width, 1e-9));
    });

    test('exposes one divider per interior boundary', () {
      expect(layoutGrid(spec(_twoColumns()), canvas).dividers, hasLength(1));
      // Three columns = 2 dividers; big-left = 1 vertical + 1 horizontal.
      expect(layoutGrid(spec(_threeColumns()), canvas).dividers, hasLength(2));
      final nested = layoutGrid(spec(_bigLeft()), canvas).dividers;
      expect(nested, hasLength(2));
      expect(nested.map((d) => d.axis), [GridAxis.columns, GridAxis.rows]);
      // The nested divider is addressed through its parent's child index.
      expect(nested[0].path, isEmpty);
      expect(nested[1].path, [1]);
    });

    test('an oversized margin is clamped instead of inverting the rect', () {
      final layout = layoutGrid(
        spec(_twoColumns(), margin: 5000),
        const Size(400, 400),
      );
      for (final rect in layout.cells.values) {
        expect(rect.width, greaterThanOrEqualTo(0));
        expect(rect.height, greaterThanOrEqualTo(0));
      }
    });

    test('an oversized border degenerates cells but never inverts them', () {
      final layout = layoutGrid(
        spec(_threeColumns(), border: GridSpec.maxBorderWidth),
        const Size(160, 160),
      );
      for (final rect in layout.cells.values) {
        expect(rect.width, greaterThanOrEqualTo(0));
        expect(rect.height, greaterThanOrEqualTo(0));
      }
    });

    test('cellAt finds the cell under a point and nothing in a gap', () {
      final layout = layoutGrid(spec(_twoColumns()), canvas);
      expect(layout.cellAt(const Offset(100, 500)), 'c0');
      expect(layout.cellAt(const Offset(900, 500)), 'c1');
      // Dead centre falls in the gap between the two columns.
      expect(layout.cellAt(const Offset(500, 500)), isNull);
      expect(layout.rectOf(null), isNull);
    });
  });

  group('moveDivider', () {
    test('exchanges weight between the two adjacent children only', () {
      final before = spec(_threeColumns());
      final divider = layoutGrid(before, canvas).dividers.first;
      final after = moveDivider(before, divider, 96);

      final a = layoutGrid(before, canvas).cells;
      final b = layoutGrid(after, canvas).cells;
      expect(b['c0']!.width, greaterThan(a['c0']!.width));
      expect(b['c1']!.width, lessThan(a['c1']!.width));
      // The third column is untouched by construction - this is the whole
      // reason the partition is a tree and not a flat list of rects.
      expect(b['c2'], a['c2']);
    });

    test('a drag and its inverse return the original weights (no drift)', () {
      final start = spec(_twoColumns());
      final divider = layoutGrid(start, canvas).dividers.first;
      final moved = moveDivider(start, divider, 120);
      final back = moveDivider(
        moved,
        layoutGrid(moved, canvas).dividers.first,
        -120,
      );

      final original = layoutGrid(start, canvas).cells;
      final restored = layoutGrid(back, canvas).cells;
      for (final id in original.keys) {
        expect(restored[id]!.left, closeTo(original[id]!.left, 1e-9));
        expect(restored[id]!.right, closeTo(original[id]!.right, 1e-9));
      }
    });

    test('two successive drags equal one combined drag', () {
      final start = spec(_twoColumns());
      GridSpec drag(GridSpec s, double px) =>
          moveDivider(s, layoutGrid(s, canvas).dividers.first, px);

      final stepwise = drag(drag(start, 40), 60);
      final combined = drag(start, 100);
      final a = layoutGrid(stepwise, canvas).cells['c0']!;
      final b = layoutGrid(combined, canvas).cells['c0']!;
      expect(a.width, closeTo(b.width, 1e-9));
    });

    test('clamps to the minimum weight at both ends', () {
      final start = spec(_twoColumns());
      final divider = layoutGrid(start, canvas).dividers.first;

      final collapsed = moveDivider(start, divider, -100000);
      final blown = moveDivider(start, divider, 100000);
      final content = canvas.width - 40; // minus the outer margin

      expect(
        layoutGrid(collapsed, canvas).cells['c0']!.width,
        closeTo(content * GridSplit.minWeight - 5, 1e-6),
      );
      expect(
        layoutGrid(blown, canvas).cells['c1']!.width,
        closeTo(content * GridSplit.minWeight - 5, 1e-6),
      );
    });

    test('moves a nested divider without touching the other column', () {
      final start = spec(_bigLeft());
      final vertical = layoutGrid(start, canvas).dividers[1];
      expect(vertical.axis, GridAxis.rows);
      final after = moveDivider(start, vertical, 100);

      final a = layoutGrid(start, canvas).cells;
      final b = layoutGrid(after, canvas).cells;
      expect(b['c0'], a['c0']); // the big left cell is unaffected
      expect(b['c1']!.height, greaterThan(a['c1']!.height));
      expect(b['c2']!.height, lessThan(a['c2']!.height));
    });

    test('a divider with a bad path leaves the spec untouched', () {
      final start = spec(_twoColumns());
      const bogus = GridDivider(
        path: [7],
        index: 0,
        axis: GridAxis.columns,
        band: Rect.zero,
        parentExtent: 100,
      );
      expect(moveDivider(start, bogus, 50), start);
    });

    test('divider keys are stable and unique within a layout', () {
      final dividers = layoutGrid(spec(_bigLeft()), canvas).dividers;
      expect(dividers.map((d) => d.key).toSet(), hasLength(dividers.length));
      expect(dividers[1].key, 'div:1:0');
    });
  });

  group('JSON', () {
    test('round-trips through a real encode/decode', () {
      final original = GridSpec(
        root: _bigLeft(),
        borderColor: const Color(0xFF17B6D6),
        borderWidth: 24,
        outerMargin: 8,
        cornerRadius: 16,
      );
      final decoded = GridSpec.fromJson(
        (jsonDecode(jsonEncode(original.toJson())) as Map)
            .cast<String, dynamic>(),
      );
      expect(decoded, original);
      expect(decoded.cellIds, ['c0', 'c1', 'c2']);
    });

    test('clamps hostile styling values and defaults missing ones', () {
      final decoded = GridSpec.fromJson({
        'root': _twoColumns().toJson(),
        'borderWidth': 1e9,
        'cornerRadius': -40,
      });
      expect(decoded.borderWidth, GridSpec.maxBorderWidth);
      expect(decoded.cornerRadius, 0);
      expect(decoded.outerMargin, GridSpec.defaultBorderWidth);
      expect(decoded.borderColor, const Color(0xFFFFFFFF));
    });

    test('rejects an unknown node type', () {
      expect(
        () => GridNode.fromJson({'type': 'pinwheel'}),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
