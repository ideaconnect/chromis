import 'dart:io';

import 'package:chromis/features/about/about_data.dart';
import 'package:chromis/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

/// Complements the license/identity smoke checks in `smoke_test.dart`: this
/// file guards the *shape* of the About data - the remaining [AboutInfo]
/// scalar fields, that every privacy highlight is a well-formed line covering
/// the on-device / ads / Pro themes, and that every [LicenseNotice] row is
/// fully populated with a permissive, SPDX-ish license. It deliberately does
/// not repeat smoke_test's exact appName / contactEmail / category-keyword
/// assertions.
void main() {
  group('AboutInfo scalars', () {
    test('appVersion is a plain semver', () {
      expect(RegExp(r'^\d+\.\d+\.\d+$').hasMatch(AboutInfo.appVersion), isTrue);
    });

    test('appVersion matches pubspec.yaml', () {
      // This used to assert the literal '1.0.0' as "the documented default",
      // which pinned the bug instead of catching it: the app shipped two more
      // versions while the drawer, the About sheet and the Licenses page all
      // still told users 1.0.0, and the test stayed green throughout.
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final match = RegExp(
        r'^version:\s*(\d+\.\d+\.\d+)',
        multiLine: true,
      ).firstMatch(pubspec);
      expect(match, isNotNull, reason: 'no version: line in pubspec.yaml');
      expect(
        AboutInfo.appVersion,
        match!.group(1),
        reason:
            'AboutInfo.appVersion is shown to users - bump it with pubspec, '
            'or they are told the wrong version',
      );
    });

    test('no source file hardcodes a version string', () {
      // The pubspec<->AboutInfo check above only guards the constant. The
      // drawer header printed a literal 'v1.0.0' and so kept showing it two
      // releases after AboutInfo was fixed - the user saw the stale version in
      // the sidebar while the About sheet was correct. Every user-visible
      // version must interpolate AboutInfo.appVersion, so no other file in
      // lib/ may contain a version literal at all.
      final literal = RegExp(r"v\d+\.\d+\.\d+|'\d+\.\d+\.\d+'");
      final offenders = <String>[];
      for (final f in Directory('lib').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        if (f.path.endsWith('about_data.dart')) continue; // declares it
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final code = lines[i].split('//').first; // ignore comments
          if (literal.hasMatch(code)) {
            offenders.add('${f.path}:${i + 1}: ${lines[i].trim()}');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'hardcoded version literal - interpolate AboutInfo.appVersion '
            'instead:\n${offenders.join('\n')}',
      );
    });

    test('publisher names IDCT and is non-empty', () {
      expect(AboutInfo.publisher.trim(), isNotEmpty);
      expect(AboutInfo.publisher, contains('IDCT'));
    });

    test('privacyUrl is an absolute https URL', () {
      final uri = Uri.parse(AboutInfo.privacyUrl);
      expect(uri.isAbsolute, isTrue);
      expect(uri.scheme, 'https');
      expect(uri.host, isNotEmpty);
    });

    test('contactEmail is a well-formed address', () {
      expect(
        RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(AboutInfo.contactEmail),
        isTrue,
      );
    });
  });

  group('Privacy highlights', () {
    test('every highlight is a non-empty trimmed line', () {
      final highlights = privacyHighlights(AppLocalizationsEn());
      expect(highlights, isNotEmpty);
      for (final h in highlights) {
        expect(h.trim(), isNotEmpty);
        expect(h.trim().length, greaterThan(10)); // real sentences, not stubs
      }
    });

    test('the set covers on-device, ads and Pro themes (per line)', () {
      // Element-level coverage (smoke_test only checks the joined string).
      final highlights = privacyHighlights(AppLocalizationsEn());
      bool anyHas(String needle) =>
          highlights.any((h) => h.toLowerCase().contains(needle));
      expect(anyHas('device'), isTrue); // processed on-device
      expect(anyHas('upload'), isTrue); // nothing is uploaded
      expect(anyHas('admob'), isTrue); // ads named concretely
      expect(anyHas('consent'), isTrue); // UMP consent prompt
      expect(anyHas('pro'), isTrue); // one-time Pro removes ads
    });
  });

  group('License notices', () {
    test('every row is fully populated', () {
      expect(licenseNotices, isNotEmpty);
      for (final n in licenseNotices) {
        expect(n.category.trim(), isNotEmpty, reason: n.name);
        expect(n.name.trim(), isNotEmpty, reason: n.category);
        expect(n.by.trim(), isNotEmpty, reason: n.name);
        expect(n.use.trim(), isNotEmpty, reason: n.name);
        expect(n.license.trim(), isNotEmpty, reason: n.name);
      }
    });

    test('every license is a valid permissive / vendor-terms string', () {
      for (final n in licenseNotices) {
        expect(
          _validLicense(n.license),
          isTrue,
          reason: '${n.name}: "${n.license}"',
        );
      }
    });

    test('each expected category has at least one row', () {
      // 'device'/'media encoding'/'framework' extend smoke_test's coverage.
      const expected = [
        'font',
        'device',
        'media encoding',
        'monetization',
        'framework',
      ];
      for (final key in expected) {
        final rows = licenseNotices.where(
          (n) => n.category.toLowerCase().contains(key),
        );
        expect(rows, isNotEmpty, reason: 'no rows in "$key" category');
      }
    });

    test('licenseCategories is the distinct, first-seen category order', () {
      final cats = licenseCategories();
      // No duplicates.
      expect(cats.length, cats.toSet().length);
      // Exactly the set of categories present in the data.
      expect(cats.toSet(), licenseNotices.map((n) => n.category).toSet());
      // Preserves first-seen order.
      final firstSeen = <String>[];
      for (final n in licenseNotices) {
        if (!firstSeen.contains(n.category)) firstSeen.add(n.category);
      }
      expect(cats, firstSeen);
    });
  });
}

/// A license string is valid when every `/`- or `·`-separated token is a known
/// permissive SPDX id, or the whole string is a named vendor-terms license
/// (ML Kit / SDK / AdMob terms) that we still ship under a permissive policy.
bool _validLicense(String license) {
  final spdx = RegExp(r'^(MIT|Apache-2\.0|BSD-3-Clause|SIL OFL 1\.1)$');
  final vendorTerms = RegExp(r'terms|licence|sdk', caseSensitive: false);
  final tokens = license
      .split(RegExp(r'[/·]'))
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();
  if (tokens.isEmpty) return false;
  final allSpdx = tokens.every(spdx.hasMatch);
  return allSpdx || vendorTerms.hasMatch(license);
}
