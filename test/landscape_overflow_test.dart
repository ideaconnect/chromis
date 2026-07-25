import 'package:chromis/core/theme/app_theme.dart';
import 'package:chromis/features/about/about_sheet.dart';
import 'package:chromis/features/editor/editor_screen.dart';
import 'package:chromis/features/editor/widgets/canvas_size_sheet.dart';
import 'package:chromis/features/editor/widgets/project_canvas.dart';
import 'package:chromis/features/grid/widgets/grid_setup_sheet.dart';
import 'package:chromis/features/home/home_screen.dart';
import 'package:chromis/features/home/widgets/app_drawer.dart';
import 'package:chromis/features/home/widgets/new_project_sheet.dart';
import 'package:chromis/features/onboarding/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: buildAppTheme(), home: home),
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
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildAppTheme(),
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

      testWidgets('about sheet', (tester) async {
        await pumpSheet(tester, size, showAboutSheet);
        expect(tester.takeException(), isNull);
        expect(find.text('Open-source licenses'), findsOneWidget);
      });

      testWidgets('navigation drawer', (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final key = GlobalKey<ScaffoldState>();
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: buildAppTheme(),
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
