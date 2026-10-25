import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A bundled license text shipped as an asset (the shipped fonts are SIL OFL /
/// Apache-2.0, which require distributing their license text with the app).
class BundledLicense {
  const BundledLicense(this.packages, this.asset);

  /// Component name(s) the license covers, shown on the full license page.
  final List<String> packages;

  /// Asset path of the license text (declared in pubspec).
  final String asset;
}

/// Font license texts bundled in `assets/fonts/`. Kept in sync with the
/// `fonts:` section of pubspec and the notices in [licenseNotices].
const bundledLicenses = <BundledLicense>[
  BundledLicense(['Space Grotesk'], 'assets/fonts/OFL-SpaceGrotesk.txt'),
  BundledLicense(['Manrope'], 'assets/fonts/OFL-Manrope.txt'),
  BundledLicense(['Bangers'], 'assets/fonts/OFL-Bangers.txt'),
  BundledLicense([
    'Luckiest Guy',
  ], 'assets/fonts/LICENSE-LuckiestGuy-Apache.txt'),
  BundledLicense(['Pacifico'], 'assets/fonts/OFL-Pacifico.txt'),
  BundledLicense(['Rubik'], 'assets/fonts/OFL-Rubik.txt'),
  BundledLicense(['Comic Neue'], 'assets/fonts/OFL-ComicNeue.txt'),
  BundledLicense(['Kalam'], 'assets/fonts/OFL-Kalam.txt'),
  BundledLicense(['Patrick Hand'], 'assets/fonts/OFL-PatrickHand.txt'),
  BundledLicense(['Caveat Brush'], 'assets/fonts/OFL-CaveatBrush.txt'),
  BundledLicense(['Mali'], 'assets/fonts/OFL-Mali.txt'),
  BundledLicense(['Titan One'], 'assets/fonts/OFL-TitanOne.txt'),
  BundledLicense(['Bungee'], 'assets/fonts/OFL-Bungee.txt'),
  BundledLicense(['Anton'], 'assets/fonts/OFL-Anton.txt'),
  BundledLicense(['Lobster'], 'assets/fonts/OFL-Lobster.txt'),
  BundledLicense(['Shrikhand'], 'assets/fonts/OFL-Shrikhand.txt'),
  BundledLicense(['Press Start 2P'], 'assets/fonts/OFL-PressStart2P.txt'),
  BundledLicense([
    'Special Elite',
  ], 'assets/fonts/LICENSE-SpecialElite-Apache.txt'),
  // Bundled on-device AI models: MobileSAM (tap-to-remove) and U²-Netp
  // (background removal), both Apache-2.0 - attribution + license text ship
  // in-app as the license requires.
  BundledLicense([
    'MobileSAM',
    'U²-Netp',
  ], 'assets/licenses/Apache-2.0-models.txt'),
  // MI-GAN (generative fill) is MIT, a different licence from the two above, so
  // it gets its own entry rather than being folded into the Apache text - MIT
  // requires ITS copyright notice reproduced, and a reader has to be able to
  // tell which terms cover which model.
  BundledLicense(['MI-GAN'], 'assets/licenses/MIT-migan.txt'),
];

/// Registers the bundled font license texts into [LicenseRegistry] so they
/// appear on Flutter's aggregated license page (reachable from the in-app
/// Licenses screen). Call once at startup. Pass [bundle] in tests.
void registerBundledLicenses([AssetBundle? bundle]) {
  final assets = bundle ?? rootBundle;
  LicenseRegistry.addLicense(() async* {
    for (final entry in bundledLicenses) {
      final text = await assets.loadString(entry.asset);
      yield LicenseEntryWithLineBreaks(entry.packages, text);
    }
  });
}
