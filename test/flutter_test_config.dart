import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Applies to every test under `test/`. Its only job is to swap the golden
/// comparator for one with a small tolerance.
///
/// Goldens here are vector art rendered by the app's own painters, and
/// `flutter test` uses the bundled test font rather than a system one, so the
/// output is far more portable than a golden of a live UI would be. What still
/// moves between a developer's Windows machine and CI's Linux is
/// anti-aliasing along curves and the odd sub-pixel rounding - single-digit
/// numbers of pixels, differing by a shade. Byte-exact comparison would fail on
/// that and teach everyone to ignore golden failures, which is worse than
/// having none.
///
/// Regenerate after an intended visual change:
///   flutter test --update-goldens test/rendering
/// and LOOK at the resulting PNGs before committing - that review is the whole
/// point of a golden.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final local = goldenFileComparator as LocalFileComparator;
  goldenFileComparator = _TolerantGoldenComparator(
    Uri.parse('${local.basedir}placeholder_test.dart'),
  );
  await testMain();
}

/// A [LocalFileComparator] that passes when at most [_maxDiffFraction] of the
/// pixels differ.
///
/// Deliberately tight: 0.5% of a 320x320 golden is ~500 pixels, which covers
/// anti-aliasing on every curve in the frame but is nowhere near enough to hide
/// a shape that changed, a colour that shifted, or a layer that stopped being
/// drawn - the regressions these goldens exist to catch.
class _TolerantGoldenComparator extends LocalFileComparator {
  _TolerantGoldenComparator(super.testFile);

  static const double _maxDiffFraction = 0.005;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed) return true;
    if (result.diffPercent <= _maxDiffFraction) {
      debugPrint(
        'Golden $golden differs by ${(result.diffPercent * 100).toStringAsFixed(3)}%'
        ' - within the ${_maxDiffFraction * 100}% anti-aliasing tolerance.',
      );
      return true;
    }
    throw FlutterError(await generateFailureOutput(result, golden, basedir));
  }
}
