import 'package:chromis/app/router.dart';
import 'package:chromis/core/models/layer.dart';
import 'package:chromis/core/models/project.dart';
import 'package:chromis/core/theme/app_theme.dart';
import 'package:chromis/features/editor/services/image_import.dart';
import 'package:chromis/features/editor/widgets/project_canvas.dart';
import 'package:chromis/features/go_pro/iap.dart';
import 'package:chromis/features/home/home_screen.dart';
import 'package:chromis/features/home/project_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/surface.dart';

/// A project that starts WITH content must be on disk before the editor opens.
///
/// The editor auto-saves on edits made while it is on screen. Both Home start
/// flows place their content BEFORE pushing the editor route, so nothing was
/// listening yet - and backing straight out of a freshly created collage, or of
/// a photo you had just opened, silently threw it away. The photos were even
/// copied into the assets dir first, so it looked like it had worked.
///
/// A blank canvas is deliberately NOT saved: nothing has been chosen yet, and
/// an abandoned one should not litter Recent.
void main() {
  setUp(() {
    ProjectCanvas.fileExists = (_) => false;
    ProjectCanvas.existsCache.clear();
  });
  tearDown(() => ProjectCanvas.fileExists = ProjectCanvas.defaultFileExists);

  Future<_RecordingRepo> pumpHome(
    WidgetTester tester, {
    required _StubImport imports,
  }) async {
    // Pinned so the assertions are about persistence, not about whatever the
    // default 800x600 surface does to a layout under the test font.
    setSurface(tester, const Size(1280, 800));
    final repo = _RecordingRepo();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          name: Routes.home,
          builder: (_, _) => const HomeScreen(),
          routes: [
            GoRoute(
              path: 'editor',
              name: Routes.editor,
              builder: (_, _) => const Scaffold(body: Text('editor')),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectRepositoryProvider.overrideWithValue(repo),
          imageImportServiceProvider.overrideWithValue(imports),
          // Pro hides the ad slot, whose platform channel is unimplemented
          // here and would otherwise throw once runAsync lets it load.
          isProProvider.overrideWithValue(true),
        ],
        // A real router, because the flow ends by pushing the editor route.
        // Stubbing the destination keeps the test about persistence while
        // letting the push succeed - an unrouted push throws asynchronously,
        // outside any pump, where takeException cannot reach it.
        child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    return repo;
  }

  testWidgets('opening a photo saves it before the editor is reachable', (
    tester,
  ) async {
    final repo = await pumpHome(
      tester,
      imports: _StubImport(single: '/fake/photo.png'),
    );

    await _tapAndSettle(tester, 'Open a photo');

    expect(
      repo.saved,
      isNotEmpty,
      reason:
          'the photo was placed before the editor mounted, so only this '
          'flow can persist it',
    );
    final project = repo.saved.last;
    expect(project.currentFrame.layers.whereType<ImageLayer>(), hasLength(1));
  });

  testWidgets('a cancelled photo pick saves nothing', (tester) async {
    final repo = await pumpHome(tester, imports: _StubImport());
    await _tapAndSettle(tester, 'Open a photo');
    expect(repo.saved, isEmpty);
  });
}

/// Taps and lets the flow finish.
///
/// Inside `runAsync` because the flow reads the picked file to measure it, and
/// real file I/O does not complete in the fake-async zone `testWidgets` runs
/// in - without this the flow stalls at the decode and never reaches the save,
/// which looks exactly like the bug under test.
Future<void> _tapAndSettle(WidgetTester tester, String label) async {
  await tester.runAsync(() async {
    await tester.tap(find.text(label));
    await Future<void>.delayed(const Duration(milliseconds: 300));
  });
  await tester.pump();
  // The flow ends by pushing the editor route and this harness has no
  // GoRouter. That failure happens AFTER the save under test, so it is
  // expected - but anything else must still surface.
  expect(
    tester.takeException(),
    isNull,
    reason: 'the start flow should complete cleanly',
  );
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

/// Returns a canned pick result without a system picker.
class _StubImport implements ImageImportService {
  _StubImport({this.single});

  final String? single;

  @override
  Future<String?> pickFromGallery() async => single;

  @override
  Future<List<String>> pickMultipleFromGallery({int? limit}) async =>
      single == null ? const [] : [single!];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
