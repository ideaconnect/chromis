import 'dart:math' as math;
import 'dart:ui';

import 'package:chromis/features/editor/mask_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the per-layer-crop fix: the inverse mapper must invert the SAME
/// cropped source rect the renderer draws, so Erase / object-removal taps land
/// on the right source pixel on a cropped layer.
///
/// The added cases exercise every branch of the geometry - rotation, scale, a
/// non-square image, the dy (vertical) crop axis, a `boxSize` override and
/// `radiusToMask` - plus a general round-trip against an independent forward
/// transform ([_maskToCanvas]) so no single case leans on a magic number.
void main() {
  const size = Size(1000, 1000);
  const centre = Offset(256, 256); // a layer centred in 512-logical space

  test('full crop maps the layer centre to the image centre', () {
    const m = MaskMapper(
      imageSize: size,
      position: centre,
      layerScale: 1,
      rotation: 0,
    );
    final p = m.canvasToMask(centre);
    expect(p, isNotNull);
    expect(p!.dx, closeTo(500, 0.5));
    expect(p.dy, closeTo(500, 0.5));
  });

  test('right-half crop maps the centre to source x≈750 (not 500)', () {
    const m = MaskMapper(
      imageSize: size,
      position: centre,
      layerScale: 1,
      rotation: 0,
      cropRect: Rect.fromLTRB(0.5, 0, 1, 1),
    );
    final p = m.canvasToMask(centre);
    expect(p, isNotNull);
    expect(p!.dx, closeTo(750, 0.5));
    expect(p.dy, closeTo(500, 0.5));
  });

  test('a point outside the visible crop returns null', () {
    const m = MaskMapper(
      imageSize: size,
      position: centre,
      layerScale: 1,
      rotation: 0,
      cropRect: Rect.fromLTRB(0.5, 0, 1, 1),
    );
    // Far left of the layer - off the (right-half) visible content.
    expect(m.canvasToMask(centre - const Offset(400, 0)), isNull);
  });

  test('rotation is inverted back to the source pixel', () {
    // Quarter-turn layer. Forward: source (750,500) → fraction (0.75,0.5) →
    // box (110,0) → rotate +π/2 → rel (0,110) → canvas (256,366). canvasToMask
    // must undo that rotation and recover (750,500).
    const m = MaskMapper(
      imageSize: size,
      position: centre,
      layerScale: 1,
      rotation: math.pi / 2,
    );
    final p = m.canvasToMask(const Offset(256, 366));
    expect(p, isNotNull);
    expect(p!.dx, closeTo(750, 0.5));
    expect(p.dy, closeTo(500, 0.5));
    // The layer centre is the rotation pivot: it still maps to the image centre.
    final c = m.canvasToMask(centre);
    expect(c!.dx, closeTo(500, 0.5));
    expect(c.dy, closeTo(500, 0.5));
  });

  test('layerScale > 1 shrinks the source step per canvas unit', () {
    const m = MaskMapper(
      imageSize: size,
      position: centre,
      layerScale: 2,
      rotation: 0,
    );
    // At scale 2 a canvas offset of 220 (vs 110 at scale 1) reaches x≈750.
    final p = m.canvasToMask(const Offset(476, 256));
    expect(p, isNotNull);
    expect(p!.dx, closeTo(750, 0.5));
    expect(p.dy, closeTo(500, 0.5));
    // Scale never moves the centre off the image centre.
    final c = m.canvasToMask(centre);
    expect(c!.dx, closeTo(500, 0.5));
    expect(c.dy, closeTo(500, 0.5));
  });

  test('non-square image stays undistorted and centres correctly', () {
    const m = MaskMapper(
      imageSize: Size(1200, 800),
      position: centre,
      layerScale: 1,
      rotation: 0,
    );
    final c = m.canvasToMask(centre);
    expect(c, isNotNull);
    expect(c!.dx, closeTo(600, 0.5)); // image centre x
    expect(c.dy, closeTo(400, 0.5)); // image centre y
    // Undistorted: equal canvas offsets on x and y do NOT map to equal source
    // steps - a 1200-wide image spreads x over more source pixels than y.
    final px = m.canvasToMask(centre + const Offset(50, 0))!;
    final py = m.canvasToMask(centre + const Offset(0, 50))!;
    expect((px.dx - 600).abs(), closeTo((py.dy - 400).abs(), 0.5));
  });

  test('top/bottom crop maps down the dy axis', () {
    // cropRect shows the bottom half; the layer centre lands at the centre of
    // that visible band (source y≈750) and points above the band fall off.
    const m = MaskMapper(
      imageSize: size,
      position: centre,
      layerScale: 1,
      rotation: 0,
      cropRect: Rect.fromLTRB(0, 0.5, 1, 1),
    );
    final c = m.canvasToMask(centre);
    expect(c, isNotNull);
    expect(c!.dx, closeTo(500, 0.5));
    expect(c.dy, closeTo(750, 0.5));
    // A point higher up the layer maps higher up the bottom-half band.
    final up = m.canvasToMask(const Offset(256, 190));
    expect(up, isNotNull);
    expect(up!.dy, closeTo(600, 0.5));
    // Above the visible band → outside the crop → null.
    expect(m.canvasToMask(const Offset(256, 120)), isNull);
  });

  test('boxSize override changes which canvas offset hits a pixel', () {
    const m = MaskMapper(
      imageSize: size,
      position: centre,
      layerScale: 1,
      rotation: 0,
      boxSize: 512,
    );
    // fx = d/boxSize + 0.5; with boxSize 512, d=128 → fx=0.75 → x≈750
    // (the same pixel needs d=110 at the default boxSize 440).
    final p = m.canvasToMask(const Offset(384, 256));
    expect(p, isNotNull);
    expect(p!.dx, closeTo(750, 0.5));
    expect(p.dy, closeTo(500, 0.5));
  });

  test('radiusToMask converts logical radius to mask pixels', () {
    // containScale = boxSize/imgW = 440/1000 = 0.44; radius / scale / contain.
    const m = MaskMapper(
      imageSize: size,
      position: centre,
      layerScale: 1,
      rotation: 0,
    );
    expect(m.radiusToMask(44), closeTo(100, 1e-9)); // 44 / 1 / 0.44
    // Linear in the logical radius: doubling the input doubles the output.
    expect(m.radiusToMask(88), closeTo(200, 1e-9));
    // Inverse in the layer scale: doubling the scale halves the mask radius.
    const m2 = MaskMapper(
      imageSize: size,
      position: centre,
      layerScale: 2,
      rotation: 0,
    );
    expect(m2.radiusToMask(44), closeTo(50, 1e-9));
  });

  test('round-trips source pixels through the forward transform', () {
    // Combine every axis (scale, rotation, non-square, crop) and assert
    // canvasToMask exactly inverts an independent forward map.
    const mappers = <MaskMapper>[
      MaskMapper(
        imageSize: size,
        position: centre,
        layerScale: 1.7,
        rotation: 0,
      ),
      MaskMapper(
        imageSize: size,
        position: centre,
        layerScale: 1,
        rotation: math.pi / 3,
      ),
      MaskMapper(
        imageSize: Size(1200, 800),
        position: Offset(200, 300),
        layerScale: 1.3,
        rotation: -math.pi / 5,
      ),
      MaskMapper(
        imageSize: size,
        position: centre,
        layerScale: 1.2,
        rotation: math.pi / 7,
        cropRect: Rect.fromLTRB(0.25, 0.5, 0.75, 1),
      ),
    ];
    const srcs = [Offset(400, 420), Offset(600, 550), Offset(520, 700)];
    for (final m in mappers) {
      for (final s in srcs) {
        // Skip pixels outside this mapper's visible crop (canvasToMask → null).
        final visible =
            s.dx >= m.cropRect.left * m.imageSize.width &&
            s.dx < m.cropRect.right * m.imageSize.width &&
            s.dy >= m.cropRect.top * m.imageSize.height &&
            s.dy < m.cropRect.bottom * m.imageSize.height;
        if (!visible) continue;
        final back = m.canvasToMask(_maskToCanvas(m, s));
        expect(back, isNotNull, reason: '$s in $m');
        expect(back!.dx, closeTo(s.dx, 1e-3), reason: '$s dx');
        expect(back.dy, closeTo(s.dy, 1e-3), reason: '$s dy');
      }
    }
  });
}

/// Independent forward map (mask pixel → canvas logical): the exact inverse of
/// [MaskMapper.canvasToMask], built only from the mapper's public fields. Used
/// to round-trip arbitrary transforms without re-deriving magic numbers.
Offset _maskToCanvas(MaskMapper m, Offset srcPx) {
  final srcW = m.cropRect.width * m.imageSize.width;
  final srcH = m.cropRect.height * m.imageSize.height;
  final containScale = math.min(m.boxSize / srcW, m.boxSize / srcH);
  final fitW = srcW * containScale;
  final fitH = srcH * containScale;
  final fx =
      (srcPx.dx / m.imageSize.width - m.cropRect.left) / m.cropRect.width;
  final fy =
      (srcPx.dy / m.imageSize.height - m.cropRect.top) / m.cropRect.height;
  final bx = fx * fitW + (m.boxSize - fitW) / 2;
  final by = fy * fitH + (m.boxSize - fitH) / 2;
  final box = Offset(bx - m.boxSize / 2, by - m.boxSize / 2);
  final scaled = box * m.layerScale;
  final cosR = math.cos(m.rotation);
  final sinR = math.sin(m.rotation);
  final rel = Offset(
    scaled.dx * cosR - scaled.dy * sinR,
    scaled.dx * sinR + scaled.dy * cosR,
  );
  return m.position + rel;
}
