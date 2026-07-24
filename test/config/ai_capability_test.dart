import 'package:chromis/core/platform/platform_services.dart';
import 'package:chromis/features/segmentation/ai_capability.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the once-per-run device gate for the heavy MobileSAM tier: deny only
/// on a *positive* too-small signal (`isLowRamDevice`, or total RAM under
/// [samMinTotalMemBytes]); when the platform can't answer at all, default to
/// ALLOWED so devices that work today never regress. Drives it through the
/// real provider with a fake [PlatformServices.memoryInfo] surface.
void main() {
  test('an unknown memory profile (null) defaults to allowed', () async {
    final cap = await _capFor(null);
    expect(cap.samAllowed, isTrue);
    expect(cap.reason, isNull);
  });

  test(
    'a low-RAM device is denied regardless of how much total RAM it has',
    () async {
      // 8 GiB total but flagged low-RAM: the lowRam signal wins.
      final cap = await _capFor((
        totalMem: 8 * 1024 * 1024 * 1024,
        availMem: 4 * 1024 * 1024 * 1024,
        lowRam: true,
      ));
      expect(cap.samAllowed, isFalse);
      expect(cap.reason, 'Android reports a low-RAM device');
    },
  );

  test(
    'a device below the 2.5 GiB threshold is denied with a GiB reason',
    () async {
      final cap = await _capFor((
        totalMem: 2 * 1024 * 1024 * 1024,
        availMem: 1 * 1024 * 1024 * 1024,
        lowRam: false,
      ));
      expect(cap.samAllowed, isFalse);
      expect(cap.reason, isNotNull);
      expect(cap.reason, contains('GiB'));
      expect(cap.reason, contains('2.0 GiB'));
      expect(cap.reason, contains('needs 2.5 GiB'));
    },
  );

  test(
    'total RAM exactly at the threshold is allowed; one byte under is denied',
    () async {
      final atThreshold = await _capFor((
        totalMem: samMinTotalMemBytes,
        availMem: 1024,
        lowRam: false,
      ));
      expect(atThreshold.samAllowed, isTrue);
      expect(atThreshold.reason, isNull);

      final underThreshold = await _capFor((
        totalMem: samMinTotalMemBytes - 1,
        availMem: 1024,
        lowRam: false,
      ));
      expect(underThreshold.samAllowed, isFalse);
      expect(underThreshold.reason, contains('GiB'));
    },
  );

  test('an ample-RAM, non-low-RAM device is allowed', () async {
    final cap = await _capFor((
      totalMem: 6 * 1024 * 1024 * 1024,
      availMem: 3 * 1024 * 1024 * 1024,
      lowRam: false,
    ));
    expect(cap.samAllowed, isTrue);
    expect(cap.reason, isNull);
  });
}

/// Resolves [aiCapabilityProvider] with [platformServicesProvider] overridden to
/// report [info] (null == platform couldn't answer).
Future<AiCapability> _capFor(MemoryInfo? info) {
  final container = ProviderContainer.test(
    overrides: [
      platformServicesProvider.overrideWithValue(_FakePlatformServices(info)),
    ],
  );
  return container.read(aiCapabilityProvider.future);
}

/// [PlatformServices] with a canned [memoryInfo]; the real method channel is
/// never touched.
class _FakePlatformServices extends PlatformServices {
  _FakePlatformServices(this._info);

  final MemoryInfo? _info;

  @override
  Future<MemoryInfo?> memoryInfo() async => _info;
}
