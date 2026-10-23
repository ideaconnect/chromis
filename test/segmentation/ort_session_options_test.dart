import 'dart:io';

import 'package:chromis/features/segmentation/engines/ort_session_options.dart';
import 'package:flutter_test/flutter_test.dart';

/// The KleidiAI opt-out (#64) is only a guarantee if no session is created
/// without it. A session that skipped it carries ORT's default - KleidiAI on -
/// and nothing on an emulator or a non-SME phone would ever show the
/// difference: the SIGILL only fires on a Snapdragon 8 Gen 5 / 8 Elite Gen 5.
/// So the guard is a scan of the source rather than anything a device test
/// can observe.
void main() {
  test('the session options turn KleidiAI off', () {
    expect(ortSessionOptions().toMap()['sessionConfigs'], {
      'mlas.disable_kleidiai': '1',
    });
  });

  test('every createSession call in lib/ passes ortSessionOptions()', () {
    final sites = <String>[];
    final sources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final file in sources) {
      final source = file.readAsStringSync();
      final calls = RegExp(r'\bcreateSession(?:FromAsset)?\(');
      for (final call in calls.allMatches(source)) {
        sites.add(file.path);
        expect(
          _argumentsAt(source, call.end),
          contains('options: ortSessionOptions()'),
          reason: '${file.path} creates an ORT session without the app options',
        );
      }
    }
    // MobileSAM + MI-GAN share OrtGraphSession.fromAsset; U²-Net has its own.
    // Finding neither would mean the scan, not the code, is broken.
    expect(sites, hasLength(greaterThanOrEqualTo(2)));
  });
}

/// The argument text of the call whose `(` ends at [start], up to the
/// matching `)`.
String _argumentsAt(String source, int start) {
  var depth = 1;
  for (var i = start; i < source.length; i++) {
    if (source[i] == '(') depth++;
    if (source[i] == ')' && --depth == 0) return source.substring(start, i);
  }
  return source.substring(start);
}
