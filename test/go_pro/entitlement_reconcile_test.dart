import 'dart:async';
import 'dart:io';

import 'package:chromis/core/settings/settings_store.dart';
import 'package:chromis/features/go_pro/iap.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Permissive entitlement reconciliation: revoke ONLY on a confirmed refund
/// (Play returns without the Pro purchase). Every uncertain case - offline, a
/// query error, billing unavailable, or no answer - keeps Pro.
void main() {
  late Directory tmp;
  late SettingsStore store;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('chromis_iap');
    store = SettingsStore(baseDir: tmp);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  PurchaseDetails restored(String productId) => PurchaseDetails(
    productID: productId,
    purchaseID: 'p',
    status: PurchaseStatus.restored,
    transactionDate: null,
    verificationData: PurchaseVerificationData(
      localVerificationData: '',
      serverVerificationData: '',
      source: 'google_play',
    ),
  );

  Future<int> revokesFor(_FakeIap iap) async {
    var revokes = 0;
    await reconcileEntitlement(
      iap: iap,
      store: store,
      onRevoke: () async => revokes++,
      timeout: const Duration(milliseconds: 300),
    );
    return revokes;
  }

  test('confirmed not owned (empty restore) revokes', () async {
    await store.setProEntitled(true);
    final iap = _FakeIap(restoreEmits: const []);
    expect(await revokesFor(iap), 1);
    expect(iap.restoreCalled, isTrue);
  });

  test('restore without the Pro product revokes', () async {
    await store.setProEntitled(true);
    final iap = _FakeIap(restoreEmits: [restored('another_product')]);
    expect(await revokesFor(iap), 1);
  });

  test('still owned keeps Pro', () async {
    await store.setProEntitled(true);
    final iap = _FakeIap(restoreEmits: [restored(kProProductId)]);
    expect(await revokesFor(iap), 0);
  });

  test('offline / query error keeps Pro (permissive)', () async {
    await store.setProEntitled(true);
    final iap = _FakeIap(restoreThrows: true);
    expect(await revokesFor(iap), 0);
    expect(iap.restoreCalled, isTrue);
  });

  test('billing unavailable keeps Pro (no restore attempted)', () async {
    await store.setProEntitled(true);
    final iap = _FakeIap(available: false);
    expect(await revokesFor(iap), 0);
    expect(iap.restoreCalled, isFalse);
  });

  test('no answer within the window keeps Pro (permissive)', () async {
    await store.setProEntitled(true);
    final iap = _FakeIap(silentRestore: true); // succeeds but emits nothing
    expect(await revokesFor(iap), 0);
  });

  test('not entitled: no check, no restore, no revoke', () async {
    await store.setProEntitled(false);
    final iap = _FakeIap(restoreEmits: const []);
    expect(await revokesFor(iap), 0);
    expect(iap.restoreCalled, isFalse);
  });

  // ------------------------------------------------------- restore probe
  // reconcileEntitlement is revoke-only by design (the test above pins it), so
  // a reinstall - cached flag false, purchase still owned - was never checked
  // at all: the user landed in a fully ad-supported app with recovery hidden
  // behind a secondary button under one offering to charge them again.
  group('probeRestoreOnce', () {
    test('a fresh install asks Play once and remembers it did', () async {
      final iap = _FakeIap(restoreEmits: [restored(kProProductId)]);
      await probeRestoreOnce(iap: iap, store: store);
      expect(iap.restoreCalled, isTrue);
      expect(await store.restoreProbed(), isTrue);

      // Second launch: no repeat query.
      final again = _FakeIap(restoreEmits: [restored(kProProductId)]);
      await probeRestoreOnce(iap: again, store: store);
      expect(again.restoreCalled, isFalse);
    });

    test('an already-Pro install never probes', () async {
      await store.setProEntitled(true);
      final iap = _FakeIap(restoreEmits: const []);
      await probeRestoreOnce(iap: iap, store: store);
      expect(iap.restoreCalled, isFalse);
      expect(await store.restoreProbed(), isFalse);
    });

    test('an offline first launch does not burn the probe', () async {
      // The flag is set only after a query that reached Play; otherwise a
      // paying user who first opened the app in airplane mode would never be
      // asked about again.
      final offline = _FakeIap(restoreThrows: true);
      await probeRestoreOnce(iap: offline, store: store);
      expect(offline.restoreCalled, isTrue);
      expect(await store.restoreProbed(), isFalse);

      final later = _FakeIap(restoreEmits: [restored(kProProductId)]);
      await probeRestoreOnce(iap: later, store: store);
      expect(later.restoreCalled, isTrue);
      expect(await store.restoreProbed(), isTrue);
    });

    test('billing unavailable retries next launch', () async {
      final iap = _FakeIap(available: false);
      await probeRestoreOnce(iap: iap, store: store);
      expect(iap.restoreCalled, isFalse);
      expect(await store.restoreProbed(), isFalse);
    });
  });
}

/// Minimal [InAppPurchase] fake exposing only what reconciliation touches.
class _FakeIap implements InAppPurchase {
  _FakeIap({
    this.available = true,
    this.restoreEmits,
    this.restoreThrows = false,
    this.silentRestore = false,
  });

  final bool available;
  final List<PurchaseDetails>? restoreEmits;
  final bool restoreThrows;
  final bool silentRestore;
  bool restoreCalled = false;
  final _ctrl = StreamController<List<PurchaseDetails>>.broadcast();

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _ctrl.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    restoreCalled = true;
    if (restoreThrows) throw Exception('offline');
    if (silentRestore) return;
    _ctrl.add(restoreEmits ?? const []);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
