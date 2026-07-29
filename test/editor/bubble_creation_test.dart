import 'package:chromis/core/models/layer.dart';
import 'package:chromis/core/theme/app_colors.dart';
import 'package:chromis/core/theme/app_theme.dart';
import 'package:chromis/features/editor/editor_screen.dart';
import 'package:chromis/features/editor/state/editor_controller.dart';
import 'package:chromis/features/editor/widgets/bubble_shape_sheet.dart';
import 'package:chromis/features/editor/widgets/project_canvas.dart';
import 'package:chromis/features/go_pro/iap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/surface.dart';

/// Adding a comic bubble.
///
/// Two things were wrong and both are user-visible: only the default format was
/// reachable at creation (the other four lived in a panel you had to find
/// first), and a bubble arrived with no acknowledgement under a panel headed
/// "Text" while the dock lit up "Text" - so it read as "the Text tool opened",
/// not "a bubble was added".
void main() {
  setUp(() {
    // Layers point at files that do not exist here; stub the probe so the
    // canvas draws its placeholder instead of stat-ing the disk.
    ProjectCanvas.fileExists = (_) => false;
    ProjectCanvas.existsCache.clear();
  });
  tearDown(() => ProjectCanvas.fileExists = ProjectCanvas.defaultFileExists);

  Future<void> pumpEditor(WidgetTester tester, {double textScale = 1.0}) async {
    setSurface(tester, const Size(412, 915));
    await tester.pumpWidget(
      ProviderScope(
        // Pro so the crown is out of the dock - this is about the Bubble entry,
        // not about how far along the row it sits.
        overrides: [isProProvider.overrideWithValue(true)],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: const EditorScreen(),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> tapDock(WidgetTester tester, String label) async {
    final finder = find.byKey(ValueKey('dock-$label'));
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  List<Layer> layersOf(WidgetTester tester) => ProviderScope.containerOf(
    tester.element(find.byType(EditorScreen)),
    listen: false,
  ).read(editorControllerProvider).layers;

  /// The dock button's own 44x44 tile colour - cyan is the "this is what the
  /// panel is showing" fill.
  Color dockTint(WidgetTester tester, String label) {
    final box = tester.widget<Container>(
      find
          .descendant(
            of: find.byKey(ValueKey('dock-$label')),
            matching: find.byType(Container),
          )
          .first,
    );
    return (box.decoration! as BoxDecoration).color!;
  }

  testWidgets('the Bubble tool offers every format, drawn', (tester) async {
    await pumpEditor(tester);
    await tapDock(tester, 'Bubble');

    expect(tester.takeException(), isNull);
    expect(find.text('Add a bubble'), findsOneWidget);
    for (final shape in BubbleShape.values) {
      expect(
        find.byKey(ValueKey('bubble-format-${shape.name}')),
        findsOneWidget,
        reason: '${shape.name} should be offered when adding a bubble',
      );
    }
    // Drawn by the real painter, not described in words - "Caption" and
    // "Shout" told nobody which silhouette they would get.
    expect(find.byType(BubbleShapeThumb), findsNWidgets(5));
    // And nothing is created until one is chosen.
    expect(layersOf(tester).whereType<BubbleLayer>(), isEmpty);
  });

  for (final shape in BubbleShape.values) {
    testWidgets('picking ${shape.name} creates a ${shape.name} bubble', (
      tester,
    ) async {
      await pumpEditor(tester);
      await tapDock(tester, 'Bubble');
      await tester.tap(find.byKey(ValueKey('bubble-format-${shape.name}')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      final bubbles = layersOf(tester).whereType<BubbleLayer>();
      expect(bubbles, hasLength(1));
      expect(
        bubbles.single.shape,
        shape,
        reason: 'the chosen format, not the default, should be created',
      );
    });
  }

  testWidgets('dismissing the picker adds nothing', (tester) async {
    await pumpEditor(tester);
    await tapDock(tester, 'Bubble');
    // Prove the sheet was actually up first - otherwise a picker that never
    // opened would pass this test by doing nothing at all.
    expect(find.text('Add a bubble'), findsOneWidget);

    // The scrim above the sheet - how a bottom sheet is cancelled by hand.
    await tester.tapAt(const Offset(20, 10));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Add a bubble'), findsNothing);
    expect(layersOf(tester).whereType<BubbleLayer>(), isEmpty);
    expect(find.byType(EditorScreen), findsOneWidget);
  });

  testWidgets('the Add-layer menu reaches the same picker', (tester) async {
    await pumpEditor(tester);
    await tapDock(tester, 'Layers');
    await tester.tap(find.text('Add'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Add bubble'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The second entry point must ask too, not fall back to a default bubble.
    expect(find.text('Add a bubble'), findsOneWidget);
    expect(layersOf(tester).whereType<BubbleLayer>(), isEmpty);

    await tester.tap(find.byKey(const ValueKey('bubble-format-caption')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(
      layersOf(tester).whereType<BubbleLayer>().single.shape,
      BubbleShape.caption,
    );
  });

  testWidgets('a new bubble says so instead of looking like the Text tool', (
    tester,
  ) async {
    await pumpEditor(tester);
    final idleBubbleTint = dockTint(tester, 'Bubble');

    await tapDock(tester, 'Bubble');
    await tester.tap(find.byKey(const ValueKey('bubble-format-shout')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The toast and the panel title both name the bubble, and neither says
    // "Text" - which is what made the added layer easy to miss.
    expect(
      find.text('Shout bubble added - edit it in the panel'),
      findsOneWidget,
    );
    expect(find.text('Comic bubble'), findsOneWidget);

    // The dock badges Bubble rather than lighting it like a selected tool:
    // Bubble is an action whose next tap adds a SECOND bubble, so it must not
    // wear the cyan that means "this mode is on".
    final badged = dockTint(tester, 'Bubble');
    expect(badged, isNot(idleBubbleTint));
    expect(badged, isNot(AppColors.cyan));
    expect(badged, AppColors.pink.withValues(alpha: 0.16));
    // And Text stays honestly lit - it IS the tool holding this panel, which
    // is what the landscape fold-on-retap acts on.
    expect(dockTint(tester, 'Text'), AppColors.cyan);
  });

  testWidgets('the panel opens on the format that was just picked', (
    tester,
  ) async {
    await pumpEditor(tester);
    await tapDock(tester, 'Bubble');
    // Whisper is the fifth of five - past the fold at phone width, so a row
    // left at offset 0 would not even build its tile.
    await tester.tap(find.byKey(const ValueKey('bubble-format-whisper')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final tile = find.byKey(const ValueKey('bubble-shape-whisper'));
    expect(
      tile,
      findsOneWidget,
      reason: 'the chosen format should be scrolled into the row',
    );
    final rect = tester.getRect(tile);
    final row = tester.getRect(find.byKey(const ValueKey('bubble-shape-row')));
    expect(rect.left, greaterThanOrEqualTo(row.left - 0.5));
    expect(rect.right, lessThanOrEqualTo(row.right + 0.5));
  });

  // The format row must give its tiles a fixed cross-axis extent, and a
  // hard-coded one overflowed the moment Android's font size left "Default" -
  // the tile ends in a text label. Pumped in isolation on purpose: the editor
  // screen has its own, pre-existing large-font overflows (the top bar, the
  // outer column) that would mask what this is guarding.
  for (final scale in [1.0, 1.15, 1.3, 1.5, 1.6, 1.8, 2.0]) {
    for (final blurb in [false, true]) {
      testWidgets('the tile fits its measured height at text scale $scale'
          '${blurb ? ' with a description' : ''}', (tester) async {
        setSurface(tester, const Size(412, 915));
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  // Scrolled: five tiles are wider than the surface, and a
                  // horizontal overflow of the harness's own Row would be
                  // mistaken for the vertical one under test.
                  body: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Builder(
                      builder: (inner) => Row(
                        children: [
                          for (final shape in BubbleShape.values)
                            SizedBox(
                              width: blurb ? 165 : 92,
                              height: bubbleShapeTileHeight(
                                inner,
                                thumbWidth: blurb ? 88 : 68,
                                showBlurb: blurb,
                              ),
                              child: BubbleShapeTile(
                                shape: shape,
                                thumbWidth: blurb ? 88 : 68,
                                showBlurb: blurb,
                                onTap: () {},
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('the panel can still change the format afterwards', (
    tester,
  ) async {
    await pumpEditor(tester);
    await tapDock(tester, 'Bubble');
    await tester.tap(find.byKey(const ValueKey('bubble-format-speech')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final row = find.byKey(const ValueKey('bubble-shape-row'));
    expect(row, findsOneWidget);
    final thought = find.byKey(const ValueKey('bubble-shape-thought'));
    await tester.ensureVisible(thought);
    await tester.pump();
    await tester.tap(thought);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(
      layersOf(tester).whereType<BubbleLayer>().single.shape,
      BubbleShape.thought,
    );
    // Reshaped, not duplicated.
    expect(layersOf(tester).whereType<BubbleLayer>(), hasLength(1));
  });

  test('every format has a distinct name and description', () {
    final labels = BubbleShape.values.map(bubbleShapeLabel).toSet();
    final blurbs = BubbleShape.values.map(bubbleShapeBlurb).toSet();
    expect(labels, hasLength(BubbleShape.values.length));
    expect(blurbs, hasLength(BubbleShape.values.length));
  });
}
