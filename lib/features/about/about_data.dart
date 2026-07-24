/// Static "About" content: the privacy summary and the third‑party license
/// notices shown in‑app. Pure data so it can be unit‑tested and kept in sync
/// with `docs/legal/privacy-policy.md`.
abstract final class AboutInfo {
  AboutInfo._();

  static const appName = 'Chromis';
  static const appVersion = '1.0.0';
  static const publisher = 'IDCT · Bartosz Pachołek';
  static const contactEmail = 'bartosz@idct.tech';

  /// Canonical hosted privacy policy — the live page served from
  /// `website/privacy.html`. Keep identical to the URL entered in Play Console.
  static const privacyUrl = 'https://idct.tech/chromis/privacy.html';

  /// Community Discord invite — opened from the Home header button.
  static const discordUrl = 'https://discord.gg/uYsuaa8HNm';

  /// The plain‑language privacy promises shown on the in‑app privacy screen.
  static const privacyHighlights = <String>[
    'Your photos are edited entirely on your device — nothing is uploaded.',
    'AI background & object removal run locally; photos never leave your phone.',
    'No accounts, no sign‑in, no photo uploads.',
    'The free app shows ads (Google AdMob), which use an advertising ID.',
    'Where required, a consent prompt (UMP) lets you choose personalised or '
        'non‑personalised ads.',
    'The one‑time Pro upgrade removes all ads — and the advertising ID with them.',
  ];
}

/// One third‑party component we ship, with attribution and its SPDX license.
class LicenseNotice {
  const LicenseNotice({
    required this.category,
    required this.name,
    required this.by,
    required this.license,
    required this.use,
  });

  final String category;
  final String name;

  /// Author / copyright holder.
  final String by;

  /// SPDX identifier or license name.
  final String license;

  /// What the component is used for in the app.
  final String use;
}

/// The curated in‑app notices. Flutter's aggregated license page (linked from
/// the Licenses screen) additionally lists every pub package automatically;
/// this list covers the bundled assets and headline components a reader cares
/// about. `[planned]` items ship with the native encoders (#42).
const licenseNotices = <LicenseNotice>[
  // Fonts (bundled — see assets/fonts/*.txt).
  LicenseNotice(
    category: 'Fonts',
    name: 'Space Grotesk',
    by: 'Florian Karsten',
    license: 'SIL OFL 1.1',
    use: 'Display / heading typeface',
  ),
  LicenseNotice(
    category: 'Fonts',
    name: 'Manrope',
    by: 'Mikhail Sharanda',
    license: 'SIL OFL 1.1',
    use: 'UI / body typeface',
  ),
  LicenseNotice(
    category: 'Fonts',
    name: 'Bangers',
    by: 'Vernon Adams',
    license: 'SIL OFL 1.1',
    use: 'Comic caption font',
  ),
  LicenseNotice(
    category: 'Fonts',
    name: 'Luckiest Guy',
    by: 'Astigmatic',
    license: 'Apache-2.0',
    use: 'Caption font',
  ),
  LicenseNotice(
    category: 'Fonts',
    name: 'Pacifico',
    by: 'Cyreal',
    license: 'SIL OFL 1.1',
    use: 'Script caption font',
  ),
  LicenseNotice(
    category: 'Fonts',
    name: 'Rubik',
    by: 'Hubert & Fischer · Google',
    license: 'SIL OFL 1.1',
    use: 'Caption font',
  ),
  // On‑device AI.
  LicenseNotice(
    category: 'On‑device AI',
    name: 'Google ML Kit — Subject Segmentation',
    by: 'Google',
    license: 'Google ML Kit Terms',
    use: 'Background removal (Android)',
  ),
  LicenseNotice(
    category: 'On‑device AI',
    name: 'ONNX Runtime',
    by: 'Microsoft',
    license: 'MIT',
    use: 'Runs the bundled fallback model',
  ),
  LicenseNotice(
    category: 'On‑device AI',
    name: 'MobileSAM & U²‑Netp (bundled models)',
    by: 'Kyung Hee University · Xuebin Qin et al.',
    license: 'Apache-2.0',
    use: 'On‑device object & background removal',
  ),
  // Media encoding.
  LicenseNotice(
    category: 'Media encoding',
    name: 'image (Dart)',
    by: 'Brendan Duncan',
    license: 'Apache-2.0 / MIT',
    use: 'PNG / JPG / WebP encoding',
  ),
  // Monetization.
  LicenseNotice(
    category: 'Monetization',
    name: 'Google Mobile Ads (AdMob) + UMP',
    by: 'Google',
    license: 'Android SDK licence · AdMob terms',
    use: 'Banner / interstitial / rewarded ads + consent',
  ),
  LicenseNotice(
    category: 'Monetization',
    name: 'in_app_purchase',
    by: 'Flutter team',
    license: 'BSD-3-Clause',
    use: 'One‑time Go Pro (remove ads) purchase',
  ),
  // Framework & packages.
  LicenseNotice(
    category: 'Framework & packages',
    name: 'Flutter',
    by: 'Google',
    license: 'BSD-3-Clause',
    use: 'App framework',
  ),
  LicenseNotice(
    category: 'Framework & packages',
    name: 'go_router · path_provider · share_plus · image_picker',
    by: 'Flutter team',
    license: 'BSD-3-Clause',
    use: 'Routing, storage, sharing, image picking',
  ),
  LicenseNotice(
    category: 'Framework & packages',
    name: 'Riverpod',
    by: 'Remi Rousselet',
    license: 'MIT',
    use: 'State management',
  ),
  LicenseNotice(
    category: 'Framework & packages',
    name: 'pasteboard',
    by: 'Kingsword',
    license: 'MIT',
    use: 'Paste image from clipboard',
  ),
];

/// Distinct categories in [licenseNotices], in first‑seen order.
List<String> licenseCategories() {
  final seen = <String>[];
  for (final n in licenseNotices) {
    if (!seen.contains(n.category)) seen.add(n.category);
  }
  return seen;
}
