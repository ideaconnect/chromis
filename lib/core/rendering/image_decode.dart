import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// A decoded photo together with the size of the file it came from. [image] is
/// usually smaller: the decode is capped so a 12 MP source does not become a
/// 48 MB bitmap for a thumbnail-sized box.
class DecodedImage {
  const DecodedImage({
    required this.image,
    required this.sourceWidth,
    required this.sourceHeight,
  });

  final ui.Image image;

  /// Dimensions of the *encoded* file, before any decode cap.
  final int sourceWidth;
  final int sourceHeight;
}

/// Decodes the image at [path], scaled down to fit within [maxWidth] /
/// [maxHeight] px, or null if the file is missing or is not a decodable image.
/// Never upscales.
///
/// **Every photo decode in the app goes through this one function, and the
/// point of that is the dispose order.** `instantiateCodec` copies nothing -
/// the encoded bytes and the decoder still belong to the `ImageDescriptor` -
/// so releasing the descriptor (or the buffer) before `getNextFrame()` hands
/// the decoder an empty descriptor. `ImageDecoderSkia` checks for that and
/// answers with "Codec failed to produce an image" - which is what a widget
/// test and a `--debug` APK see. `ImageDecoderImpeller`, which is what an
/// Android release build runs, has no equivalent check: it passes the null data
/// to `SkMallocPixelRef::MakeWithData`, which dereferences it. (Read from the
/// engine source, not observed on hardware.) Getting this backwards in one of
/// three hand-copied decoders is what broke the Adjust panel's Crop button.
Future<DecodedImage?> decodeImageFile(
  String path, {
  int? maxWidth,
  int? maxHeight,
}) async {
  try {
    final file = File(path);
    if (!file.existsSync()) return null;
    final buffer = await ui.ImmutableBuffer.fromUint8List(
      await file.readAsBytes(),
    );
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    try {
      final codec = await descriptor.instantiateCodec(
        targetWidth: _targetWidth(
          descriptor.width,
          descriptor.height,
          maxWidth,
          maxHeight,
        ),
      );
      try {
        final frame = await codec.getNextFrame();
        return DecodedImage(
          image: frame.image,
          sourceWidth: descriptor.width,
          sourceHeight: descriptor.height,
        );
      } finally {
        codec.dispose();
      }
    } finally {
      // Both AFTER the frame is produced - see the note above.
      descriptor.dispose();
      buffer.dispose();
    }
  } catch (error, stack) {
    // A missing file returned above; anything reaching here is a decode that
    // genuinely failed, and callers turn that into a placeholder or a toast.
    // Swallowing it silently is how a 100%-reproducible failure shipped, so
    // say so in debug builds.
    assert(() {
      debugPrint('decodeImageFile("$path") failed: $error\n$stack');
      return true;
    }());
    return null;
  }
}

/// The `targetWidth` that fits a [w]x[h] source inside the caps, or null to
/// decode at full size. Only ever ONE dimension is given to the codec: passing
/// both `targetWidth` and `targetHeight` stretches the image instead of
/// fitting it, so a height cap is expressed as the width it implies.
int? _targetWidth(int w, int h, int? maxWidth, int? maxHeight) {
  int? target;
  if (maxWidth != null && w > maxWidth) target = maxWidth;
  if (maxHeight != null && h > maxHeight && h > 0) {
    final byHeight = math.max(1, (w * maxHeight / h).round());
    target = target == null ? byHeight : math.min(target, byHeight);
  }
  return target;
}
