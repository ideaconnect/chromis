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

  /// AdMob device ids that should be served **test** ads even from the real unit
  /// ids above. This is the only supported way to see a live unit fill during
  /// development: an unregistered device asking a production unit for an ad
  /// normally gets no fill at all - and because [AdsService.showRewarded] is
  /// deliberately fail-open, "no fill" reads to the user as "the export skipped
  /// its ad", which is exactly how a missing entry here shows up.
  ///
  /// Get the id from logcat on the first ad request; the SDK prints it:
  ///   `Use RequestConfiguration.Builder().setTestDeviceIds(Arrays.asList("33BE2250B43518CCDA7DE426D04EE231"))`
  ///
  ///   adb logcat -s Ads | grep -i setTestDeviceIds
  ///
  /// Never ship a real user's id here - it only ever costs revenue, never earns
  /// it. Clicking a live ad on an unregistered device is invalid traffic and can
  /// get the AdMob account suspended, which is the other reason to register.
  static const List<String> testDeviceIds = <String>[];

  /// All-zero placeholder: a `_prod*` id left as this stays on its test unit.
  static const _placeholder = 'ca-app-pub-0000000000000000/0000000000';

  // Google's official Android test unit ids (safe to ship during development).
  static const _testBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const _testInterstitial = 'ca-app-pub-3940256099942544/1033173712';

  /// Rewarded **INTERSTITIAL**, matching what [AdsService] loads - Google
  /// publishes a different demo unit per format, and asking for the plain
  /// Rewarded one (`…/5224354917`) with `RewardedInterstitialAd.load` fails with
  /// "Ad unit doesn't match format", which is the production bug this pair of
  /// constants exists to avoid reproducing. Change both together or neither.
  static const _testRewarded = 'ca-app-pub-3940256099942544/5354046379';

  // Real unit ids from the AdMob console. Leave the placeholder to keep that ad
  // type on its test unit until you have the real id.
  static const _prodBanner = 'ca-app-pub-6904561240517963/7987729825';
  static const _prodInterstitial = _placeholder;
  static const _prodRewarded = 'ca-app-pub-6904561240517963/3027192977';

  static String _unit(String prod, String test) =>
      (useTestAds || prod == _placeholder) ? test : prod;

  static String get banner => _unit(_prodBanner, _testBanner);
  static String get interstitial => _unit(_prodInterstitial, _testInterstitial);
  static String get rewarded => _unit(_prodRewarded, _testRewarded);
}
