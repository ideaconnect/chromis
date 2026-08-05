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
      - **On Android 10+ AND on an Android 9-or-below device.** They take
        completely different code paths: MediaStore (no permission) above,
        a permission prompt + file write + media scan below. The pre-Q path
        was broken for the entire life of the app because this line did not
        say which OS version to check it on.
- [ ] EEA/UK consent: the form appears on first launch BEFORE any ad loads, and
      Privacy & Cookies then offers "Ad privacy choices" to change the answer
- [ ] Reinstall with the same Play account: Pro comes back on its own, without
      tapping Restore

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

1. **Already done for this app**: the manifest carries the real App ID
   (`ca-app-pub-6904561240517963~5964201716`) and `ads_config.dart` has
   `useTestAds = false` with real banner and rewarded units. Verify, do not
   replace. The instruction below is what to do for a *new* app.
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
5. **app-ads.txt** - AdMob → *Apps → (app) → App settings* shows the one record
   to publish. It must be served from the **root** of the domain in the app's
   Play listing website field:

   ```
   https://idct.tech/app-ads.txt
   google.com, pub-6904561240517963, DIRECT, f08c47fec0942fa0
   ```

   The verified copy therefore lives in **`ideaconnect/ideaconnect.github.io`**
   (which serves `idct.tech`); `website/app-ads.txt` here is a mirror of it under
   `idct.tech/chromis/`, matching the listing URL, and no crawler looks at a
   subpath. Two things have to agree or the check stays "not found": the Play
   listing's **Website** must be a URL on `idct.tech`, and the file must return
   `text/plain` (GitHub Pages does).
   Verification takes up to 24 h and until it passes some demand sources will not
   bid, so do this before, not after, the first release.

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

### Listing graphics and copy

**One folder per Play locale**, `assets/store/<locale>/`, and every one of them
is complete: `details.md` (title, short, long), `feature-graphic.png`, and a
`screenshots/` tree. The six are `en-US`, `pl-PL`, `de-DE`, `es-ES`, `fr-FR`,
`cs-CZ` - the same set as `kAppLanguages`. Everything except `details.md` is
generated, so it can be rebuilt when the UI moves:

| Play slot | File (per locale) | Generator |
|---|---|---|
| App icon (512x512) | `assets/branding/store_icon.png` *(shared)* | `tool/gen_branding.py` |
| Feature graphic (1024x500) | `<loc>/feature-graphic.png` | `tool/gen_store_graphic.py` |
| **Phone** (8, 1080x1920) | `<loc>/screenshots/portrait/` | `tool/gen_store_screens.py` |
| **7-inch tablet** (8, 1920x1080) | `<loc>/screenshots/tablet-7in/` | `tool/gen_store_screens.py` |
| **10-inch tablet** (8, 2560x1440) | `<loc>/screenshots/tablet-10in/` | `tool/gen_store_screens.py` |
| *(spare)* phone landscape (8, 1920x1080) | `<loc>/screenshots/landscape/` | `tool/gen_store_screens.py` |

Two checks, both offline, both worth running before an upload:

```bash
python tool/check_store_listings.py   # Play's 30/80/4000 limits; feature counts;
                                      #   the copy names the localized controls
python tool/store_copy.py             # every caption line fits the width it is
                                      #   drawn into, in every language
```

**Social graphics** are separate from the listing and live in
`assets/store/social/`, both 1200x1200 and both generated from the same English
captures the listing uses, so nothing in them is a mock-up:

| File | Generator | What it is for |
|---|---|---|
| `linkedin-promo.png` | `tool/gen_social_promo.py` | the app in general; does not change per release |
| `linkedin-update-1-2-0.png` | `tool/gen_update_promo.py` | what 1.2.0 added |

The update one reads three *different* languages' captures. Copy it to a new
`gen_update_promo.py`-shaped file per release rather than editing this one, or
the graphic for the last release stops being reproducible.

`check_store_listings.py` is the one that matters most: Play truncates the title
at 30 characters and the short description at 80 **silently**, and German,
Spanish and French all ran past the 4000-character long-description cap on the
first draft. It also counts the looks, blend modes, grid layouts and bundled
fonts out of the Dart source, so a listing cannot go on promising 14 filters
after a fifteenth lands.

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
| `build/shots-i18n/<loc>/phone/` | Pixel 10 Pro | 1280x2856 @ 480dpi | phone |
| `build/shots-i18n/<loc>/tab7/` | 7-inch tablet | 1920x1200 @ 320dpi = `sw600dp` | 7-inch |
| `build/shots-i18n/<loc>/tab10/` | Pixel Tablet | 2560x1600 @ 320dpi = `sw800dp` | 10-inch |

Capture in the tablet's natural **landscape** orientation - note `user_rotation 0`
is landscape on a tablet and portrait on a phone, so the value that gives you a
portrait phone gives you a landscape tablet. A set whose captures are missing is
skipped with a notice, so the phone sets rebuild fine with no tablet attached.

**Every language is captured again, not re-captioned.** Everything inside the
device frame is UI text, so pasting a Polish caption beside an English
screenshot reads worse than shipping no Polish listing at all.
`tool/capture_store_shots.py` sets the app's per-app locale and drives all
eight states again on each device; run the three profiles at once, they do not
contend:

```bash
python tool/capture_store_shots.py prepare phone tab10 tab7   # once per device
python tool/capture_store_shots.py seed    phone tab10 tab7   # the CC0 samples
python tool/capture_store_shots.py phone   # + tab10, tab7 in parallel
python tool/gen_store_screens.py
python tool/gen_store_graphic.py
```

That script needs a **debug** build installed (a Play-store emulator image
refuses `adb root`, so app data goes through `run-as`). It writes the project
manifests itself, and the project names, layer names, the sticker's caption and
the bubble's line are localized in that file: those are *document data*, stored
once and never re-translated, so a Polish screenshot needs Polish names on disk
rather than a Polish build.

**`prepare` is not optional, and skipping it does not look like an error.**
Writing `proEntitled: true` keeps ads out only until the app checks it:
`reconcileEntitlement` re-verifies the flag against Play on every launch and
revokes it on a confirmed "not owned", which is exactly what a Play-store
emulator with no purchase answers. And **without Pro the editor's rail grows a
Go Pro entry at the top, which pushes every tool down one slot** - so the tap
tables hit Bubble where they mean AI Cut and the run produces eight plausible
screenshots of the wrong panels. `prepare` disables the Play Store so the
billing query throws instead (every uncertain case keeps Pro), takes the radios
down so UMP cannot fetch a consent form, and sets the dark theme the listing
art is built from. `restore` puts all of it back.

**The sample photos are CC0 and live in the repo.** `assets/store/samples/`,
fetched by `tool/fetch_stock_photos.py` from Wikimedia Commons with the licence
and source URL of each recorded in `SOURCES.json`; `seed` pushes them to the
device. A Play listing is commercial use of every pixel inside the device
frame, so which photograph appears in one is a decision that belongs in the
repo, not whatever happened to be in an emulator's gallery. The cut-out
(`subject-mask.png`) is a real AI Cut output, made once with
`capture_store_shots.py mask phone` and copied to the other devices - a
hand-drawn alpha would show a result the app did not produce.

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
- ~~**MI-GAN generative fill.**~~ **Shipped in 1.3.0.** `assets/models/migan.onnx`
  is bundled (26.7 MB, MIT) and tried ahead of the pure-Dart `ContentFillEngine`,
  which remains the floor. See `docs/inpaint-setup.md`.

Everything else from the original scope is implemented.
