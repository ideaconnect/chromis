import 'package:chromis/core/settings/settings_store.dart';
import 'package:chromis/features/go_pro/iap.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Guards the Go Pro entitlement + product-load contract with fakes (no plugin
/// / store): the controller surfaces the cached flag at build, `grant()` is
/// idempotent and persisted, `isProProvider` is false until the flag resolves,
/// and [IapService.loadProduct] maps an empty product query to null.
void main() {
  test('the Pro product id still matches the one in Play Console', () {
    // Pinned deliberately, tautological as it looks. This id is one half of a
    // contract whose other half lives in a web console, and getting it wrong
    // raises NO error: `loadProduct` returns an empty query, the provider
    // resolves to null, and the Go Pro screen says "Purchases are temporarily
    // unavailable" for every user forever. Nothing in a build, a test run or a
    // crash report would say why. If the console product is renamed, change it
    // here and update docs/monetization-setup.md in the same commit.
    expect(kProProductId, 'chromis_pro_mode');
  });

  group('EntitlementController', () {
    test('build() surfaces the cached proEntitled flag', () async {
      final entitled = ProviderContainer.test(
        overrides: [
          settingsStoreProvider.overrideWithValue(_FakeStore(initial: true)),
        ],
      );
      expect(await entitled.read(proEntitledProvider.future), isTrue);

      final notEntitled = ProviderContainer.test(
        overrides: [
          settingsStoreProvider.overrideWithValue(_FakeStore(initial: false)),
        ],
      );
      expect(await notEntitled.read(proEntitledProvider.future), isFalse);
    });

    test(
      'isProProvider is false while the entitlement loads, true once resolved',
      () async {
        final container = ProviderContainer.test(
          overrides: [
            settingsStoreProvider.overrideWithValue(_FakeStore(initial: true)),
          ],
        );

        // build() is async, so the very first synchronous read is still loading.
        expect(container.read(isProProvider), isFalse);

        expect(await container.read(proEntitledProvider.future), isTrue);
        expect(container.read(isProProvider), isTrue);
      },
    );

    test(
      'grant() flips + persists the entitlement and is idempotent on repeat',
      () async {
        final store = _FakeStore(initial: false);
        final container = ProviderContainer.test(
          overrides: [settingsStoreProvider.overrideWithValue(store)],
        );
        expect(await container.read(proEntitledProvider.future), isFalse);

        await container.read(proEntitledProvider.notifier).grant();
        expect(container.read(isProProvider), isTrue);
        expect(store.persisted, isTrue);
        expect(store.setCalls, 1);

        // A second grant is a no-op: no extra persist.
        await container.read(proEntitledProvider.notifier).grant();
        expect(store.setCalls, 1);
        expect(container.read(isProProvider), isTrue);
      },
    );

    test(
      'grant() early-returns when already entitled at build (no re-persist)',
      () async {
        final store = _FakeStore(initial: true);
        final container = ProviderContainer.test(
          overrides: [settingsStoreProvider.overrideWithValue(store)],
        );
        expect(await container.read(proEntitledProvider.future), isTrue);

        await container.read(proEntitledProvider.notifier).grant();
        expect(store.setCalls, 0);
        expect(container.read(isProProvider), isTrue);
      },
    );
  });

  group('IapService.loadProduct', () {
    test('returns null when the product query yields an empty list', () async {
      final iap = _FakeInAppPurchase(
        ProductDetailsResponse(
          productDetails: const [],
          notFoundIDs: [kProProductId],
        ),
      );
      final service = IapService(iap);

      expect(await service.loadProduct(), isNull);
      expect(iap.lastQuery, contains(kProProductId));
    });

    test('returns the first product when the query finds it', () async {
      final product = _product(kProProductId);
      final iap = _FakeInAppPurchase(
        ProductDetailsResponse(
          productDetails: [product],
          notFoundIDs: const [],
        ),
      );
      final service = IapService(iap);

      final loaded = await service.loadProduct();
      expect(loaded, same(product));
      expect(loaded?.id, kProProductId);
    });
  });
}

ProductDetails _product(String id) => ProductDetails(
  id: id,
  title: 'Go Pro',
  description: 'Remove ads',
  price: r'$2.99',
  rawPrice: 2.99,
  currencyCode: 'USD',
);

/// [SettingsStore] whose Pro flag lives in memory; file I/O is never touched.
class _FakeStore extends SettingsStore {
  _FakeStore({required bool initial}) : persisted = initial;

  bool persisted;
  int setCalls = 0;

  @override
  Future<bool> proEntitled() async => persisted;

  @override
  Future<void> setProEntitled(bool value) async {
    setCalls++;
    persisted = value;
  }
}

/// [InAppPurchase] test double returning a canned product-details response.
/// Only [queryProductDetails] is exercised; anything else throws.
class _FakeInAppPurchase implements InAppPurchase {
  _FakeInAppPurchase(this._response);

  final ProductDetailsResponse _response;
  Set<String>? lastQuery;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async {
    lastQuery = identifiers;
    return _response;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    '${invocation.memberName} is not stubbed on _FakeInAppPurchase',
  );
}
