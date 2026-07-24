import 'package:flutter_test/flutter_test.dart';
import 'package:photo_editor_ai/features/segmentation/engines/inpaint/inpaint_engine.dart';

/// Guards the MI-GAN letterbox geometry: a non-square photo must map into the
/// square 512 field fit-contain (undistorted), and _postprocess crops the fill
/// back out of the SAME rect. A wrong box would misplace the synthesized fill.
void main() {
  test('square photo fills the whole 512 field (no padding)', () {
    final b = inpaintLetterbox(100, 100);
    expect(b.x, 0);
    expect(b.y, 0);
    expect(b.w, 512);
    expect(b.h, 512);
  });

  test('landscape 2:1 photo is letterboxed with top/bottom padding', () {
    final b = inpaintLetterbox(200, 100);
    expect(b.w, 512);
    expect(b.h, 256);
    expect(b.x, 0);
    expect(b.y, 128); // centered vertically
  });

  test('portrait 1:2 photo is letterboxed with left/right padding', () {
    final b = inpaintLetterbox(100, 200);
    expect(b.w, 256);
    expect(b.h, 512);
    expect(b.x, 128); // centered horizontally
    expect(b.y, 0);
  });

  test('box always fits the 512 field and preserves aspect', () {
    const cases = [
      [1920, 1080],
      [640, 480],
      [1000, 3000],
      [37, 512],
    ];
    for (final dims in cases) {
      final b = inpaintLetterbox(dims[0], dims[1]);
      expect(b.x + b.w, lessThanOrEqualTo(512), reason: '$dims width overflow');
      expect(
        b.y + b.h,
        lessThanOrEqualTo(512),
        reason: '$dims height overflow',
      );
      expect(b.w, greaterThan(0));
      expect(b.h, greaterThan(0));
      final srcAr = dims[0] / dims[1];
      final boxAr = b.w / b.h;
      expect(boxAr, closeTo(srcAr, 0.03), reason: '$dims aspect distorted');
    }
  });
}
