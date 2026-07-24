# Chromis — BG Removal

A free, ad-supported Flutter **Android** photo editor with on-device AI. Cut out
backgrounds, remove objects, add text & speech bubbles, adjust colors, and
export with transparency — everything processed locally, nothing uploaded.

> Modeled on IDCT's [Sticker Maker](https://github.com/ideaconnect/sticker-maker)
> and built from the approved Claude Design mockup.

## Features (by milestone)

The build is planned as [GitHub milestones + issues](../../milestones):

- **M0** Scaffold & app shell — navigation, Home/projects, side menu, About/Privacy/Licenses, theme, icon/splash
- **M1** Canvas, layers & transforms (move/scale/rotate, undo/redo)
- **M2** AI background removal — ML Kit + bundled **U²-Netp** (ONNX)
- **M3** Manual tools — fast brush erase, crop, adjust (light/color/detail)
- **M4** Text & comic bubbles (rotatable/re-tailed)
- **M5** Object removal — **MobileSAM** tap-to-select + optional MI-GAN inpaint
- **M6** Export & share — PNG (transparent) / JPG / WebP
- **M7** Ads — AdMob banner/interstitial/rewarded + UMP consent
- **M8** Go Pro IAP — one-time `pro_remove_ads`, removes all ads
- **M9** Licenses, legal & release

## On-device AI

Background removal uses **Google ML Kit Subject Segmentation** with a bundled
**U²-Netp** ONNX fallback; object selection uses **MobileSAM** — all Apache-2.0
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
bundled (no GPL/LGPL — ffmpeg was intentionally dropped). The in-app **Licenses**
screen lists everything via Flutter's `LicenseRegistry`.

## Develop

```bash
flutter pub get
flutter run                 # debug on a connected Android device
flutter analyze
flutter test
flutter build apk --release # split ABIs, x86_64 excluded
```

Regenerate the icon/splash after editing `assets/branding/*`:

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

- **applicationId:** `tech.idct.chromis` · **namespace:** `tech.idct.chromis` · **minSdk:** 26

© 2026 IDCT · Bartosz Pachołek · [idct.tech](https://idct.tech)
