/// AdMob ad-unit ids. Each ad type uses its **real** id from the AdMob console
/// when one is set below; anything still on the all-zero placeholder falls back
/// to Google's official **test** unit, so ad types you haven't wired up yet keep
/// working during development. Set [useTestAds] to true to force test units for
/// every type. The AdMob **App ID** lives separately, in AndroidManifest.xml
/// (`com.google.android.gms.ads.APPLICATION_ID`).
///
/// See docs/monetization-setup.md.
abstract final class AdsConfig {
  AdsConfig._();

  /// Master override: when true, force Google's test units for every ad type
  /// (handy during development so you never risk clicking a live ad).
  static const bool useTestAds = false;

  /// All-zero placeholder: a `_prod*` id left as this stays on its test unit.
  static const _placeholder = 'ca-app-pub-0000000000000000/0000000000';

  // Google's official Android test unit ids (safe to ship during development).
  static const _testBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const _testInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const _testRewarded = 'ca-app-pub-3940256099942544/5224354917';

  // Real unit ids from the AdMob console. Leave the placeholder to keep that ad
  // type on its test unit until you have the real id.
  static const _prodBanner = 'ca-app-pub-6904561240517963/7987729825';
  static const _prodInterstitial = _placeholder;
  static const _prodRewarded = _placeholder;

  static String _unit(String prod, String test) =>
      (useTestAds || prod == _placeholder) ? test : prod;

  static String get banner => _unit(_prodBanner, _testBanner);
  static String get interstitial => _unit(_prodInterstitial, _testInterstitial);
  static String get rewarded => _unit(_prodRewarded, _testRewarded);
}
