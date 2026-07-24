import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_editor_ai/features/about/bundled_licenses.dart';

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

  test('covers the six bundled fonts and both Apache AI models', () async {
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
      ]),
    );
    // The two on-device models ship together under one Apache-2.0 notice.
    final models = entries.firstWhere((e) => e.packages.contains('MobileSAM'));
    expect(models.packages, containsAll(<String>['MobileSAM', 'U²-Netp']));
  });
}
