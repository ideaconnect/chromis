import 'package:chromis/features/segmentation/alpha_mask.dart';
import 'package:chromis/features/segmentation/segmentation_engine.dart';
import 'package:chromis/features/segmentation/segmentation_registry.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the [SegmentationRegistry] resolution + fall-through contract with
/// fake engines (no device / plugins): the preferred engine is a *preference*
/// moved to the front - never a dead end - and both `resolve` and `segment`
/// skip unavailable engines and fall through failures, returning null only when
/// nothing can produce a mask.
void main() {
  // A configurable in-memory engine: reports [available], and either returns a
  // result tagged with its own id or throws a [SegmentationException].
  const req = SegmentationRequest(imagePath: 'photo.png');

  test(
    'resolve returns the first available engine in configured order',
    () async {
      final a = _FakeEngine('a');
      final b = _FakeEngine('b');
      final registry = SegmentationRegistry([a, b]);

      final resolved = await registry.resolve();
      expect(resolved?.id, 'a');
    },
  );

  test(
    'resolve skips an unavailable engine and returns the next available',
    () async {
      final registry = SegmentationRegistry([
        _FakeEngine('a', available: false),
        _FakeEngine('b'),
      ]);

      expect((await registry.resolve())?.id, 'b');
    },
  );

  test('resolve returns null when no engine is available', () async {
    final registry = SegmentationRegistry([
      _FakeEngine('a', available: false),
      _FakeEngine('b', available: false),
    ]);

    expect(await registry.resolve(), isNull);
  });

  test(
    'resolve moves the preferred engine to the front even when a later one',
    () async {
      final a = _FakeEngine('a');
      final b = _FakeEngine('b');
      final registry = SegmentationRegistry([a, b]);

      // Both available; without a preference `a` wins, so choosing `b` proves the
      // reordering rather than a coincidence.
      expect((await registry.resolve(preferredId: 'b'))?.id, 'b');
    },
  );

  test('an absent or empty preferred id keeps the original order', () async {
    final registry = SegmentationRegistry([_FakeEngine('a'), _FakeEngine('b')]);

    expect((await registry.resolve(preferredId: 'nope'))?.id, 'a');
    expect((await registry.resolve(preferredId: ''))?.id, 'a');
    expect((await registry.resolve())?.id, 'a');
  });

  test(
    'an unavailable preferred engine falls through to fallbacks in order',
    () async {
      // preferred `c` is unavailable, `a` is unavailable, so the first remaining
      // available fallback in configured order (`b`) wins.
      final registry = SegmentationRegistry([
        _FakeEngine('a', available: false),
        _FakeEngine('b'),
        _FakeEngine('c', available: false),
      ]);

      expect((await registry.resolve(preferredId: 'c'))?.id, 'b');
    },
  );

  test('segment uses the first available engine and tags the result', () async {
    final a = _FakeEngine('a');
    final b = _FakeEngine('b');
    final registry = SegmentationRegistry([a, b]);

    final result = await registry.segment(req);
    expect(result?.engineId, 'a');
    expect(a.segmentCalls, 1);
    expect(b.segmentCalls, 0);
  });

  test('segment does not call segment on an unavailable engine', () async {
    final a = _FakeEngine('a', available: false);
    final b = _FakeEngine('b');
    final registry = SegmentationRegistry([a, b]);

    final result = await registry.segment(req);
    expect(result?.engineId, 'b');
    expect(a.segmentCalls, 0);
    expect(b.segmentCalls, 1);
  });

  test(
    'segment falls through to the next engine on a SegmentationException',
    () async {
      final a = _FakeEngine('a', throwOnSegment: true);
      final b = _FakeEngine('b');
      final registry = SegmentationRegistry([a, b]);

      final result = await registry.segment(req);
      expect(result?.engineId, 'b');
      // The failing engine was tried before falling through.
      expect(a.segmentCalls, 1);
      expect(b.segmentCalls, 1);
    },
  );

  test('segment returns null when every available engine throws', () async {
    final registry = SegmentationRegistry([
      _FakeEngine('a', throwOnSegment: true),
      _FakeEngine('b', throwOnSegment: true),
    ]);

    expect(await registry.segment(req), isNull);
  });

  test('segment returns null when no engine is available', () async {
    final registry = SegmentationRegistry([
      _FakeEngine('a', available: false),
      _FakeEngine('b', available: false),
    ]);

    expect(await registry.segment(req), isNull);
  });

  test(
    'segment runs the preferred engine first, before configured order',
    () async {
      final a = _FakeEngine('a');
      final b = _FakeEngine('b');
      final registry = SegmentationRegistry([a, b]);

      final result = await registry.segment(req, preferredId: 'b');
      expect(result?.engineId, 'b');
      expect(a.segmentCalls, 0); // preferred short-circuited the fallback
      expect(b.segmentCalls, 1);
    },
  );
}

/// Minimal [SegmentationEngine] test double: an id, a fixed availability, and a
/// segment() that either returns a self-tagged result or throws.
class _FakeEngine implements SegmentationEngine {
  _FakeEngine(this.id, {this.available = true, this.throwOnSegment = false});

  @override
  final String id;

  final bool available;
  final bool throwOnSegment;

  int segmentCalls = 0;

  @override
  String get label => id;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<SegmentationResult> segment(SegmentationRequest request) async {
    segmentCalls++;
    if (throwOnSegment) {
      throw SegmentationException('boom', engineId: id);
    }
    return SegmentationResult(mask: AlphaMask.empty(1, 1), engineId: id);
  }
}
