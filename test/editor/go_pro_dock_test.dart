import 'package:chromis/core/theme/app_theme.dart';
import 'package:chromis/features/editor/editor_screen.dart';
import 'package:chromis/features/editor/widgets/project_canvas.dart';
import 'package:chromis/features/go_pro/iap.dart';
import 'package:chromis/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/surface.dart';

/// The dock's Go Pro crown.
///
/// It is the only dock entry that isn't a tool, and the only one that is
/// conditional - so the two things worth pinning are that a paying customer
/// never sees it, and that it explains itself instead of jumping straight to a
/// purchase screen from a button that sits in the middle of the tool row.
void main() {
  setUp(() {
    ProjectCanvas.fileExists = (_) => false;
    ProjectCanvas.existsCache.clear();
  });
  tearDown(() => ProjectCanvas.fileExists = ProjectCanvas.defaultFileExists);

  Future<void> pumpEditor(WidgetTester tester, {required bool pro}) async {
    setSurface(tester, const Size(412, 915));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [isProProvider.overrideWithValue(pro)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: darkAppTheme,
          home: const EditorScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  final crown = find.byKey(const ValueKey('dock-Go Pro'));

  testWidgets('a free user gets the crown, first in the dock', (tester) async {
    await pumpEditor(tester, pro: false);
    expect(crown, findsOneWidget);

    // "First" is the claim, so check position rather than mere presence: the
    // crown has to sit left of every tool, not just exist somewhere in the row.
    final crownX = tester.getTopLeft(crown).dx;
    for (final label in ['Add layer', 'Text', 'Layers']) {
      final tool = find.byKey(ValueKey('dock-$label'));
      expect(
        tool,
        findsOneWidget,
        reason: '$label should still be in the dock',
      );
      expect(
        crownX,
        lessThan(tester.getTopLeft(tool).dx),
        reason: 'the crown should come before $label',
      );
    }
  });

  testWidgets('a Pro user never sees it', (tester) async {
    await pumpEditor(tester, pro: true);
    expect(crown, findsNothing);
    // And the tools it sits next to are untouched.
    expect(find.byKey(const ValueKey('dock-Add layer')), findsOneWidget);
  });

  testWidgets('tapping it explains Pro rather than navigating', (tester) async {
    await pumpEditor(tester, pro: false);
    await tester.tap(crown);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.text('One-time purchase, no subscription'), findsOneWidget);
    expect(find.text('No ads, anywhere'), findsOneWidget);
    // Still on the editor - the sheet is over it, nothing was pushed.
    expect(find.byType(EditorScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('go-pro-sheet-cta')), findsOneWidget);
  });

  testWidgets('"Not now" closes it and leaves the editor alone', (
    tester,
  ) async {
    await pumpEditor(tester, pro: false);
    await tester.tap(crown);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.text('No ads, anywhere'), findsNothing);
    expect(tester.takeException(), isNull);
    expect(crown, findsOneWidget);
  });
}
