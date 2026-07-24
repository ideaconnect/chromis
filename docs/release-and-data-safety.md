# Release build & Play Data Safety

Everything here is a **your-console / your-machine** step — the app code is done.
Pairs with [monetization-setup.md](monetization-setup.md) (AdMob + IAP).

---

## 1. Upload keystore (one time)

Generate an upload key, keeping the `.jks` **outside** the repo:

```bat
keytool -genkey -v -keystore %USERPROFILE%\photo-editor-upload.jks ^
  -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Then copy `android/key.properties.template` → `android/key.properties` and fill in
the four values (`storePassword`, `keyPassword`, `keyAlias`, `storeFile`).
`key.properties` and `*.jks` are git-ignored — never commit them.

> Back up the keystore + passwords somewhere durable. A lost upload key is
> recoverable **only** through Play Support (reset), and never if you also lose
> Play App Signing enrollment.

When `key.properties` is present, `release` builds sign with it automatically
(`android/app/build.gradle.kts`). When it's absent, release falls back to the
debug key so `flutter run --release` still works during development — but the
Play Store **rejects** debug-signed uploads.

---

## 2. Versioning

`versionCode` / `versionName` come from `pubspec.yaml`'s `version:` line
(`1.0.0+1` → name `1.0.0`, code `1`). Bump it before every upload — Play
requires a strictly increasing `versionCode`:

```yaml
version: 1.0.1+2   # name+code
```

---

## 3. Build the upload artifact

```bat
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab` — upload this to Play
Console (App bundles, not APKs). The bundle carries all ABIs; Play generates
per-device splits. (`flutter build apk --release` is only for sideload testing;
its x86_64 ABI is stripped from release per `build.gradle.kts`.)

---

## 4. Before flipping ads/IAP to production

- `lib/config/ads_config.dart`: set `useTestAds = false` and fill the real
  `_prod*` unit ids.
- `AndroidManifest.xml`: replace the test `com.google.android.gms.ads.APPLICATION_ID`
  (`ca-app-pub-3940256099942544~3347511713`) with your real AdMob app id.
- Create the `pro_remove_ads` managed product in Play Console (see
  monetization-setup.md). IAP only returns a product on a signed build that's
  on a Play track (internal testing is enough).

---

## 5. Play Data Safety form

All heavy processing (background removal, object erase, U²-Net / MobileSAM) runs
**on-device** — photos are never uploaded. The only network use is AdMob ad
requests and Google Play Billing. Fill the Data Safety form as:

| Question | Answer |
|---|---|
| Does your app collect or share user data? | **Yes** (via the AdMob SDK) |
| Data encrypted in transit? | **Yes** (ad/billing calls are HTTPS) |
| Users can request data deletion? | No account — N/A / no data retained by us |

**Data types** — declare what the Google Mobile Ads SDK handles (it, not our
code, collects these):

| Data type | Collected | Shared | Purpose |
|---|---|---|---|
| Device or other IDs (Advertising ID) | Yes | Yes | Advertising / marketing |
| App activity (ad interactions) | Yes | Yes | Advertising, analytics |
| Diagnostics (crash/performance) | Yes | No | App functionality |
| Purchase history | Yes | No | App functionality (Play Billing) |

**Photos & media:** **Not collected.** The user picks an image; it is edited
locally and only leaves the device if the user explicitly Shares/exports it.
Do **not** declare photos as collected — we never send them anywhere.

Notes:
- The app declares `com.google.android.gms.permission.AD_ID` (merged in by
  `google_mobile_ads`) — required, and consistent with the Advertising ID
  disclosure above.
- UMP (Google's consent SDK, bundled in `google_mobile_ads`) shows the EEA/UK
  consent form at first launch; no extra SDK or config needed.
- Google's own AdMob Data Safety guidance lists the exact types to declare:
  https://support.google.com/admob/answer/11150250
