import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_editor_ai/core/models/layer.dart';
import 'package:photo_editor_ai/features/editor/editor_screen.dart';
import 'package:photo_editor_ai/features/editor/state/editor_controller.dart';

/// Usage: a comic bubble layer is added
///
/// Reads the real editor state (a fresh bubble has an empty caption, so we can't
/// assert on rendered text) and confirms a BubbleLayer now exists.
Future<void> aComicBubbleLayerIsAdded(WidgetTester tester) async {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(EditorScreen)),
    listen: false,
  );
  final layers = container.read(editorControllerProvider).layers;
  expect(
    layers.whereType<BubbleLayer>(),
    isNotEmpty,
    reason: 'Tapping the Bubble tool should add a comic bubble layer',
  );
}
