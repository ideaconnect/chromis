import 'package:chromis/core/models/project.dart';
import 'package:chromis/core/theme/app_theme.dart';
import 'package:chromis/core/widgets/gradient_button.dart';
import 'package:chromis/features/editor/editor_screen.dart';
import 'package:chromis/features/editor/state/editor_controller.dart';
import 'package:chromis/features/editor/widgets/project_canvas.dart';
import 'package:chromis/features/go_pro/iap.dart';
import 'package:chromis/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/surface.dart';

/// The editor top bar has to hold its own content on a small phone.
///
/// It used to overflow by 12px at 360dp - the commonest small-phone width - in
/// English, before any translation was involved: four 48dp icon buttons (192dp)
/// and the Export pill (139dp) left the project title 6.5dp, and the title
/// row's non-shrinkable 5px gap + 13px rename pencil then spilled out of it.
///
/// The fix is that the bar reserves width for the title and lets the Export
/// label ellipsize into what is left, and that the pencil drops out when the
/// title area is too narrow to decorate. These tests pin the MECHANISM, not
/// just the absence of a stripe: a later change that restores a fixed-width
/// Export or an unconditional pencil brings the overflow straight back, and
/// "no exception at 360dp" alone would not say why.
void main() {
  setUp(() {
    ProjectCanvas.fileExists = (_) => false;
    ProjectCanvas.existsCache.clear();
  });
  tearDown(() => ProjectCanvas.fileExists = ProjectCanvas.defaultFileExists);

  Future<void> pumpEditor(
    WidgetTester tester, {
    required Size size,
    double textScale = 1.0,
    Locale locale = const Locale('en'),
  }) async {
    setSurface(tester, size);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [isProProvider.overrideWithValue(true)],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: darkAppTheme,
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
    ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp)),
          listen: false,
        )
        .read(editorControllerProvider.notifier)
        .loadProject(Project.empty(id: 'p1'));
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Horizontal overflow only. A large text scale also overflows the editor
  /// body VERTICALLY, which is a separate, still-open problem (the body does
  /// not scroll); asserting on it here would make this file fail for something
  /// it is not about.
  int horizontalOverflows(List<FlutterErrorDetails> errors) => errors
      .where((d) => d.exception.toString().contains('on the right'))
      .length;

  Future<List<FlutterErrorDetails>> collect(
    Future<void> Function() body,
  ) async {
    final captured = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = captured.add;
    await body();
    FlutterError.onError = previous;
    return captured;
  }

  group('360dp', () {
    for (final locale in const [Locale('en'), Locale('de'), Locale('pl')]) {
      testWidgets('the top bar fits in ${locale.languageCode}', (tester) async {
        final errors = await collect(
          () => pumpEditor(tester, size: const Size(360, 780), locale: locale),
        );
        expect(horizontalOverflows(errors), 0);
        tester.takeException();
      });
    }

    testWidgets('the title keeps room rather than being crushed', (
      tester,
    ) async {
      await pumpEditor(tester, size: const Size(360, 780));
      tester.takeException();

      // The regression was the title being squeezed to 6.5dp. It does not have
      // to be generous, but it has to be more than the row's own furniture.
      final title = find.text('Untitled');
      expect(title, findsOneWidget);
      expect(tester.getSize(title).width, greaterThan(18));
    });

    testWidgets('the secondary buttons really are 40dp wide', (tester) async {
      // Asserting the RENDERED width, not the constraint: IconButton defaults
      // to MaterialTapTargetSize.padded, which quietly pads a 40dp button back
      // out to 48 and made the first version of this fix a no-op - the width
      // was reserved on paper and taken back by the framework.
      await pumpEditor(tester, size: const Size(360, 780));
      tester.takeException();

      for (final icon in const [Icons.aspect_ratio, Icons.undo, Icons.redo]) {
        final button = find.ancestor(
          of: find.byIcon(icon),
          matching: find.byType(IconButton),
        );
        final size = tester.getSize(button.first);
        expect(size.width, 40, reason: '$icon should be 40dp wide');
        // The touch target keeps its full height - only width was traded.
        expect(size.height, greaterThanOrEqualTo(48));
      }
    });

    testWidgets('Export gives up label width instead of overflowing', (
      tester,
    ) async {
      await pumpEditor(tester, size: const Size(360, 780));
      tester.takeException();

      // Capped, not intrinsic: at 412dp the same button is wider. If a later
      // change drops the cap this stays at its intrinsic width and the title
      // loses the space again.
      final narrow = tester.getSize(find.byType(GradientButton)).width;

      await pumpEditor(tester, size: const Size(412, 915));
      tester.takeException();
      final wide = tester.getSize(find.byType(GradientButton)).width;

      expect(narrow, lessThan(wide));
    });
  });

  testWidgets('the rename pencil drops out when the title has no room', (
    tester,
  ) async {
    // 320dp with a doubled text scale is past the point where a pencil is
    // decorating anything; it must disappear rather than clip the row.
    final errors = await collect(
      () => pumpEditor(tester, size: const Size(320, 780), textScale: 2.0),
    );
    expect(
      horizontalOverflows(errors),
      0,
      reason: 'the title row must never be the thing that overflows',
    );
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    tester.takeException();
  });

  testWidgets('the pencil is still there when there is room', (tester) async {
    await pumpEditor(tester, size: const Size(412, 915));
    tester.takeException();
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
  });
}
