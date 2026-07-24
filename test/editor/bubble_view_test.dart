import 'dart:ui';

import 'package:chromis/core/models/layer.dart';
import 'package:chromis/features/editor/widgets/bubble_view.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the bubble geometry + caption-fitting helpers shared by the live
/// [BubbleView] and the export renderer (WYSIWYG, #78/#79). The tail-tip and
/// tail-from-local mappers must invert each other inside the clamp bounds, the
/// caption line-cap must stay >= 1, and the auto font-size must clamp between
/// the caller's maxSize and the 6.0 floor.
void main() {
  // The fit helpers lay out real [TextPainter]s (dart:ui), so a binding is
  // required even though we never pump a widget tree.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('kBubbleBaseSize', () {
    test('is the documented 210x168 logical box', () {
      expect(kBubbleBaseSize, const Size(210, 168));
    });
  });

  group('bubbleBodyRect', () {
    test('is the documented 6%/5% inset at 88% x 63%', () {
      const size = Size(300, 200);
      final body = bubbleBodyRect(size);
      expect(body.left, closeTo(size.width * 0.06, 1e-9));
      expect(body.top, closeTo(size.height * 0.05, 1e-9));
      expect(body.width, closeTo(size.width * 0.88, 1e-9));
      expect(body.height, closeTo(size.height * 0.63, 1e-9));
    });

    test('stays fully inside the box for a scaled size', () {
      final size = kBubbleBaseSize * 2.5;
      final body = bubbleBodyRect(size);
      expect(body.left, greaterThanOrEqualTo(0));
      expect(body.top, greaterThanOrEqualTo(0));
      expect(body.right, lessThanOrEqualTo(size.width));
      expect(body.bottom, lessThanOrEqualTo(size.height));
    });
  });

  group('bubbleTailTip / bubbleTailFromLocal round-trip', () {
    // Every tail here lands strictly inside the box AND inside the normalized
    // clamp window, so the two mappers are exact inverses (within fp epsilon).
    const size = kBubbleBaseSize;
    const inBounds = <Offset>[
      Offset(-0.28, 0.86), // the BubbleLayer default tail
      Offset(0, 0),
      Offset(0.5, 0.3),
      Offset(-0.9, 0.9),
      Offset(1.0, -1.0),
    ];

    for (final tail in inBounds) {
      test('tail $tail survives tip -> local -> tail', () {
        final layer = BubbleLayer(id: 'b', name: 'Bubble', tail: tail);
        final back = bubbleTailFromLocal(bubbleTailTip(layer, size), size);
        expect(back.dx, closeTo(tail.dx, 1e-9));
        expect(back.dy, closeTo(tail.dy, 1e-9));
      });
    }

    test('round-trips identically at a larger (scaled) box', () {
      final scaled = kBubbleBaseSize * 3;
      const tail = Offset(0.4, 0.7);
      const layer = BubbleLayer(id: 'b', name: 'Bubble', tail: tail);
      final back = bubbleTailFromLocal(bubbleTailTip(layer, scaled), scaled);
      expect(back.dx, closeTo(tail.dx, 1e-9));
      expect(back.dy, closeTo(tail.dy, 1e-9));
    });
  });

  group('bubbleTailTip clamping', () {
    const size = kBubbleBaseSize;

    test('clamps the tip to the box, not the (smaller) body', () {
      final body = bubbleBodyRect(size);
      const layer = BubbleLayer(id: 'b', name: 'Bubble', tail: Offset(10, 10));
      final tip = bubbleTailTip(layer, size);
      // Tip pinned to the box edges...
      expect(tip.dx, size.width);
      expect(tip.dy, size.height);
      // ...which lie beyond the body rect, proving it is not body-clamped.
      expect(tip.dx, greaterThan(body.right));
      expect(tip.dy, greaterThan(body.bottom));
    });

    test('negative extreme clamps to the box origin', () {
      const layer = BubbleLayer(
        id: 'b',
        name: 'Bubble',
        tail: Offset(-10, -10),
      );
      final tip = bubbleTailTip(layer, size);
      expect(tip.dx, 0);
      expect(tip.dy, 0);
    });

    test('any tail yields a tip within the box bounds', () {
      const tails = [
        Offset(50, 50),
        Offset(-50, -50),
        Offset(3, -3),
        Offset(-0.28, 0.86),
      ];
      for (final t in tails) {
        final tip = bubbleTailTip(
          BubbleLayer(id: 'b', name: 'Bubble', tail: t),
          size,
        );
        expect(tip.dx, inInclusiveRange(0, size.width), reason: 'tail $t');
        expect(tip.dy, inInclusiveRange(0, size.height), reason: 'tail $t');
      }
    });
  });

  group('bubbleCaptionMaxLines', () {
    test('non-positive fontSize falls back to a single line', () {
      expect(bubbleCaptionMaxLines(0, 100), 1);
      expect(bubbleCaptionMaxLines(-5, 100), 1);
    });

    test('non-positive height falls back to a single line', () {
      expect(bubbleCaptionMaxLines(10, 0), 1);
      expect(bubbleCaptionMaxLines(10, -5), 1);
    });

    test('is floor(height / (fontSize * 1.05))', () {
      // 100 / (10 * 1.05) = 9.523... -> 9
      expect(bubbleCaptionMaxLines(10, 100), 9);
    });

    test('never returns below 1 even when a line cannot fit', () {
      // 10 / (50 * 1.05) = 0.19 -> floor 0 -> clamped up to 1.
      expect(bubbleCaptionMaxLines(50, 10), 1);
    });

    test('is monotonic: more height allows at least as many lines', () {
      final few = bubbleCaptionMaxLines(12, 60);
      final many = bubbleCaptionMaxLines(12, 240);
      expect(many, greaterThanOrEqualTo(few));
    });
  });

  group('bubbleFitFontSize', () {
    const family = 'Roboto';

    test('empty text returns maxSize untouched', () {
      expect(
        bubbleFitFontSize(
          text: '',
          fontFamily: family,
          maxSize: 30,
          bounds: const Size(100, 100),
        ),
        30,
      );
    });

    test('blank (whitespace-only) text returns maxSize', () {
      expect(
        bubbleFitFontSize(
          text: '   \n\t',
          fontFamily: family,
          maxSize: 24,
          bounds: const Size(100, 100),
        ),
        24,
      );
    });

    test('empty bounds returns maxSize', () {
      expect(
        bubbleFitFontSize(
          text: 'Hello',
          fontFamily: family,
          maxSize: 18,
          bounds: Size.zero,
        ),
        18,
      );
    });

    test('short text that already fits keeps maxSize', () {
      // A tiny caption in a generous box fits at maxSize -> no shrink.
      expect(
        bubbleFitFontSize(
          text: 'Hi',
          fontFamily: family,
          maxSize: 8,
          bounds: const Size(400, 400),
        ),
        8,
      );
    });

    test('very long text shrinks toward, but not below, the 6.0 floor', () {
      const maxSize = 30.0;
      final size = bubbleFitFontSize(
        text: 'A' * 1000,
        fontFamily: family,
        maxSize: maxSize,
        bounds: const Size(60, 40),
      );
      expect(size, lessThan(maxSize)); // it did not fit at maxSize
      expect(size, greaterThanOrEqualTo(6.0)); // never below the floor
    });

    test('roomier bounds never yield a smaller font for the same text', () {
      const text = 'The quick brown fox jumps over the lazy dog again';
      const maxSize = 40.0;
      final tight = bubbleFitFontSize(
        text: text,
        fontFamily: family,
        maxSize: maxSize,
        bounds: const Size(60, 50),
      );
      final roomy = bubbleFitFontSize(
        text: text,
        fontFamily: family,
        maxSize: maxSize,
        bounds: const Size(400, 400),
      );
      expect(roomy, greaterThanOrEqualTo(tight));
      expect(roomy, lessThanOrEqualTo(maxSize));
    });
  });
}
