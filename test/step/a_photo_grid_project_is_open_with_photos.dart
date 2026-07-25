import 'package:chromis/core/models/grid.dart';
import 'package:chromis/core/models/project.dart';
import 'package:chromis/features/editor/services/image_import.dart';
import 'package:chromis/features/editor/state/editor_controller.dart';
import 'package:chromis/features/grid/grid_templates.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: a photo grid project is open with {3} photos
///
/// Swaps the open document for a collage of [count] cells, each holding a real
/// photo. Seeded through the controller rather than the create flow on purpose:
/// creating a grid ends in the system photo picker, which is a separate process
/// that rejects synthetic input on this device (see docs/e2e-testing.md).
Future<void> aPhotoGridProjectIsOpenWithPhotos(
  WidgetTester tester,
  int count,
) async {
  final container = containerOf(tester);
  final controller = container.read(editorControllerProvider.notifier);
  final grid = GridSpec(root: gridTemplatesFor(count).first.root);

  controller.loadProject(
    Project.empty(
      id: 'e2e_grid',
      name: 'Grid',
      createdAt: DateTime.now(),
    ).copyWith(grid: grid),
  );

  final data = await rootBundle.load('assets/branding/logo.png');
  final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  for (final cellId in grid.cellIds) {
    final path = await container
        .read(imageImportServiceProvider)
        .storeBytes(bytes);
    controller.addPhotoToCell(assetPath: path, cellId: cellId);
  }
  await settle(tester);
}
