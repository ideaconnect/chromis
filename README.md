# Chromis - BG Removal

A free, ad-supported Flutter **Android** photo editor with on-device AI. Cut out
backgrounds, remove objects, add text & speech bubbles, adjust colors, and
export with transparency - everything processed locally, nothing uploaded.

> Modeled on IDCT's [Sticker Maker](https://github.com/ideaconnect/sticker-maker)
> and built from the approved Claude Design mockup.

## Features (by milestone)

The build is planned as [GitHub milestones + issues](../../milestones):

- **M0** Scaffold & app shell - navigation, Home/projects, side menu, About/Privacy/Licenses, theme, icon/splash
- **M1** Canvas, layers & transforms (move/scale/rotate, undo/redo)
- **M2** AI background removal - ML Kit + bundled **U²-Netp** (ONNX)
- **M3** Manual tools - fast brush erase, crop, adjust (light/color/detail)
- **M4** Text & comic bubbles (rotatable/re-tailed)
- **M5** Object removal - **MobileSAM** tap-to-select, then fill in (PatchMatch
  content-aware fill, or optional MI-GAN) or erase to transparency
- **M6** Export & share - PNG (transparent) / JPG / WebP
- **M7** Ads - AdMob banner/interstitial/rewarded + UMP consent
- **M8** Go Pro IAP - one-time `pro_remove_ads`, removes all ads
- **M9** Licenses, legal & release

## On-device AI

Background removal uses **Google ML Kit Subject Segmentation** with a bundled
**U²-Netp** ONNX fallback; object selection uses **MobileSAM** - all Apache-2.0
and run entirely on-device via `flutter_onnxruntime`. No cloud, no uploads.

## Monetization

Free with **Google AdMob** ads (banner on Home, interstitial on export,
rewarded to run AI features) behind a UMP consent flow, plus a one-time
**Go Pro** purchase (`pro_remove_ads`) that removes all ads. See
[`docs/monetization-setup.md`](docs/monetization-setup.md) for the AdMob +
Play Console setup you must complete before release. AdMob/IAP use Google's
**test** identifiers until then.

## Licensing

Closed-source app: only MIT / BSD / Apache-2.0 / SIL-OFL dependencies are
bundled (no GPL/LGPL - ffmpeg was intentionally dropped). The in-app **Licenses**
screen lists everything via Flutter's `LicenseRegistry`.

## Develop

```bash
flutter pub get
flutter run                 # debug on a connected Android device
flutter analyze
flutter test
flutter build apk --release # split ABIs, x86_64 excluded
```

- **applicationId:** `tech.idct.chromis` · **namespace:** `tech.idct.chromis` · **minSdk:** 26

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
- **No plate.** The tile is mid-tone teal and reads on our dark surfaces
  unaided. The icon before it was `#0A2127` - within a couple of steps of
  `AppColors.panel` - and needed a light ground; if the artwork ever goes dark
  again, that is the fix.

© 2026 IDCT · Bartosz Pachołek · [idct.tech](https://idct.tech)
