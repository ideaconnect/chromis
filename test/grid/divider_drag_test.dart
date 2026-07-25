import 'package:chromis/core/models/grid.dart';
import 'package:chromis/core/models/project.dart';
import 'package:chromis/features/editor/state/editor_controller.dart';
import 'package:chromis/features/editor/state/editor_tool.dart';
import 'package:chromis/features/editor/widgets/editor_canvas.dart';
import 'package:chromis/features/grid/grid_templates.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dragging a Photo Grid divider on the canvas: the gesture grabs the divider
/// ahead of any layer, moves only the two cells it separates, and is inert in
/// the tools where a canvas gesture means "paint" instead of "manipulate".
void main() {
  // The canvas widget is given exactly the canvas aspect by its parent, so a
  // 400-px box over a 400-logical canvas puts logical units at 1:1 with pixels
  // and drag distances read directly.
  const side = 400.0;
  const canvas = Size(side, side);

  Project collage(int count) => Project.empty(
    id: 'p',
    width: side.toInt(),
    height: side.toInt(),
  ).copyWith(grid: GridSpec(root: gridTemplatesFor(count).first.root));

  Future<ProviderContainer> pump(
    WidgetTester tester,
    Project project, {
    EditorTool tool = EditorTool.grid,
  }) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(editorControllerProvider.notifier);
    controller.loadProject(project);
    controller.setTool(tool);

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
                  dropPlaceholder: const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return container;
  }

  Map<String, Rect> cellsOf(ProviderContainer c) =>
      layoutGrid(c.read(editorControllerProvider).project.grid!, canvas).cells;

  GridDivider dividerOf(ProviderContainer c, [int index = 0]) => layoutGrid(
    c.read(editorControllerProvider).project.grid!,
    canvas,
  ).dividers[index];

  /// The divider band's centre in the widget's own coordinates. The canvas is
  /// centred in the test surface, so shift by its top-left.
  Offset centreOf(WidgetTester tester, GridDivider divider) {
    final topLeft = tester.getTopLeft(find.byType(EditorCanvas));
    return topLeft + divider.band.center;
  }

  testWidgets('dragging a divider resizes only the two cells it separates', (
    tester,
  ) async {
    final container = await pump(tester, collage(3));
    final before = cellsOf(container);

    await tester.dragFrom(
      centreOf(tester, dividerOf(container)),
      const Offset(40, 0),
    );
    await tester.pump();

    final after = cellsOf(container);
    expect(after['c0']!.width, greaterThan(before['c0']!.width));
    expect(after['c1']!.width, lessThan(before['c1']!.width));
    expect(after['c2'], before['c2']);
  });

  testWidgets('a vertical drag moves a horizontal divider', (tester) async {
    // "Big left": a column divider, then a row divider inside the right column.
    final container = await pump(tester, collage(3));
    container
        .read(editorControllerProvider.notifier)
        .setGridTemplate(gridTemplatesFor(3)[2].root);
    await tester.pump();

    final divider = dividerOf(container, 1);
    expect(divider.axis, GridAxis.rows);
    final before = cellsOf(container);

    await tester.dragFrom(centreOf(tester, divider), const Offset(0, 50));
    await tester.pump();

    final after = cellsOf(container);
    expect(after['c1']!.height, greaterThan(before['c1']!.height));
    expect(after['c2']!.height, lessThan(before['c2']!.height));
    expect(after['c0'], before['c0']); // the other column is unaffected
  });

  testWidgets('the whole drag is a single undo step', (tester) async {
    final container = await pump(tester, collage(2));
    final before = cellsOf(container);

    await tester.dragFrom(
      centreOf(tester, dividerOf(container)),
      const Offset(60, 0),
    );
    await tester.pump();
    expect(cellsOf(container), isNot(before));

    container.read(editorControllerProvider.notifier).undo();
    expect(cellsOf(container), before);
  });

  testWidgets('a drag away from any divider does not resize the grid', (
    tester,
  ) async {
    final container = await pump(tester, collage(2));
    final before = cellsOf(container);
    final topLeft = tester.getTopLeft(find.byType(EditorCanvas));

    // Deep inside the first cell, well clear of the divider's touch slop.
    await tester.dragFrom(topLeft + const Offset(40, 40), const Offset(50, 0));
    await tester.pump();

    expect(cellsOf(container), before);
  });

  testWidgets('dividers are inert while the Erase tool is active', (
    tester,
  ) async {
    // Erase means brush strokes; a divider must never steal one.
    final container = await pump(tester, collage(2), tool: EditorTool.erase);
    final before = cellsOf(container);

    await tester.dragFrom(
      centreOf(tester, dividerOf(container)),
      const Offset(60, 0),
    );
    await tester.pump();

    expect(cellsOf(container), before);
    expect(
      find.byKey(ValueKey('grid-${dividerOf(container).key}')),
      findsNothing,
    );
  });

  testWidgets('a handle is drawn per divider in the manipulate tools', (
    tester,
  ) async {
    final container = await pump(tester, collage(4));
    // 2 x 2 = one column divider per row plus the row divider between them.
    final dividers = layoutGrid(
      container.read(editorControllerProvider).project.grid!,
      canvas,
    ).dividers;
    expect(dividers, hasLength(3));
    for (final divider in dividers) {
      expect(find.byKey(ValueKey('grid-${divider.key}')), findsOneWidget);
    }
  });
}
