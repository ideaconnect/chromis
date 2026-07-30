import 'dart:typed_data';

import 'package:chromis/core/models/project.dart';
import 'package:chromis/core/platform/platform_services.dart';
import 'package:chromis/core/theme/app_theme.dart';
import 'package:chromis/features/ads/ads_service.dart';
import 'package:chromis/features/editor/state/editor_controller.dart';
import 'package:chromis/features/export/export_screen.dart';
import 'package:chromis/features/go_pro/iap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A free export costs one ad. This pins that a user whose consent choice has
/// switched ads off cannot simply take the export anyway.
///
/// That was the hole. `AdsService.showRewarded` is deliberately fail-open so a
/// no-fill never traps anyone - but "the user refused ads" reached that same
/// branch, so declining consent silently bought the entire free tier: every
/// export, every AI action, no ad, forever.
void main() {
  final watch = find.byKey(const ValueKey('ad-gate-watch'));
  final consent = find.byKey(const ValueKey('ad-gate-consent'));
  final warning = find.byKey(const ValueKey('ad-gate-consent-warning'));

  Future<_RecordingPlatform> pumpExport(
    WidgetTester tester,
    _FakeAds ads, {
    bool pro = false,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(412, 915);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final platform = _RecordingPlatform();
    final container = ProviderContainer(
      overrides: [
        isProProvider.overrideWithValue(pro),
        adsServiceProvider.overrideWithValue(ads),
        platformServicesProvider.overrideWithValue(platform),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(editorControllerProvider.notifier)
        .loadProject(Project.empty(id: 'p'));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: buildAppTheme(), home: const ExportScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    return platform;
  }

  Future<void> tapSave(WidgetTester tester) async {
    final save = find.text('Save to device');
    await tester.ensureVisible(save);
    await tester.pump();
    await tester.tap(save);
    // The render runs before the gate, on the real event loop.
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  testWidgets('consent refused: the export is refused, with a way out', (
    tester,
  ) async {
    final ads = _FakeAds(allowed: false);
    final platform = await pumpExport(tester, ads);
    await tapSave(tester);

    expect(
      ads.asked,
      1,
      reason: 'they are asked again before being told no - that is the point',
    );
    expect(warning, findsOneWidget, reason: 'and told why, not left guessing');
    expect(
      tester.widget<FilledButton>(watch).onPressed,
      isNull,
      reason: 'no ad exists to watch, so watch-and-export must be greyed out',
    );
    expect(consent, findsOneWidget, reason: 'the way back must be offered');

    // Close the sheet: nothing was exported and no ad was faked into existence.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(platform.saved, isEmpty, reason: 'a free export without an ad');
    expect(ads.watched, 0);
  });

  testWidgets('allowing ads from the sheet lets the export through', (
    tester,
  ) async {
    final ads = _FakeAds(allowed: false, grantsOnAsk: true);
    // grantsOnAsk makes the gate's own re-ask succeed, so by the time the sheet
    // renders the ad is available again - the recovery path, end to end.
    final platform = await pumpExport(tester, ads);
    await tapSave(tester);

    expect(warning, findsNothing);
    expect(tester.widget<FilledButton>(watch).onPressed, isNotNull);
    await tester.tap(watch);
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(ads.watched, 1, reason: 'the ad is still the price of the export');
    expect(platform.saved, hasLength(1));
  });

  testWidgets('a Pro user exports without any of this', (tester) async {
    final ads = _FakeAds(allowed: false);
    final platform = await pumpExport(tester, ads, pro: true);
    await tapSave(tester);
    expect(warning, findsNothing);
    expect(ads.asked, 0, reason: 'never prompt someone who paid to not be');
    expect(ads.watched, 0);
    expect(platform.saved, hasLength(1));
  });
}

/// Consent state without a platform UMP round-trip.
class _FakeAds extends AdsService {
  _FakeAds({required this.allowed, this.grantsOnAsk = false});

  bool allowed;
  final bool grantsOnAsk;
  int asked = 0;
  int watched = 0;

  @override
  bool get canRequestAds => allowed;

  @override
  Future<bool> requestConsent({void Function(String message)? onError}) async {
    asked++;
    if (grantsOnAsk) allowed = true;
    return allowed;
  }

  @override
  Future<bool> showRewarded() async {
    watched++;
    return allowed;
  }
}

class _RecordingPlatform implements PlatformServices {
  final List<String> saved = [];

  @override
  Future<GallerySaveResult> saveToGallery(
    String fileName,
    String mimeType,
    Uint8List bytes,
  ) async {
    saved.add(fileName);
    return const GallerySaveSuccess('Pictures/Chromis');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
