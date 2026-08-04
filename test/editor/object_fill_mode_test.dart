import 'dart:io';
import 'dart:ui' as ui;

import 'package:chromis/core/models/project.dart';
import 'package:chromis/core/theme/app_theme.dart';
import 'package:chromis/features/editor/editor_screen.dart';
import 'package:chromis/features/editor/state/editor_controller.dart';
import 'package:chromis/features/editor/state/editor_tool.dart';
import 'package:chromis/features/editor/widgets/project_canvas.dart';
import 'package:chromis/features/go_pro/iap.dart';
import 'package:chromis/features/home/project_repository.dart';
import 'package:chromis/features/segmentation/ai_capability.dart';
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

  Future<void> pumpCutout(
    WidgetTester tester, {
    Size surface = const Size(412, 915),
    Locale locale = const Locale('en'),
  }) async {
    setSurface(tester, surface);
    final container = ProviderContainer(
      overrides: [
        isProProvider.overrideWithValue(true),
        projectRepositoryProvider.overrideWithValue(_RecordingRepo()),
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
      'Fill rebuilds the background from the rest of the '
      'photo.';
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
    expect(
      find.text('Füllen rekonstruiert den Hintergrund aus dem übrigen Foto.'),
      findsOneWidget,
    );
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
