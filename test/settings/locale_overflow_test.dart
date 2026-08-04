import 'package:chromis/core/models/project.dart';
import 'package:chromis/core/theme/app_theme.dart';
import 'package:chromis/features/editor/editor_screen.dart';
import 'package:chromis/features/editor/state/editor_controller.dart';
import 'package:chromis/features/editor/widgets/project_canvas.dart';
import 'package:chromis/features/export/export_screen.dart';
import 'package:chromis/features/go_pro/go_pro_screen.dart';
import 'package:chromis/features/go_pro/iap.dart';
import 'package:chromis/features/home/home_screen.dart';
import 'package:chromis/features/home/widgets/app_drawer.dart';
import 'package:chromis/features/onboarding/onboarding_screen.dart';
import 'package:chromis/features/settings/settings_screen.dart';
import 'package:chromis/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/surface.dart';

/// Every screen has to survive every language, not just English.
///
/// German runs 10-35% longer than English and Polish has its own long
/// compounds, so a row that fits in English can overflow in translation - and
/// the rest of the suite pumps everything in the default locale, which means a
/// translated string that does not fit is invisible to it. This file is the
/// automated half of "look at it on a device in German"; the manual half is
/// still worth doing for anything it flags as merely ugly rather than broken.
///
/// It asserts NO OVERFLOW, not exact layout: what a translation must never do
/// is put content somewhere the user cannot reach.
void main() {
  setUp(() {
    ProjectCanvas.fileExists = (_) => false;
    ProjectCanvas.existsCache.clear();
  });
  tearDown(() => ProjectCanvas.fileExists = ProjectCanvas.defaultFileExists);

  /// The shapes that leave the least room for a longer word.
  ///
  /// 360dp is the one that matters most: it is the commonest small-phone width,
  /// and the editor top bar used to overflow there by 12px even in English -
  /// four 48dp icon buttons plus the Export pill left the project title 6.5dp,
  /// and the title row's own 18dp of pencil-and-gap could not shrink into it.
  /// Now that the bar reserves room for the title and the pencil drops out when
  /// there is none, this size belongs in the sweep.
  const sizes = <String, Size>{
    'narrow phone': Size(360, 780),
    'phone': Size(412, 915),
    'landscape phone': Size(915, 412),
  };

  Project populated() => Project.empty(id: 'p1', name: 'Projekt');

  Future<void> pump(
    WidgetTester tester,
    Locale locale,
    Size size,
    Widget home, {
    Project? project,
  }) async {
    setSurface(tester, size);
    await tester.pumpWidget(
      ProviderScope(
        // Pro hides the Home ad slot, whose platform channel is unimplemented
        // here - this file is about text fitting, not about ad loading.
        overrides: [isProProvider.overrideWithValue(true)],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: darkAppTheme,
          home: home,
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
  }

  // Every language the app ships, so adding one to supportedLocales puts it
  // under these checks automatically.
  for (final locale in AppLocalizations.supportedLocales) {
    group(locale.languageCode, () {
      for (final entry in sizes.entries) {
        final size = entry.value;

        testWidgets('home fits a ${entry.key}', (tester) async {
          await pump(tester, locale, size, const HomeScreen());
          expect(tester.takeException(), isNull);
        });

        testWidgets('editor fits a ${entry.key}', (tester) async {
          await pump(
            tester,
            locale,
            size,
            const EditorScreen(),
            project: populated(),
          );
          expect(tester.takeException(), isNull);
        });

        testWidgets('settings fits a ${entry.key}', (tester) async {
          await pump(tester, locale, size, const SettingsScreen());
          expect(tester.takeException(), isNull);
        });

        testWidgets('onboarding fits a ${entry.key}', (tester) async {
          await pump(tester, locale, size, const OnboardingScreen());
          expect(tester.takeException(), isNull);
        });

        testWidgets('go pro fits a ${entry.key}', (tester) async {
          await pump(tester, locale, size, const GoProScreen());
          expect(tester.takeException(), isNull);
        });

        testWidgets('export fits a ${entry.key}', (tester) async {
          await pump(
            tester,
            locale,
            size,
            const ExportScreen(),
            project: populated(),
          );
          expect(tester.takeException(), isNull);
        });

        testWidgets('the drawer fits a ${entry.key}', (tester) async {
          await pump(
            tester,
            locale,
            size,
            const Scaffold(drawer: AppDrawer(), body: SizedBox.shrink()),
          );
          // The drawer is a fixed 304dp whatever the screen is, so its rows are
          // where a long translated label runs out of room first.
          final state = tester.state<ScaffoldState>(find.byType(Scaffold));
          state.openDrawer();
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull);
        });
      }
    });
  }
}
