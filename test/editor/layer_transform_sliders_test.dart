import 'dart:math' as math;

import 'package:chromis/core/models/frame.dart';
import 'package:chromis/core/models/grid.dart';
import 'package:chromis/core/models/layer.dart';
import 'package:chromis/core/models/layer_transform.dart';
import 'package:chromis/core/models/project.dart';
import 'package:chromis/core/theme/app_theme.dart';
import 'package:chromis/core/widgets/labeled_slider.dart';
import 'package:chromis/features/editor/editor_screen.dart';
import 'package:chromis/features/editor/state/editor_controller.dart';
import 'package:chromis/features/editor/state/editor_tool.dart';
import 'package:chromis/features/editor/widgets/project_canvas.dart';
import 'package:chromis/features/go_pro/iap.dart';
import 'package:chromis/features/grid/grid_templates.dart';
import 'package:chromis/features/home/project_repository.dart';
import 'package:chromis/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/surface.dart';

/// The Adjust panel's Scale and Rotation sliders.
///
/// A caption or a bubble created small - or pinched down by accident - is the
/// one thing a finger cannot get back: the hit box IS the layer, so past a
/// certain size there is nothing left to grab. The panel is the way back, which
/// is only true if it works for a layer that is NOT a photo: Adjust used to
/// answer anything but an ImageLayer with an empty hint.
void main() {
  setUp(() {
    // Layers reference files that do not exist here; stub the probe so
    // ProjectCanvas paints its placeholder instead of stat-ing the disk.
    ProjectCanvas.fileExists = (_) => false;
    ProjectCanvas.existsCache.clear();
  });
  tearDown(() => ProjectCanvas.fileExists = ProjectCanvas.defaultFileExists);

  Future<ProviderContainer> pumpEditor(
    WidgetTester tester,
    Project project, {
    String? select,
    Size surface = const Size(412, 915),
  }) async {
    setSurface(tester, surface);
    final container = ProviderContainer(
      overrides: [
        isProProvider.overrideWithValue(true),
        projectRepositoryProvider.overrideWithValue(_RecordingRepo()),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(editorControllerProvider.notifier);
    controller.loadProject(project);
    if (select != null) controller.selectLayer(select);
    controller.setTool(EditorTool.adjust);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: darkAppTheme,
          home: const EditorScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return container;
  }

  Finder sliderFor(String label) => find.descendant(
    of: find.ancestor(
      of: find.text(label),
      matching: find.byType(LabeledSlider),
    ),
    matching: find.byType(Slider),
  );

  Layer layerOf(ProviderContainer c) =>
      c.read(editorControllerProvider).selectedLayer!;

  Project withLayers(List<Layer> layers, {GridSpec? grid}) =>
      Project.empty(id: 'p').copyWith(
        grid: grid,
        frames: [Frame(id: 'p_f0', layers: layers)],
      );

  TextLayer caption({double scale = 1, double rotation = 0}) => TextLayer(
    id: 'txt',
    name: 'Text',
    text: 'Hello',
    fontFamily: 'Manrope',
    transform: LayerTransform(scale: scale, rotation: rotation),
  );

  BubbleLayer bubble({double scale = 1}) => BubbleLayer(
    id: 'bub',
    name: 'Bubble',
    text: 'Hi',
    transform: LayerTransform(scale: scale),
  );

  ImageLayer photo({String? cellId, LayerTransform? transform}) => ImageLayer(
    id: 'img',
    name: 'Photo',
    assetPath: '/fake/photo.png',
    cellId: cellId,
    transform: transform ?? const LayerTransform(),
  );

  testWidgets('a text layer gets Scale and Rotation, not the empty hint', (
    tester,
  ) async {
    await pumpEditor(tester, withLayers([caption()]), select: 'txt');

    expect(sliderFor('Scale'), findsOneWidget);
    expect(sliderFor('Rotation'), findsOneWidget);
    expect(sliderFor('Opacity'), findsOneWidget);
    // The pixel half of Adjust stays a photo's own.
    expect(find.text('Brightness'), findsNothing);
    expect(find.text('Crop photo'), findsNothing);
    expect(
      find.textContaining('Select a layer'),
      findsNothing,
      reason: 'a selected layer is not the empty state',
    );
  });

  testWidgets('a bubble layer gets them too', (tester) async {
    await pumpEditor(tester, withLayers([bubble()]), select: 'bub');
    expect(sliderFor('Scale'), findsOneWidget);
    expect(sliderFor('Rotation'), findsOneWidget);
  });

  testWidgets('nothing selected still shows the empty hint', (tester) async {
    await pumpEditor(tester, withLayers([caption()]));
    expect(sliderFor('Scale'), findsNothing);
    expect(find.textContaining('Select a layer'), findsOneWidget);
  });

  testWidgets('the Scale slider rescues a layer too small to touch', (
    tester,
  ) async {
    // 6% of its own size: on a 412dp canvas this caption is a couple of pixels
    // across, which is the state the sliders exist for.
    final container = await pumpEditor(
      tester,
      withLayers([caption(scale: 0.06)]),
      select: 'txt',
    );
    expect(layerOf(container).transform.scale, 0.06);

    // Well past the right end - the value saturates, so the assertion does not
    // depend on the track's exact geometry.
    await tester.drag(sliderFor('Scale'), const Offset(2000, 0));
    await tester.pump();
    expect(
      layerOf(container).transform.scale,
      6.0,
      reason: 'the slider tops out at the pinch gesture\'s own clamp',
    );

    await tester.drag(sliderFor('Scale'), const Offset(-2000, 0));
    await tester.pump();
    expect(layerOf(container).transform.scale, 0.2, reason: 'and bottoms out');
  });

  testWidgets('the Rotation slider turns the layer both ways', (tester) async {
    final container = await pumpEditor(
      tester,
      withLayers([caption()]),
      select: 'txt',
    );

    await tester.drag(sliderFor('Rotation'), const Offset(2000, 0));
    await tester.pump();
    expect(layerOf(container).transform.rotation, closeTo(math.pi, 0.001));

    await tester.drag(sliderFor('Rotation'), const Offset(-2000, 0));
    await tester.pump();
    expect(layerOf(container).transform.rotation, closeTo(-math.pi, 0.001));
  });

  testWidgets('the Rotation slider cannot leave a layer a hair off level', (
    tester,
  ) async {
    final container = await pumpEditor(
      tester,
      withLayers([caption()]),
      select: 'txt',
    );
    final rect = tester.getRect(sliderFor('Rotation'));

    // Sweep the middle of the track a pixel at a time. Straight is the value a
    // slider is least able to hit on purpose, so it is snapped: the model must
    // come to rest either exactly level or a visible angle away, never at the
    // 0.4° that reads as a mistake.
    var sawZero = false;
    for (var dx = -14.0; dx <= 14.0; dx++) {
      await tester.tapAt(Offset(rect.center.dx + dx, rect.center.dy));
      await tester.pump();
      final degrees = layerOf(container).transform.rotation * 180 / math.pi;
      if (degrees == 0) {
        sawZero = true;
      } else {
        expect(
          degrees.abs(),
          greaterThanOrEqualTo(2),
          reason: '$dx px from centre left the layer at $degrees°',
        );
      }
    }
    expect(sawZero, isTrue, reason: 'the sweep must cross straight');
  });

  testWidgets('a rotation past a full turn shows its wrapped angle', (
    tester,
  ) async {
    // The canvas ACCUMULATES rotation across pinches, so 400° is a state the
    // model really reaches; the slider has no room for it and shows 40°.
    final container = await pumpEditor(
      tester,
      withLayers([caption(rotation: 400 * math.pi / 180)]),
      select: 'txt',
    );
    expect(find.text('40°'), findsOneWidget);
    final slider = tester.widget<Slider>(sliderFor('Rotation'));
    expect(slider.value, closeTo(40, 0.001));
    expect(
      layerOf(container).transform.rotation,
      closeTo(400 * math.pi / 180, 0.001),
      reason: 'showing the wrapped angle must not rewrite the layer',
    );
  });

  testWidgets('a free photo layer keeps the sliders and its own controls', (
    tester,
  ) async {
    await pumpEditor(tester, withLayers([photo()]), select: 'img');
    expect(sliderFor('Scale'), findsOneWidget);
    expect(sliderFor('Rotation'), findsOneWidget);
    expect(find.text('Crop photo'), findsOneWidget);
    expect(find.text('Brightness'), findsOneWidget);
    expect(find.text('Opacity'), findsOneWidget);
  });

  testWidgets('a photo filling a grid cell is placed by the cell', (
    tester,
  ) async {
    // The cell clamp (`EditorCanvas._clampToCell`) keeps a cell photo covering
    // its cell, because one shrunk aside leaves a hole in the collage. A slider
    // would be a second path to that state with none of the clamp - so the cell
    // photo keeps clamped pinch-to-zoom and no sliders. Its colour controls are
    // untouched.
    final grid = GridSpec(root: gridTemplatesFor(2).first.root);
    await pumpEditor(
      tester,
      withLayers([photo(cellId: 'c0')], grid: grid),
      select: 'img',
    );

    expect(sliderFor('Scale'), findsNothing);
    expect(sliderFor('Rotation'), findsNothing);
    expect(find.text('Brightness'), findsOneWidget);
    expect(find.text('Opacity'), findsOneWidget);
  });

  testWidgets('a caption inside a cell still gets them', (tester) async {
    // Captions and bubbles are never clamped to a cell - they are meant to be
    // small and are simply clipped - so nothing is protected by hiding these.
    final grid = GridSpec(root: gridTemplatesFor(2).first.root);
    const layer = TextLayer(
      id: 'txt',
      name: 'Text',
      text: 'Hello',
      fontFamily: 'Manrope',
      cellId: 'c0',
    );
    await pumpEditor(tester, withLayers([layer], grid: grid), select: 'txt');
    expect(sliderFor('Scale'), findsOneWidget);
    expect(sliderFor('Rotation'), findsOneWidget);
  });

  testWidgets('one drag is one undo step', (tester) async {
    final container = await pumpEditor(
      tester,
      withLayers([caption(scale: 0.5)]),
      select: 'txt',
    );
    await tester.drag(sliderFor('Scale'), const Offset(2000, 0));
    await tester.pump();
    expect(layerOf(container).transform.scale, 6.0);

    container.read(editorControllerProvider.notifier).undo();
    await tester.pump();
    expect(
      container.read(editorControllerProvider).layers.single.transform.scale,
      0.5,
      reason: 'the ticks of one drag coalesce into a single step',
    );
  });

  testWidgets('the sliders lay out in landscape', (tester) async {
    await pumpEditor(
      tester,
      withLayers([caption()]),
      select: 'txt',
      surface: const Size(900, 412),
    );
    expect(tester.takeException(), isNull);
    expect(sliderFor('Scale'), findsOneWidget);
    expect(sliderFor('Rotation'), findsOneWidget);
  });
}

/// Captures saves instead of touching the filesystem.
class _RecordingRepo implements ProjectRepository {
  final List<Project> saved = [];

  @override
  Future<void> save(Project project) async => saved.add(project);

  @override
  Future<List<Project>> list() async => saved;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
