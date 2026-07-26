import 'package:chromis/core/models/project.dart';
import 'package:chromis/core/theme/app_theme.dart';
import 'package:chromis/features/editor/editor_screen.dart';
import 'package:chromis/features/editor/state/editor_controller.dart';
import 'package:chromis/features/editor/state/editor_tool.dart';
import 'package:chromis/features/editor/widgets/editor_canvas.dart';
import 'package:chromis/features/editor/widgets/project_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/surface.dart';

/// The editor's landscape layout: the dock becomes a rail down the left edge,
/// the tool panel a column beside it that folds away on demand, and whatever is
/// left over goes to the canvas - which is the reason to turn the phone in the
/// first place.
void main() {
  setUp(() {
    ProjectCanvas.fileExists = (_) => false;
    ProjectCanvas.existsCache.clear();
  });
  tearDown(() => ProjectCanvas.fileExists = ProjectCanvas.defaultFileExists);

  const portrait = Size(420, 900);
  const landscape = Size(900, 600);

  Finder dock(String label) => find.byKey(ValueKey('dock-$label'));

  /// Taps a rail button, scrolling it into view first. The rail is a scroll
  /// view and does not fit every button on a 600-px-tall phone, so a bare tap
  /// silently misses whichever ones are below the fold. The extra pump matters:
  /// ensureVisible moves the offset, layout catches up on the next frame.
  Future<void> tapDock(WidgetTester tester, String label) async {
    await tester.ensureVisible(dock(label));
    await tester.pump();
    await tester.tap(dock(label));
    await tester.pumpAndSettle();
  }

  final collapse = find.byKey(const ValueKey('collapse-panel'));
  final expand = find.byKey(const ValueKey('expand-panel'));

  Future<ProviderContainer> pump(
    WidgetTester tester,
    Size size, {
    Size project = const Size(1080, 1080),
  }) async {
    setSurface(tester, size);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(editorControllerProvider.notifier)
        .loadProject(
          Project.empty(
            id: 'p',
            width: project.width.toInt(),
            height: project.height.toInt(),
          ),
        );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: buildAppTheme(), home: const EditorScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('the dock stacks vertically down the left edge', (tester) async {
    await pump(tester, landscape);

    // Every dock entry is still reachable...
    for (final label in const ['Adjust', 'Effects', 'Layers', 'Text']) {
      expect(dock(label), findsOneWidget, reason: '$label is missing');
    }
    // ...and they are stacked, not in a row: same x, different heights.
    final adjust = tester.getTopLeft(dock('Adjust'));
    final layers = tester.getTopLeft(dock('Layers'));
    expect(adjust.dx, closeTo(layers.dx, 0.5));
    expect(adjust.dy, isNot(closeTo(layers.dy, 1)));
    // The rail hugs the left edge.
    expect(adjust.dx, lessThan(80));
  });

  testWidgets('portrait keeps the horizontal dock and no fold control', (
    tester,
  ) async {
    await pump(tester, portrait);
    final adjust = tester.getTopLeft(dock('Adjust'));
    final layers = tester.getTopLeft(dock('Layers'));
    expect(adjust.dy, closeTo(layers.dy, 0.5));
    expect(adjust.dx, isNot(closeTo(layers.dx, 1)));
    expect(collapse, findsNothing);
    expect(expand, findsNothing);
  });

  testWidgets('folding the panel away hands its space to the canvas', (
    tester,
  ) async {
    // A landscape project, so the canvas is bounded by the width the panel is
    // competing for - on a square one the height binds first and folding the
    // panel would only re-centre it.
    await pump(tester, landscape, project: const Size(1920, 1080));
    expect(collapse, findsOneWidget);
    final before = tester.getSize(find.byType(EditorCanvas));
    final leftBefore = tester.getTopLeft(find.byType(EditorCanvas)).dx;

    await tester.tap(collapse);
    await tester.pumpAndSettle();

    expect(collapse, findsNothing);
    expect(expand, findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(EditorCanvas)).dx,
      lessThan(leftBefore),
      reason: 'the canvas moves into the space the panel gave up',
    );
    expect(
      tester.getSize(find.byType(EditorCanvas)).width,
      greaterThan(before.width),
      reason: 'and gets bigger, which is the point of folding it away',
    );

    await tester.tap(expand);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(EditorCanvas)).width, before.width);
  });

  testWidgets(
    'tapping the active tool folds the panel, tapping again reopens',
    (tester) async {
      final container = await pump(tester, landscape);
      container
          .read(editorControllerProvider.notifier)
          .setTool(EditorTool.adjust);
      await tester.pumpAndSettle();

      await tapDock(tester, 'Adjust');
      expect(expand, findsOneWidget);

      await tapDock(tester, 'Adjust');
      expect(collapse, findsOneWidget);
      expect(container.read(editorControllerProvider).tool, EditorTool.adjust);
    },
  );

  testWidgets('switching tools while folded reopens the panel', (tester) async {
    final container = await pump(tester, landscape);
    await tester.tap(collapse);
    await tester.pumpAndSettle();

    // The rail scrolls when the window is short, so bring the entry into view
    // the way a user would before tapping it.
    await tester.ensureVisible(dock('Layers'));
    await tester.pumpAndSettle();
    await tapDock(tester, 'Layers');

    expect(
      collapse,
      findsOneWidget,
      reason: 'picking a different tool is a request to see it',
    );
    expect(container.read(editorControllerProvider).tool, EditorTool.layers);
  });

  testWidgets('the landscape canvas is not capped at the portrait width', (
    tester,
  ) async {
    // Portrait caps the canvas at 460 logical px; landscape must not, or
    // turning the phone would gain nothing.
    await pump(tester, const Size(1400, 800), project: const Size(1920, 1080));
    await tester.tap(collapse);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(EditorCanvas)).width, greaterThan(460));
  });
}
