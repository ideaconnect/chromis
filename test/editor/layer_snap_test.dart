import 'dart:math' as math;

import 'package:chromis/core/models/frame.dart';
import 'package:chromis/core/models/layer.dart';
import 'package:chromis/core/models/layer_transform.dart';
import 'package:chromis/core/models/project.dart';
import 'package:chromis/core/theme/app_theme.dart';
import 'package:chromis/core/widgets/labeled_slider.dart';
import 'package:chromis/features/editor/editor_screen.dart';
import 'package:chromis/features/editor/layer_snap.dart';
import 'package:chromis/features/editor/state/editor_controller.dart';
import 'package:chromis/features/editor/state/editor_tool.dart';
import 'package:chromis/features/editor/widgets/bubble_view.dart';
import 'package:chromis/features/editor/widgets/editor_canvas.dart';
import 'package:chromis/features/editor/widgets/project_canvas.dart';
import 'package:chromis/features/go_pro/iap.dart';
import 'package:chromis/features/home/project_repository.dart';
import 'package:chromis/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/surface.dart';

/// Alignment snapping: the Snap toggle, the engine behind it, and the two
/// surfaces that must agree about it.
///
/// The toggle governs BOTH ways a layer is moved and resized - the canvas
/// gesture and the Adjust panel's placement sliders - because they are the same
/// two edits. A toggle sitting directly above the sliders that only reached the
/// canvas would be a promise about the controls under it that it does not keep.
///
/// The engine works in a FRAME rather than on canvas axes, which is what lets a
/// turned layer align by the edges it draws instead of by a bounding box its
/// edges only touch at one corner - and what lets one layer take another's
/// angle so the two can go flush at all.
void main() {
  // ------------------------------------------------------------ the engine
  //
  // `measure` is injected, so these describe boxes rather than layers: 'a' is
  // 100x60 at scale 1 and 'b' is 200x40, whatever type they nominally are.
  const sizes = {'a': Size(100, 60), 'b': Size(200, 40), 'c': Size(200, 40)};
  Size measure(Layer layer, double scale) =>
      Size(sizes[layer.id]!.width * scale, sizes[layer.id]!.height * scale);

  Layer box(
    String id, {
    Offset at = Offset.zero,
    double scale = 1,
    double rotation = 0,
    bool visible = true,
  }) => BubbleLayer(
    id: id,
    name: id,
    visible: visible,
    transform: LayerTransform(position: at, scale: scale, rotation: rotation),
  );

  SnapResult snap(
    Layer moving,
    List<Layer> others, {
    double tolerance = 10,
    double rotationTolerance = 0,
    bool snapRotation = false,
    bool snapScale = false,
    bool snapX = true,
    bool snapY = true,
    SnapFrame frame = SnapFrame.layer,
  }) => snapTransform(
    moving: moving,
    proposed: moving.transform,
    others: others,
    measure: measure,
    canvas: const Size(1000, 1000),
    tolerance: tolerance,
    rotationTolerance: rotationTolerance,
    snapRotation: snapRotation,
    snapScale: snapScale,
    snapX: snapX,
    snapY: snapY,
    frame: frame,
  );

  group('snapTransform', () {
    test('an edge lands on a neighbour\'s edge', () {
      // 'a' ends at 398, 'b' starts at 400 - two pixels of daylight nobody
      // asked for, and the exact gap a finger cannot close.
      final moving = box('a', at: const Offset(348, 300));
      final result = snap(moving, [
        moving,
        box('b', at: const Offset(500, 300)),
      ]);

      expect(result.transform.position.dx, 350);
      expect(result.guides, contains(const SnapGuide(SnapAxis.x, 400)));
      expect(
        result.transform.position.dy,
        300,
        reason: 'the two centres were already level, so nothing moved there',
      );
      expect(result.guides, contains(const SnapGuide(SnapAxis.y, 300)));
    });

    test('nothing within reach leaves the transform exactly alone', () {
      final moving = box('a', at: const Offset(300, 300));
      final result = snap(moving, [
        moving,
        box('b', at: const Offset(800, 800)),
      ]);

      expect(result.transform, moving.transform);
      expect(result.guides, isEmpty);
      expect(result.isEmpty, isTrue);
    });

    test('the canvas is a target too, not only the other layers', () {
      final moving = box('a', at: const Offset(498, 300));
      final result = snap(moving, [moving]);

      expect(result.transform.position.dx, 500);
      expect(result.guides, contains(const SnapGuide(SnapAxis.x, 500)));
    });

    test('an invisible layer is not something to line up with', () {
      final moving = box('a', at: const Offset(348, 300));
      final result = snap(moving, [
        moving,
        box('b', at: const Offset(500, 300), visible: false),
      ]);

      expect(result.transform.position.dx, 348);
    });

    test('the axes are independent, so one slider moves one axis', () {
      // Both axes have an alignment in reach; only the one asked for is taken.
      final moving = box('a', at: const Offset(348, 302));
      final result = snap(moving, [
        moving,
        box('b', at: const Offset(500, 300)),
      ], snapY: false);

      expect(result.transform.position.dx, 350);
      expect(result.transform.position.dy, 302);
      expect(result.guides, hasLength(1));
    });

    test('resizing stops on another layer\'s width', () {
      // 100 wide at scale 1.9 is 190; 'b' is 200 across.
      final moving = box('a', at: const Offset(300, 300), scale: 1.9);
      final result = snap(
        moving,
        [moving, box('b', at: const Offset(800, 800))],
        tolerance: 12,
        snapScale: true,
      );

      expect(result.transform.scale, 2.0);
      expect(result.sizeMatchId, 'b');
    });

    test('a plain move never resizes', () {
      // The same numbers with snapScale off - which is what a one-finger drag
      // passes, because the proposed scale is then the layer's own and
      // "snapping" it would resize a layer that was only being moved.
      final moving = box('a', at: const Offset(300, 300), scale: 1.9);
      final result = snap(moving, [
        moving,
        box('b', at: const Offset(800, 800)),
      ], tolerance: 12);

      expect(result.transform.scale, 1.9);
      expect(result.sizeMatchId, isNull);
    });

    test('an impossible size match does not shadow a reachable one', () {
      // 'b' is the nearer candidate by width but would need scale 8; 'c' is a
      // little further off and reachable. Rejecting the nearest AFTER the
      // search would leave the layer with no match at all.
      const sizes = {
        'a': Size(100, 100),
        'b': Size(605, 605),
        'c': Size(570, 570),
      };
      final moving = box('a', at: const Offset(300, 300), scale: 5.9);
      final result = snapTransform(
        moving: moving,
        proposed: moving.transform,
        others: [
          moving,
          box('b', at: const Offset(2000, 2000)),
          box('c', at: const Offset(3000, 3000)),
        ],
        measure: (l, s) =>
            Size(sizes[l.id]!.width * s, sizes[l.id]!.height * s),
        canvas: const Size(1000, 1000),
        tolerance: 30,
        snapScale: true,
      );

      expect(result.transform.scale, closeTo(5.7, 1e-9));
      expect(result.sizeMatchId, 'c');
    });

    test('a size match outside the shared scale range is dropped', () {
      // 'b' would want scale 7, past the 6.0 both resizers stop at. Clamping to
      // 6 instead would park the layer on the end of the range while claiming a
      // match it does not have.
      const sizes = {'a': Size(100, 60), 'b': Size(700, 700)};
      final moving = box('a', at: const Offset(300, 300), scale: 6.9);
      final result = snapTransform(
        moving: moving,
        proposed: moving.transform,
        others: [
          moving,
          box('b', at: const Offset(2000, 2000)),
        ],
        measure: (l, s) =>
            Size(sizes[l.id]!.width * s, sizes[l.id]!.height * s),
        canvas: const Size(1000, 1000),
        tolerance: 12,
        snapScale: true,
      );

      expect(result.transform.scale, 6.9);
      expect(result.sizeMatchId, isNull);
    });
  });

  group('a clipped target', () {
    // A collage cell clips its layer, and a cell photo is cover-scaled, so much
    // of its box is behind the neighbouring cells. Only what is on screen may
    // be lined up with - the same rule the canvas hit test applies to taps.
    const cell = Rect.fromLTWH(400, 200, 200, 200);

    test('offers the edge you can see, not the one behind the cell', () {
      // 'b' is 200 wide and centred on a 200-wide cell, so nothing is hidden on
      // x; make it overflow by scaling it. At scale 2 it reaches 200 either
      // side of the cell centre - 100 units into the neighbouring cells.
      final b = box('b', at: cell.center, scale: 2);
      // 'a' ends three units short of the CELL's left edge.
      final moving = box('a', at: Offset(cell.left - 3 - 50, cell.center.dy));
      final result = snapTransform(
        moving: moving,
        proposed: moving.transform,
        others: [moving, b],
        measure: measure,
        canvas: const Size(1000, 1000),
        tolerance: 10,
        clipOf: (l) => l.id == 'b' ? cell : null,
      );

      expect(result.transform.position.dx, cell.left - 50);
      expect(result.guides, contains(SnapGuide(SnapAxis.x, cell.left)));
    });

    test('without the clip it sticks to an edge that is not on screen', () {
      // The same layers with no clip: 'b' reaches 200 units left of the cell
      // centre, so the layer is pulled to a line inside the cell next door
      // where nothing is drawn. This is the bug, written down.
      final b = box('b', at: cell.center, scale: 2);
      final hidden = cell.center.dx - 200; // b's real left edge
      final moving = box('a', at: Offset(hidden - 3 - 50, cell.center.dy));
      final result = snapTransform(
        moving: moving,
        proposed: moving.transform,
        others: [moving, b],
        measure: measure,
        canvas: const Size(1000, 1000),
        tolerance: 10,
      );

      expect(result.transform.position.dx, hidden - 50);
    });

    test('a target clipped clean off the canvas offers nothing', () {
      final b = box('b', at: const Offset(900, 900));
      final moving = box('a', at: const Offset(748, 900));
      final result = snapTransform(
        moving: moving,
        proposed: moving.transform,
        others: [moving, b],
        measure: measure,
        canvas: const Size(1000, 1000),
        tolerance: 10,
        clipOf: (l) => l.id == 'b' ? cell : null,
      );

      expect(result.transform, moving.transform);
      expect(result.isEmpty, isTrue);
    });
  });

  // -------------------------------------------------------------- the frame
  group('the frame', () {
    test('the canvas frame measures a turned layer by its bounding box', () {
      // Which is what the placement sliders need: "how far left does it reach"
      // on the canvas's own x. 100x60 on its side reaches 30 either way, so its
      // right edge is at 330 rather than 350.
      final moving = box(
        'a',
        at: const Offset(300, 300),
        rotation: math.pi / 2,
      );
      final result = snap(moving, [
        moving,
        box('b', at: const Offset(432, 300)),
      ], frame: SnapFrame.canvas);

      expect(result.transform.position.dx, closeTo(302, 1e-9));
      expect(
        rotatedExtent(const Size(100, 60), math.pi / 2).width,
        closeTo(60, 1e-9),
      );
    });

    test('two layers at the same angle go flush along their own edge', () {
      // The thing a bounding box cannot do. At 45° neither layer has an edge
      // parallel to anything on the canvas, but they are parallel to EACH
      // OTHER - so in their shared frame there is an alignment, and it is the
      // one the eye sees.
      const angle = math.pi / 4;
      const bAt = Offset(500, 300);
      // 'a' placed with its far edge three units short of b's near edge.
      final aAt = _fromFrame(
        _u(bAt, angle) - 100 - 50 - 3,
        _v(bAt, angle),
        angle,
      );
      final moving = box('a', at: aAt, rotation: angle);
      final result = snap(moving, [moving, box('b', at: bAt, rotation: angle)]);

      expect(
        _u(result.transform.position, angle) + 50,
        closeTo(_u(bAt, angle) - 100, 1e-9),
        reason: 'flush: a\'s far edge exactly on b\'s near edge',
      );
      expect(
        result.guides.first.angle,
        angle,
        reason: 'the guide runs with them',
      );
    });

    test('the canvas frame cannot see that alignment at all', () {
      // Same two layers, measured on the canvas's axes: their bounding boxes
      // are 33 apart, so nothing fires. This is why a gesture uses the layer's
      // frame and only the sliders use the canvas's.
      const angle = math.pi / 4;
      const bAt = Offset(500, 300);
      final aAt = _fromFrame(
        _u(bAt, angle) - 100 - 50 - 3,
        _v(bAt, angle),
        angle,
      );
      final moving = box('a', at: aAt, rotation: angle);
      final result = snap(moving, [
        moving,
        box('b', at: bAt, rotation: angle),
      ], frame: SnapFrame.canvas);

      expect(result.isEmpty, isTrue);
      expect(result.transform, moving.transform);
    });
  });

  // ----------------------------------------------------------- the rotation
  const deg26 = 26 * math.pi / 180;
  const deg28 = 28 * math.pi / 180;

  group('taking a neighbour\'s angle', () {
    /// 'b' at 28°, and 'a' at 26° with its far edge [gap] short of b's near
    /// edge measured in b's frame - i.e. as good as flush already.
    (Layer, Layer) pair({required double gap}) {
      const bAt = Offset(500, 300);
      final aAt = _fromFrame(
        _u(bAt, deg28) - 100 - 50 - gap,
        _v(bAt, deg28),
        deg28,
      );
      return (
        box('a', at: aAt, rotation: deg26),
        box('b', at: bAt, rotation: deg28),
      );
    }

    test('a move onto a neighbour\'s edge takes its angle', () {
      // The whole point: 26° brought against 28° comes out at 28°, flush.
      final (a, b) = pair(gap: 3);
      final result = snap(a, [a, b], rotationTolerance: kSnapRotationTolerance);

      expect(result.transform.rotation, closeTo(deg28, 1e-9));
      expect(result.rotationMatchId, 'b');
      expect(
        _u(result.transform.position, deg28) + 50,
        closeTo(_u(b.transform.position, deg28) - 100, 1e-9),
        reason: 'and the edges are flush, which is why the angle moved',
      );
    });

    test('with no rotation tolerance the angle is left alone', () {
      final (a, b) = pair(gap: 3);
      final result = snap(a, [a, b]);

      expect(result.transform.rotation, deg26);
      expect(result.rotationMatchId, isNull);
    });

    test('an angle past the tolerance is not taken', () {
      const deg40 = 40 * math.pi / 180;
      final (a, _) = pair(gap: 3);
      final far = box('b', at: const Offset(500, 300), rotation: deg40);
      final result = snap(a, [
        a,
        far,
      ], rotationTolerance: kSnapRotationTolerance);

      expect(result.transform.rotation, deg26);
    });

    test('a move that lands nowhere near it does NOT take its angle', () {
      // The gate, and the reason a deliberate tilt survives being carried
      // across a canvas of upright layers: a borrowed angle has to be paid for
      // with an alignment against the very layer it came from.
      const bAt = Offset(500, 300);
      final aAt = _fromFrame(_u(bAt, deg28) - 500, _v(bAt, deg28) - 500, deg28);
      final a = box('a', at: aAt, rotation: deg26);
      final b = box('b', at: bAt, rotation: deg28);
      final result = snap(a, [a, b], rotationTolerance: kSnapRotationTolerance);

      expect(result.transform.rotation, deg26);
      expect(result.rotationMatchId, isNull);
      expect(result.isEmpty, isTrue);
    });

    test('a gesture that is TURNING the layer takes it outright', () {
      // No alignment required: a pinch that twists, like the Rotation slider,
      // is asking for the angle rather than getting one as a side effect.
      const bAt = Offset(500, 300);
      final aAt = _fromFrame(_u(bAt, deg28) - 500, _v(bAt, deg28) - 500, deg28);
      final a = box('a', at: aAt, rotation: deg26);
      final result = snap(
        a,
        [a, box('b', at: bAt, rotation: deg28)],
        rotationTolerance: kSnapRotationTolerance,
        snapRotation: true,
      );

      expect(result.transform.rotation, closeTo(deg28, 1e-9));
      expect(result.rotationMatchId, 'b');
    });

    test('a layer square to the canvas keeps its right angle', () {
      // Arriving at level is a small surprise; leaving it is a large one. An
      // upright layer dragged against a neighbour a couple of degrees off must
      // stay upright - otherwise one tilted sticker on the canvas can knock
      // every other layer askew just by being aligned to.
      const bAt = Offset(500, 300);
      const tilt = 3 * math.pi / 180;
      final aAt = _fromFrame(_u(bAt, tilt) - 100 - 50 - 3, _v(bAt, tilt), tilt);
      final a = box('a', at: aAt);
      final result = snap(a, [
        a,
        box('b', at: bAt, rotation: tilt),
      ], rotationTolerance: kSnapRotationTolerance);

      expect(result.transform.rotation, 0);
      expect(result.rotationMatchId, isNull);
      expect(isSquareToCanvas(0), isTrue);
      expect(isSquareToCanvas(math.pi / 2), isTrue);
      expect(isSquareToCanvas(tilt), isFalse);
    });

    test('a deliberate twist may still take it off square', () {
      // The same layer, with the caller saying the gesture IS turning it - by
      // then it is not square any more anyway.
      const bAt = Offset(500, 300);
      const tilt = 3 * math.pi / 180;
      final a = box('a', at: const Offset(100, 100));
      final result = snap(
        a,
        [a, box('b', at: bAt, rotation: tilt)],
        rotationTolerance: kSnapRotationTolerance,
        snapRotation: true,
      );

      expect(result.transform.rotation, closeTo(tilt, 1e-9));
    });

    test('a borrow that would cost an alignment it already has is refused', () {
      // A borrowed angle must not win on merely existing. 'c' is at the same
      // angle and exactly flush already; 'b' is two degrees off and three units
      // away. Taking b's angle would tilt the layer off a perfect alignment for
      // a worse one.
      const aAt = Offset(300, 300);
      final cAt = _fromFrame(_u(aAt, deg26) + 50 + 100, _v(aAt, deg26), deg26);
      final bAt = _fromFrame(
        _u(aAt, deg28) + 50 + 100 + 3,
        _v(aAt, deg28),
        deg28,
      );
      final a = box('a', at: aAt, rotation: deg26);
      final result = snap(a, [
        a,
        box('b', at: bAt, rotation: deg28),
        box('c', at: cAt, rotation: deg26),
      ], rotationTolerance: kSnapRotationTolerance);

      expect(result.transform.rotation, deg26);
      expect(result.rotationMatchId, isNull);
      // closeTo, not equality: a turned frame round-trips the position through
      // sin and cos, and 300 comes back a bit off itself.
      expect(
        result.transform.position.dx,
        closeTo(aAt.dx, 1e-9),
        reason: 'it was already exactly flush with c, so nothing moved',
      );
      expect(result.transform.position.dy, closeTo(aAt.dy, 1e-9));
    });

    test('the canvas frame never borrows an angle', () {
      // It would have to move the layer diagonally to pay for it, and the
      // sliders that use this frame each own one axis.
      final (a, b) = pair(gap: 3);
      final result = snap(
        a,
        [a, b],
        rotationTolerance: kSnapRotationTolerance,
        frame: SnapFrame.canvas,
      );

      expect(result.transform.rotation, deg26);
      expect(result.rotationMatchId, isNull);
    });

    test('a layer wound past a full turn keeps its winding', () {
      // The canvas ACCUMULATES rotation, so 386° is a state the model reaches.
      // Taking a 28° neighbour's angle must add two degrees, not unwind it.
      const wound = 386 * math.pi / 180;
      const bAt = Offset(500, 300);
      final aAt = _fromFrame(
        _u(bAt, deg28) - 100 - 50 - 3,
        _v(bAt, deg28),
        deg28,
      );
      final a = box('a', at: aAt, rotation: wound);
      final result = snap(a, [
        a,
        box('b', at: bAt, rotation: deg28),
      ], rotationTolerance: kSnapRotationTolerance);

      expect(
        result.transform.rotation,
        closeTo(388 * math.pi / 180, 1e-9),
        reason: '388°, not 28° - the same picture, and the turns kept',
      );
    });
  });

  group('nearestLayerRotation', () {
    test('finds the nearest angle within the tolerance', () {
      final moving = box('a', rotation: deg26);
      final match = nearestLayerRotation(
        moving: moving,
        proposed: deg26,
        others: [
          moving,
          box('b', rotation: deg28),
        ],
        tolerance: kSnapRotationTolerance,
      );
      expect(match, closeTo(deg28, 1e-9));
    });

    test('ignores itself, the invisible and the far', () {
      final moving = box('a', rotation: deg26);
      expect(
        nearestLayerRotation(
          moving: moving,
          proposed: deg26,
          others: [moving],
          tolerance: kSnapRotationTolerance,
        ),
        isNull,
      );
      expect(
        nearestLayerRotation(
          moving: moving,
          proposed: deg26,
          others: [
            moving,
            box('b', rotation: deg28, visible: false),
          ],
          tolerance: kSnapRotationTolerance,
        ),
        isNull,
      );
      expect(
        nearestLayerRotation(
          moving: moving,
          proposed: deg26,
          others: [
            moving,
            box('b', rotation: 40 * math.pi / 180),
          ],
          tolerance: kSnapRotationTolerance,
        ),
        isNull,
      );
    });
  });

  // ------------------------------------------------------------ the editor
  setUp(() {
    ProjectCanvas.fileExists = (_) => false;
    ProjectCanvas.existsCache.clear();
  });
  tearDown(() => ProjectCanvas.fileExists = ProjectCanvas.defaultFileExists);

  Future<ProviderContainer> pumpEditor(
    WidgetTester tester,
    List<Layer> layers, {
    String? select,
    bool snap = true,
  }) async {
    setSurface(tester, const Size(412, 915));
    final container = ProviderContainer(
      overrides: [
        isProProvider.overrideWithValue(true),
        projectRepositoryProvider.overrideWithValue(_RecordingRepo()),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(editorControllerProvider.notifier);
    controller.loadProject(
      Project.empty(id: 'p').copyWith(
        frames: [Frame(id: 'p_f0', layers: layers)],
      ),
    );
    controller.snapEnabled = snap;
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

  // A bubble is the layer whose size is a plain constant - kBubbleBaseSize,
  // 210x168 - so what "the same width" and "edge to edge" come out as can be
  // written down here rather than recomputed from the code under test.
  const canvas = 1080.0; // Project.empty's default, square.
  const half = Offset(105, 84);
  BubbleLayer bubble(
    String id, {
    Offset? at,
    double scale = 1,
    double rotation = 0,
  }) => BubbleLayer(
    id: id,
    name: id,
    text: 'Hi',
    transform: LayerTransform(
      position: at ?? const Offset(540, 540),
      scale: scale,
      rotation: rotation,
    ),
  );

  /// What the Adjust panel treats as "close enough" - 2% of the canvas.
  const tolerance = canvas * 0.02;

  testWidgets('the Snap toggle sits above the placement sliders', (
    tester,
  ) async {
    final container = await pumpEditor(tester, [bubble('a')], select: 'a');

    expect(find.text('Snap'), findsOneWidget);
    expect(
      tester.getCenter(find.text('Snap')).dy,
      lessThan(tester.getCenter(sliderFor('Scale')).dy),
      reason: 'it governs the sliders under it, so it reads before them',
    );

    final toggle = find.byType(Switch);
    expect(tester.widget<Switch>(toggle).value, isTrue, reason: 'default on');
    await tester.tap(toggle);
    await tester.pump();
    expect(
      container.read(editorControllerProvider.notifier).snapEnabled,
      isFalse,
    );
  });

  testWidgets('a layer with nothing to align to still shows the toggle', (
    tester,
  ) async {
    // It governs the canvas gesture as well, and a control that came and went
    // with the layer count would be one nobody could find on purpose.
    await pumpEditor(tester, [bubble('a')], select: 'a');
    expect(find.text('Snap'), findsOneWidget);
  });

  testWidgets('the Scale slider stops on the other layer\'s size', (
    tester,
  ) async {
    // 'b' is twice the size, so the match is scale 2.0 exactly - on width
    // (420/210) and on height (336/168) alike.
    final container = await pumpEditor(tester, [
      bubble('a'),
      bubble('b', at: const Offset(200, 900), scale: 2),
    ], select: 'a');
    final rect = tester.getRect(sliderFor('Scale'));

    var sawMatch = false;
    for (var dx = -60.0; dx <= 20.0; dx++) {
      await tester.tapAt(Offset(rect.center.dx + dx, rect.center.dy));
      await tester.pump();
      final scale = layerOf(container).transform.scale;
      if (scale == 2.0) {
        sawMatch = true;
      } else {
        expect(
          (kBubbleBaseSize.width * scale - 420).abs(),
          greaterThanOrEqualTo(tolerance),
          reason: '$dx px along the bar left the layer $scale, a near miss',
        );
      }
    }
    expect(sawMatch, isTrue, reason: 'the sweep must cross the match');
  });

  testWidgets('with Snap off the Scale slider passes straight through', (
    tester,
  ) async {
    final container = await pumpEditor(
      tester,
      [bubble('a'), bubble('b', at: const Offset(200, 900), scale: 2)],
      select: 'a',
      snap: false,
    );
    final rect = tester.getRect(sliderFor('Scale'));

    var sawNearMiss = false;
    for (var dx = -60.0; dx <= 20.0; dx++) {
      await tester.tapAt(Offset(rect.center.dx + dx, rect.center.dy));
      await tester.pump();
      final off =
          (kBubbleBaseSize.width * layerOf(container).transform.scale - 420)
              .abs();
      if (off > 0 && off < tolerance) sawNearMiss = true;
    }
    expect(
      sawNearMiss,
      isTrue,
      reason: 'the sweep passed through the band and was not pulled in',
    );
  });

  testWidgets('the Rotation slider stops on the other layer\'s angle', (
    tester,
  ) async {
    // The panel's half of "layers snap to each other": the way to make a
    // caption parallel to a photo already sitting at 28°, which is not a number
    // a drag can hit.
    final container = await pumpEditor(tester, [
      bubble('a'),
      bubble('b', at: const Offset(200, 900), rotation: deg28),
    ], select: 'a');
    final rect = tester.getRect(sliderFor('Rotation'));

    var sawMatch = false;
    for (var dx = 5.0; dx <= 45.0; dx++) {
      await tester.tapAt(Offset(rect.center.dx + dx, rect.center.dy));
      await tester.pump();
      final off = (layerOf(container).transform.rotation - deg28).abs();
      if (off < 1e-9) {
        sawMatch = true;
      } else {
        expect(
          off,
          greaterThanOrEqualTo(kSnapRotationTolerance),
          reason: '$dx px along the bar left the layer a near miss',
        );
      }
    }
    expect(sawMatch, isTrue, reason: 'the sweep must cross the angle');
  });

  testWidgets('with Snap off the Rotation slider passes through the angle', (
    tester,
  ) async {
    final container = await pumpEditor(
      tester,
      [bubble('a'), bubble('b', at: const Offset(200, 900), rotation: deg28)],
      select: 'a',
      snap: false,
    );
    final rect = tester.getRect(sliderFor('Rotation'));

    var sawNearMiss = false;
    for (var dx = 5.0; dx <= 45.0; dx++) {
      await tester.tapAt(Offset(rect.center.dx + dx, rect.center.dy));
      await tester.pump();
      final off = (layerOf(container).transform.rotation - deg28).abs();
      if (off > 0 && off < kSnapRotationTolerance) sawNearMiss = true;
    }
    expect(
      sawNearMiss,
      isTrue,
      reason: 'the sweep passed through the band and was not pulled in',
    );
  });

  testWidgets('level still beats a neighbour\'s angle', (tester) async {
    // Straight is the stronger target: a layer resting a hair off level reads
    // as a mistake, so a neighbour at 3° must not be able to pull it off 0.
    final container = await pumpEditor(tester, [
      bubble('a'),
      bubble('b', at: const Offset(200, 900), rotation: 3 * math.pi / 180),
    ], select: 'a');
    final rect = tester.getRect(sliderFor('Rotation'));

    var sawZero = false;
    for (var dx = -14.0; dx <= 14.0; dx++) {
      await tester.tapAt(Offset(rect.center.dx + dx, rect.center.dy));
      await tester.pump();
      if (layerOf(container).transform.rotation == 0) sawZero = true;
    }
    expect(sawZero, isTrue);
  });

  testWidgets('the Horizontal slider comes to rest on an alignment', (
    tester,
  ) async {
    final container = await pumpEditor(tester, [
      bubble('a'),
      bubble('b', at: const Offset(900, 540)),
    ], select: 'a');
    // Every coordinate the moving bubble may line up on, along x.
    const targets = [900.0, 795, 1005, canvas / 2, 0, canvas];
    final rect = tester.getRect(sliderFor('Horizontal'));

    var sawSnap = false;
    for (var dx = -40.0; dx <= 70.0; dx++) {
      await tester.tapAt(Offset(rect.center.dx + dx, rect.center.dy));
      await tester.pump();
      final x = layerOf(container).transform.position.dx;
      final nearest = [
        for (final anchor in [x, x - half.dx, x + half.dx])
          for (final target in targets) (target - anchor).abs(),
      ].reduce(math.min);
      if (nearest < 1e-9) {
        sawSnap = true;
      } else {
        expect(
          nearest,
          greaterThanOrEqualTo(tolerance),
          reason: '$dx px along the bar left the layer $nearest off an edge',
        );
      }
    }
    expect(sawSnap, isTrue, reason: 'the sweep must cross an alignment');
  });

  testWidgets('with Snap off the Horizontal slider passes through them', (
    tester,
  ) async {
    final container = await pumpEditor(
      tester,
      [bubble('a'), bubble('b', at: const Offset(900, 540))],
      select: 'a',
      snap: false,
    );
    const targets = [900.0, 795, 1005];
    final rect = tester.getRect(sliderFor('Horizontal'));

    var sawNearMiss = false;
    for (var dx = -40.0; dx <= 70.0; dx++) {
      await tester.tapAt(Offset(rect.center.dx + dx, rect.center.dy));
      await tester.pump();
      final x = layerOf(container).transform.position.dx;
      final nearest = [
        for (final anchor in [x, x - half.dx, x + half.dx])
          for (final target in targets) (target - anchor).abs(),
      ].reduce(math.min);
      if (nearest > 0 && nearest < tolerance) sawNearMiss = true;
    }
    expect(
      sawNearMiss,
      isTrue,
      reason: 'the sweep passed through the band and was not pulled in',
    );
  });

  /// Drags the canvas by [logicalDx] canvas units, leaving the finger down.
  Future<TestGesture> dragCanvas(WidgetTester tester, double logicalDx) async {
    final finder = find.byType(EditorCanvas);
    final scale = tester.getSize(finder).width / canvas;
    final gesture = await tester.startGesture(tester.getCenter(finder));
    // Past the pan slop first (~36 logical px): a scale gesture is not
    // recognized before that, so this move is where the drag starts from and
    // the next one is the drag itself.
    await gesture.moveBy(const Offset(40, 0));
    await gesture.moveBy(Offset(logicalDx * scale, 0));
    await tester.pump();
    return gesture;
  }

  testWidgets('a canvas drag lands on the alignment and draws its guides', (
    tester,
  ) async {
    // The bubble's right edge stops 3 units short of 'b' - a gap a finger has
    // no way to close, which is the whole reason this exists.
    final container = await pumpEditor(tester, [
      bubble('a'),
      bubble('b', at: const Offset(940, 540)),
    ], select: 'a');

    final gesture = await dragCanvas(tester, 187);

    expect(
      layerOf(container).transform.position,
      const Offset(730, 540),
      reason: 'right edge onto b\'s left edge, and the centres already level',
    );
    expect(_guides(), findsNWidgets(2));

    await gesture.up();
    await tester.pump();
    expect(
      _guides(),
      findsNothing,
      reason: 'the guides belong to the gesture, not to the document',
    );
    expect(layerOf(container).transform.position, const Offset(730, 540));
  });

  testWidgets('with Snap off the drag ends where the finger left it', (
    tester,
  ) async {
    final container = await pumpEditor(
      tester,
      [bubble('a'), bubble('b', at: const Offset(940, 540))],
      select: 'a',
      snap: false,
    );

    final gesture = await dragCanvas(tester, 187);

    expect(layerOf(container).transform.position.dx, closeTo(727, 0.001));
    expect(_guides(), findsNothing);
    await gesture.up();
  });

  /// 'b' at 28°, placed so that a drag of [dragBy] brings 'a' (at 26°) to
  /// within three units of flush with it, measured in b's own frame.
  Offset bFacing(double dragBy) {
    final aAfterDrag = const Offset(540, 540) + Offset(dragBy, 0);
    return _fromFrame(
      _u(aAfterDrag, deg28) + 105 + 105 + 3,
      _v(aAfterDrag, deg28),
      deg28,
    );
  }

  testWidgets('a drag onto a turned neighbour takes its angle', (tester) async {
    // The scenario this exists for, end to end: 26° carried up against 28°
    // comes out at 28°, with the two edges flush - which no amount of dragging
    // could have produced on its own.
    final container = await pumpEditor(tester, [
      bubble('a', rotation: deg26),
      bubble('b', at: bFacing(150), rotation: deg28),
    ], select: 'a');

    final gesture = await dragCanvas(tester, 150);
    final t = layerOf(container).transform;

    expect(t.rotation, closeTo(deg28, 1e-9));
    expect(
      _u(t.position, deg28) + 105,
      closeTo(_u(bFacing(150), deg28) - 105, 1e-6),
      reason: 'flush along the edge the two now share',
    );
    expect(
      find.byKey(const ValueKey('snap-match-b')),
      findsOneWidget,
      reason: 'the layer whose angle was taken is pointed at',
    );

    await gesture.up();
    await tester.pump();
    expect(find.byKey(const ValueKey('snap-match-b')), findsNothing);
    expect(layerOf(container).transform.rotation, closeTo(deg28, 1e-9));
  });

  testWidgets('with Snap off the drag leaves the angle at 26°', (tester) async {
    final container = await pumpEditor(
      tester,
      [
        bubble('a', rotation: deg26),
        bubble('b', at: bFacing(150), rotation: deg28),
      ],
      select: 'a',
      snap: false,
    );

    final gesture = await dragCanvas(tester, 150);
    expect(layerOf(container).transform.rotation, deg26);
    await gesture.up();
  });

  /// Pinches the canvas open by a factor of 1.95, leaving both fingers down.
  Future<(TestGesture, TestGesture)> pinchOut(
    WidgetTester tester,
    Offset centre,
  ) async {
    // Both pointer ids given explicitly, and well clear of the low numbers the
    // tester hands out on its own: an auto-allocated first finger can land on
    // the id the second one asks for by name, and two pointers with one id trip
    // an assertion inside the gesture binding rather than failing an expect.
    final left = await tester.startGesture(
      centre - const Offset(100, 0),
      pointer: 101,
    );
    final right = await tester.startGesture(
      centre + const Offset(100, 0),
      pointer: 102,
    );
    // A second finger makes a scale gesture unambiguous, so it is accepted at
    // once - but "scale 1.0" is the span at its first MOVE, not at touch-down.
    // This one is it: the fingers end up 115 apart, about a focal point that
    // has shifted 15px left with them.
    await left.moveBy(const Offset(-30, 0));
    // Out to a span of 224.25 - a factor of 1.95, symmetric about that same
    // focal point, so this is a resize and nothing else.
    await left.moveBy(const Offset(-109.25, 0));
    await right.moveBy(const Offset(109.25, 0));
    await tester.pump();
    return (left, right);
  }

  testWidgets('a pinch stops on the other layer\'s size and points at it', (
    tester,
  ) async {
    // The size match is the half with no line to draw: 'b' is somewhere else
    // entirely, so the canvas outlines it instead. Nothing but a two-finger
    // gesture reaches this - a one-finger drag passes snapScale: false - which
    // is exactly how a branch like this ships dead.
    final container = await pumpEditor(tester, [
      bubble('a'),
      bubble('b', at: const Offset(200, 900), scale: 2),
    ], select: 'a');

    final (left, right) = await pinchOut(
      tester,
      tester.getCenter(find.byType(EditorCanvas)),
    );

    expect(
      layerOf(container).transform.scale,
      2.0,
      reason:
          '1.95 of its own size is a few units short of twice, and b is '
          'exactly twice',
    );
    expect(find.byKey(const ValueKey('snap-match-b')), findsOneWidget);

    await left.up();
    await right.up();
    await tester.pump();
    expect(find.byKey(const ValueKey('snap-match-b')), findsNothing);
    expect(layerOf(container).transform.scale, 2.0);
  });

  /// Puts two fingers down on a vertical line and settles the gesture's own
  /// zero: a span of 115 about a focal point 15px above [centre].
  Future<(TestGesture, TestGesture, Offset)> twistStart(
    WidgetTester tester,
    Offset centre,
  ) async {
    final top = await tester.startGesture(
      centre - const Offset(0, 100),
      pointer: 201,
    );
    final bottom = await tester.startGesture(
      centre + const Offset(0, 100),
      pointer: 202,
    );
    // Like pinchOut's first move: a two-finger gesture is accepted at once, but
    // its own "no rotation, scale 1" is the line between the fingers at their
    // first MOVE rather than at touch-down.
    await top.moveBy(const Offset(0, -30));
    return (top, bottom, centre - const Offset(0, 15));
  }

  testWidgets('a twisting pinch takes a neighbour\'s angle outright', (
    tester,
  ) async {
    // The ungated half of the rule, and the only path that passes
    // `snapRotation: true` in the shipped app. 'b' is nowhere near, so nothing
    // sponsors this - a twist asks for the angle the way the Rotation slider
    // does, rather than getting one for landing somewhere.
    const twist = 20 * math.pi / 180;
    const target = 22 * math.pi / 180;
    final container = await pumpEditor(tester, [
      bubble('a'),
      bubble('b', at: const Offset(200, 900), rotation: target),
    ], select: 'a');
    final centre = tester.getCenter(find.byType(EditorCanvas));

    final (top, bottom, focal) = await twistStart(tester, centre);
    // The fingers start VERTICAL, not horizontal: the recognizer measures the
    // angle of the line between them with atan2, and a line that starts flat
    // sits exactly on that function's cut - a 20° turn there is reported as
    // -340°, which is the same picture and a completely different number.
    final arm = Offset(-115 * math.sin(twist), 115 * math.cos(twist));
    await top.moveTo(focal - arm);
    await bottom.moveTo(focal + arm);
    await tester.pump();

    expect(
      layerOf(container).transform.rotation,
      closeTo(target, 1e-9),
      reason: '20° of twist stops on the neighbour sitting at 22°',
    );
    expect(find.byKey(const ValueKey('snap-match-b')), findsOneWidget);

    await top.up();
    await bottom.up();
  });

  testWidgets('a hand\'s worth of wobble is not a twist', (tester) async {
    // The reason the call site asks with a slop instead of `d.rotation != 0`.
    // Flutter derives the rotation from the line between the two pointers, so
    // on a real screen it is never exactly zero during a pinch - read as
    // intent, an exact test says "yes, a deliberate twist" for every pinch
    // anybody ever makes, and this layer would come out at 3° for being
    // resized. A synthetic pointer moves exactly, so this has to be staged: one
    // degree of twist, which is wobble, not a decision.
    const wobble = 1 * math.pi / 180;
    const neighbour = 3 * math.pi / 180;
    final container = await pumpEditor(tester, [
      bubble('a'),
      bubble('b', at: const Offset(200, 900), rotation: neighbour),
    ], select: 'a');
    final centre = tester.getCenter(find.byType(EditorCanvas));

    final (top, bottom, focal) = await twistStart(tester, centre);
    final arm = Offset(-115 * math.sin(wobble), 115 * math.cos(wobble));
    await top.moveTo(focal - arm);
    await bottom.moveTo(focal + arm);
    await tester.pump();

    expect(
      layerOf(container).transform.rotation,
      closeTo(wobble, 1e-6),
      reason: 'b is nowhere near it, so nothing sponsors taking b\'s angle',
    );
    await top.up();
    await bottom.up();
  });

  testWidgets('a hand\'s worth of wobble is not a resize', (tester) async {
    // The same trap on the other axis: `d.scale` is never exactly 1 with two
    // fingers down, so an exact test turns a two-finger MOVE into a size snap.
    // Half a percent of squeeze is wobble; 'b' is close enough in size that an
    // ungated size snap would take it.
    final container = await pumpEditor(tester, [
      bubble('a'),
      bubble('b', at: const Offset(200, 900), scale: 1.05),
    ], select: 'a');
    final centre = tester.getCenter(find.byType(EditorCanvas));

    final (top, bottom, focal) = await twistStart(tester, centre);
    // Span 115 out to 115.575 - a factor of 1.005, well under the slop.
    await top.moveTo(focal - const Offset(0, 115.575));
    await bottom.moveTo(focal + const Offset(0, 115.575));
    await tester.pump();

    expect(
      layerOf(container).transform.scale,
      closeTo(1.005, 1e-6),
      reason: 'a squeeze this small is not a request to be b\'s size',
    );
    expect(find.byKey(const ValueKey('snap-match-b')), findsNothing);
    await top.up();
    await bottom.up();
  });

  testWidgets('with Snap off the twist keeps the angle the fingers made', (
    tester,
  ) async {
    const twist = 20 * math.pi / 180;
    const target = 22 * math.pi / 180;
    final container = await pumpEditor(
      tester,
      [bubble('a'), bubble('b', at: const Offset(200, 900), rotation: target)],
      select: 'a',
      snap: false,
    );
    final centre = tester.getCenter(find.byType(EditorCanvas));

    final (top, bottom, focal) = await twistStart(tester, centre);
    final arm = Offset(-115 * math.sin(twist), 115 * math.cos(twist));
    await top.moveTo(focal - arm);
    await bottom.moveTo(focal + arm);
    await tester.pump();

    expect(layerOf(container).transform.rotation, closeTo(twist, 1e-6));
    await top.up();
    await bottom.up();
  });

  testWidgets('with Snap off the pinch keeps the size the fingers made', (
    tester,
  ) async {
    final container = await pumpEditor(
      tester,
      [bubble('a'), bubble('b', at: const Offset(200, 900), scale: 2)],
      select: 'a',
      snap: false,
    );

    final (left, right) = await pinchOut(
      tester,
      tester.getCenter(find.byType(EditorCanvas)),
    );

    expect(layerOf(container).transform.scale, closeTo(1.95, 1e-9));
    expect(find.byKey(const ValueKey('snap-match-b')), findsNothing);
    await left.up();
    await right.up();
  });
}

// Frame coordinates, written out here rather than imported, so the tests derive
// what they expect instead of restating the code under test.
double _u(Offset p, double angle) =>
    p.dx * math.cos(angle) + p.dy * math.sin(angle);

double _v(Offset p, double angle) =>
    -p.dx * math.sin(angle) + p.dy * math.cos(angle);

Offset _fromFrame(double u, double v, double angle) => Offset(
  u * math.cos(angle) - v * math.sin(angle),
  u * math.sin(angle) + v * math.cos(angle),
);

/// The snap guide lines currently on the canvas.
Finder _guides() => find.byWidgetPredicate(
  (w) => w.key is ValueKey<String> && '${w.key}'.contains('snap-guide-'),
);

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
