import 'package:chromis/features/grid/grid_templates.dart';
import 'package:chromis/features/grid/widgets/grid_setup_sheet.dart';
import 'package:chromis/features/home/widgets/new_project_sheet.dart';
import 'package:chromis/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The two steps of the Photo Grid create flow: choosing the document kind, and
/// choosing the photo count / layout / size the collage starts on.
void main() {
  /// Pumps a screen whose only button opens [open], capturing what it returns.
  Future<List<T?>> host<T>(
    WidgetTester tester,
    Future<T?> Function(BuildContext) open,
  ) async {
    final results = <T?>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => results.add(await open(context)),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  group('new project mode sheet', () {
    testWidgets('offers both kinds and returns the tapped one', (tester) async {
      final results = await host(tester, showNewProjectModeSheet);
      expect(find.text('Blank canvas'), findsOneWidget);
      expect(find.text('Photo grid'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('new-project-grid')));
      await tester.pumpAndSettle();
      expect(results, [NewProjectMode.grid]);
    });

    testWidgets('dismissing returns null', (tester) async {
      final results = await host(tester, showNewProjectModeSheet);
      await tester.tapAt(const Offset(400, 40)); // the scrim
      await tester.pumpAndSettle();
      expect(results, [null]);
    });
  });

  group('grid setup sheet', () {
    testWidgets('starts at 2 photos on the first layout and Square', (
      tester,
    ) async {
      final results = await host(tester, showGridSetupSheet);
      expect(find.text('How many photos?'.toUpperCase()), findsOneWidget);
      // One tile per 2-photo layout.
      for (final template in gridTemplatesFor(2)) {
        expect(
          find.byKey(ValueKey('grid-template-${template.label}')),
          findsOneWidget,
        );
      }

      await tester.tap(find.byKey(const ValueKey('grid-setup-create')));
      await tester.pumpAndSettle();

      final result = results.single!;
      expect(result.width, 1080);
      expect(result.height, 1080);
      expect(result.grid.cellCount, 2);
      expect(matchGridTemplate(result.grid.root)?.label, 'Side by side');
    });

    testWidgets('the count swaps the layout strip and resets the choice', (
      tester,
    ) async {
      final results = await host(tester, showGridSetupSheet);

      // Pick a non-default layout, then change the count: the old index means
      // nothing at the new count, so the selection must reset rather than
      // carry over into a different layout.
      await tester.tap(find.byKey(const ValueKey('grid-template-Stacked')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('grid-count-4')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('grid-template-Stacked')), findsNothing);
      expect(find.byKey(const ValueKey('grid-template-2 x 2')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('grid-setup-create')));
      await tester.pumpAndSettle();

      final result = results.single!;
      expect(result.grid.cellCount, 4);
      expect(matchGridTemplate(result.grid.root)?.label, '2 x 2');
      expect(result.grid.cellIds, ['c0', 'c1', 'c2', 'c3']);
    });

    testWidgets('returns the chosen layout and aspect', (tester) async {
      final results = await host(tester, showGridSetupSheet);

      await tester.tap(find.byKey(const ValueKey('grid-count-3')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('grid-template-Big left')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('grid-aspect-Story')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('grid-setup-create')));
      await tester.pumpAndSettle();

      final result = results.single!;
      expect(result.width, 1080);
      expect(result.height, 1920);
      expect(result.grid.cellCount, 3);
      expect(matchGridTemplate(result.grid.root)?.label, 'Big left');
    });
  });
}
