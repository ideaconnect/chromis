import 'dart:convert';
import 'dart:io';

import 'package:chromis/features/about/bundled_licenses.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards that [registerBundledLicenses] streams exactly one
/// [LicenseEntryWithLineBreaks] per bundled asset (the six OFL/Apache fonts plus
/// the combined MobileSAM / U²-Netp Apache-2.0 model notice), reading each
/// license text from the injected [AssetBundle].
class _FakeAssetBundle extends CachingAssetBundle {
  /// Distinct stub text per asset so we can prove each entry was loaded from its
  /// own asset key.
  static String stubFor(String key) => 'STUB LICENSE TEXT for $key';

  @override
  Future<ByteData> load(String key) async {
    if (!bundledLicenses.any((e) => e.asset == key)) {
      throw FlutterError('unexpected asset requested: $key');
    }
    return ByteData.sublistView(utf8.encode(stubFor(key)));
  }
}

void main() {
  // registerBundledLicenses / loadString touch the services layer.
  TestWidgetsFlutterBinding.ensureInitialized();

  // The test binding registers no default licenses, so LicenseRegistry yields
  // only what we add here. Register once; each drain re-runs the collector.
  setUpAll(() => registerBundledLicenses(_FakeAssetBundle()));

  Future<List<LicenseEntry>> drain() => LicenseRegistry.licenses.toList();

  test('emits one LicenseEntryWithLineBreaks per bundled license', () async {
    final entries = await drain();
    expect(entries, hasLength(bundledLicenses.length));
    expect(entries, everyElement(isA<LicenseEntryWithLineBreaks>()));
  });

  test('each entry carries its bundled packages and its asset text', () async {
    final entries = await drain();
    for (final bl in bundledLicenses) {
      final matches = entries
          .where((e) => listEquals(e.packages.toList(), bl.packages))
          .toList();
      expect(matches, hasLength(1), reason: 'one entry for ${bl.packages}');
      final text = matches.single.paragraphs.map((p) => p.text).join('\n');
      expect(text, contains(_FakeAssetBundle.stubFor(bl.asset)));
    }
  });

  test('covers the six bundled fonts and all three AI models', () async {
    final entries = await drain();
    final allPackages = <String>{for (final e in entries) ...e.packages};
    expect(
      allPackages,
      containsAll(<String>[
        'Space Grotesk',
        'Manrope',
        'Bangers',
        'Luckiest Guy',
        'Pacifico',
        'Rubik',
        'MobileSAM',
        'U²-Netp',
        'MI-GAN',
      ]),
    );
    // The two Apache models ship together under one notice; MI-GAN is MIT and
    // therefore has to be its own entry, not a third name on that one.
    final models = entries.firstWhere((e) => e.packages.contains('MobileSAM'));
    expect(models.packages, containsAll(<String>['MobileSAM', 'U²-Netp']));
    expect(models.packages, isNot(contains('MI-GAN')));
  });

  // The three guards above all run the SAME direction: they start from what is
  // registered and check it resolves. Nothing ran the other way, so a model or
  // font added to `pubspec.yaml` with no registration shipped silently and the
  // suite stayed green - which is exactly what happened to MI-GAN, bundled as
  // an asset for a whole release while the in-app attribution still said the
  // app carried two models under one licence.
  //
  // Reads pubspec.yaml as text rather than parsing YAML: the assertion is
  // about which files are listed, the list is flat, and a parser dependency
  // for that is not worth it.
  test('every bundled model and font has a licence registration', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final flutter = pubspec.split(RegExp(r'^flutter:$', multiLine: true)).last;

    final bundledModels = RegExp(
      r'^\s+-\s+(assets/models/\S+\.onnx)\s*$',
      multiLine: true,
    ).allMatches(flutter).map((m) => m.group(1)!).toList();
    expect(bundledModels, isNotEmpty, reason: 'the app bundles ONNX models');

    // model file -> the package name its licence entry must carry.
    const owner = <String, String>{
      'assets/models/u2netp.onnx': 'U²-Netp',
      'assets/models/mobile_sam_encoder.onnx': 'MobileSAM',
      'assets/models/mobile_sam_decoder.onnx': 'MobileSAM',
      'assets/models/migan.onnx': 'MI-GAN',
    };
    final registered = <String>{for (final e in bundledLicenses) ...e.packages};

    for (final model in bundledModels) {
      final name = owner[model];
      expect(
        name,
        isNotNull,
        reason:
            '$model is bundled but this test does not know whose licence '
            'covers it - add it to `owner` and register its notice',
      );
      expect(
        registered,
        contains(name),
        reason: '$model ships with no entry in bundledLicenses',
      );
    }

    // Same rule for the licence texts themselves: every asset a registration
    // points at has to be one the build actually bundles, or the entry throws
    // at runtime on the licence page instead of failing here.
    for (final entry in bundledLicenses) {
      expect(
        flutter,
        contains(entry.asset),
        reason: '${entry.asset} is registered but not listed in pubspec assets',
      );
    }
  });
}
