import '../../l10n/app_localizations.dart';

/// Static "About" content: the privacy summary and the third-party license
/// notices shown in-app. Pure data so it can be unit-tested and kept in sync
/// with `docs/legal/privacy-policy.md`.
abstract final class AboutInfo {
  AboutInfo._();

  static const appName = 'Chromis';

  /// MUST match `version:` in pubspec.yaml (the part before the `+`).
  ///
  /// It is duplicated rather than read from the package at runtime, so it
  /// drifts silently - it still read 1.0.0 two releases on, which the drawer,
  /// the About sheet and the Licenses page were all showing to users.
  /// `about_data_test.dart` now parses pubspec.yaml and fails if the two
  /// disagree, so a version bump cannot forget this again.
  static const appVersion = '1.3.0';
  static const publisher = 'IDCT · Bartosz Pachołek';
  static const contactEmail = 'bartosz@idct.tech';

  /// Canonical hosted privacy policy - the live page served from
  /// `website/privacy.html`. Keep identical to the URL entered in Play Console.
  static const privacyUrl = 'https://idct.tech/chromis/privacy.html';

  /// Community Discord invite - opened from the Home header button.
  static const discordUrl = 'https://discord.gg/uYsuaa8HNm';
}

/// The plain-language privacy promises shown on the in-app privacy screen.
///
/// A function of the localizations rather than a `static const` list: these are
/// prose shown to the user, so they live in the ARB with everything else. The
/// English readings are still the ones `about_data_test` asserts on - it passes
/// `AppLocalizationsEn()`.
List<String> privacyHighlights(AppLocalizations l10n) => <String>[
  l10n.privacyOnDevice,
  l10n.privacyAiLocal,
  l10n.privacyNoAccounts,
  l10n.privacyAds,
  l10n.privacyConsent,
  l10n.privacyWithdraw,
  l10n.privacyPro,
];

/// One third-party component we ship, with attribution and its SPDX license.
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

/// The curated in-app notices. Flutter's aggregated license page (linked from
/// the Licenses screen) additionally lists every pub package automatically;
/// this list covers the bundled assets and headline components a reader cares
/// about. `[planned]` items ship with the native encoders (#42).
const licenseNotices = <LicenseNotice>[
  // Fonts (bundled - see assets/fonts/*.txt).
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
  // On-device AI.
  LicenseNotice(
    category: 'On-device AI',
    name: 'Google ML Kit - Subject Segmentation',
    by: 'Google',
    license: 'Google ML Kit Terms',
    use: 'Background removal (Android)',
  ),
  LicenseNotice(
    category: 'On-device AI',
    name: 'ONNX Runtime',
    by: 'Microsoft',
    license: 'MIT',
    use: 'Runs the bundled fallback model',
  ),
  LicenseNotice(
    category: 'On-device AI',
    name: 'MobileSAM & U²-Netp (bundled models)',
    by: 'Kyung Hee University · Xuebin Qin et al.',
    license: 'Apache-2.0',
    use: 'On-device object & background removal',
  ),
  // A row of its own rather than a third name on the line above, because the
  // licence differs: the two models above are Apache-2.0 and this one is MIT.
  // Folding it in would have made this list say the app ships two models under
  // one licence when it ships three under two - which is what it said for the
  // whole of 1.3.0's development. The MIT text itself is bundled and
  // registered separately (see bundled_licenses.dart), so the notice reaches
  // the user either way; this list is the readable summary beside it.
  LicenseNotice(
    category: 'On-device AI',
    name: 'MI-GAN (bundled model)',
    by: 'Picsart AI Research',
    license: 'MIT',
    use: 'Generative fill when an object is removed',
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
    use: 'Banner / rewarded ads + consent',
  ),
  LicenseNotice(
    category: 'Monetization',
    name: 'in_app_purchase',
    by: 'Flutter team',
    license: 'BSD-3-Clause',
    use: 'One-time Go Pro (remove ads) purchase',
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

/// The two DESCRIPTIVE fields of a [LicenseNotice] in the user's language.
///
/// The notices themselves stay English data: `name`, `by` and `license` are
/// attribution - proper nouns and SPDX ids - and the About tests assert on the
/// English category keywords. Only `category` and `use` are prose, so only
/// those are mapped here. An unmapped value falls through to the English
/// original, so a notice added without a translation renders in English rather
/// than blank.
String localizedLicenseCategory(AppLocalizations l10n, String category) =>
    switch (category) {
      'Fonts' => l10n.licenseCategoryFonts,
      'On-device AI' => l10n.licenseCategoryAi,
      'Media encoding' => l10n.licenseCategoryEncoding,
      'Monetization' => l10n.licenseCategoryMonetization,
      'Framework & packages' => l10n.licenseCategoryFramework,
      _ => category,
    };

/// See [localizedLicenseCategory].
String localizedLicenseUse(AppLocalizations l10n, String use) => switch (use) {
  'Display / heading typeface' => l10n.licenseUseDisplayFont,
  'UI / body typeface' => l10n.licenseUseBodyFont,
  'Comic caption font' => l10n.licenseUseComicFont,
  'Caption font' => l10n.licenseUseCaptionFont,
  'Script caption font' => l10n.licenseUseScriptFont,
  'Background removal (Android)' => l10n.licenseUseBgRemoval,
  'Runs the bundled fallback model' => l10n.licenseUseRuntime,
  'On-device object & background removal' => l10n.licenseUseOnDeviceAi,
  'PNG / JPG / WebP encoding' => l10n.licenseUseEncoding,
  'Banner / rewarded ads + consent' => l10n.licenseUseAds,
  'One-time Go Pro (remove ads) purchase' => l10n.licenseUsePurchase,
  'App framework' => l10n.licenseUseFramework,
  'Routing, storage, sharing, image picking' => l10n.licenseUsePlugins,
  'State management' => l10n.licenseUseState,
  'Paste image from clipboard' => l10n.licenseUseClipboard,
  _ => use,
};

/// Distinct categories in [licenseNotices], in first-seen order.
List<String> licenseCategories() {
  final seen = <String>[];
  for (final n in licenseNotices) {
    if (!seen.contains(n.category)) seen.add(n.category);
  }
  return seen;
}
