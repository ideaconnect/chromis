import 'package:chromis/core/models/layer.dart';
import 'package:chromis/core/models/project.dart';
import 'package:chromis/core/theme/app_theme.dart';
import 'package:chromis/core/widgets/sheet_body.dart';
import 'package:chromis/features/about/about_sheet.dart';
import 'package:chromis/features/ads/ad_gate.dart';
import 'package:chromis/features/editor/editor_screen.dart';
import 'package:chromis/features/editor/widgets/bubble_shape_sheet.dart';
import 'package:chromis/features/editor/widgets/canvas_size_sheet.dart';
import 'package:chromis/features/editor/widgets/project_canvas.dart';
import 'package:chromis/features/go_pro/iap.dart';
import 'package:chromis/features/grid/widgets/grid_setup_sheet.dart';
import 'package:chromis/features/home/home_screen.dart';
import 'package:chromis/features/home/widgets/app_drawer.dart';
import 'package:chromis/features/home/widgets/new_project_sheet.dart';
import 'package:chromis/features/home/widgets/project_tile.dart';
import 'package:chromis/features/onboarding/onboarding_screen.dart';
import 'package:chromis/features/settings/settings_screen.dart';
import 'package:chromis/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/surface.dart';

/// Every screen and sheet has to survive a landscape phone.
///
/// The app used to be locked to portrait, so nothing below had ever been laid
/// out in a 412-px-tall window; unlocking rotation turned that into a real user
/// path overnight, and the bottom sheets in particular are sized from content
/// that assumed a tall screen. A fixed-height Column in a short viewport
/// overflows rather than scrolling, which is both an ugly stripe and content
/// the user cannot reach.
void main() {
  setUp(() {
    // Layers point at files that do not exist here; stub the probe so the
    // canvas draws its placeholder instead of stat-ing the disk.
    ProjectCanvas.fileExists = (_) => false;
    ProjectCanvas.existsCache.clear();
  });
  tearDown(() => ProjectCanvas.fileExists = ProjectCanvas.defaultFileExists);

  // A phone in landscape, and a squatter window for headroom.
  const sizes = <String, Size>{
    'landscape phone': Size(915, 412),
    'short window': Size(800, 340),
  };

  Future<void> pumpScreen(WidgetTester tester, Size size, Widget home) async {
    setSurface(tester, size);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: darkAppTheme,
          home: home,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Opens a sheet from a bare scaffold and settles it.
  Future<void> pumpSheet(
    WidgetTester tester,
    Size size,
    void Function(BuildContext) open,
  ) async {
    setSurface(tester, size);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: darkAppTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => open(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Taps a dock/rail button, scrolling it into view first - the dock is a
  /// scroll view and most of its buttons start off-screen in a short window.
  /// The extra pump matters: ensureVisible only moves the offset, layout
  /// catches up on the next frame, so tapping straight after aims at the old
  /// position.
  Future<void> tapDock(WidgetTester tester, String label) async {
    final finder = find.byKey(ValueKey('dock-$label'));
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  for (final entry in sizes.entries) {
    group(entry.key, () {
      final size = entry.value;

      testWidgets('onboarding', (tester) async {
        await pumpScreen(tester, size, const OnboardingScreen());
        expect(tester.takeException(), isNull);
      });

      testWidgets('home', (tester) async {
        await pumpScreen(tester, size, const HomeScreen());
        expect(tester.takeException(), isNull);
      });

      testWidgets('editor', (tester) async {
        await pumpScreen(tester, size, const EditorScreen());
        expect(tester.takeException(), isNull);
      });

      testWidgets('settings', (tester) async {
        await pumpScreen(tester, size, const SettingsScreen());
        expect(tester.takeException(), isNull);
      });

      testWidgets('new-project mode sheet', (tester) async {
        await pumpSheet(tester, size, showNewProjectModeSheet);
        expect(tester.takeException(), isNull);
        expect(find.text('Blank canvas'), findsOneWidget);
      });

      testWidgets('canvas size sheet', (tester) async {
        await pumpSheet(
          tester,
          size,
          (context) => showCanvasSizeSheet(
            context,
            title: 'New project',
            initialWidth: 1080,
            initialHeight: 1080,
          ),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('photo grid setup sheet', (tester) async {
        await pumpSheet(tester, size, showGridSetupSheet);
        expect(tester.takeException(), isNull);
      });

      // Shown to every free user before an ad, so it is on the busiest path in
      // the app - and its two full-width buttons plus the one-time-purchase note
      // are exactly the kind of stack that runs out of room on a short window.
      testWidgets('ad gate sheet', (tester) async {
        await pumpSheet(
          tester,
          size,
          (context) => showModalBottomSheet<AdGateChoice>(
            context: context,
            isScrollControlled: true,
            builder: (_) => const AdGateSheet(
              title: 'Unlock AI tools',
              message:
                  'Watch a short ad to use the AI tools for the rest of this '
                  'editing session. Go Pro to use them without ads, forever.',
              watchLabel: 'Watch & unlock',
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('ad-gate-watch')), findsOneWidget);
        expect(find.byKey(const ValueKey('ad-gate-go-pro')), findsOneWidget);
      });

      testWidgets('about sheet', (tester) async {
        await pumpSheet(tester, size, showAboutSheet);
        expect(tester.takeException(), isNull);
        expect(find.text('Open-source licenses'), findsOneWidget);
      });

      // The editor's own sheets, which are opened from inside the screen
      // rather than by a top-level `show…Sheet` function. The crop sheet
      // shipped as a bare Column with no SafeArea, so its ratio chips sat
      // under the system gesture bar even in portrait.
      testWidgets('crop sheet', (tester) async {
        await pumpScreen(tester, size, const EditorScreen());
        await tapDock(tester, 'Crop');
        expect(tester.takeException(), isNull);
        expect(find.text('Crop to ratio'), findsOneWidget);
        expect(find.byType(SheetBody), findsOneWidget);
      });

      testWidgets('go pro sheet', (tester) async {
        // Needs the free path - the crown is not in a Pro user's dock.
        setSurface(tester, size);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [isProProvider.overrideWithValue(false)],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: darkAppTheme,
              home: const EditorScreen(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));
        await tapDock(tester, 'Go Pro');
        expect(tester.takeException(), isNull);
        expect(find.text('No ads, anywhere'), findsOneWidget);
        expect(find.byType(SheetBody), findsOneWidget);
      });

      // Five drawn tiles plus a blurb each - the sheet a landscape phone is
      // most likely to run out of room on.
      testWidgets('bubble format picker', (tester) async {
        await pumpSheet(tester, size, showBubbleShapeSheet);
        expect(tester.takeException(), isNull);
        expect(find.byType(SheetBody), findsOneWidget);
        for (final shape in BubbleShape.values) {
          expect(
            find.byKey(ValueKey('bubble-format-${shape.name}')),
            findsOneWidget,
            reason: '${shape.name} should be offered when adding a bubble',
          );
        }
      });

      // And the panel that picking one opens: its format row is a second set of
      // drawn tiles stacked above the caption field, font row and sliders.
      testWidgets('bubble panel', (tester) async {
        await pumpScreen(tester, size, const EditorScreen());
        await tapDock(tester, 'Bubble');
        await tester.tap(find.byKey(const ValueKey('bubble-format-thought')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
        expect(find.text('Comic bubble'), findsOneWidget);
        expect(find.byKey(const ValueKey('bubble-shape-row')), findsOneWidget);
      });

      testWidgets('add-layer menu', (tester) async {
        await pumpScreen(tester, size, const EditorScreen());
        await tapDock(tester, 'Layers');
        await tester.tap(find.text('Add'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
        expect(find.text('Add bubble'), findsOneWidget);
        expect(find.byType(SheetBody), findsOneWidget);
      });

      testWidgets('project tile menu', (tester) async {
        setSurface(tester, size);
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: darkAppTheme,
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 160,
                    height: 200,
                    child: ProjectTile(
                      project: Project.empty(
                        id: 'p',
                        createdAt: DateTime(2026),
                      ),
                      radius: 16,
                      onTap: () {},
                      onRename: () {},
                      onDuplicate: () {},
                      onDelete: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.longPress(find.byType(ProjectTile));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
        expect(find.text('Duplicate'), findsOneWidget);
        expect(find.byType(SheetBody), findsOneWidget);
      });

      testWidgets('navigation drawer', (tester) async {
        setSurface(tester, size);
        final key = GlobalKey<ScaffoldState>();
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: darkAppTheme,
              home: Scaffold(
                key: key,
                drawer: const AppDrawer(),
                body: const SizedBox.expand(),
              ),
            ),
          ),
        );
        key.currentState!.openDrawer();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
        // A fixed-width drawer plus the test font (every glyph one em wide)
        // also makes this a decent proxy for a large system font scale.
        // The footer stays reachable rather than being pushed off the bottom.
        expect(find.textContaining('IDCT'), findsOneWidget);
      });
    });
  }
}
