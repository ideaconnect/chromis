import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Device RAM facts from Android's ActivityManager: total/available bytes and
/// the system's own low-RAM classification (`isLowRamDevice`).
typedef MemoryInfo = ({int totalMem, int availMem, bool lowRam});

/// Small Android platform helpers behind `photo_editor/platform`: a device RAM
/// query (for AI-capability checks) and saving exported images into the gallery
/// (MediaStore). [channel] is injectable so tests mock the method channel.
class PlatformServices {
  PlatformServices({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'photo_editor/platform';

  final MethodChannel _channel;

  /// Device RAM snapshot (ActivityManager.getMemoryInfo + isLowRamDevice).
  /// Returns null when the platform side can't answer — an APK predating the
  /// call, tests without a handler, or a non-Android host — so callers can
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

  /// Saves [bytes] as [fileName] into the Pictures gallery (Android 10+ uses
  /// MediaStore with no runtime permission). Returns the user-visible location
  /// (e.g. `Pictures/Photo Editor AI/…`), or null on failure.
  Future<String?> saveToGallery(
    String fileName,
    String mimeType,
    Uint8List bytes,
  ) async {
    try {
      return await _channel.invokeMethod<String>('saveImageToGallery', {
        'fileName': fileName,
        'mimeType': mimeType,
        'bytes': bytes,
      });
    } on PlatformException {
      return null;
    }
  }
}

final platformServicesProvider = Provider<PlatformServices>(
  (ref) => PlatformServices(),
);
