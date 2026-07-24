import 'package:chromis/config/ads_config.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards ad-unit id selection: each getter returns the real prod id when one is
/// set, and falls back to Google's official Android **test** unit id while the
/// `_prod*` slot is still the all-zero placeholder.
void main() {
  const testPublisher = 'ca-app-pub-3940256099942544';
  const prodPublisher = 'ca-app-pub-6904561240517963';
  const placeholderPublisher = 'ca-app-pub-0000000000000000';

  test('useTestAds is off (real ids configured)', () {
    expect(AdsConfig.useTestAds, isFalse);
  });

  test('banner resolves to the real prod banner unit id', () {
    expect(AdsConfig.banner, '$prodPublisher/7987729825');
  });

  test('interstitial falls back to the test unit until a real id is set', () {
    expect(AdsConfig.interstitial, '$testPublisher/1033173712');
  });

  test('rewarded resolves to the real prod rewarded unit id', () {
    expect(AdsConfig.rewarded, '$prodPublisher/3027192977');
  });

  test('every resolved id is a real, distinct (non-placeholder) unit', () {
    final ids = <String>[
      AdsConfig.banner,
      AdsConfig.interstitial,
      AdsConfig.rewarded,
    ];
    for (final id in ids) {
      expect(
        id,
        isNot(startsWith('$placeholderPublisher/')),
        reason: '$id must not be the placeholder',
      );
    }
    expect(ids.toSet(), hasLength(3), reason: 'ids must be distinct');
  });
}
