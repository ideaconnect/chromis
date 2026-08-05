import 'package:chromis/core/models/frame.dart';
import 'package:chromis/core/models/layer.dart';
import 'package:chromis/core/models/layer_transform.dart';
import 'package:chromis/core/models/project.dart';
import 'package:chromis/features/editor/state/editor_controller.dart';
import 'package:chromis/features/editor/state/editor_tool.dart';
import 'package:chromis/features/editor/widgets/editor_canvas.dart';
import 'package:chromis/features/editor/widgets/erase_trail.dart';
import 'package:chromis/features/editor/widgets/project_canvas.dart';
import 'package:chromis/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The erase brush used to show nothing at all until the finger came UP.
///
/// Not because of a debounce - there was never a timer. `_onScaleUpdate`
/// appended to a list and returned, with no `setState` and no callback, so the
/// widget tree did not rebuild and nothing on screen COULD change during the
/// drag. Then the lift started decode → isolate → encode → write → re-decode
/// before a single pixel moved.
///
/// These pin both halves: the mark appears while the finger is still down, and
/// it stays until the erased pixels have actually been painted - never cleared
/// in between, which would flash the un-erased photo.
const double _side = 400;

void main() {
  setUp(() {
    // The layer's mask/asset need not exist on disk for the canvas to lay out.
    ProjectCanvas.fileExists = (_) => false;
    ProjectCanvas.existsCache.clear();
  });
  tearDown(() => ProjectCanvas.fileExists = ProjectCanvas.defaultFileExists);

  Project projectWithPhoto() => Project(
    id: 'p1',
    name: 'p',
    canvasWidth: _side.toInt(),
    canvasHeight: _side.toInt(),
    frames: const [
      Frame(
        id: 'f1',
        layers: [
          ImageLayer(
            id: 'l1',
            name: 'Photo',
            assetPath: '/nope/photo.jpg',
            transform: LayerTransform(position: Offset(_side / 2, _side / 2)),
          ),
        ],
      ),
    ],
  );

  /// Pumps the canvas at 1 logical unit == 1 px, so a canvas-local offset and
  /// the stroke coordinate it produces are the same number.
  ///
  /// Returns the trail and a `at()` that turns a canvas-local point into the
  /// GLOBAL one a gesture needs - the canvas is centred in the test surface, so
  /// passing local coordinates straight to `startGesture` aims outside it and
  /// the drag silently does nothing.
  Future<(EraseTrail, Offset Function(Offset))> pumpCanvas(
    WidgetTester tester, {
    void Function(List<Offset>, int)? onEraseStroke,
    EditorTool tool = EditorTool.erase,
  }) async {
    final trail = EraseTrail();
    addTearDown(trail.dispose);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(editorControllerProvider.notifier);
    controller.loadProject(projectWithPhoto());
    controller.setTool(tool);
    controller.selectLayer('l1');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: _side,
                height: _side,
                child: EditorCanvas(
                  onEmptyTap: () {},
                  dropPlaceholder: const SizedBox.shrink(),
                  eraseTrail: trail,
                  onEraseStroke: onEraseStroke,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final origin = tester.getTopLeft(find.byType(EditorCanvas));
    return (trail, (Offset local) => origin + local);
  }

  // ------------------------------------------------------------- the drag
  testWidgets('the mark is on screen before the finger lifts', (tester) async {
    final (trail, at) = await pumpCanvas(tester);

    final gesture = await tester.startGesture(at(const Offset(120, 120)));
    await tester.pump();
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump();

    // This is the regression. Before, nothing existed here until the lift.
    expect(find.byKey(const ValueKey('erase-trail')), findsOneWidget);
    expect(trail.live, isNotNull, reason: 'a live stroke while dragging');
    expect(trail.liveLayerId, 'l1');

    await gesture.up();
    await tester.pump();
  });

  testWidgets('the mark survives the lift and waits for the pixels', (
    tester,
  ) async {
    late int ticket;
    final (trail, at) = await pumpCanvas(
      tester,
      onEraseStroke: (_, t) => ticket = t,
    );

    final gesture = await tester.startGesture(at(const Offset(100, 100)));
    await tester.pump();
    await gesture.moveBy(const Offset(60, 60));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    // Handed over, still drawn: clearing here is what would flash the
    // un-erased photo, because the write has not even started.
    expect(trail.live, isNull, reason: 'no longer under the finger');
    expect(trail.pending, hasLength(1));
    expect(trail.isEmpty, isFalse);

    // The pixels are written...
    trail.markCommitted(ticket, '/masks/m1.png');
    expect(trail.isEmpty, isFalse, reason: 'written is not yet painted');

    // ...and only a repaint carrying THAT mask retires it.
    trail.paintedFor('l1', '/masks/other.png');
    expect(trail.isEmpty, isFalse, reason: 'a different mask proves nothing');
    trail.paintedFor('l1', '/masks/m1.png');
    expect(trail.isEmpty, isTrue);
  });

  testWidgets('a stroke that never commits leaves no ghost', (tester) async {
    late int ticket;
    final (trail, at) = await pumpCanvas(
      tester,
      onEraseStroke: (_, t) => ticket = t,
    );

    final gesture = await tester.startGesture(at(const Offset(100, 100)));
    await tester.pump();
    await gesture.moveBy(const Offset(30, 30));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(trail.pending, hasLength(1));

    // The apply path has several exits that commit nothing - not an image
    // layer, every point off the photo, unmounted mid-await, the brushFailed
    // catch. Without this floor the blue mark would sit there forever.
    trail.retireIfUncommitted(ticket);
    expect(trail.isEmpty, isTrue);
  });

  testWidgets('a tap-dab draws its footprint too', (tester) async {
    final (trail, at) = await pumpCanvas(tester, onEraseStroke: (_, _) {});
    await tester.tapAt(at(const Offset(200, 200)));
    await tester.pump();
    // begin() emits moveTo+lineTo at one point, which StrokeCap.round
    // rasterises as a full-diameter disc - so a tap shows the brush's size
    // with no special case in the painter.
    expect(trail.pending, hasLength(1));
    expect(
      trail.pending.single.path.getBounds().center,
      const Offset(200, 200),
    );
  });

  testWidgets('no trail when the tool is not Erase', (tester) async {
    final (trail, at) = await pumpCanvas(tester, tool: EditorTool.adjust);
    expect(find.byKey(const ValueKey('erase-trail')), findsNothing);

    final gesture = await tester.startGesture(at(const Offset(200, 200)));
    await tester.pump();
    await gesture.moveBy(const Offset(30, 30));
    await tester.pump();
    expect(trail.live, isNull, reason: 'a drag here moves the layer');
    await gesture.up();
    await tester.pump();
  });

  // ------------------------------------------------------- the ledger alone
  group('EraseTrail ledger', () {
    test('settle returns null with no live stroke', () {
      final trail = EraseTrail();
      addTearDown(trail.dispose);
      expect(trail.settle(), isNull);
      expect(trail.isEmpty, isTrue);
    });

    test('each stroke keeps the radius it was drawn at', () {
      final trail = EraseTrail();
      addTearDown(trail.dispose);
      trail.begin('l1', Offset.zero, 20);
      final first = trail.settle()!;
      // The Brush size slider is live while an apply is in flight, so a second
      // stroke can want a different width - the first must not follow it.
      trail.begin('l1', Offset.zero, 60);
      trail.settle();
      expect(trail.pending.first.radius, 20);
      expect(trail.pending.last.radius, 60);
      expect(first, isNot(trail.pending.last.ticket));
    });

    test('a repaint retires everything up to the mask it carries', () {
      final trail = EraseTrail();
      addTearDown(trail.dispose);
      trail.begin('l1', Offset.zero, 10);
      final a = trail.settle()!;
      trail.begin('l1', Offset.zero, 10);
      final b = trail.settle()!;
      trail.markCommitted(a, '/m/a.png');
      trail.markCommitted(b, '/m/b.png');

      // Strokes are serialised, so b's mask supersedes a's - one repaint
      // retires both rather than leaving the older one stranded.
      trail.paintedFor('l1', '/m/b.png');
      expect(trail.pending, isEmpty);
    });

    test('a repaint for another layer retires nothing', () {
      final trail = EraseTrail();
      addTearDown(trail.dispose);
      trail.begin('l1', Offset.zero, 10);
      final t = trail.settle()!;
      trail.markCommitted(t, '/m/a.png');
      trail.paintedFor('l2', '/m/a.png');
      expect(trail.pending, hasLength(1));
    });

    test('retireIfUncommitted spares a stroke whose pixels are coming', () {
      final trail = EraseTrail();
      addTearDown(trail.dispose);
      trail.begin('l1', Offset.zero, 10);
      final t = trail.settle()!;
      trail.markCommitted(t, '/m/a.png');
      trail.retireIfUncommitted(t);
      expect(
        trail.pending,
        hasLength(1),
        reason: 'committed: the repaint retires it, not the floor',
      );
    });
  });
}
