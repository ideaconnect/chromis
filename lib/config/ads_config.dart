/// AdMob ad-unit ids. Google's official **test** ids ship until you create the
/// real ones (AdMob console → your app → Ad units) - set [useTestAds] to false
/// and fill the `_prod*` constants. The AdMob **App ID** lives separately, in
/// AndroidManifest.xml (`com.google.android.gms.ads.APPLICATION_ID`).
///
/// See docs/monetization-setup.md.
abstract final class AdsConfig {
  AdsConfig._();

  /// Flip to false once the real unit ids below are filled in.
  static const bool useTestAds = true;

  // Google's official Android test unit ids (safe to ship during development).
  static const _testBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const _testInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const _testRewarded = 'ca-app-pub-3940256099942544/5224354917';

  // Real unit ids from the AdMob console. Swap useTestAds -> false to use them.
  static const _prodBanner = 'ca-app-pub-0000000000000000/0000000000';
  static const _prodInterstitial = 'ca-app-pub-0000000000000000/0000000000';
  static const _prodRewarded = 'ca-app-pub-0000000000000000/0000000000';

  static String get banner => useTestAds ? _testBanner : _prodBanner;
  static String get interstitial =>
      useTestAds ? _testInterstitial : _prodInterstitial;
  static String get rewarded => useTestAds ? _testRewarded : _prodRewarded;
}
