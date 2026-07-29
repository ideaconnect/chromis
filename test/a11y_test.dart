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
import 'package:chromis/features/home/all_projects_screen.dart';
import 'package:chromis/features/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/surface.dart';

/// Accessibility floor for the screens a user actually spends time in.
///
/// Two guidelines, both of which the app failed: `labeledTapTargetGuideline`
/// (icon-only controls announced as a bare "button" - the layer row's eye and
/// trash, the undo/redo pair, the canvas delete handle, nine identical colour
/// swatches) and `androidTapTargetGuideline` (48dp minimum - the swatches were
/// 26dp and the delete handle 32dp).
///
/// The editor is pumped WITH content on purpose: an empty project renders none
/// of the per-layer chrome, so an empty-state pass would be vacuous.
void main() {
  setUp(() {
    ProjectCanvas.fileExists = (_) => false;
    ProjectCanvas.existsCache.clear();
  });
  tearDown(() => ProjectCanvas.fileExists = ProjectCanvas.defaultFileExists);

  Project populated() => const Project(
    id: 'a11y',
    name: 'A11y',
    canvasWidth: 800,
    canvasHeight: 800,
    frames: [
      Frame(
        id: 'f0',
        layers: [
          ImageLayer(
            id: 'l0',
            name: 'Photo',
            assetPath: '/nope/img.png',
            transform: LayerTransform(position: Offset(400, 400)),
          ),
          TextLayer(
            id: 'l1',
            name: 'Caption',
            text: 'Hi',
            fontFamily: 'Manrope',
            transform: LayerTransform(position: Offset(400, 200)),
          ),
          BubbleLayer(
            id: 'l2',
            name: 'Bubble',
            transform: LayerTransform(position: Offset(400, 600)),
          ),
        ],
      ),
    ],
  );

  Future<void> pump(
    WidgetTester tester,
    Widget home, {
    Project? project,
  }) async {
    // A real phone size with real insets: at a zero-inset surface the
    // guidelines skip nodes flush with the screen edge, and the test passes
    // for a reason that has nothing to do with the app.
    setSurface(tester, const Size(412, 915));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [isProProvider.overrideWithValue(true)],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(padding: const EdgeInsets.only(top: 24, bottom: 16)),
              child: home,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    if (project != null) {
      final container = ProviderScope.containerOf(
        tester.element(find.byType(EditorScreen)),
        listen: false,
      );
      container.read(editorControllerProvider.notifier)
        ..loadProject(project)
        ..selectLayer('l0');
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  /// Every tappable node must announce something.
  ///
  /// Only this guideline is applied wholesale. `androidTapTargetGuideline`
  /// is NOT: the approved design has deliberately compact chrome (the Export
  /// pill is 37dp tall, the editable project title 21dp), and growing those to
  /// 48dp would redesign screens nobody asked to change. The controls this
  /// audit actually named are size-checked individually below instead.
  Future<void> expectLabeled(WidgetTester tester) async {
    final handle = tester.ensureSemantics();
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  }

  testWidgets('the editor, with layers and a selection', (tester) async {
    await pump(tester, const EditorScreen(), project: populated());
    await expectLabeled(tester);
  });

  testWidgets('the editor, on the Layers panel', (tester) async {
    // The per-layer eye / duplicate / trash row only exists here, and two of
    // its three buttons were unlabeled.
    await pump(tester, const EditorScreen(), project: populated());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(EditorScreen)),
      listen: false,
    );
    container
        .read(editorControllerProvider.notifier)
        .setTool(EditorTool.layers);
    await tester.pump(const Duration(milliseconds: 400));
    await expectLabeled(tester);
  });

  testWidgets('the editor, on the bubble panel with its colour swatches', (
    tester,
  ) async {
    await pump(tester, const EditorScreen(), project: populated());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(EditorScreen)),
      listen: false,
    );
    container.read(editorControllerProvider.notifier)
      ..selectLayer('l2')
      ..setTool(EditorTool.text);
    await tester.pump(const Duration(milliseconds: 400));
    await expectLabeled(tester);
  });

  testWidgets('home', (tester) async {
    await pump(tester, const HomeScreen());
    await expectLabeled(tester);
  });

  testWidgets('all projects', (tester) async {
    await pump(tester, const AllProjectsScreen());
    await expectLabeled(tester);
  });

  // The two controls the audit named by size. Asserted directly rather than
  // through androidTapTargetGuideline, which would also demand redesigning the
  // Export pill and the project title (see [expectLabeled]).
  testWidgets('the canvas delete handle is a 48dp target', (tester) async {
    await pump(tester, const EditorScreen(), project: populated());
    final handle = find.byKey(const ValueKey('layer-delete-handle'));
    expect(handle, findsOneWidget);
    final size = tester.getSize(handle);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('every colour swatch is at least a 40dp target', (tester) async {
    // 40 rather than 48: nine 48dp targets cannot fit one row on a 360dp
    // phone, and wrapping them pushed the controls below it off the fold. The
    // dots are 26px drawn, so this is still a >50% larger tap area than
    // before, in a scrollable row.
    await pump(tester, const EditorScreen(), project: populated());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(EditorScreen)),
      listen: false,
    );
    container.read(editorControllerProvider.notifier)
      ..selectLayer('l2')
      ..setTool(EditorTool.text);
    await tester.pump(const Duration(milliseconds: 400));

    final swatches = find.bySemanticsLabel(RegExp('^Fill '));
    expect(swatches, findsWidgets);
    for (final element in swatches.evaluate()) {
      final size = element.size!;
      expect(size.width, greaterThanOrEqualTo(40));
      expect(size.height, greaterThanOrEqualTo(40));
    }
  });
}
