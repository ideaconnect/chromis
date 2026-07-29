import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Device RAM facts from Android's ActivityManager: total/available bytes and
/// the system's own low-RAM classification (`isLowRamDevice`).
typedef MemoryInfo = ({int totalMem, int availMem, bool lowRam});

/// Small Android platform helpers behind `chromis/platform`: a device RAM
/// query (for AI-capability checks) and saving exported images into the gallery
/// (MediaStore). [channel] is injectable so tests mock the method channel.
class PlatformServices {
  PlatformServices({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'chromis/platform';

  final MethodChannel _channel;

  /// Device RAM snapshot (ActivityManager.getMemoryInfo + isLowRamDevice).
  /// Returns null when the platform side can't answer - an APK predating the
  /// call, tests without a handler, or a non-Android host - so callers can
  /// choose their own safe default instead of guessing here.
  Future<MemoryInfo?> memoryInfo() async {
    try {
      final map = await _channel.invokeMapMethod<String, Object?>(
        'getMemoryInfo',
      );
      final total = map?['totalMem'];
      final avail = map?['availMem'];
      final lowRam = map?['lowRam'];
      if (total is! int || avail is! int || lowRam is! bool) return null;
      return (totalMem: total, availMem: avail, lowRam: lowRam);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Saves [bytes] as [fileName] into the Pictures gallery. Android 10+ goes
  /// through MediaStore with no runtime permission; below that the native side
  /// asks for storage access once, then writes and media-scans the file.
  ///
  /// Returns the user-visible location (e.g. `Pictures/Chromis/…`) on success,
  /// or a [GallerySaveFailure] saying WHY it failed - "you declined the
  /// permission" needs different words from "the write broke", and the caller
  /// cannot tell them apart from a bare null.
  Future<GallerySaveResult> saveToGallery(
    String fileName,
    String mimeType,
    Uint8List bytes,
  ) async {
    try {
      final location = await _channel.invokeMethod<String>(
        'saveImageToGallery',
        {'fileName': fileName, 'mimeType': mimeType, 'bytes': bytes},
      );
      return location == null
          ? const GallerySaveFailure(permissionDenied: false)
          : GallerySaveSuccess(location);
    } on PlatformException catch (e) {
      return GallerySaveFailure(
        permissionDenied: e.code == 'permission_denied',
      );
    } on MissingPluginException {
      return const GallerySaveFailure(permissionDenied: false);
    }
  }
}

/// Outcome of [PlatformServices.saveToGallery].
sealed class GallerySaveResult {
  const GallerySaveResult();
}

final class GallerySaveSuccess extends GallerySaveResult {
  const GallerySaveSuccess(this.location);

  /// Where it landed, in words a user can act on ("Pictures/Chromis/x.png").
  final String location;
}

final class GallerySaveFailure extends GallerySaveResult {
  const GallerySaveFailure({required this.permissionDenied});

  /// True when the user declined the pre-Android-10 storage permission, which
  /// is recoverable by granting it - unlike every other failure here.
  final bool permissionDenied;
}

final platformServicesProvider = Provider<PlatformServices>(
  (ref) => PlatformServices(),
);
