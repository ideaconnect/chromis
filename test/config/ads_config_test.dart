import 'package:flutter_test/flutter_test.dart';
import 'package:photo_editor_ai/config/ads_config.dart';

/// Guards the ad-unit id selection: while [AdsConfig.useTestAds] is true (the
/// shipped default until real ids are filled in), every getter must resolve to
/// Google's official Android **test** unit ids — never the prod placeholders.
void main() {
  // Google's documented Android test unit ids share this test publisher id.
  const testPublisher = 'ca-app-pub-3940256099942544';

  test('useTestAds is currently true (test ids ship by default)', () {
    expect(AdsConfig.useTestAds, isTrue);
  });

  test('banner resolves to the Google test banner unit id', () {
    expect(AdsConfig.banner, '$testPublisher/6300978111');
  });

  test('interstitial resolves to the Google test interstitial unit id', () {
    expect(AdsConfig.interstitial, '$testPublisher/1033173712');
  });

  test('rewarded resolves to the Google test rewarded unit id', () {
    expect(AdsConfig.rewarded, '$testPublisher/5224354917');
  });

  test('all three ids are the shared test publisher and are distinct', () {
    final ids = <String>[
      AdsConfig.banner,
      AdsConfig.interstitial,
      AdsConfig.rewarded,
    ];
    for (final id in ids) {
      expect(id, startsWith('$testPublisher/'), reason: '$id is a test id');
    }
    expect(ids.toSet(), hasLength(3), reason: 'ids must be distinct');
  });
}
