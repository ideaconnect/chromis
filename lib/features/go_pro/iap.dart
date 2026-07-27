import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/settings/settings_store.dart';

/// The one-time, non-consumable product that removes all ads.
///
/// This must match the **product id** in Play Console → Monetize → Products →
/// One-time products exactly; a mismatch is silent. `loadProduct` simply gets an
/// empty response, `proProductProvider` resolves to null, and the Go Pro screen
/// shows "Purchases are temporarily unavailable" forever - there is no error to
/// notice, only a paywall that never sells anything.
///
/// The product also needs a purchase option marked **backward compatible** in
/// the console. `in_app_purchase` speaks the legacy Play Billing product model,
/// which addresses a product by this id alone and cannot name a purchase option;
/// without that flag the query comes back empty exactly as if the id were wrong.
///
/// See docs/monetization-setup.md.
const kProProductId = 'chromis_pro_mode';

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

  /// Drops the entitlement (e.g. after a confirmed refund). Persisted so ads
  /// stay back on the next launch too.
  Future<void> revoke() async {
    if (state.asData?.value == false) return;
    state = const AsyncData(false);
    await ref.read(settingsStoreProvider).setProEntitled(false);
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
/// is auto-refunded). It also permissively reconciles the cached entitlement
/// against live Play ownership at launch (see [reconcileEntitlement]). Activate
/// once at app start (see app.dart). Idempotent.
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

  // Catch refunds: re-check the cached Pro flag against Play, revoking only on
  // a confirmed "not owned". Any uncertainty keeps Pro. Best-effort.
  unawaited(
    reconcileEntitlement(
      iap: iap,
      store: ref.read(settingsStoreProvider),
      onRevoke: () => ref.read(proEntitledProvider.notifier).revoke(),
    ),
  );
});

/// Permissive launch-time re-check of the cached Pro flag against Google Play's
/// live ownership. Calls [onRevoke] ONLY on a confirmed "not owned" - e.g. the
/// user refunded the purchase. Every uncertain case keeps Pro intact: not
/// currently entitled, billing unavailable, a query error / no internet
/// ([InAppPurchase.restorePurchases] throws), or no answer within [timeout].
///
/// Relies on `restorePurchases` emitting Play's full current owned set (each
/// item `restored`, or an empty list) and throwing on a failed query.
Future<void> reconcileEntitlement({
  required InAppPurchase iap,
  required SettingsStore store,
  required Future<void> Function() onRevoke,
  Duration timeout = const Duration(seconds: 10),
}) async {
  if (!await store.proEntitled()) return; // not Pro -> nothing to revoke
  bool available;
  try {
    available = await iap.isAvailable();
  } catch (_) {
    return; // can't reach billing -> keep
  }
  if (!available) return; // can't verify -> keep

  // true = Pro owned, false = confirmed not owned, null = couldn't determine.
  final answer = Completer<bool?>();
  final sub = iap.purchaseStream.listen((purchases) {
    // A restore result is Play's full current owned set: every item `restored`,
    // or an empty list. Ignore fresh `purchased` events (delivered elsewhere).
    final isRestore =
        purchases.isEmpty ||
        purchases.every((p) => p.status == PurchaseStatus.restored);
    if (!isRestore || answer.isCompleted) return;
    final ownsPro = purchases.any(
      (p) =>
          p.productID == kProProductId && p.status == PurchaseStatus.restored,
    );
    answer.complete(ownsPro);
  });
  final timer = Timer(timeout, () {
    if (!answer.isCompleted) answer.complete(null); // no answer -> keep
  });
  try {
    await iap.restorePurchases();
  } catch (_) {
    if (!answer.isCompleted) answer.complete(null); // error / offline -> keep
  }
  final owned = await answer.future;
  await sub.cancel();
  timer.cancel();
  if (owned == false) await onRevoke(); // confirmed not owned -> revoke
}
