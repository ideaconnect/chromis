import 'package:chromis/core/models/frame.dart';
import 'package:chromis/core/models/layer.dart';
import 'package:chromis/core/models/layer_transform.dart';
import 'package:chromis/core/models/project.dart';
import 'package:chromis/core/theme/app_theme.dart';
import 'package:chromis/features/editor/editor_screen.dart';
import 'package:chromis/features/editor/state/editor_controller.dart';
import 'package:chromis/features/editor/widgets/project_canvas.dart';
import 'package:chromis/features/export/export_screen.dart';
import 'package:chromis/features/go_pro/go_pro_screen.dart';
import 'package:chromis/features/go_pro/iap.dart';
import 'package:chromis/features/home/all_projects_screen.dart';
import 'package:chromis/features/home/home_screen.dart';
import 'package:chromis/features/onboarding/onboarding_screen.dart';
import 'package:chromis/features/settings/settings_screen.dart';
import 'package:chromis/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/surface.dart';

/// Every screen has to survive the system font being turned up.
///
/// Android lets a user scale text to 2x, and that is not a rare setting - it is
/// what anyone with poor eyesight runs all the time. Every screen but one is a
/// ListView and simply scrolls further; the EDITOR is the exception, because a
/// canvas app cannot scroll its canvas away, so it is laid out as a fixed
/// Column of top bar / canvas / panel / dock. That Column is the only place in
/// the app where growing text can push content off the bottom of the screen,
/// and it did: at 2x the top bar's "0 layers · auto-saved" wrapped into eight
/// lines inside a 56dp-wide column and the body overflowed.
///
/// The two fixes this pins are structural rather than cosmetic, which is why
/// they hold at 3x as well as 2x:
///   - the top bar's secondary line is capped to one ellipsized line, so the
///     chrome cannot grow without bound;
///   - the tool panel's cap is half of the space that is LEFT after the top bar
///     and dock, not half of the whole viewport, so it cannot claim room the
///     chrome has already taken.
void main() {
  setUp(() {
    ProjectCanvas.fileExists = (_) => false;
    ProjectCanvas.existsCache.clear();
  });
  tearDown(() => ProjectCanvas.fileExists = ProjectCanvas.defaultFileExists);

  /// A project with content: an empty editor exercises none of the panel.
  Project populated() => const Project(
    id: 'p1',
    name: 'Untitled',
    frames: [
      Frame(
        id: 'f0',
        layers: [
          ImageLayer(
            id: 'l0',
            name: 'Photo',
            assetPath: '/nope.png',
            transform: LayerTransform(position: Offset(400, 400)),
          ),
          TextLayer(
            id: 'l1',
            name: 'Caption',
            text: 'Caption',
            fontFamily: 'Manrope',
            transform: LayerTransform(position: Offset(400, 200)),
          ),
        ],
      ),
    ],
  );

  Future<List<FlutterErrorDetails>> pump(
    WidgetTester tester,
    Widget home, {
    required double scale,
    required Locale locale,
    Project? project,
  }) async {
    final captured = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = captured.add;

    setSurface(tester, const Size(360, 780));
    await tester.pumpWidget(
      ProviderScope(
        // Pro hides the Home ad slot, whose platform channel is unimplemented
        // here; this file is about text fitting, not ad loading.
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
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: home,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    if (project != null) {
      ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
        listen: false,
      ).read(editorControllerProvider.notifier).loadProject(project);
      await tester.pump(const Duration(milliseconds: 400));
    }
    FlutterError.onError = previous;
    return captured;
  }

  String describe(List<FlutterErrorDetails> errors) =>
      errors.map((d) => d.exception.toString().split('\n').first).join('; ');

  final screens = <String, Widget Function()>{
    'home': () => const HomeScreen(),
    'editor': () => const EditorScreen(),
    'settings': () => const SettingsScreen(),
    'onboarding': () => const OnboardingScreen(),
    'go pro': () => const GoProScreen(),
    'export': () => const ExportScreen(),
    'all projects': () => const AllProjectsScreen(),
  };

  // 2.0 is Android's largest font setting; 1.5 is the common one. English is
  // the shortest wording we ship; German and Spanish are the two that run
  // longest, and a label only clips once it is both long AND scaled up.
  for (final scale in [1.5, 2.0]) {
    for (final locale in const [Locale('en'), Locale('de'), Locale('es')]) {
      group('${scale}x ${locale.languageCode}', () {
        for (final entry in screens.entries) {
          testWidgets('${entry.key} fits', (tester) async {
            final errors = await pump(
              tester,
              entry.value(),
              scale: scale,
              locale: locale,
              project: entry.key == 'editor' || entry.key == 'export'
                  ? populated()
                  : null,
            );
            expect(errors, isEmpty, reason: describe(errors));
            tester.takeException();
          });
        }
      });
    }
  }

  testWidgets('the editor still holds at an extreme 3x', (tester) async {
    // Not a setting Android offers, but it proves the fix is structural: if
    // anything here were a tuned constant it would fail well before this.
    final errors = await pump(
      tester,
      const EditorScreen(),
      scale: 3.0,
      locale: const Locale('de'),
      project: populated(),
    );
    expect(errors, isEmpty, reason: describe(errors));
    tester.takeException();
  });

  testWidgets('the tool panel yields to the chrome, not the other way', (
    tester,
  ) async {
    // The regression was the panel taking half of the WHOLE viewport while the
    // top bar and dock grew underneath it. Its cap must fall as the text scale
    // rises, otherwise the three of them stop fitting together.
    double panelHeight(WidgetTester tester) =>
        tester.getSize(find.byKey(const ValueKey('tool-panel'))).height;

    await pump(
      tester,
      const EditorScreen(),
      scale: 1.0,
      locale: const Locale('en'),
      project: populated(),
    );
    tester.takeException();
    final atNormal = panelHeight(tester);

    await pump(
      tester,
      const EditorScreen(),
      scale: 2.0,
      locale: const Locale('en'),
      project: populated(),
    );
    tester.takeException();
    final atLarge = panelHeight(tester);

    // It may still grow with its own content; what it may not do is exceed
    // half of what is left once the chrome has taken its share.
    expect(atLarge, lessThan(300));
    expect(atNormal, lessThanOrEqualTo(300));
  });
}
