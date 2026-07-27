import 'package:chromis/core/models/frame.dart';
import 'package:chromis/core/models/layer.dart';
import 'package:chromis/core/models/layer_transform.dart';
import 'package:chromis/core/models/project.dart';
import 'package:chromis/core/theme/app_theme.dart';
import 'package:chromis/features/editor/editor_screen.dart';
import 'package:chromis/features/editor/state/editor_controller.dart';
import 'package:chromis/features/editor/state/editor_tool.dart';
import 'package:chromis/features/editor/widgets/project_canvas.dart';
import 'package:chromis/features/go_pro/iap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/surface.dart';

/// The Layers panel reads TOP-DOWN, and `Project.layers` reads bottom-up.
///
/// `layers` is paint order - index 0 is painted first, so the last entry is the
/// one on top of the canvas. The panel listed it in that raw order, which put the
/// bottom-most layer at the top of the list and meant dragging a row upwards
/// pushed it *behind* everything. These tests pin both halves of the fix: the
/// order the rows appear in, and that a drag lands the layer where the panel says
/// it will. Positions are asserted rather than mere presence - "which end is on
/// top" is the whole bug, and a presence check cannot see it.
void main() {
  setUp(() {
    ProjectCanvas.fileExists = (_) => false;
    ProjectCanvas.existsCache.clear();
  });
  tearDown(() => ProjectCanvas.fileExists = ProjectCanvas.defaultFileExists);

  TextLayer txt(String id) => TextLayer(
    id: id,
    name: id,
    text: id,
    fontFamily: 'Bangers',
    transform: const LayerTransform(position: Offset(540, 540)),
  );

  /// `l_0` is painted first (bottom of the stack), `l_2` last (on top).
  Project seed() => Project(
    id: 'p',
    name: 'Untitled',
    canvasWidth: 1080,
    canvasHeight: 1080,
    frames: [
      Frame(id: 'p_f0', layers: [txt('l_0'), txt('l_1'), txt('l_2')]),
    ],
    createdAt: DateTime(2024),
  );

  Future<ProviderContainer> pumpLayersPanel(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [isProProvider.overrideWithValue(true)],
    );
    addTearDown(container.dispose);
    container.read(editorControllerProvider.notifier)
      ..loadProject(seed())
      // Straight to the tool rather than through the dock: on a 412-wide phone
      // the dock scrolls and the Layers button sits off-screen, which is the
      // dock's business and not what these tests are about.
      ..setTool(EditorTool.layers);

    setSurface(tester, const Size(412, 915));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: buildAppTheme(), home: const EditorScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      container.read(editorControllerProvider).tool,
      EditorTool.layers,
      reason: 'the Layers panel has to actually be the visible one',
    );
    return container;
  }

  Finder row(String id) => find.byKey(ValueKey(id));

  /// The grip is the ONLY place a drag may start: the row's long press is
  /// rename, and letting the list wrap the whole row in its default delayed
  /// listener put the two in one arena, where rename won and reordering became
  /// impossible on a device.
  Finder grips() => find.byType(ReorderableDragStartListener);

  List<String> modelOrder(ProviderContainer c) =>
      c.read(editorControllerProvider).layers.map((l) => l.id).toList();

  testWidgets('the panel lists the top-most layer first', (tester) async {
    final container = await pumpLayersPanel(tester);
    expect(modelOrder(container), ['l_0', 'l_1', 'l_2']);

    for (final id in ['l_0', 'l_1', 'l_2']) {
      expect(row(id), findsOneWidget, reason: '$id should have a row');
    }
    // l_2 is on top of the canvas, so it must be the first row on screen.
    final y = {
      for (final id in ['l_0', 'l_1', 'l_2']) id: tester.getCenter(row(id)).dy,
    };
    expect(
      y['l_2'],
      lessThan(y['l_1']!),
      reason: 'l_2 is painted above l_1, so its row belongs higher up',
    );
    expect(
      y['l_1'],
      lessThan(y['l_0']!),
      reason: 'l_1 is painted above l_0, so its row belongs higher up',
    );
  });

  testWidgets('every row carries its own drag grip', (tester) async {
    await pumpLayersPanel(tester);
    expect(
      grips(),
      findsNWidgets(3),
      reason:
          'one immediate drag listener per row, or reordering is '
          'unreachable behind the long-press-to-rename',
    );
    final list = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    expect(
      list.buildDefaultDragHandles,
      isFalse,
      reason:
          'the default handles are the delayed listeners that lose the '
          'arena to rename',
    );
  });

  /// Fires the reorder the way the list itself would when a drag is dropped.
  ///
  /// Driving the callback rather than synthesizing a long-press-and-drag: the
  /// gesture belongs to Flutter (a `ReorderableDelayedDragStartListener` racing
  /// the enclosing `SingleChildScrollView`) and reproducing it here tests the
  /// framework, not this app. What is ours is the panel-row -> paint-order
  /// conversion on the way in, and these indices are exactly what
  /// `onReorderItem` hands over: `newIndex` already accounts for the dragged row
  /// having been lifted out.
  void dropRow(WidgetTester tester, {required int from, required int to}) {
    final list = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    list.onReorderItem!(from, to);
  }

  testWidgets('dropping the top row at the bottom sends it behind everything', (
    tester,
  ) async {
    final container = await pumpLayersPanel(tester);
    dropRow(tester, from: 0, to: 2); // l_2's row, dragged to the last slot
    await tester.pump();

    expect(
      modelOrder(container),
      ['l_2', 'l_0', 'l_1'],
      reason:
          'the bottom of the panel is painted first, so l_2 belongs at '
          'index 0 - not at the end, which is what the un-flipped indices did',
    );
    // ...and the panel still agrees with the model it just produced.
    expect(
      tester.getCenter(row('l_2')).dy,
      greaterThan(tester.getCenter(row('l_0')).dy),
      reason: 'l_2 is now the bottom layer, so its row must be the lowest',
    );
  });

  testWidgets('dropping the bottom row at the top brings it in front', (
    tester,
  ) async {
    final container = await pumpLayersPanel(tester);
    dropRow(tester, from: 2, to: 0); // l_0's row, dragged to the first slot
    await tester.pump();

    expect(
      modelOrder(container),
      ['l_1', 'l_2', 'l_0'],
      reason: 'l_0 dropped at the top of the panel is painted last',
    );
    expect(
      tester.getCenter(row('l_0')).dy,
      lessThan(tester.getCenter(row('l_2')).dy),
    );
  });
}
