import 'package:chromis/core/models/project.dart';
import 'package:chromis/core/theme/app_theme.dart';
import 'package:chromis/core/widgets/sheet_body.dart';
import 'package:chromis/features/editor/editor_screen.dart';
import 'package:chromis/features/editor/state/editor_controller.dart';
import 'package:chromis/features/editor/widgets/project_canvas.dart';
import 'package:chromis/features/home/home_screen.dart';
import 'package:chromis/features/home/widgets/new_project_sheet.dart';
import 'package:chromis/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/surface.dart';

/// Things that must hug their content instead of filling the space offered.
///
/// This whole file exists because of one mistake made three times: wrapping a
/// bottom-anchored box in `ResponsiveCenter` to cap its WIDTH. Its `Center`
/// also takes all the HEIGHT it is offered, so a bottom sheet became a
/// near-full-height panel with its content floating in the middle, the editor's
/// tool panel reserved its 300-px cap for a two-line empty state, and the Home
/// ad slot swallowed the entire page.
///
/// Every one of those looked right in review and passed the layout tests, which
/// only asserted "no overflow" and "this widget exists". Height is the thing to
/// assert.
void main() {
  setUp(() {
    ProjectCanvas.fileExists = (_) => false;
    ProjectCanvas.existsCache.clear();
  });
  tearDown(() => ProjectCanvas.fileExists = ProjectCanvas.defaultFileExists);

  const tablet = Size(1280, 800);
  const phone = Size(412, 915);

  for (final entry in const {'a tablet': tablet, 'a phone': phone}.entries) {
    testWidgets('a bottom sheet on ${entry.key} is as tall as its content', (
      tester,
    ) async {
      final size = entry.value;
      setSurface(tester, size);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: darkAppTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showNewProjectModeSheet(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final height = tester.getSize(find.byType(SheetBody)).height;
      expect(
        height,
        lessThan(size.height * 0.6),
        reason:
            'the two-card sheet took ${height.round()}px of ${size.height} - '
            'it is hugging the offered height instead of its content',
      );
      // And it is still anchored to the bottom, not floating mid-screen.
      expect(
        tester.getBottomRight(find.byType(SheetBody)).dy,
        closeTo(size.height, 1),
      );
    });
  }

  testWidgets('the editor tool panel hugs a short empty state', (tester) async {
    setSurface(tester, const Size(800, 1280)); // tablet portrait
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(editorControllerProvider.notifier)
        .loadProject(Project.empty(id: 'p'));
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
    await tester.pumpAndSettle();

    // The Adjust panel with nothing selected is a title plus two lines. Its
    // SURFACE is what must hug that - the scroll view inside shrink-wraps
    // either way, so measuring it proves nothing.
    expect(find.textContaining('Select a layer'), findsOneWidget);
    final height = tester
        .getSize(find.byKey(const ValueKey('tool-panel')))
        .height;
    expect(
      height,
      lessThan(200),
      reason:
          'the empty state reserved ${height.round()}px - the panel is '
          'hugging its height cap instead of its content',
    );
  });

  testWidgets('the Home ad slot does not swallow the page', (tester) async {
    setSurface(tester, tablet);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: darkAppTheme,
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    // The page content is what must survive - the slot itself is hidden
    // without a loaded ad, so assert on the body rather than on the banner.
    expect(
      find.text('New project'),
      findsOneWidget,
      reason: 'a bottom slot that expands pushes the whole body off screen',
    );
  });
}
