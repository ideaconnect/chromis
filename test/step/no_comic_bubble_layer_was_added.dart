import 'package:chromis/core/models/layer.dart';
import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: no comic bubble layer was added
///
/// The other half of the format picker's contract: backing out of it leaves the
/// project exactly as it was, rather than dropping a default bubble anyway.
Future<void> noComicBubbleLayerWasAdded(WidgetTester tester) async {
  expect(
    editorState(tester).layers.whereType<BubbleLayer>(),
    isEmpty,
    reason: 'Dismissing the format picker should add no bubble',
  );
}
