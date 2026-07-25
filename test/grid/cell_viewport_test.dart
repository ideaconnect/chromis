import 'package:chromis/core/models/grid.dart';
import 'package:chromis/core/models/layer.dart';
import 'package:chromis/core/models/layer_transform.dart';
import 'package:chromis/core/models/project.dart';
import 'package:chromis/core/rendering/canvas_geometry.dart';
import 'package:chromis/features/editor/state/editor_controller.dart';
import 'package:chromis/features/editor/state/editor_tool.dart';
import 'package:chromis/features/editor/widgets/editor_canvas.dart';
import 'package:chromis/features/editor/widgets/project_canvas.dart';
import 'package:chromis/features/grid/grid_templates.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Each Photo Grid cell behaving as its own viewport: an empty one invites a
/// photo, a filled one answers taps only where it is actually visible, a photo
/// cannot be panned out of its cell, and dropping one over a neighbour swaps
/// them.
void main() {
  const side = 400.0;
  const canvas = Size(side, side);

  setUp(() {
    // Layers reference image files that do not exist in tests; stub the probe
    // so ProjectCanvas renders its placeholder instead of stat-ing the disk.
    ProjectCanvas.fileExists = (_) => false;
    ProjectCanvas.existsCache.clear();
  });
  tearDown(() => ProjectCanvas.fileExists = ProjectCanvas.defaultFileExists);

  Project collage(int count) => Project.empty(
    id: 'p',
    width: side.toInt(),
    height: side.toInt(),
  ).copyWith(grid: GridSpec(root: gridTemplatesFor(count).first.root));

  Map<String, Rect> cellsOf(GridSpec grid) => layoutGrid(grid, canvas).cells;

  Future<({ProviderContainer container, List<String> tapped})> pump(
    WidgetTester tester,
    Project project, {
    EditorTool tool = EditorTool.grid,
  }) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(editorControllerProvider.notifier);
    controller.loadProject(project);
    controller.setTool(tool);
    final tapped = <String>[];

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: side,
                height: side,
                child: EditorCanvas(
                  onEmptyTap: () {},
                  onEmptyCellTap: tapped.add,
                  dropPlaceholder: const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return (container: container, tapped: tapped);
  }

  Offset at(WidgetTester tester, Offset logical) =>
      tester.getTopLeft(find.byType(EditorCanvas)) + logical;

  testWidgets('tapping an empty cell asks for a photo for THAT cell', (
    tester,
  ) async {
    final project = collage(2);
    final (:container, :tapped) = await pump(tester, project);
    final cells = cellsOf(project.grid!);

    await tester.tapAt(at(tester, cells['c1']!.center));
    await tester.pump();
    expect(tapped, ['c1']);

    await tester.tapAt(at(tester, cells['c0']!.center));
    await tester.pump();
    expect(tapped, ['c1', 'c0']);
  });

  testWidgets('a filled cell selects its photo instead', (tester) async {
    final project = collage(2);
    final cells = cellsOf(project.grid!);
    final photo = ImageLayer(
      id: 'l0',
      name: 'Photo',
      assetPath: '/fake/a.png',
      cellId: 'c0',
      transform: LayerTransform(position: cells['c0']!.center),
    );
    final (:container, :tapped) = await pump(
      tester,
      project.copyWith(
        frames: [
          project.frames.single.copyWith(layers: [photo]),
        ],
      ),
    );

    await tester.tapAt(at(tester, cells['c0']!.center));
    await tester.pump();
    expect(tapped, isEmpty);
    expect(container.read(editorControllerProvider).selectedLayerId, 'l0');
  });

  testWidgets('a photo overflowing its cell does not answer taps outside it', (
    tester,
  ) async {
    // The whole point of the cell clip: c0's photo is cover-scaled and spills
    // over c1, but c1 must still be tappable as an empty cell.
    final project = collage(2);
    final cells = cellsOf(project.grid!);
    final photo = ImageLayer(
      id: 'l0',
      name: 'Photo',
      assetPath: '/fake/a.png',
      cellId: 'c0',
      transform: LayerTransform(position: cells['c0']!.center, scale: 3),
    );
    final (:container, :tapped) = await pump(
      tester,
      project.copyWith(
        frames: [
          project.frames.single.copyWith(layers: [photo]),
        ],
      ),
    );

    await tester.tapAt(at(tester, cells['c1']!.center));
    await tester.pump();
    expect(tapped, ['c1']);
    expect(container.read(editorControllerProvider).selectedLayerId, isNull);
  });

  testWidgets('a photo cannot be panned out of its cell', (tester) async {
    final project = collage(2);
    final cells = cellsOf(project.grid!);
    final cell = cells['c0']!;
    // Cover-scaled for the cell, so there IS some slack to pan within.
    final scale = photoCoverScale(
      const Size(1000, 1000),
      cell.width,
      cell.height,
    );
    final photo = ImageLayer(
      id: 'l0',
      name: 'Photo',
      assetPath: '/fake/a.png',
      cellId: 'c0',
      transform: LayerTransform(position: cell.center, scale: scale),
    );
    final (:container, :tapped) = await pump(
      tester,
      project.copyWith(
        frames: [
          project.frames.single.copyWith(layers: [photo]),
        ],
      ),
      tool: EditorTool.adjust,
    );
    container.read(editorControllerProvider.notifier).selectLayer('l0');
    await tester.pump();

    // Yank it far past the cell edge.
    await tester.dragFrom(at(tester, cell.center), const Offset(500, 500));
    await tester.pump();

    final moved = container
        .read(editorControllerProvider)
        .layers
        .single
        .transform;
    // The drag really did move it (otherwise the cover assertions below would
    // pass trivially on the untouched, centred photo).
    expect(moved.position.dx, greaterThan(cell.center.dx));
    // Whatever the drag asked for, the photo still covers its cell.
    final half = Offset(
      kLayerFitBoxSide * moved.scale / 2,
      kLayerFitBoxSide * moved.scale / 2,
    );
    expect(moved.position.dx - half.dx, lessThanOrEqualTo(cell.left + 0.01));
    expect(
      moved.position.dx + half.dx,
      greaterThanOrEqualTo(cell.right - 0.01),
    );
    expect(moved.position.dy - half.dy, lessThanOrEqualTo(cell.top + 0.01));
    expect(
      moved.position.dy + half.dy,
      greaterThanOrEqualTo(cell.bottom - 0.01),
    );
  });

  group('moveLayerToCell', () {
    ({ProviderContainer container, EditorController controller}) open(
      Project project,
    ) {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(editorControllerProvider.notifier);
      controller.loadProject(project);
      return (container: container, controller: controller);
    }

    test('swaps the two cells contents in one undo step', () {
      final project = collage(3);
      final (:container, :controller) = open(project);
      controller.addPhotoToCell(assetPath: '/a.png', cellId: 'c0');
      controller.addPhotoToCell(assetPath: '/b.png', cellId: 'c2');
      final ids = container
          .read(editorControllerProvider)
          .layers
          .map((l) => l.id)
          .toList();

      controller.moveLayerToCell(ids.first, 'c2');

      final after = container.read(editorControllerProvider).layers;
      expect(after[0].cellId, 'c2');
      expect(after[1].cellId, 'c0'); // the displaced photo took its place
      controller.undo();
      expect(
        container.read(editorControllerProvider).layers.map((l) => l.cellId),
        ['c0', 'c2'],
      );
    });

    test('moving into an empty cell just relocates the photo', () {
      final project = collage(3);
      final (:container, :controller) = open(project);
      final photo = controller.addPhotoToCell(
        assetPath: '/a.png',
        cellId: 'c0',
      )!;

      controller.moveLayerToCell(photo.id, 'c1');

      final moved = container.read(editorControllerProvider).layers.single;
      expect(moved.cellId, 'c1');
      // Re-centred on its new cell: a drop reads as "put this photo here".
      expect(moved.transform.position, cellsOf(project.grid!)['c1']!.center);
    });

    test('is inert for a free layer, an unknown cell, or the same cell', () {
      final project = collage(2);
      final (:container, :controller) = open(project);
      final photo = controller.addPhotoToCell(
        assetPath: '/a.png',
        cellId: 'c0',
      )!;
      final free = controller.addTextLayer();
      final before = container.read(editorControllerProvider).project;

      controller
        ..moveLayerToCell(free.id, 'c1')
        ..moveLayerToCell(photo.id, 'c0')
        ..moveLayerToCell(photo.id, 'c9')
        ..moveLayerToCell('nope', 'c1');

      expect(container.read(editorControllerProvider).project, same(before));
    });
  });
}
