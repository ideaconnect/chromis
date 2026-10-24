import 'dart:io';
import 'dart:ui' as ui;

import 'package:chromis/core/models/project.dart';
import 'package:chromis/core/settings/settings_store.dart';
import 'package:chromis/core/theme/app_theme.dart';
import 'package:chromis/features/editor/editor_screen.dart';
import 'package:chromis/features/editor/state/editor_controller.dart';
import 'package:chromis/features/editor/state/editor_tool.dart';
import 'package:chromis/features/editor/widgets/editor_canvas.dart';
import 'package:chromis/features/editor/widgets/fill_quality_sheet.dart';
import 'package:chromis/features/editor/widgets/project_canvas.dart';
import 'package:chromis/features/go_pro/iap.dart';
import 'package:chromis/features/home/project_repository.dart';
import 'package:chromis/features/segmentation/ai_capability.dart';
import 'package:chromis/features/segmentation/fill_quality.dart';
import 'package:chromis/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/surface.dart';

/// The cut-out tool's Remove-object modes.
///
/// This is the coverage whose absence let the feature ship ambiguous. The
/// Fill/Erase chooser was built behind `inpaintAvailableProvider`, which is an
/// asset-manifest check for an OPTIONAL MI-GAN model that no shipped build has
/// ever bundled - so the branch was dead, every tap erased the object to a
/// transparent hole, and nothing on screen said which of the two things
/// "remove object" was about to do. Users read the hole as a broken fill.
///
/// Nothing caught it: the panel renders fine either way, the gate is a runtime
/// provider rather than a compile-time flag, and no test entered the mode.
void main() {
  late Directory tmp;
  late String png;

  Future<String> writePng(String name, int w, int h) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()..color = const Color(0xFF3366AA),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(w, h);
    picture.dispose();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final file = File('${tmp.path}/$name');
    await file.writeAsBytes(
      data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
    return file.path;
  }

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tmp = await Directory.systemTemp.createTemp('chromis_fill_mode');
    // Written here, not in a test body: `Picture.toImage` completes on the real
    // event loop, which a `testWidgets` fake-async zone never turns.
    png = await writePng('photo.png', 640, 480);
  });

  tearDownAll(() {
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  setUp(() => ProjectCanvas.existsCache.clear());

  /// A settings file of its own per test, so a choice made in one cannot stop
  /// the next from asking.
  SettingsStore freshStore() {
    final dir = Directory.systemTemp.createTempSync('fill_quality_choice');
    addTearDown(() {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    });
    return SettingsStore(baseDir: dir);
  }

  Future<void> pumpCutout(
    WidgetTester tester, {
    Size surface = const Size(412, 915),
    Locale locale = const Locale('en'),
    SettingsStore? store,
    FillQuality recommended = FillQuality.best,
  }) async {
    setSurface(tester, surface);
    final container = ProviderContainer(
      overrides: [
        isProProvider.overrideWithValue(true),
        projectRepositoryProvider.overrideWithValue(_RecordingRepo()),
        settingsStoreProvider.overrideWithValue(store ?? freshStore()),
        // What the phone's memory would suggest - pinned, because a host test
        // has no platform side to ask.
        fillQualityRecommendationProvider.overrideWith(
          (ref) async => recommended,
        ),
        // Arming Remove-object warms the SAM embedding; deny the tier so the
        // test never reaches for an ONNX runtime it does not have.
        aiCapabilityProvider.overrideWith(
          (ref) async => (samAllowed: false, reason: 'test'),
        ),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(editorControllerProvider.notifier);
    controller.loadProject(Project.empty(id: 'p'));
    controller.addImageLayer(assetPath: png, name: 'Photo');
    controller.setTool(EditorTool.cutout);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: darkAppTheme,
          home: MediaQuery(
            data: MediaQueryData(size: surface),
            child: const EditorScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  const fillExplainer =
      'Fill rebuilds the background in the most detail. It needs more memory '
      'and takes longer.';
  const lowMemoryExplainer =
      'Fill rebuilds the background from the rest of the photo with far less '
      'memory. Large objects come out simpler.';
  const eraseExplainer = 'Erase cuts the object out to transparency.';

  testWidgets('Remove object offers Fill and Erase without any model bundled', (
    tester,
  ) async {
    await pumpCutout(tester);
    await tester.tap(find.text('Remove object'));
    await tester.pump();

    expect(find.text('Fill in'), findsOneWidget);
    expect(
      find.text('Erase'),
      findsWidgets,
      reason: 'the tab; the dock carries the same word for the Erase tool',
    );
  });

  testWidgets('Fill is the default, and it says what it will do', (
    tester,
  ) async {
    await pumpCutout(tester);
    await tester.tap(find.text('Remove object'));
    await tester.pump();

    // The whole point: what "remove" means is on screen before the tap that
    // does it, and the default is the one people expect.
    expect(find.text(fillExplainer), findsOneWidget);
    expect(find.text(eraseExplainer), findsNothing);
  });

  testWidgets('choosing Erase switches the explanation, and back again', (
    tester,
  ) async {
    await pumpCutout(tester);
    await tester.tap(find.text('Remove object'));
    await tester.pump();

    // The Erase TAB - reached through the row it shares with Fill in, because
    // the editor dock carries an "Erase" item too and tapping that one leaves
    // the cut-out tool entirely.
    final tabs = find
        .ancestor(of: find.text('Fill in'), matching: find.byType(Row))
        .first;
    await tester.tap(find.descendant(of: tabs, matching: find.text('Erase')));
    await tester.pump();
    expect(find.text(eraseExplainer), findsOneWidget);
    expect(find.text(fillExplainer), findsNothing);

    await tester.tap(find.text('Fill in'));
    await tester.pump();
    expect(find.text(fillExplainer), findsOneWidget);
  });

  testWidgets('the chooser fits a 360dp German phone', (tester) async {
    // Two Expanded tabs in one row is the shape that breaks first, and German
    // runs 10-35% longer than English. The rest of the suite pumps in the
    // default locale, so a label that does not fit is otherwise invisible.
    await pumpCutout(
      tester,
      surface: const Size(360, 780),
      locale: const Locale('de'),
    );
    await tester.tap(find.text('Objekt entfernen'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Füllen'), findsOneWidget);
    expect(find.text('Beste Qualität'), findsOneWidget);
    expect(find.text('Wenig Speicher'), findsOneWidget);
    expect(
      find.text(
        'Füllen rekonstruiert den Hintergrund mit den meisten Details. Es '
        'braucht mehr Speicher und dauert länger.',
      ),
      findsOneWidget,
    );
  });

  // #68: how to fill is a choice, offered only while Fill is the mode.
  group('fill quality', () {
    /// Lets real I/O land. settings.json is read and written through
    /// `dart:io`, which completes on the real event loop, and each step's
    /// continuation then needs a frame of the fake one - so a choice takes a
    /// few rounds of both to reach the disk.
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 400));
    }

    Future<void> openRemoveObject(WidgetTester tester) async {
      await tester.tap(find.text('Remove object'));
      await settle(tester);
    }

    /// The row sits below the panel's fold on a phone, which scrolls.
    Future<void> tapRow(WidgetTester tester, String label) async {
      await tester.ensureVisible(find.text(label));
      await tester.pump();
      await tester.tap(find.text(label));
      await settle(tester);
    }

    /// Taps the middle of the photo and lets the tap's real I/O land - the
    /// photo's size is decoded and settings.json read before anything asks.
    Future<void> tapPhoto(WidgetTester tester) async {
      await tester.tapAt(tester.getCenter(find.byType(EditorCanvas)));
      await settle(tester);
    }

    testWidgets('the row is under Fill in, and gone under Erase', (
      tester,
    ) async {
      await pumpCutout(tester);
      await openRemoveObject(tester);
      expect(find.text('Best quality'), findsOneWidget);
      expect(find.text('Low memory'), findsOneWidget);

      final tabs = find
          .ancestor(of: find.text('Fill in'), matching: find.byType(Row))
          .first;
      await tester.tap(find.descendant(of: tabs, matching: find.text('Erase')));
      await tester.pump();
      expect(find.text('Best quality'), findsNothing);
      expect(find.text('Low memory'), findsNothing);
    });

    testWidgets('before any choice it shows what the phone suggests', (
      tester,
    ) async {
      await pumpCutout(tester, recommended: FillQuality.lowMemory);
      await openRemoveObject(tester);
      expect(find.text(lowMemoryExplainer), findsOneWidget);
      expect(find.text(fillExplainer), findsNothing);
    });

    testWidgets('a tap on the row is the choice, and it is kept', (
      tester,
    ) async {
      final store = freshStore();
      await pumpCutout(tester, store: store);
      await openRemoveObject(tester);
      await tapRow(tester, 'Low memory');
      expect(find.text(lowMemoryExplainer), findsOneWidget);
      expect(
        await tester.runAsync(store.fillQualityId),
        FillQuality.lowMemory.id,
      );
    });

    testWidgets('the first fill asks, and backing out saves nothing', (
      tester,
    ) async {
      final store = freshStore();
      await pumpCutout(
        tester,
        store: store,
        recommended: FillQuality.lowMemory,
      );
      await openRemoveObject(tester);
      await tapPhoto(tester);

      expect(find.byType(FillQualitySheet), findsOneWidget);
      // The phone's suggestion is the one already selected, and marked.
      expect(find.text('Recommended for this phone'), findsOneWidget);
      expect(
        tester.getSemantics(
          find.byKey(const ValueKey('fill-quality-lowMemory')),
        ),
        isSemantics(isChecked: true),
      );

      await tester.tapAt(const Offset(20, 20)); // the scrim
      await settle(tester);
      expect(find.byType(FillQualitySheet), findsNothing);
      expect(
        await tester.runAsync(store.fillQualityId),
        isNull,
        reason: 'dismissed is "not now" - the next fill must ask again',
      );
    });

    testWidgets('answering it once is enough', (tester) async {
      final store = freshStore();
      await pumpCutout(tester, store: store);
      await openRemoveObject(tester);
      await tapPhoto(tester);
      await tester.tap(find.byKey(const ValueKey('fill-quality-continue')));
      await settle(tester);
      expect(await tester.runAsync(store.fillQualityId), FillQuality.best.id);

      await tapPhoto(tester);
      expect(
        find.byType(FillQualitySheet),
        findsNothing,
        reason: 'the choice is made; the panel is where it changes now',
      );
    });

    testWidgets('a choice made in the panel means the first fill never asks', (
      tester,
    ) async {
      await pumpCutout(tester);
      await openRemoveObject(tester);
      await tapRow(tester, 'Best quality');
      await tapPhoto(tester);
      expect(find.byType(FillQualitySheet), findsNothing);
    });
  });
}

/// Captures saves instead of touching the filesystem.
class _RecordingRepo implements ProjectRepository {
  final List<Project> saved = [];

  @override
  Future<void> save(Project project) async => saved.add(project);

  @override
  Future<List<Project>> list() async => saved;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
