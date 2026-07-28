# Ship checklist - Chromis

All **code** is done and builds green (debug + release APK). What remains needs
your phone and your Google consoles. Work top to bottom.

Companion docs:
- [monetization-setup.md](monetization-setup.md) - AdMob + IAP product setup
- [release-and-data-safety.md](release-and-data-safety.md) - keystore, AAB, Data Safety

---

## A. On-device testing (your phone)

Install the debug build and walk every feature. It's already built:
`build/app/outputs/flutter-apk/app-debug.apk` - or `flutter run`.

**Editor core**
- [ ] New project → resolution picker (presets + custom W×H)
- [ ] Open image → canvas auto-sizes to the image
- [ ] Move / scale / rotate layers; undo/redo
- [ ] Color/contrast adjustments
- [ ] Text (built-in + custom fonts); comic bubbles (rotate, re-tail)
- [ ] Canvas-size button: resize canvas + "scale layers" toggle
- [ ] **Crop → Freeform**: drag the box + corners, Done applies the crop
- [ ] **Crop → Ratios**: 1:1 / 4:5 / 9:16 / 16:9 / 3:2 / 2:3 center-crop

**AI (each should run; first run loads the model - slight delay)**
- [ ] AI Cut → Background, built-in (ML Kit) engine
- [ ] AI Cut → Background, U²-Net (ONNX) engine; feather slider
- [ ] AI Cut → Object → tap an object to erase it (MobileSAM)
- [ ] Transparent background is preserved through to export

**Export**
- [ ] PNG (transparent) / JPG (flattened) / WebP at 100/75/50/25 %
- [ ] Save to gallery (check the "Chromis" album) + Share sheet

**Ads (test ads - they render "Test Ad")**
- [ ] Home banner shows at the bottom
- [ ] Rewarded ad appears before AI Cut / object removal / export
      (there is no plain interstitial - `AdsService` loads a banner and a
      *rewarded* interstitial only, so nothing fires after a plain Save)
- [ ] UMP consent form shows on first launch (EEA - test with a VPN)

**Go Pro / IAP** (needs a signed build on a Play track - see C)
- [ ] Paywall shows the localized price
- [ ] Purchase completes; **all ads disappear** immediately
- [ ] Kill + reopen: still Pro (entitlement persisted)
- [ ] "Restore purchase" re-grants on a fresh install
- [ ] Licenses screen lists bundled OSS licenses

> The phone requires your on-device acknowledgement to install - tell me when
> you're ready to sideload and which build you want.

---

## B. AdMob console (Google AdMob)

1. Create the app in AdMob; copy its **App ID** →
   `android/app/src/main/AndroidManifest.xml` (replace the test
   `ca-app-pub-3940256099942544~3347511713`).
2. Create three ad units - Banner, Interstitial, and **Rewarded interstitial**
   (NOT plain "Rewarded": `AdsService` loads a `RewardedInterstitialAd`, and the
   SDK rejects the other format with "Ad unit doesn't match format" - which the
   fail-open gate then hides by letting exports through for free). Copy their ids
   into `lib/config/ads_config.dart`
   (`_prodBanner/_prodInterstitial/_prodRewarded`) and set `useTestAds = false`.
   See `docs/monetization-setup.md` step 5.
3. AdMob → Privacy & messaging: create a **GDPR (EEA)** consent message. The app
   already calls UMP; this is the message it shows.
4. Link AdMob ⇄ Play so payments and reporting connect.

> Keep test ids until the app is live - clicking your own real ads risks a ban.

---

## C. Play Console

1. Create the app; package name **`tech.idct.chromis`**.
2. **Monetize → Products → One-time products**: create `chromis_pro_mode`
   (must match `kProProductId`), set price, **Activate** it, and mark its
   purchase option **backward compatible** or `in_app_purchase` cannot see it.
   (IAP only returns a product on a signed build uploaded to a track - internal
   testing is enough. Add your account as a licensed tester for test purchases.)
3. Upload the signed **AAB** (see release doc) to Internal testing.
4. **Data safety** form - answers are in the release doc (photos NOT collected;
   AdMob collects advertising id / app activity).
5. **App content → Advertising ID**: answer **Yes**, purpose *Advertising or
   marketing* (+ *Analytics*, matching the Data safety table). This is a
   SEPARATE declaration from Data safety and is easy to miss. Play cross-checks
   it against the manifest: the build declares
   `com.google.android.gms.permission.AD_ID` (merged in by `google_mobile_ads`,
   and required because `targetSdk` is 36), so answering "No" here contradicts
   the binary and gets the release blocked. Both pages must also agree with each
   other, or Play flags the inconsistency.
6. Store listing, content rating (IARC), target audience, and a hosted
   **privacy policy URL** (required - the app uses ads + an advertising id).

### Listing graphics

Both are generated, not hand-made, so they can be rebuilt when the UI moves:

| Play slot | File | Generator |
|---|---|---|
| App icon (512x512) | `assets/branding/store_icon.png` | `tool/gen_branding.py` |
| Feature graphic (1024x500) | `assets/branding/feature_graphic.png` | `tool/gen_store_graphic.py` |
| **Phone** (8, 1080x1920) | `assets/store/screenshots/portrait/` | `tool/gen_store_screens.py` |
| **7-inch tablet** (8, 1920x1080) | `assets/store/screenshots/tablet-7in/` | `tool/gen_store_screens.py` |
| **10-inch tablet** (8, 2560x1440) | `assets/store/screenshots/tablet-10in/` | `tool/gen_store_screens.py` |
| *(spare)* phone landscape (8, 1920x1080) | `assets/store/screenshots/landscape/` | `tool/gen_store_screens.py` |

**Phone slot: upload the portrait set.** The app is portrait and Play renders a
portrait phone screenshot larger in the listing than a landscape one. The
landscape set says the same thing from the same caption table; a slot takes one
orientation, not both.

**Both tablet slots matter.** Leaving them empty is what makes Play warn that the
app is not designed for large screens, even though it has a full landscape rail
layout. Each slot now has its own genuine capture rather than a reused one, which
is worth having: the rail *scrolls* on a 7-inch screen and does not on a 10-inch
one, so the two really are different screenshots of different layouts.

| Captures in | Device | Screen | Slot |
|---|---|---|---|
| `build/shots/` | Pixel 10 Pro | 1280x2856 @ 480dpi | phone |
| `build/shots/tablet7/` | 7-inch tablet | 1920x1200 @ 320dpi = `sw600dp` | 7-inch |
| `build/shots/tablet/` | Pixel Tablet | 2560x1600 @ 320dpi = `sw800dp` | 10-inch |

Capture in the tablet's natural **landscape** orientation - note `user_rotation 0`
is landscape on a tablet and portrait on a phone, so the value that gives you a
portrait phone gives you a landscape tablet. A set whose captures are missing is
skipped with a notice, so the phone sets rebuild fine with no tablet attached.

The system photo picker keeps its own index: after re-seeding `/sdcard` it reports
"No photos yet" even while `content query` lists every file. Fix with
`pm clear com.google.android.providers.media.module` and a `scan_volume`.

Both graphics generators read the raw device captures in `build/shots` (see
[website/README.md](../../website/README.md#screenshots) for how those are
taken). Capture them with the **Pro entitlement set**, so no ad is on screen:

```bash
adb shell run-as tech.idct.chromis sh -c \
  "printf %s '{\"onboardingSeen\":true,\"proEntitled\":true}' \
   > /data/data/tech.idct.chromis/app_flutter/settings.json"
```

An ad slot is not a product feature, and Play crops these into surfaces where
one would only read as clutter. Set it back to `false` afterwards or the device
stops exercising the ad paths.

---

## D. Cut the release build

Follow [release-and-data-safety.md](release-and-data-safety.md):
create the keystore + `android/key.properties`, flip the ad ids (B), bump
`version:` in `pubspec.yaml`, then:

```bat
flutter build appbundle --release
```

Upload `build/app/outputs/bundle/release/app-release.aab`.

---

## E. Deliberately NOT built (optional future work)

- **Labeled object-detection overlay** (tap a "person/dog" chip to remove).
  Skipped: it's functionally redundant with the existing MobileSAM tap-to-erase
  (which segments *any* tapped object, more precisely) and would add the
  `google_mlkit_object_detection` native dependency + model. Say the word and I'll
  add it.
- **MI-GAN inpaint fill** after object erase. Object removal currently erases to
  transparent; generative fill-behind is a larger ONNX addition. Optional.

Everything else from the original scope is implemented.
