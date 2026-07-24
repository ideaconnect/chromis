import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: a photo layer is added
Future<void> aPhotoLayerIsAdded(WidgetTester tester) async {
  await seedPhoto(tester);
}
