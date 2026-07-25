import 'package:chromis/core/models/project.dart';
import 'package:chromis/core/theme/app_theme.dart';
import 'package:chromis/features/editor/widgets/project_canvas.dart';
import 'package:chromis/features/go_pro/iap.dart';
import 'package:chromis/features/home/home_screen.dart';
import 'package:chromis/features/home/project_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/surface.dart';

/// The Recent header counts saved projects, and a count of one has to read
/// "1 project" - the interpolated plural shipped as "1 projects".
void main() {
  setUp(() {
    ProjectCanvas.fileExists = (_) => false;
    ProjectCanvas.existsCache.clear();
  });
  tearDown(() => ProjectCanvas.fileExists = ProjectCanvas.defaultFileExists);

  Future<void> pumpHome(WidgetTester tester, int projects) async {
    setSurface(tester, const Size(412, 915));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectRepositoryProvider.overrideWithValue(_StubRepo(projects)),
          // Pro hides the ad slot, whose platform channel is unimplemented here.
          isProProvider.overrideWithValue(true),
        ],
        child: MaterialApp(theme: buildAppTheme(), home: const HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('one saved project is not "1 projects"', (tester) async {
    await pumpHome(tester, 1);
    expect(find.text('1 project'), findsOneWidget);
    expect(find.text('1 projects'), findsNothing);
  });

  testWidgets('none and many stay plural', (tester) async {
    await pumpHome(tester, 0);
    expect(find.text('0 projects'), findsOneWidget);

    await pumpHome(tester, 3);
    expect(find.text('3 projects'), findsOneWidget);
  });
}

/// Returns [count] blank projects without touching the filesystem.
class _StubRepo implements ProjectRepository {
  _StubRepo(this.count);

  final int count;

  @override
  Future<List<Project>> list() async => [
    for (var i = 0; i < count; i++)
      Project.empty(id: 'p$i', createdAt: DateTime(2026)),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
