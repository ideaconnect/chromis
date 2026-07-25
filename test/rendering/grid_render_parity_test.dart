import 'dart:typed_data';

import 'package:chromis/core/models/frame.dart';
import 'package:chromis/core/models/grid.dart';
import 'package:chromis/core/models/layer.dart';
import 'package:chromis/core/models/layer_transform.dart';
import 'package:chromis/features/editor/widgets/project_canvas.dart';
import 'package:chromis/features/export/project_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// WYSIWYG parity between the two rendering surfaces - the on-canvas preview
/// ([ProjectCanvas]) and the headless export renderer ([ProjectRenderer]) - for
/// Photo Grid composition: cell clipping, the border-as-background fill, and
/// the cell-then-free draw order.
///
/// The probes are caption bubbles rather than photos on purpose: they paint as
/// solid vector fills through the same painter in both paths, with no async
/// image decode, so any colour difference at a sampled point is a composition
/// bug and not a decode race or a filtering artefact.
void main() {
  // The canvas is deliberately small so sample coordinates are readable.
  const side = 240;
  const canvas = Size(240, 240);

  // 2 columns, 20px frame, 20px gap:
  //   cell c0 = x 20..110, cell c1 = x 130..220, gap = x 110..130.
  GridSpec twoColumns({Color border = const Color(0xFFFFFFFF)}) => GridSpec(
    root: GridSplit(
      GridAxis.columns,
      [1, 1],
      const [GridLeaf('a'), GridLeaf('b')],
    ).withCanonicalIds(),
    borderColor: border,
    borderWidth: 20,
    outerMargin: 20,
  );

  /// A tail-less bubble - a solid rounded box - centred on [position].
  BubbleLayer probe(
    String id,
    Color color,
    Offset position, {
    String? cellId,
    double scale = 1,
  }) => BubbleLayer(
    id: id,
    name: id,
    shape: BubbleShape.caption,
    fillColor: color,
    strokeColor: color,
    cellId: cellId,
    transform: LayerTransform(position: position, scale: scale),
  );

  const red = Color(0xFFFF0000);
  const blue = Color(0xFF0000FF);
  const green = Color(0xFF00FF00);
  const white = Color(0xFFFFFFFF);

  /// Both bubbles are scaled to overflow their cell, so a missing clip shows up
  /// as the wrong colour in the neighbour cell or in the gap.
  Frame collageFrame() => Frame(
    id: 'f0',
    layers: [
      probe('l0', red, const Offset(65, 120), cellId: 'c0', scale: 1.6),
      probe('l1', blue, const Offset(175, 120), cellId: 'c1'),
      // No cell: rides above the whole collage, unclipped - it is the only
      // thing that may paint over the border gap.
      probe('l2', green, const Offset(120, 200), scale: 0.5),
    ],
  );

  /// The rendered pixel at ([x], [y]).
  Color pixelAt(ByteData data, int x, int y) {
    final i = (y * side + x) * 4;
    return Color.fromARGB(
      data.getUint8(i + 3),
      data.getUint8(i),
      data.getUint8(i + 1),
      data.getUint8(i + 2),
    );
  }

  Future<ByteData> rasterizeExport(Frame frame, GridSpec? grid) async {
    final image = await ProjectRenderer.renderImageSized(
      frame,
      canvasWidth: side,
      canvasHeight: side,
      outputWidth: side,
      grid: grid,
    );
    try {
      return (await image.toByteData())!;
    } finally {
      image.dispose();
    }
  }

  Future<ByteData> rasterizeCanvas(
    WidgetTester tester,
    Frame frame,
    GridSpec? grid,
  ) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            key: key,
            child: SizedBox(
              width: canvas.width,
              height: canvas.height,
              child: ProjectCanvas(
                frame: frame,
                width: side,
                height: side,
                grid: grid,
              ),
            ),
          ),
        ),
      ),
    );
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    try {
      return (await image.toByteData())!;
    } finally {
      image.dispose();
    }
  }

  /// Sampled points that pin down the whole composition contract.
  const samples = <String, Offset>{
    'cell c0 centre': Offset(65, 120),
    'cell c1 centre': Offset(175, 120),
    'gap between the cells': Offset(120, 60),
    'outer frame': Offset(4, 4),
    'free layer over the gap': Offset(120, 200),
  };

  void expectColor(ByteData data, Offset at, Color want, String reason) {
    final got = pixelAt(data, at.dx.round(), at.dy.round());
    expect(
      [got.a, got.r, got.g, got.b],
      [
        closeTo(want.a, 0.01),
        closeTo(want.r, 0.01),
        closeTo(want.g, 0.01),
        closeTo(want.b, 0.01),
      ],
      reason: reason,
    );
  }

  testWidgets('a collage composes identically on canvas and in export', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final frame = collageFrame();
      final grid = twoColumns();
      final export = await rasterizeExport(frame, grid);
      final preview = await rasterizeCanvas(tester, frame, grid);

      for (final entry in samples.entries) {
        final x = entry.value.dx.round();
        final y = entry.value.dy.round();
        final a = pixelAt(export, x, y);
        final b = pixelAt(preview, x, y);
        expect(
          [b.a, b.r, b.g, b.b],
          [
            closeTo(a.a, 0.01),
            closeTo(a.r, 0.01),
            closeTo(a.g, 0.01),
            closeTo(a.b, 0.01),
          ],
          reason: 'canvas and export disagree at ${entry.key}',
        );
      }
    });
  });

  testWidgets('cells clip, the border fills, and free layers ride on top', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final frame = collageFrame();
      final grid = twoColumns();
      final export = await rasterizeExport(frame, grid);
      final preview = await rasterizeCanvas(tester, frame, grid);

      for (final data in [export, preview]) {
        expectColor(
          data,
          samples['cell c0 centre']!,
          red,
          'c0 holds its photo',
        );
        // Blue survives even though the red probe is scaled to overflow c0.
        expectColor(
          data,
          samples['cell c1 centre']!,
          blue,
          'c1 is not painted over by its neighbour spilling out of c0',
        );
        expectColor(
          data,
          samples['gap between the cells']!,
          white,
          'the gap shows the border colour, not a bubble that overflowed',
        );
        expectColor(
          data,
          samples['outer frame']!,
          white,
          'the outer margin shows the border colour',
        );
        expectColor(
          data,
          samples['free layer over the gap']!,
          green,
          'a free layer draws above the grid, unclipped',
        );
      }
    });
  });

  testWidgets('a transparent border leaves real transparency in the gaps', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final frame = collageFrame();
      final grid = twoColumns(border: const Color(0x00000000));
      final export = await rasterizeExport(frame, grid);
      final preview = await rasterizeCanvas(tester, frame, grid);

      for (final data in [export, preview]) {
        expect(
          pixelAt(data, 120, 60).a,
          0,
          reason: 'no fill is painted for a fully transparent border',
        );
        expect(pixelAt(data, 4, 4).a, 0);
        // Cells still hold their content.
        expectColor(data, samples['cell c0 centre']!, red, 'c0 still paints');
      }
    });
  });

  testWidgets('an ordinary project renders identically in both paths', (
    tester,
  ) async {
    await tester.runAsync(() async {
      // Guards the non-grid path through the same refactor: no grid means no
      // fill, no clip, plain z-order.
      final frame = Frame(
        id: 'f0',
        layers: [probe('l0', red, const Offset(120, 120))],
      );
      final export = await rasterizeExport(frame, null);
      final preview = await rasterizeCanvas(tester, frame, null);

      expectColor(export, const Offset(120, 120), red, 'export paints it');
      expectColor(preview, const Offset(120, 120), red, 'canvas paints it');
      // Nothing else is painted - the canvas stays transparent.
      expect(pixelAt(export, 4, 4).a, 0);
      expect(pixelAt(preview, 4, 4).a, 0);
    });
  });
}
