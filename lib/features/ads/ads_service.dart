import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../config/ads_config.dart';
import '../go_pro/iap.dart';

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

  /// Completes once it is known whether ads may be requested. Never rejects.
  ///
  /// Anything that loads an ad awaits this. The consent update used to be
  /// fire-and-forget with `MobileAds.initialize()` and the rewarded preload on
  /// the line after, and the Home banner gated on nothing but the Pro flag - so
  /// a first launch in the EEA asked production units for ads *before* the
  /// consent form had been answered.
  final _consentSettled = Completer<void>();
  Future<void> get consentSettled => _consentSettled.future;

  /// Whether UMP says an ad request is permitted. False only when consent is
  /// required and has not been given.
  bool _canRequestAds = true;
  bool get canRequestAds => _canRequestAds;

  void _settleConsent() {
    if (!_consentSettled.isCompleted) _consentSettled.complete();
  }

  /// Initializes the Mobile Ads SDK and runs the UMP consent flow once, then
  /// preloads the rewarded ad. Safe to call repeatedly.
  ///
  /// There is no plain interstitial anywhere in the app - the only formats are
  /// the Home banner and this rewarded (interstitial-format) unit.
  ///
  /// Deliberately NOT a straight `await` chain: `requestConsentInfoUpdate`
  /// needs the network, so making everything sequential would stall ads (and
  /// the Home banner slot) for the whole timeout on every offline launch.
  /// Instead the SDK is initialized immediately - which requests nothing - and
  /// [consentSettled] is what actually gates ad LOADS.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    // Before initialize(), so the very first request already carries it.
    // Without a matching entry a production unit simply does not fill on a dev
    // device - see [AdsConfig.testDeviceIds].
    if (AdsConfig.testDeviceIds.isNotEmpty) {
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(testDeviceIds: AdsConfig.testDeviceIds),
      );
    }
    await MobileAds.instance.initialize();

    // UMP consent (EEA/UK). Best-effort - never block or crash the app on it,
    // but nothing may load until it has answered one way or the other.
    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () async {
          try {
            await ConsentForm.loadAndShowConsentFormIfRequired((error) {
              if (error != null) {
                debugPrint(
                  'AdsService: consent form failed - ${error.message}',
                );
              }
            });
            _canRequestAds = await ConsentInformation.instance.canRequestAds();
          } catch (e) {
            debugPrint('AdsService: consent flow failed - $e');
          }
          _settleConsent();
          if (_canRequestAds) _preloadRewarded();
        },
        (error) {
          // Could not reach the consent service. Requesting ads anyway is the
          // documented fallback - a user outside the EEA must not lose ads
          // (and with them the free tier) because a network call failed.
          debugPrint('AdsService: consent update failed - ${error.message}');
          _settleConsent();
          _preloadRewarded();
        },
      );
    } catch (e) {
      debugPrint('AdsService: consent request threw - $e');
      _settleConsent();
      _preloadRewarded();
    }
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
    // Nothing may be requested before consent has answered. Fail-open applies
    // afterwards: if consent is refused there is no ad to show, and the gate
    // must still let the user through rather than locking the feature.
    await consentSettled;
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
///
/// A Pro user never reaches [AdsService.init] at all: no SDK handshake, no UMP
/// prompt, no preloaded ad - so no ad request is ever made from their device and
/// the advertising ID is never used by this app. That is what "Go Pro removes
/// all ads" has to mean to be true, and both the privacy policy and the in-app
/// Privacy screen say it. Before this, the SDK was initialised and a rewarded ad
/// preloaded for EVERY user, paying or not; only the *display* of ads was gated.
///
/// Awaits the entitlement rather than reading `isProProvider`, which reports
/// false while the cached flag is still loading - long enough for a paying user
/// to have made an ad request before anyone knew they had paid.
final adsInitProvider = FutureProvider<void>((ref) async {
  if (await ref.watch(proEntitledProvider.future)) return;
  return ref.read(adsServiceProvider).init();
});
