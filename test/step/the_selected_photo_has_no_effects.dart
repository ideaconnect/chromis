import 'package:chromis/core/models/layer_effects.dart';
import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: the selected photo has no effects
Future<void> theSelectedPhotoHasNoEffects(WidgetTester tester) async {
  final l = selectedImage(tester);
  expect(l.effects, LayerEffects.none);
  expect(l.vignette, Vignette.none);
  expect(l.adjustments.hasFilter, isFalse);
  expect(l.adjustments.hdr, 0);
}
