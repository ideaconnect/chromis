import 'package:chromis/core/settings/settings_store.dart';
import 'package:chromis/features/ads/ads_service.dart';
import 'package:chromis/features/go_pro/iap.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// "Go Pro removes all ads" has to mean the ads SDK is never spoken to.
///
/// Both the privacy policy and the in-app Privacy screen tell a paying user that
/// the upgrade removes ads "and the advertising ID with them". That was not true:
/// `adsInitProvider` was watched unconditionally at app start, so a Pro user's
/// device still initialised the Mobile Ads SDK, ran the UMP consent flow and
/// preloaded a rewarded ad. Only the *display* of ads was gated. An ad request
/// uses the advertising ID whether or not anything is drawn.
///
/// Nothing here touches the real SDK - `AdsService.init()` would need a platform
/// channel. The claim under test is upstream of that: whether the provider even
/// gets as far as calling it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Records whether init() was reached, without going near AdMob.
  late bool initCalled;

  ProviderContainer containerFor({required bool entitled}) {
    initCalled = false;
    final container = ProviderContainer(
      overrides: [
        settingsStoreProvider.overrideWithValue(_FakeSettings(entitled)),
        adsServiceProvider.overrideWithValue(
          _SpyAdsService(() => initCalled = true),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('a Pro user never reaches the ads SDK', () async {
    final container = containerFor(entitled: true);
    await container.read(adsInitProvider.future);
    expect(
      initCalled,
      isFalse,
      reason:
          'a paying user must make no ad request at all - not even the SDK '
          'handshake, which is itself an advertising-ID use',
    );
  });

  test('a free user still initialises ads', () async {
    final container = containerFor(entitled: false);
    await container.read(adsInitProvider.future);
    expect(
      initCalled,
      isTrue,
      reason: 'the free tier is ad-supported; this must not over-correct',
    );
  });

  test(
    'the decision waits for the entitlement, it does not assume free',
    () async {
      // isProProvider reports false while the cached flag loads. Gating on it
      // would let a paying user fire an ad request in that window, which is
      // exactly the bug - so the provider must await the real answer.
      final container = containerFor(entitled: true);
      expect(
        container.read(isProProvider),
        isFalse,
        reason: 'precondition: the synchronous view really is false at first',
      );
      await container.read(adsInitProvider.future);
      expect(initCalled, isFalse);
    },
  );
}

class _SpyAdsService implements AdsService {
  _SpyAdsService(this._onInit);
  final VoidCallback _onInit;

  @override
  Future<void> init() async => _onInit();

  @override
  Future<bool> showRewarded() async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSettings implements SettingsStore {
  _FakeSettings(this._entitled);
  final bool _entitled;

  @override
  Future<bool> proEntitled() async => _entitled;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
