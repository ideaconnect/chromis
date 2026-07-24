// Aggregated BDD suite - runs every deterministic feature in a SINGLE test
// binary so `flutter test` builds + installs the app only ONCE (instead of once
// per feature file, which on MIUI means one "Install via USB" prompt per file).
//
// Run:  flutter test integration_test/bdd_suite_test.dart -d <deviceId>
//
// The hardware/ML-dependent AI feature (editor_ai) is intentionally left out -
// run it on its own when needed: flutter test integration_test/bdd/editor_ai_test.dart -d <id>
import 'bdd/about_test.dart' as about;
import 'bdd/app_launch_test.dart' as app_launch;
import 'bdd/canvas_size_test.dart' as canvas_size;
import 'bdd/editor_bubble_test.dart' as editor_bubble;
import 'bdd/editor_crop_test.dart' as editor_crop;
import 'bdd/editor_erase_test.dart' as editor_erase;
import 'bdd/editor_layers_test.dart' as editor_layers;
import 'bdd/editor_photo_adjust_test.dart' as editor_photo_adjust;
import 'bdd/editor_test.dart' as editor;
import 'bdd/editor_text_test.dart' as editor_text;
import 'bdd/export_test.dart' as export_feature;
import 'bdd/go_pro_test.dart' as go_pro;
import 'bdd/home_test.dart' as home;
import 'bdd/onboarding_test.dart' as onboarding;

void main() {
  // Each generated main() calls IntegrationTestWidgetsFlutterBinding
  // .ensureInitialized() (idempotent) and registers its group() of scenarios.
  onboarding.main();
  home.main();
  app_launch.main();
  canvas_size.main();
  editor.main();
  editor_layers.main();
  editor_text.main();
  editor_bubble.main();
  editor_photo_adjust.main();
  editor_crop.main();
  editor_erase.main();
  export_feature.main();
  go_pro.main();
  about.main();
}
