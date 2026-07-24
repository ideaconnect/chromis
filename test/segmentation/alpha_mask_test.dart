import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:photo_editor_ai/features/segmentation/alpha_mask.dart';

/// Exercises the AlphaMask value type: its dimension/length invariants, the
/// filled/empty factories, row-major indexing, coverage fractions, copyWith,
/// and value equality (== / hashCode over the alpha bytes).
void main() {
  test('constructor rejects non-positive dimensions', () {
    expect(
      () => AlphaMask(width: 0, height: 4, alpha: Uint8List(0)),
      throwsAssertionError,
    );
    expect(
      () => AlphaMask(width: 4, height: 0, alpha: Uint8List(0)),
      throwsAssertionError,
    );
  });

  test('constructor rejects a mismatched alpha length', () {
    expect(
      () => AlphaMask(width: 2, height: 2, alpha: Uint8List(3)),
      throwsAssertionError,
    );
  });

  test('filled clamps the value into 0..255', () {
    expect(AlphaMask.filled(2, 2, 300).at(0, 0), 255); // over the top
    expect(AlphaMask.filled(2, 2, -5).at(0, 0), 0); // below the floor
    expect(AlphaMask.filled(2, 2, 128).at(1, 1), 128); // in range, untouched
    final f = AlphaMask.filled(3, 2, 77);
    expect(f.length, 6);
    expect(f.alpha.every((v) => v == 77), isTrue); // every pixel is the value
  });

  test('empty is a fully-transparent mask', () {
    final e = AlphaMask.empty(3, 3);
    expect(e.length, 9);
    expect(e.alpha.every((v) => v == 0), isTrue);
    expect(e.coverage(1), 0.0); // nothing at or above 1
  });

  test('at reads row-major (y * width + x)', () {
    final buf = Uint8List.fromList([0, 1, 2, 3, 4, 5]);
    final m = AlphaMask(width: 3, height: 2, alpha: buf);
    for (var y = 0; y < 2; y++) {
      for (var x = 0; x < 3; x++) {
        expect(m.at(x, y), buf[y * 3 + x]);
      }
    }
    expect(m.at(0, 0), 0); // first pixel is the first byte
    expect(m.at(2, 1), 5); // last pixel is the last byte
  });

  test('coverage is the fraction of pixels at or above the cutoff', () {
    final m = AlphaMask(
      width: 2,
      height: 2,
      alpha: Uint8List.fromList([0, 127, 128, 255]),
    );
    expect(m.coverage(), closeTo(0.5, 1e-9)); // default cutoff 128 -> {128,255}
    expect(m.coverage(127), closeTo(0.75, 1e-9)); // {127,128,255}
    expect(m.coverage(200), closeTo(0.25, 1e-9)); // {255}
    expect(m.coverage(0), 1.0); // every pixel is >= 0
    expect(m.coverage(256), 0.0); // no pixel reaches 256
    // A lower cutoff can only ever include more pixels.
    expect(m.coverage(127), greaterThanOrEqualTo(m.coverage()));
    expect(m.coverage(), greaterThanOrEqualTo(m.coverage(200)));
  });

  test('copyWith swaps alpha and keeps dimensions', () {
    final m = AlphaMask.filled(2, 3, 50);
    final swapped = m.copyWith(alpha: Uint8List.fromList([1, 2, 3, 4, 5, 6]));
    expect(swapped.width, m.width);
    expect(swapped.height, m.height);
    expect(swapped.alpha, orderedEquals([1, 2, 3, 4, 5, 6]));
    // No argument reuses the same backing buffer and stays equal.
    final same = m.copyWith();
    expect(same, equals(m));
    expect(identical(same.alpha, m.alpha), isTrue);
  });

  test('== and hashCode compare dimensions and alpha element-wise', () {
    final a = AlphaMask(
      width: 2,
      height: 2,
      alpha: Uint8List.fromList([1, 2, 3, 4]),
    );
    final b = AlphaMask(
      width: 2,
      height: 2,
      alpha: Uint8List.fromList([1, 2, 3, 4]),
    );
    expect(a, equals(b)); // distinct instances, equal content
    expect(a.hashCode, equals(b.hashCode));
    final differentAlpha = AlphaMask(
      width: 2,
      height: 2,
      alpha: Uint8List.fromList([1, 2, 3, 5]),
    );
    expect(a, isNot(equals(differentAlpha)));
    final differentDims = AlphaMask(
      width: 4,
      height: 1,
      alpha: Uint8List.fromList([1, 2, 3, 4]),
    );
    expect(a, isNot(equals(differentDims))); // same bytes, different shape
  });
}
