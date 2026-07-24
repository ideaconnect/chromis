import 'package:flutter_test/flutter_test.dart';
import 'package:photo_editor_ai/features/about/about_data.dart';

/// M0 smoke tests — pure-data assertions that guard the reskin from the
/// Photo Editor base. The full unit/widget/golden harness lands with the
/// "Test harness & determinism strategy" issue.
void main() {
  group('About / identity', () {
    test('app identity is Photo Editor AI', () {
      expect(AboutInfo.appName, 'Photo Editor AI');
      expect(AboutInfo.privacyUrl, contains('photo-editor'));
      expect(AboutInfo.contactEmail, 'bartosz@idct.tech');
    });

    test('privacy highlights disclose on-device processing and ads', () {
      final joined = AboutInfo.privacyHighlights.join(' ').toLowerCase();
      expect(joined, contains('device'));
      expect(joined, contains('ads'));
      expect(joined, contains('pro')); // one-time Pro removes ads
    });
  });

  group('License notices', () {
    test('cover fonts, on-device AI and monetization', () {
      final cats = licenseCategories().join(' ').toLowerCase();
      expect(cats, contains('fonts'));
      expect(cats, contains('device')); // "On-device AI"
      expect(cats, contains('monetization'));
    });

    test('carry no leftover ffmpeg / animated-codec entries', () {
      final names = licenseNotices.map((n) => n.name.toLowerCase()).join(' ');
      expect(names, isNot(contains('ffmpeg')));
      expect(names, isNot(contains('webm')));
      expect(names, isNot(contains('libvpx')));
    });

    test('bundle only permissive licenses (no GPL/LGPL/CC-NC)', () {
      for (final n in licenseNotices) {
        final l = n.license.toLowerCase();
        expect(l, isNot(contains('gpl')), reason: '${n.name}: ${n.license}');
        expect(
          l,
          isNot(contains('cc by-nc')),
          reason: '${n.name}: ${n.license}',
        );
      }
    });
  });
}
