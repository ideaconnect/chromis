import 'package:chromis/core/models/frame.dart';
import 'package:chromis/core/models/layer.dart';
import 'package:chromis/core/models/layer_transform.dart';
import 'package:chromis/core/models/project.dart';
import 'package:chromis/core/theme/app_theme.dart';
import 'package:chromis/core/theme/app_typography.dart';
import 'package:chromis/features/editor/editor_screen.dart';
import 'package:chromis/features/editor/state/editor_controller.dart';
import 'package:chromis/features/editor/state/editor_tool.dart';
import 'package:chromis/features/editor/widgets/editor_canvas.dart';
import 'package:chromis/features/editor/widgets/project_canvas.dart';
import 'package:chromis/features/fonts/custom_fonts.dart';
import 'package:chromis/features/go_pro/iap.dart';
import 'package:chromis/features/home/project_repository.dart';
import 'package:chromis/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/surface.dart';

/// The Text and Bubble panels' font field, and the three places a resize can
/// run out of room and now says so: a pinch at the layer's size limits, a
/// bubble whose caption already fills it, and (in size_sheet_test) a typed
/// canvas size past the cap.
void main() {
  setUp(() {
    ProjectCanvas.fileExists = (_) => false;
    ProjectCanvas.existsCache.clear();
  });
  tearDown(() => ProjectCanvas.fileExists = ProjectCanvas.defaultFileExists);

  Future<ProviderContainer> pumpEditor(
    WidgetTester tester,
    Layer layer, {
    EditorTool tool = EditorTool.text,
  }) async {
    setSurface(tester, const Size(412, 915));
    final container = ProviderContainer(
      overrides: [
        isProProvider.overrideWithValue(true),
        projectRepositoryProvider.overrideWithValue(_NullRepo()),
        customFontsProvider.overrideWith(_NoImports.new),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(editorControllerProvider.notifier);
    controller.loadProject(
      Project.empty(id: 'p').copyWith(
        frames: [
          Frame(id: 'p_f0', layers: [layer]),
        ],
      ),
    );
    // Off, so a pinch is only ever the range's doing and not a snap's.
    controller.snapEnabled = false;
    controller.selectLayer(layer.id);
    controller.setTool(tool);
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

  Layer selected(ProviderContainer c) =>
      c.read(editorControllerProvider).selectedLayer!;

  BubbleLayer bubble({
    String text = 'Hi',
    double fontSize = 26,
    double scale = 1,
  }) => BubbleLayer(
    id: 'b',
    name: 'b',
    text: text,
    fontSize: fontSize,
    transform: LayerTransform(position: const Offset(540, 540), scale: scale),
  );

  Future<void> pick(WidgetTester tester, Key field, String family) async {
    await tester.ensureVisible(find.byKey(field));
    await tester.tap(find.byKey(field));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('font-search')),
      AppFonts.nameOf(family),
    );
    await tester.pump();
    await tester.tap(find.byKey(ValueKey('font-option-$family')));
    await tester.pumpAndSettle();
  }

  group('the font field', () {
    testWidgets('a caption takes the font picked in the sheet', (tester) async {
      final c = await pumpEditor(
        tester,
        const TextLayer(id: 't', name: 't', text: 'Hi', fontFamily: 'Bangers'),
      );
      // One field instead of the old strip of chips, showing the current
      // font by its written name.
      expect(find.byKey(const ValueKey('font-row')), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('font-field')),
          matching: find.text('Bangers'),
        ),
        findsOneWidget,
      );

      await pick(tester, const ValueKey('font-field'), AppFonts.comicNeue);

      expect((selected(c) as TextLayer).fontFamily, AppFonts.comicNeue);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('font-field')),
          matching: find.text('Comic Neue'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a bubble takes the font picked in the sheet', (tester) async {
      final c = await pumpEditor(tester, bubble());
      expect(find.byKey(const ValueKey('bubble-font-row')), findsNothing);

      await pick(tester, const ValueKey('bubble-font-field'), AppFonts.anton);

      expect((selected(c) as BubbleLayer).fontFamily, AppFonts.anton);
    });

    testWidgets('dismissing the sheet changes nothing', (tester) async {
      final c = await pumpEditor(tester, bubble());
      await tester.ensureVisible(
        find.byKey(const ValueKey('bubble-font-field')),
      );
      await tester.tap(find.byKey(const ValueKey('bubble-font-field')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(200, 20));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('font-list')), findsNothing);
      expect((selected(c) as BubbleLayer).fontFamily, AppFonts.bangers);
    });
  });

  group('a bubble caption at the size the bubble allows', () {
    final capped = find.byKey(const ValueKey('bubble-text-capped'));

    testWidgets('says so when Size asks for more than fits', (tester) async {
      await pumpEditor(
        tester,
        bubble(
          text: 'This caption is far too long to fit at the largest size',
          fontSize: 44,
        ),
      );
      await tester.ensureVisible(capped);
      expect(capped, findsOneWidget);
      expect(
        find.text(
          'The text already fills the bubble. To make it bigger, pinch the '
          'bubble.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('and is silent while the caption is drawn at its Size', (
      tester,
    ) async {
      await pumpEditor(tester, bubble());
      expect(capped, findsNothing);
    });
  });

  group('a pinch at the size limit', () {
    final badge = find.byKey(const ValueKey('scale-limit-badge'));

    /// Two fingers on a horizontal line through the canvas centre, the
    /// gesture's own zero settled by a first move (see layer_snap_test), then
    /// moved to [factor] of that span.
    Future<(TestGesture, TestGesture)> pinch(
      WidgetTester tester,
      double factor,
    ) async {
      final centre = tester.getCenter(find.byType(EditorCanvas));
      final left = await tester.startGesture(
        centre - const Offset(100, 0),
        pointer: 101,
      );
      final right = await tester.startGesture(
        centre + const Offset(100, 0),
        pointer: 102,
      );
      // Past the scale slop, or the zero lands on whichever move does pass
      // it: a span of 115 about a focal point 15px left of centre.
      await left.moveBy(const Offset(-30, 0));
      final reach = 115 * (factor - 1);
      await left.moveBy(Offset(-reach, 0));
      await right.moveBy(Offset(reach, 0));
      await tester.pump();
      return (left, right);
    }

    testWidgets('says Maximum size, and lets go of it on release', (
      tester,
    ) async {
      final c = await pumpEditor(
        tester,
        bubble(scale: 5),
        tool: EditorTool.adjust,
      );
      final (left, right) = await pinch(tester, 1.9);

      expect(selected(c).transform.scale, 6.0, reason: 'clamped at the max');
      expect(badge, findsOneWidget);
      expect(find.text('Maximum size'), findsOneWidget);

      await left.up();
      await right.up();
      await tester.pump();
      expect(badge, findsNothing);
    });

    testWidgets('says Minimum size at the other end', (tester) async {
      final c = await pumpEditor(
        tester,
        bubble(scale: 0.25),
        tool: EditorTool.adjust,
      );
      final (left, right) = await pinch(tester, 0.5);

      expect(selected(c).transform.scale, 0.2, reason: 'clamped at the min');
      expect(find.text('Minimum size'), findsOneWidget);
      await left.up();
      await right.up();
      await tester.pump();
    });

    testWidgets('says nothing while the pinch is inside the range', (
      tester,
    ) async {
      final c = await pumpEditor(tester, bubble(), tool: EditorTool.adjust);
      final (left, right) = await pinch(tester, 1.9);

      expect(selected(c).transform.scale, closeTo(1.9, 0.01));
      expect(badge, findsNothing);
      await left.up();
      await right.up();
      await tester.pump();
    });

    testWidgets('and comes off again when the pinch backs away from it', (
      tester,
    ) async {
      await pumpEditor(tester, bubble(scale: 5), tool: EditorTool.adjust);
      final (left, right) = await pinch(tester, 1.9);
      expect(badge, findsOneWidget);
      // Back to 1.1 of the start: 5.5, inside the range again.
      const back = 115 * (1.9 - 1.1);
      await left.moveBy(const Offset(back, 0));
      await right.moveBy(const Offset(-back, 0));
      await tester.pump();
      expect(badge, findsNothing);
      await left.up();
      await right.up();
      await tester.pump();
    });
  });
}

class _NoImports extends CustomFontsController {
  @override
  Future<List<CustomFont>> build() async => const [];
}

class _NullRepo implements ProjectRepository {
  @override
  Future<void> save(Project project) async {}

  @override
  Future<List<Project>> list() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
