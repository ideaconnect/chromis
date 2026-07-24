import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:photo_editor_ai/features/segmentation/alpha_mask.dart';
import 'package:photo_editor_ai/features/segmentation/mask_processing.dart';

/// Exercises every path of the pure mask post-processing chain: threshold,
/// separable feather, keep-largest-component, subtract, tap-to-remove, and the
/// composed [MaskProcessing.process]. Assertions favour invariants and
/// relationships over hand-computed pixel constants.
///
/// Nothing here touches dart:ui (AlphaMask is backed by a plain Uint8List), so
/// no test binding is required.
AlphaMask mk(int w, int h, List<int> v) =>
    AlphaMask(width: w, height: h, alpha: Uint8List.fromList(v));

int total(AlphaMask m) => m.alpha.fold<int>(0, (a, b) => a + b);

void main() {
  group('threshold', () {
    final src = mk(3, 2, [0, 50, 128, 200, 255, 127]);

    test('>= cutoff -> high (default 255), below -> low (default 0)', () {
      final out = MaskProcessing.threshold(src, 128);
      for (var i = 0; i < src.length; i++) {
        expect(out.alpha[i], src.alpha[i] >= 128 ? 255 : 0);
      }
      // Boundary is inclusive: value == cutoff maps to high.
      expect(out.at(2, 0), 255); // src value there is 128 == cutoff
      // Input mask is never mutated.
      expect(src.alpha, [0, 50, 128, 200, 255, 127]);
    });

    test('custom low/high are honoured', () {
      final out = MaskProcessing.threshold(src, 128, low: 10, high: 240);
      for (var i = 0; i < src.length; i++) {
        expect(out.alpha[i], src.alpha[i] >= 128 ? 240 : 10);
      }
    });
  });

  group('feather', () {
    test('radius <= 0 is a no-op (returns the same instance)', () {
      final m = mk(2, 2, [10, 20, 30, 40]);
      expect(identical(MaskProcessing.feather(m, 0), m), isTrue);
      expect(identical(MaskProcessing.feather(m, -3), m), isTrue);
    });

    test('a single hot pixel spreads to neighbours; energy ~preserved', () {
      final before = mk(5, 5, [
        0, 0, 0, 0, 0, //
        0, 0, 0, 0, 0, //
        0, 0, 255, 0, 0, //
        0, 0, 0, 0, 0, //
        0, 0, 0, 0, 0, //
      ]);
      final after = MaskProcessing.feather(before, 1);

      // Original untouched.
      expect(before.at(2, 2), 255);
      // The peak is flattened out...
      expect(after.at(2, 2), lessThan(255));
      expect(after.at(2, 2), greaterThan(0));
      // ...and spreads into the 4-neighbourhood.
      expect(after.at(1, 2), greaterThan(0));
      expect(after.at(3, 2), greaterThan(0));
      expect(after.at(2, 1), greaterThan(0));
      expect(after.at(2, 3), greaterThan(0));
      // Spread is symmetric about the source.
      expect(after.at(1, 2), after.at(3, 2));
      expect(after.at(2, 1), after.at(2, 3));
      expect(after.at(1, 2), after.at(2, 1));
      // Energy is approximately conserved (integer truncation only loses a bit).
      expect(total(after), lessThanOrEqualTo(255));
      expect(total(after).toDouble(), closeTo(255, 20));
    });

    test(
      'a uniform mask is unchanged (border clamping, no edge darkening)',
      () {
        final flat = AlphaMask.filled(5, 5, 90);
        expect(MaskProcessing.feather(flat, 1), flat);
      },
    );
  });

  group('keepLargestComponent', () {
    test('keeps the larger blob, zeroes the smaller, keeps soft coverage', () {
      final m = mk(5, 3, [
        200, 150, 255, 0, 0, //
        0, 0, 0, 0, 0, //
        0, 0, 0, 0, 255, //
      ]);
      final out = MaskProcessing.keepLargestComponent(m);
      // Soft values inside the kept blob survive unsnapped.
      expect(out.at(0, 0), 200);
      expect(out.at(1, 0), 150);
      expect(out.at(2, 0), 255);
      // The lone speck is gone.
      expect(out.at(4, 2), 0);
      expect(total(out), 200 + 150 + 255);
    });

    test('uses 4-connectivity (diagonal touch is a separate component)', () {
      // (0,0) touches the (1,1)-(2,1) bar only diagonally, so it is its own
      // size-1 component and loses to the size-2 bar.
      final m = mk(3, 2, [
        255, 0, 0, //
        0, 255, 255, //
      ]);
      final out = MaskProcessing.keepLargestComponent(m);
      expect(out.at(0, 0), 0); // dropped
      expect(out.at(1, 1), 255); // kept bar
      expect(out.at(2, 1), 255);
    });

    test('nothing at/above the cutoff -> AlphaMask.empty', () {
      expect(
        MaskProcessing.keepLargestComponent(AlphaMask.filled(3, 3, 100)),
        AlphaMask.empty(3, 3),
      );
      expect(
        MaskProcessing.keepLargestComponent(AlphaMask.empty(4, 2)),
        AlphaMask.empty(4, 2),
      );
    });

    test('a lower cutoff can admit the whole mask as one component', () {
      final flat = AlphaMask.filled(3, 3, 100);
      expect(MaskProcessing.keepLargestComponent(flat, cutoff: 50), flat);
    });
  });

  group('subtract', () {
    test('elementwise min(current, 255 - object)', () {
      final current = mk(2, 2, [255, 100, 50, 200]);
      final object = mk(2, 2, [255, 0, 128, 50]);
      final out = MaskProcessing.subtract(current, object);
      expect(out.alpha, [0, 100, 50, 200]);
      // Neither input is mutated.
      expect(current.alpha, [255, 100, 50, 200]);
      expect(object.alpha, [255, 0, 128, 50]);
    });

    test('empty object is a no-op; full object clears everything', () {
      final current = mk(2, 2, [10, 120, 200, 255]);
      expect(MaskProcessing.subtract(current, AlphaMask.empty(2, 2)), current);
      expect(
        MaskProcessing.subtract(current, AlphaMask.filled(2, 2, 255)),
        AlphaMask.empty(2, 2),
      );
    });

    test('asserts matching dimensions', () {
      final current = mk(2, 2, [1, 2, 3, 4]);
      final object = mk(3, 1, [1, 2, 3]);
      expect(
        () => MaskProcessing.subtract(current, object),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('removeObjectAt', () {
    // A 3x3 subject blob (top-left, 9 px) plus a lone 1-px speck at (5,3).
    AlphaMask build() => mk(6, 4, [
      255, 255, 255, 0, 0, 0, //
      255, 255, 255, 0, 0, 0, //
      255, 255, 255, 0, 0, 0, //
      0, 0, 0, 0, 0, 255, //
    ]);

    test('a tap out of bounds misses (null mask)', () {
      final m = build();
      expect(
        MaskProcessing.removeObjectAt(m, -1, 0).outcome,
        RemoveTapOutcome.miss,
      );
      expect(
        MaskProcessing.removeObjectAt(m, 6, 0).outcome,
        RemoveTapOutcome.miss,
      );
      expect(
        MaskProcessing.removeObjectAt(m, 0, 4).outcome,
        RemoveTapOutcome.miss,
      );
      expect(MaskProcessing.removeObjectAt(m, -1, 0).mask, isNull);
    });

    test('a tap on transparency misses (null mask)', () {
      final m = build();
      final r = MaskProcessing.removeObjectAt(m, 3, 3); // alpha 0 there
      expect(r.outcome, RemoveTapOutcome.miss);
      expect(r.mask, isNull);
    });

    test('tapping the largest blob is refused (subject, null mask)', () {
      final m = build();
      final r = MaskProcessing.removeObjectAt(m, 0, 0);
      expect(r.outcome, RemoveTapOutcome.subject);
      expect(r.mask, isNull);
    });

    test('tapping a smaller blob removes it with a feathered seam', () {
      final m = build();
      final r = MaskProcessing.removeObjectAt(m, 5, 3);
      expect(r.outcome, RemoveTapOutcome.removed);
      expect(r.mask, isNotNull);
      final out = r.mask!;
      // The speck is knocked down, but softly (feathered), not a hard zero.
      expect(out.at(5, 3), lessThan(255));
      expect(out.at(5, 3), greaterThan(0));
      // The subject is untouched — the seam is local to the removed blob.
      expect(out.at(0, 0), 255);
      // Overall foreground shrank.
      expect(total(out), lessThan(total(m)));
      // Input not mutated.
      expect(m.at(5, 3), 255);
    });
  });

  group('process', () {
    final input = mk(6, 5, [
      140, 100, 200, 30, 0, 0, //
      120, 255, 160, 90, 0, 0, //
      200, 130, 50, 10, 0, 0, //
      0, 0, 0, 0, 0, 0, //
      0, 0, 0, 0, 0, 255, //
    ]);

    test('applies threshold -> keepLargest -> feather in that order', () {
      const opts = MaskProcessingOptions(threshold: 128, featherRadius: 2);
      final got = MaskProcessing.process(input, opts);
      final manual = MaskProcessing.feather(
        MaskProcessing.keepLargestComponent(
          MaskProcessing.threshold(input, 128),
        ),
        2,
      );
      expect(got, manual);
    });

    test('null threshold and radius 0 skip those steps', () {
      const opts = MaskProcessingOptions(featherRadius: 0);
      final got = MaskProcessing.process(input, opts);
      expect(got, MaskProcessing.keepLargestComponent(input));
    });

    test('all steps disabled is the identity (same instance)', () {
      const opts = MaskProcessingOptions(
        keepLargestComponent: false,
        featherRadius: 0,
      );
      expect(identical(MaskProcessing.process(input, opts), input), isTrue);
    });

    test('default options: keep-largest then feather(1)', () {
      final got = MaskProcessing.process(input, const MaskProcessingOptions());
      final manual = MaskProcessing.feather(
        MaskProcessing.keepLargestComponent(input),
        1,
      );
      expect(got, manual);
    });
  });

  test('MaskProcessingOptions has documented defaults', () {
    const o = MaskProcessingOptions();
    expect(o.threshold, isNull);
    expect(o.keepLargestComponent, isTrue);
    expect(o.featherRadius, 1);
  });
}
