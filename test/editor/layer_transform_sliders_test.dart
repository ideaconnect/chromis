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

  /// Scrolls the tool panel until [target] is inside its viewport.
  ///
  /// The portrait panel is capped at 300dp and scrolls - Opacity and the
  /// Effects link have always been below the fold - and the Snap toggle above
  /// these sliders moved Vertical down past it too. A widget outside a
  /// SingleChildScrollView's viewport is clipped and so cannot be hit-tested at
  /// all: a drag aimed at it silently does nothing, which is not a failure the
  /// assertion below could describe.
  Future<void> reveal(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      40,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('tool-panel')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pump();
  }

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

  BubbleLayer bubble({double scale = 1, Offset? position}) => BubbleLayer(
    id: 'bub',
    name: 'Bubble',
    text: 'Hi',
    transform: LayerTransform(
      scale: scale,
      // LayerTransform's own default is the legacy 512² canvas's centre, which
      // is off-centre on the 1080² one Project.empty makes.
      position: position ?? const Offset(540, 540),
    ),
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
    expect(sliderFor('Horizontal'), findsOneWidget);
    expect(sliderFor('Vertical'), findsOneWidget);
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

  testWidgets('half a turn stays on the end the drag arrived at', (
    tester,
  ) async {
    // -180° and 180° are one rotation, so the layer cannot say which end of the
    // slider the finger is on and the panel has to remember. It used to wrap
    // both to 180: dragging to the LEFT end wrote -π and the thumb teleported
    // to the right end mid-drag, reading "180°" for a layer the user had just
    // turned the other way.
    final container = await pumpEditor(
      tester,
      withLayers([caption()]),
      select: 'txt',
    );

    await tester.drag(sliderFor('Rotation'), const Offset(-2000, 0));
    await tester.pump();
    expect(layerOf(container).transform.rotation, closeTo(-math.pi, 0.001));
    expect(find.text('-180°'), findsOneWidget);
    expect(
      tester.widget<Slider>(sliderFor('Rotation')).value,
      -180,
      reason: 'the thumb must stay under the finger, not hop to the far end',
    );

    await tester.drag(sliderFor('Rotation'), const Offset(2000, 0));
    await tester.pump();
    expect(layerOf(container).transform.rotation, closeTo(math.pi, 0.001));
    expect(find.text('180°'), findsOneWidget);
    expect(tester.widget<Slider>(sliderFor('Rotation')).value, 180);
  });

  testWidgets('a rotation from anywhere else drops the remembered end', (
    tester,
  ) async {
    // The remembered reading is about ONE drag, and it is sticky enough to lie
    // if it outlives the value it described - a pinch on the canvas, or an
    // undo, must put the readout back on the layer's own angle.
    final container = await pumpEditor(
      tester,
      withLayers([caption()]),
      select: 'txt',
    );
    await tester.drag(sliderFor('Rotation'), const Offset(-2000, 0));
    await tester.pump();
    expect(find.text('-180°'), findsOneWidget);

    container
        .read(editorControllerProvider.notifier)
        .updateTransform(
          'txt',
          const LayerTransform(rotation: 400 * math.pi / 180),
        );
    await tester.pump();
    expect(find.text('-180°'), findsNothing);
    expect(find.text('40°'), findsOneWidget);
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
    expect(sliderFor('Horizontal'), findsOneWidget);
    expect(sliderFor('Vertical'), findsOneWidget);
    expect(find.text('Crop photo'), findsOneWidget);
    expect(find.text('Brightness'), findsOneWidget);
    expect(find.text('Opacity'), findsOneWidget);
  });

  // ------------------------------------------------- Horizontal / Vertical
  //
  // A bubble is the layer whose size is a plain constant (kBubbleBaseSize,
  // 210×168 at scale 1) - no font metrics, no image header - so the exact
  // position each end of the bar must produce can be written down here rather
  // than recomputed from the code under test.
  const canvas = 1080.0; // Project.empty's default, square.
  const centre = canvas / 2;
  const travelX = (canvas + 210) / 2;
  const travelY = (canvas + 168) / 2;

  testWidgets('100% is the offset that puts the layer just off the canvas', (
    tester,
  ) async {
    final container = await pumpEditor(
      tester,
      withLayers([bubble()]),
      select: 'bub',
    );

    await tester.drag(sliderFor('Horizontal'), const Offset(2000, 0));
    await tester.pump();
    expect(
      layerOf(container).transform.position.dx,
      closeTo(centre + travelX, 0.5),
      reason: 'the bubble\'s left edge lands exactly on the canvas right edge',
    );
    expect(
      layerOf(container).transform.position.dx - 105,
      closeTo(canvas, 0.5),
    );

    await tester.drag(sliderFor('Horizontal'), const Offset(-4000, 0));
    await tester.pump();
    expect(
      layerOf(container).transform.position.dx,
      closeTo(centre - travelX, 0.5),
    );
    expect(
      layerOf(container).transform.position.dx + 105,
      closeTo(0, 0.5),
      reason: 'and its right edge on the canvas left edge, going the other way',
    );
  });

  testWidgets('Vertical is measured against the layer\'s own height', (
    tester,
  ) async {
    // Not the same travel as Horizontal: the bubble is wider than it is tall,
    // so it leaves the canvas sooner going up than going sideways. A slider
    // that used one number for both would overshoot on the short axis.
    final container = await pumpEditor(
      tester,
      withLayers([bubble()]),
      select: 'bub',
    );

    await reveal(tester, sliderFor('Vertical'));
    await tester.drag(sliderFor('Vertical'), const Offset(2000, 0));
    await tester.pump();
    final t = layerOf(container).transform;
    expect(t.position.dy, closeTo(centre + travelY, 0.5));
    expect(t.position.dy - 84, closeTo(canvas, 0.5));
    expect(
      t.position.dx,
      centre,
      reason: 'one axis at a time - Vertical must not move the layer sideways',
    );
  });

  testWidgets('the travel grows with the layer, so 100% is always outside', (
    tester,
  ) async {
    // The same 100% has to mean a different distance for a layer three times
    // the size, or a scaled-up layer would still be half on screen at the end
    // of the bar.
    final container = await pumpEditor(
      tester,
      withLayers([bubble(scale: 3)]),
      select: 'bub',
    );

    await tester.drag(sliderFor('Horizontal'), const Offset(2000, 0));
    await tester.pump();
    expect(
      layerOf(container).transform.position.dx - 105 * 3,
      closeTo(canvas, 0.5),
    );
  });

  testWidgets('a layer parked off-canvas reads past the end of the bar', (
    tester,
  ) async {
    // Dragging a layer clean off the canvas is ordinary, so the readout stays
    // the true percentage and only the THUMB pins to the end - the same trade
    // the Scale slider makes. A clamped readout would say "100%" for a layer
    // three canvases away and make the slider look broken when it moved it.
    await pumpEditor(
      tester,
      withLayers([bubble(position: const Offset(2000, 540))]),
      select: 'bub',
    );
    // (2000 - 540) / 645 = 226%.
    expect(find.text('226%'), findsOneWidget);
    expect(tester.widget<Slider>(sliderFor('Horizontal')).value, 100);
  });

  testWidgets('the placement sliders snap to dead centre', (tester) async {
    final container = await pumpEditor(
      tester,
      withLayers([bubble()]),
      select: 'bub',
    );
    // Off-centre first, so a slider that did nothing at all would fail this.
    await tester.drag(sliderFor('Horizontal'), const Offset(2000, 0));
    await tester.pump();

    final rect = tester.getRect(sliderFor('Horizontal'));
    var sawCentre = false;
    for (var dx = -8.0; dx <= 8.0; dx++) {
      await tester.tapAt(Offset(rect.center.dx + dx, rect.center.dy));
      await tester.pump();
      final offset = layerOf(container).transform.position.dx - centre;
      if (offset == 0) {
        sawCentre = true;
      } else {
        expect(
          offset.abs(),
          greaterThanOrEqualTo(travelX * 0.02),
          reason: '$dx px from the middle left the layer $offset off centre',
        );
      }
    }
    expect(sawCentre, isTrue, reason: 'the sweep must cross the middle');
  });

  testWidgets('a covered layer is moved by the slider, not by the drag', (
    tester,
  ) async {
    // The reason these exist: the canvas hit-test gives a drag to the TOPMOST
    // layer under the finger, so a layer sitting beneath a big photo cannot be
    // dragged out from under it. The panel addresses the selected layer, so
    // what covers it has no say.
    final container = await pumpEditor(
      tester,
      withLayers([bubble(), photo()]),
      select: 'bub',
    );

    await tester.drag(sliderFor('Horizontal'), const Offset(2000, 0));
    await tester.pump();
    final layers = container.read(editorControllerProvider).layers;
    expect(layers.first.transform.position.dx, closeTo(centre + travelX, 0.5));
    expect(
      layers.last.transform.position,
      const Offset(256, 256),
      reason: 'the photo on top of it must not move',
    );
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
    expect(sliderFor('Horizontal'), findsNothing);
    expect(sliderFor('Vertical'), findsNothing);
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
    expect(sliderFor('Horizontal'), findsOneWidget);
    expect(sliderFor('Vertical'), findsOneWidget);
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
