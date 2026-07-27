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
- [ ] Interstitial appears after a successful Save
- [ ] Rewarded ad appears before AI Cut / object removal runs
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
2. **Monetize → In-app products**: create `pro_remove_ads`, type **Managed
   product** (one-time / non-consumable), set price, **Activate** it.
   (IAP only returns a product on a signed build uploaded to a track - internal
   testing is enough. Add your account as a licensed tester for test purchases.)
3. Upload the signed **AAB** (see release doc) to Internal testing.
4. **Data safety** form - answers are in the release doc (photos NOT collected;
   AdMob collects advertising id / app activity).
5. Store listing, content rating (IARC), target audience, and a hosted
   **privacy policy URL** (required - the app uses ads + an advertising id).

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
