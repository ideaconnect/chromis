import 'package:chromis/core/models/project.dart';
import 'package:chromis/core/theme/app_theme.dart';
import 'package:chromis/core/widgets/responsive_center.dart';
import 'package:chromis/features/editor/editor_screen.dart';
import 'package:chromis/features/editor/state/editor_controller.dart';
import 'package:chromis/features/editor/widgets/editor_canvas.dart';
import 'package:chromis/features/editor/widgets/project_canvas.dart';
import 'package:chromis/features/go_pro/go_pro_screen.dart';
import 'package:chromis/features/onboarding/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/surface.dart';

/// Tablet layout, with the phone as the control group.
///
/// Every test here comes in pairs: the tablet gets the wider treatment, and the
/// phone renders exactly what it rendered before. That second half is the point
/// - phones are the priority, so a tablet win that moves a phone pixel is a
/// regression, and the gate ([isTabletWidth]) is deliberately measured on the
/// SHORTEST side so a phone held sideways is still a phone.
void main() {
  setUp(() {
    ProjectCanvas.fileExists = (_) => false;
    ProjectCanvas.existsCache.clear();
  });
  tearDown(() => ProjectCanvas.fileExists = ProjectCanvas.defaultFileExists);

  const phonePortrait = Size(412, 915);
  const phoneLandscape = Size(915, 412);
  const tabletPortrait = Size(800, 1280);
  const tabletLandscape = Size(1280, 800);

  Future<void> pump(WidgetTester tester, Size size, Widget home) async {
    setSurface(tester, size);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: buildAppTheme(), home: home),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> pumpEditor(
    WidgetTester tester,
    Size size, {
    bool withPhoto = false,
  }) async {
    setSurface(tester, size);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(editorControllerProvider.notifier);
    controller.loadProject(Project.empty(id: 'p'));
    // The Adjust panel only shows its sliders for a selected photo layer.
    if (withPhoto) controller.addImageLayer(assetPath: '/fake/photo.png');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: buildAppTheme(), home: const EditorScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('isTabletWidth', () {
    Future<bool> gateAt(WidgetTester tester, Size size) async {
      late bool result;
      setSurface(tester, size);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              result = isTabletWidth(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return result;
    }

    testWidgets('a phone is a phone in either orientation', (tester) async {
      expect(await gateAt(tester, phonePortrait), isFalse);
      expect(
        await gateAt(tester, phoneLandscape),
        isFalse,
        reason: 'a 915-wide phone must not be mistaken for a tablet',
      );
    });

    testWidgets('a tablet is a tablet in either orientation', (tester) async {
      expect(await gateAt(tester, tabletPortrait), isTrue);
      expect(await gateAt(tester, tabletLandscape), isTrue);
    });

    testWidgets('the boundary is the shortest side, at 600', (tester) async {
      expect(await gateAt(tester, const Size(599, 2000)), isFalse);
      expect(await gateAt(tester, const Size(600, 2000)), isTrue);
    });
  });

  group('editor canvas', () {
    testWidgets('a tablet in portrait gets the width, a phone keeps 460', (
      tester,
    ) async {
      await pumpEditor(tester, tabletPortrait);
      final onTablet = tester.getSize(find.byType(EditorCanvas)).width;
      expect(
        onTablet,
        greaterThan(600),
        reason: 'the 460 cap is a phone number; a tablet has room to spare',
      );

      await pumpEditor(tester, phonePortrait);
      expect(
        tester.getSize(find.byType(EditorCanvas)).width,
        lessThanOrEqualTo(460),
        reason: 'the phone canvas must not grow',
      );
    });

    testWidgets('the portrait tool panel keeps a readable column', (
      tester,
    ) async {
      await pumpEditor(tester, tabletPortrait, withPhoto: true);
      // The panel surface still spans the screen; its CONTENT does not.
      final slider = find.byType(Slider).first;
      expect(
        tester.getSize(slider).width,
        lessThan(600),
        reason: 'a slider stretched across a tablet is harder to aim',
      );
    });
  });

  group('content columns', () {
    testWidgets('Go Pro caps its column on a tablet, phone unchanged', (
      tester,
    ) async {
      await pump(tester, tabletLandscape, const GoProScreen());
      final buy = find.byType(FilledButton).first;
      expect(tester.getSize(buy).width, lessThanOrEqualTo(560));

      await pump(tester, phonePortrait, const GoProScreen());
      expect(
        tester.getSize(find.byType(FilledButton).first).width,
        closeTo(412 - 40, 1),
        reason: 'phone portrait keeps the full-bleed button it ships with',
      );
    });

    testWidgets('the onboarding CTA stops being a screen-wide bar', (
      tester,
    ) async {
      await pump(tester, tabletLandscape, const OnboardingScreen());
      final cta = find.text('Next');
      final bar = find.ancestor(of: cta, matching: find.byType(SizedBox)).first;
      expect(tester.getSize(bar).width, lessThanOrEqualTo(420));

      await pump(tester, phonePortrait, const OnboardingScreen());
      final phoneBar = find
          .ancestor(of: find.text('Next'), matching: find.byType(SizedBox))
          .first;
      expect(
        tester.getSize(phoneBar).width,
        closeTo(412 - 48, 1),
        reason: 'phone portrait is below the cap, so nothing moves',
      );
    });
  });
}
