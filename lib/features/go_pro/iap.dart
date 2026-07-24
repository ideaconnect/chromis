import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/settings/settings_store.dart';

/// The one-time, non-consumable product that removes all ads. Create this exact
/// id in Play Console → Monetize → In-app products (see docs/monetization-setup.md).
const kProProductId = 'pro_remove_ads';

// ------------------------------------------------------------- entitlement
/// Whether the user owns Go Pro. Loads the cached flag at build; [grant] flips
/// it (persisted) when a purchase is delivered or restored.
class EntitlementController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => ref.read(settingsStoreProvider).proEntitled();

  Future<void> grant() async {
    if (state.asData?.value == true) return;
    state = const AsyncData(true);
    await ref.read(settingsStoreProvider).setProEntitled(true);
  }
}

final proEntitledProvider = AsyncNotifierProvider<EntitlementController, bool>(
  EntitlementController.new,
);

/// Is Pro active right now (false while loading / not owned). Ads read this to
/// hide themselves.
final isProProvider = Provider<bool>(
  (ref) => ref.watch(proEntitledProvider).asData?.value ?? false,
);

// --------------------------------------------------------------- purchasing
final inAppPurchaseProvider = Provider<InAppPurchase>(
  (_) => InAppPurchase.instance,
);

/// Wraps `in_app_purchase` for the single Go Pro product: availability, price,
/// buy, restore. DELIVERY (acknowledge + grant entitlement) is handled by
/// [purchaseDeliveryProvider], not here, so it survives backgrounding.
class IapService {
  IapService(this._iap);
  final InAppPurchase _iap;

  Future<bool> isAvailable() => _iap.isAvailable();

  /// The Go Pro product, or null if unavailable / not found (product not active
  /// in Play Console, or the signed build isn't on a track yet).
  Future<ProductDetails?> loadProduct() async {
    final resp = await _iap.queryProductDetails({kProProductId});
    if (resp.productDetails.isEmpty) return null;
    return resp.productDetails.first;
  }

  Future<void> buy(ProductDetails product) => _iap.buyNonConsumable(
    purchaseParam: PurchaseParam(productDetails: product),
  );

  Future<void> restore() => _iap.restorePurchases();
}

final iapServiceProvider = Provider<IapService>(
  (ref) => IapService(ref.read(inAppPurchaseProvider)),
);

/// The Go Pro product (for its localized price), or null when unavailable.
final proProductProvider = FutureProvider<ProductDetails?>(
  (ref) => ref.read(iapServiceProvider).loadProduct(),
);

/// App-wide purchase delivery: grants the entitlement on a purchased/restored
/// Go Pro and acknowledges every purchase within Google's 3-day window (or it
/// is auto-refunded). Activate once at app start (see app.dart). Idempotent.
final purchaseDeliveryProvider = Provider<void>((ref) {
  final iap = ref.read(inAppPurchaseProvider);
  final sub = iap.purchaseStream.listen((purchases) async {
    for (final p in purchases) {
      if ((p.status == PurchaseStatus.purchased ||
              p.status == PurchaseStatus.restored) &&
          p.productID == kProProductId) {
        await ref.read(proEntitledProvider.notifier).grant();
      }
      if (p.pendingCompletePurchase) {
        await iap.completePurchase(p);
      }
    }
  });
  ref.onDispose(sub.cancel);
});
