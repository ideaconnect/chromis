# Chromis

A free, ad-supported Flutter **Android** photo editor with on-device AI. Cut
out backgrounds, remove objects, stack layers, add captions and comic bubbles,
build photo-grid collages, and export with transparency. Every AI model runs on
the phone, so photos are never uploaded.

[Google Play](https://play.google.com/store/apps/details?id=tech.idct.chromis) ·
[Website](https://idct.tech/chromis/)

English, Polish, German, Spanish, French and Czech; light and dark themes;
phones and tablets, portrait and landscape; Android 8.0 and newer.

> Modeled on IDCT's [Sticker Maker](https://github.com/ideaconnect/sticker-maker)
> and built from the approved Claude Design mockup. The original build plan is
> in the [GitHub milestones](../../milestones).

## Features

- **Background removal** with one tap, then refine it: clean up stray specks,
  soften the edge, or erase and restore by hand.
- **Remove object** - tap it and **Fill in** rebuilds the background behind it,
  or **Erase** cuts it to transparency.
- **Layers** of photos, captions and bubbles: drag to move, pinch to scale and
  rotate, with snapping to the other layers and the canvas. Sliders reach any layer, even
  one too small to grab or buried under another. Blend modes, drop shadow and
  outline (both follow a cut-out's silhouette), merge and flatten.
- **Colour and light** - one-tap looks with a strength slider, brightness,
  contrast, saturation, hue, HDR and vignette. Nothing is baked in.
- **Captions and comic bubbles** in the bundled display fonts, the phone's own
  fonts, or an imported .ttf / .otf.
- **Photo Grid collages** of 2 to 5 photos, with dividers you can drag.
- **Canvas** from a photo, a preset or a typed size; crop free or to a ratio;
  **Image size** resizes the whole picture with a choice of resampling.
- **Export** PNG, JPG or WebP, to the gallery or another app. Projects save
  themselves, and everything can be undone.

The complete list, with every count and control name, is the Play listing copy
in [`assets/store/en-US/details.md`](assets/store/en-US/details.md).
`tool/check_store_listings.py` keeps those numbers in step with the code, so
they are not repeated here, where nothing would.

## On-device AI

| Job | Model | Licence |
|---|---|---|
| Background removal | ML Kit Subject Segmentation, or bundled **U²-Netp** | Google ML Kit terms / Apache-2.0 |
| Object selection | bundled **MobileSAM** | Apache-2.0 |
| Fill in, Best quality | bundled **MI-GAN** | MIT |
| Fill in, Low memory | PatchMatch content fill, pure Dart | ours |

The ONNX models run through `flutter_onnxruntime`. No cloud, no uploads. See
[`docs/inpaint-setup.md`](docs/inpaint-setup.md) for how Fill in chooses
between its two tiers.

## Monetization

Free, with **Google AdMob** behind a UMP consent flow: a banner on Home, and a
rewarded interstitial before an export and once per editing session for the AI
tools. A one-time **Go Pro** purchase (`chromis_pro_mode`) removes every ad and
unlocks nothing else, because nothing else is locked. The live ad unit ids are
in `lib/config/ads_config.dart`; setup is in
[`docs/monetization-setup.md`](docs/monetization-setup.md).

## Privacy

No account and no sign-in. The app sees only the photos the user picks, edits
them on the phone, and uses the internet only for ads and purchases.
Android Auto Backup is refused in the manifest, because its default would copy
every imported photo into the user's Google Drive.

## Licensing

Closed-source app: only MIT / BSD / Apache-2.0 / SIL-OFL code, models and fonts
are bundled (no GPL/LGPL - ffmpeg was dropped; no CC-BY-NC models). Every bundled
font and model registers its licence in
`lib/features/about/bundled_licenses.dart`, a test fails the build if one is
missing, and the in-app **Licenses** screen shows them through Flutter's
`LicenseRegistry`. The phone's own fonts are offered only when the font file
itself declares the OFL or Apache 2.0.

## Develop

Flutter **3.44.9**, pinned in `.github/workflows/ci.yml` - read the Flutter pin
in [`CLAUDE.md`](CLAUDE.md) before moving off 3.44.

```bash
flutter pub get
flutter run                          # debug on a connected device or emulator
flutter analyze
flutter test --exclude-tags golden   # what CI runs
dart format lib test                 # CI fails on unformatted code
flutter gen-l10n                     # after editing lib/l10n/*.arb (output is committed)
flutter build apk --release          # arm64-v8a + armeabi-v7a; x86_64 left out
flutter build appbundle --release    # the Play upload; signs with android/key.properties
```

- **applicationId:** `tech.idct.chromis` · **namespace:** `tech.idct.chromis` · **minSdk:** 26
- `lib/app` (root, routing), `lib/core` (theme, models, rendering, widgets),
  `lib/features/*`, `lib/l10n` (ARB files and generated code).
- `integration_test/` runs on a device: checks that the AI models and fonts
  really work there, plus a BDD suite ([`docs/e2e-testing.md`](docs/e2e-testing.md)).
- `tool/` holds the Python generators and offline checks - branding, store
  graphics and screenshots, label widths, listing copy.
- [`CLAUDE.md`](CLAUDE.md) is the architecture guide: the rules each part of the
  app depends on, and why.

## Release

1. Bump `version:` in `pubspec.yaml` and `AboutInfo.appVersion`
   (`lib/features/about/about_data.dart`).
2. Write `docs/release/whatsnew-<version>.txt` - six languages, written for
   users. It goes to every user's update screen, so nothing about how a change
   was made.
3. Tag `v<version>` and publish a GitHub release.

Publishing the release runs `.github/workflows/play.yml`, which tests the tag,
builds the signed bundle and uploads it to Google Play's production track. A
pre-release uploads nothing. Setup and troubleshooting:
[`docs/release-and-data-safety.md`](docs/release-and-data-safety.md), section 6.
Play Console, listing graphics and screenshots:
[`docs/ship-checklist.md`](docs/ship-checklist.md).

## Website

`website/` is plain HTML, published to
[idct.tech/chromis](https://idct.tech/chromis/) by
`.github/workflows/pages.yml` on every push that touches it.

## Branding

Every brand asset - launcher icon, adaptive layers, splash, Play listing icon,
in-app logo, website mark and favicon - comes out of the one icon design in
`assets/branding/modern.png`. Edit `tool/gen_branding.py`, never the outputs:

```bash
python tool/gen_branding.py            # every asset, app + website
dart run flutter_launcher_icons        # -> android/**/ic_launcher*
dart run flutter_native_splash:create  # -> android/**/splash*
```

The composition is never re-arranged; the assets differ only in size, in whether
the tile keeps its corners, and in what sits behind it:

- **The mock-up is not the icon.** The source file is the tile presented on a
  white card on a grey backdrop. The tile is found by chroma - it is the only
  saturated region - and the rest discarded.
- **The background is a gradient**, so the artwork cannot be keyed off one flat
  colour. A degree-3 surface is fitted iteratively, rejecting the artwork as
  outliers, and everything downstream keys against that surface per pixel.
- **Adaptive icon** - the recovered gradient becomes a square full-bleed
  background and the artwork alone becomes the foreground, placed so the visible
  72 of the drawable's 108dp is the design at its own proportions. That lands the
  artwork inside Android's guaranteed 66dp circle, so a mask cuts gradient.
- **No plate.** The tile is mid-tone teal and reads on both the dark and the
  light theme unaided. The icon before it was `#0A2127`, a couple of steps from
  the old dark panel colour, and needed a light ground; if the artwork ever goes
  dark again, that is the fix, and it would have to clear the light theme too.

© 2026 IDCT · Bartosz Pachołek · [idct.tech](https://idct.tech)
