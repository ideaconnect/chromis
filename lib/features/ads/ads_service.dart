import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../config/ads_config.dart';

/// Central AdMob controller: one-time SDK init + UMP consent, and the rewarded
/// ad helper (unlocks AI actions and gates exports for free users). Banner ads
/// are built inline via [AdWidget] by their host widget. Callers gate on
/// `isProProvider` before showing anything - Pro users see no ads.
class AdsService {
  AdsService();

  bool _initialized = false;

  /// A **rewarded interstitial**, because that is the format the console's unit
  /// actually is - see [_preloadRewarded].
  RewardedInterstitialAd? _rewarded;

  /// Guards [_preloadRewarded] against overlapping loads.
  bool _loading = false;

  /// Initializes the Mobile Ads SDK and runs the UMP consent flow once, then
  /// preloads an interstitial + rewarded. Safe to call repeatedly.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    // UMP consent (EEA/UK). Best-effort - never block or crash the app on it.
    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () async {
          try {
            await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
          } catch (_) {}
        },
        (_) {},
      );
    } catch (_) {}
    // Before initialize(), so the very first request already carries it.
    // Without a matching entry a production unit simply does not fill on a dev
    // device - see [AdsConfig.testDeviceIds].
    if (AdsConfig.testDeviceIds.isNotEmpty) {
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(testDeviceIds: AdsConfig.testDeviceIds),
      );
    }
    await MobileAds.instance.initialize();
    _preloadRewarded();
  }

  /// AdMob has TWO reward formats and they are not interchangeable at load time:
  /// *Rewarded* (`RewardedAd`) and *Rewarded interstitial*
  /// (`RewardedInterstitialAd`). `AdsConfig.rewarded` points at a unit created as
  /// **Rewarded interstitial** ("Reklama pełnoekranowa z nagrodą" in the
  /// console), so it must be loaded as one - asking for it with `RewardedAd`
  /// fails every time with
  ///
  ///   code 3 com.google.android.gms.ads: Ad unit doesn't match format
  ///
  /// and, since [showRewarded] is fail-open, that turned every gated export into
  /// a free one, silently. If the unit is ever recreated as a plain *Rewarded*,
  /// this has to change back in step with it.
  void _preloadRewarded() {
    // One load at a time. Four call sites reach this (init, the fail-open
    // retry, and both dismissal paths), so a gated action taken while a load is
    // still in flight starts a second one - and then whichever lands last wins
    // the field: a second success silently orphans the first ad (never
    // disposed, so it stays alive in the plugin's ad manager), and a late
    // no-fill nulls out a perfectly good one, making the next export fail open
    // for free. Neither is visible from the outside, which is what makes it
    // worth a flag rather than a comment.
    if (_loading) return;
    _loading = true;
    RewardedInterstitialAd.load(
      adUnitId: AdsConfig.rewarded,
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _loading = false;
          // Defensive: nothing should be holding one here, but dropping an ad
          // without disposing it leaks it natively.
          _rewarded?.dispose();
          _rewarded = ad;
        },
        // Do NOT swallow this. An ad that never loads makes every gated action
        // pass for free, silently, and the reason lives only here: the format
        // mismatch above, a brand-new unit that has not started serving, an
        // unregistered test device, no network, or a genuine no-fill.
        onAdFailedToLoad: (error) {
          _loading = false;
          // Deliberately NOT `_rewarded = null`: this load failing says nothing
          // about an ad some other load already handed us.
          // Google's own message is the useful part - print it verbatim rather
          // than guessing a cause.
          debugPrint(
            'AdsService: rewarded interstitial failed to load '
            '(code ${error.code} ${error.domain}): ${error.message} '
            '[unit ${AdsConfig.rewarded}]. '
            'Gated actions pass WITHOUT an ad until one loads.',
          );
        },
      ),
    );
  }

  /// Shows a rewarded ad to unlock an AI action. Completes **true** when the
  /// user earned the reward - OR when no ad is available (fail-open, so a
  /// failed load never blocks the feature). Completes false only if the user
  /// dismisses without earning.
  Future<bool> showRewarded() async {
    final ad = _rewarded;
    if (ad == null) {
      debugPrint(
        'AdsService: no rewarded ad loaded - passing the gate WITHOUT showing '
        'one (fail-open) and retrying the preload. If this is every time, the '
        'load is failing; see the onAdFailedToLoad log above.',
      );
      _preloadRewarded();
      return true;
    }
    _rewarded = null;
    final completer = Completer<bool>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _preloadRewarded();
        if (!completer.isCompleted) completer.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _preloadRewarded();
        if (!completer.isCompleted) completer.complete(true);
      },
    );
    await ad.show(onUserEarnedReward: (_, _) => earned = true);
    return completer.future;
  }
}

final adsServiceProvider = Provider<AdsService>((ref) => AdsService());

/// Runs AdMob init + UMP consent once. Activated by watching it at app start.
final adsInitProvider = FutureProvider<void>(
  (ref) => ref.read(adsServiceProvider).init(),
);
