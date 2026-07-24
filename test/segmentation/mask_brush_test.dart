import 'package:chromis/features/segmentation/alpha_mask.dart';
import 'package:chromis/features/segmentation/mask_brush.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exercises MaskBrush.paint: the no-op guards (empty stroke / non-positive
/// radius), hard vs. soft dab behaviour, monotonic (never-regressing) overlap
/// of repeated dabs, in-bounds edge painting, and stroke densification so a
/// fast drag between far points still covers the gap.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('paint returns the input unchanged for an empty stroke', () {
    final mask = AlphaMask.filled(8, 8, 128);
    const stroke = BrushStroke(points: [], radius: 5, erase: true);
    final result = MaskBrush.paint(mask, stroke);
    expect(identical(result, mask), isTrue); // same instance, no work done
    expect(result.alpha, orderedEquals(mask.alpha));
  });

  test('paint returns the input unchanged for a non-positive radius', () {
    final mask = AlphaMask.filled(8, 8, 128);
    final zero = MaskBrush.paint(
      mask,
      const BrushStroke(points: [Offset(4, 4)], radius: 0, erase: true),
    );
    final negative = MaskBrush.paint(
      mask,
      const BrushStroke(points: [Offset(4, 4)], radius: -3, erase: false),
    );
    expect(identical(zero, mask), isTrue);
    expect(identical(negative, mask), isTrue);
  });

  test('a hard erase brush sets covered pixels to 0', () {
    final mask = AlphaMask.filled(32, 32, 128);
    const stroke = BrushStroke(
      points: [Offset(16, 16)],
      radius: 5,
      erase: true,
      soft: false,
    );
    final res = MaskBrush.paint(mask, stroke);
    expect(res.at(16, 16), 0); // centre
    expect(res.at(16, 20), 0); // within the radius (d=4)
    expect(res.at(0, 0), 128); // far corner is untouched
    expect(mask.at(16, 16), 128); // the source mask is not mutated
  });

  test('a hard restore brush sets covered pixels to 255', () {
    final mask = AlphaMask.filled(32, 32, 40);
    const stroke = BrushStroke(
      points: [Offset(16, 16)],
      radius: 5,
      erase: false,
      soft: false,
    );
    final res = MaskBrush.paint(mask, stroke);
    expect(res.at(16, 16), 255);
    expect(res.at(16, 20), 255);
    expect(res.at(0, 0), 40); // far corner is untouched
  });

  test('a soft erase brush moves pixels down and never regresses', () {
    final mask = AlphaMask.filled(32, 32, 200);
    const stroke = BrushStroke(
      points: [Offset(16, 16)],
      radius: 8,
      erase: true,
    );
    final r1 = MaskBrush.paint(mask, stroke);
    final r2 = MaskBrush.paint(r1, stroke);
    for (var i = 0; i < mask.length; i++) {
      expect(r1.alpha[i], lessThanOrEqualTo(200)); // never above the source
      expect(r2.alpha[i], lessThanOrEqualTo(r1.alpha[i])); // erase takes min
    }
    expect(r1.at(16, 16), 0); // full strength at the centre reaches the target
    expect(r1.at(16, 23), greaterThan(0)); // feathered edge is only partial
    expect(r1.at(16, 23), lessThan(200));
  });

  test('a soft restore brush moves pixels up and never regresses', () {
    final mask = AlphaMask.filled(32, 32, 50);
    const stroke = BrushStroke(
      points: [Offset(16, 16)],
      radius: 8,
      erase: false,
    );
    final r1 = MaskBrush.paint(mask, stroke);
    final r2 = MaskBrush.paint(r1, stroke);
    for (var i = 0; i < mask.length; i++) {
      expect(r1.alpha[i], greaterThanOrEqualTo(50)); // never below the source
      expect(
        r2.alpha[i],
        greaterThanOrEqualTo(r1.alpha[i]),
      ); // restore takes max
    }
    expect(r1.at(16, 16), 255); // full strength at the centre
    expect(r1.at(16, 23), greaterThan(50)); // feathered edge is only partial
    expect(r1.at(16, 23), lessThan(255));
  });

  test('painting past an edge stays in bounds', () {
    final mask = AlphaMask.filled(32, 32, 128);
    const strokes = <BrushStroke>[
      BrushStroke(points: [Offset(0, 0)], radius: 5, erase: true),
      BrushStroke(points: [Offset(31, 31)], radius: 5, erase: false),
      BrushStroke(points: [Offset(-4, -4)], radius: 6, erase: true),
      BrushStroke(points: [Offset(40, 40)], radius: 6, erase: true),
    ];
    for (final stroke in strokes) {
      expect(() => MaskBrush.paint(mask, stroke), returnsNormally);
    }
    // The in-bounds part of an edge dab is still applied.
    const corner = BrushStroke(
      points: [Offset(0, 0)],
      radius: 5,
      erase: true,
      soft: false,
    );
    expect(MaskBrush.paint(mask, corner).at(0, 0), 0);
  });

  test('a fast stroke is densified so the midpoint is still covered', () {
    final mask = AlphaMask.filled(32, 32, 200);
    // Endpoints 22px apart with a 3px brush: the midpoint (16,16) is 11px from
    // either endpoint, out of reach of both end dabs, so only densification
    // along the path can cover it.
    const stroke = BrushStroke(
      points: [Offset(5, 16), Offset(27, 16)],
      radius: 3,
      erase: true,
    );
    final res = MaskBrush.paint(mask, stroke);
    expect(res.at(16, 16), lessThan(128)); // midpoint genuinely covered
    expect(res.at(5, 16), lessThan(128)); // start covered
    expect(res.at(27, 16), lessThan(128)); // end covered
    expect(res.at(16, 2), 200); // far off the stroke: untouched
  });
}
