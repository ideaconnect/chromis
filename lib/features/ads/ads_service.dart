import 'dart:async';

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
  RewardedAd? _rewarded;

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
    await MobileAds.instance.initialize();
    _preloadRewarded();
  }

  void _preloadRewarded() {
    RewardedAd.load(
      adUnitId: AdsConfig.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewarded = ad,
        onAdFailedToLoad: (_) => _rewarded = null,
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
