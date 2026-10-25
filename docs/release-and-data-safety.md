# Release build & Play Data Safety

Everything here is a **your-console / your-machine** step - the app code is done.
Pairs with [monetization-setup.md](monetization-setup.md) (AdMob + IAP).

---

## 1. Upload keystore (one time)

Generate an upload key, keeping the `.jks` **outside** the repo:

```bat
keytool -genkey -v -keystore %USERPROFILE%\chromis-upload.jks ^
  -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Then copy `android/key.properties.template` → `android/key.properties` and fill in
the four values (`storePassword`, `keyPassword`, `keyAlias`, `storeFile`).
`key.properties` and `*.jks` are git-ignored - never commit them.

> Back up the keystore + passwords somewhere durable. A lost upload key is
> recoverable **only** through Play Support (reset), and never if you also lose
> Play App Signing enrollment.

When `key.properties` is present, `release` builds sign with it automatically
(`android/app/build.gradle.kts`). When it's absent, release falls back to the
debug key so `flutter run --release` still works during development - but the
Play Store **rejects** debug-signed uploads.

---

## 2. Versioning

`versionCode` / `versionName` come from `pubspec.yaml`'s `version:` line
(`1.0.0+1` → name `1.0.0`, code `1`). Bump it before every upload - Play
requires a strictly increasing `versionCode`:

```yaml
version: 1.0.1+2   # name+code
```

---

## 3. Build the upload artifact

```bat
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab` - upload this to Play
Console (App bundles, not APKs), or let a GitHub release build and upload it
(section 6). The bundle carries **arm64-v8a and armeabi-v7a only** and Play
generates per-device splits from those. The
`build.gradle.kts` x86_64 exclusion is scoped to the release *buildType*, not to
APK outputs, so it applies to the bundle too - verified in the artifact. Nothing
here supports an x86_64 Android device or a Chromebook running one; that is the
intended trade ("release builds ship only real-device ABIs"), but it is a trade,
not an accident.

---

## 4. Before flipping ads/IAP to production

- `lib/config/ads_config.dart`: set `useTestAds = false` and fill the real
  `_prod*` unit ids.
- `AndroidManifest.xml`: `com.google.android.gms.ads.APPLICATION_ID` already
  carries the real AdMob app id (`ca-app-pub-6904561240517963~5964201716`), and
  `useTestAds` is already `false`. **Both of these are done** - this step is
  here for the next app, not this one. Check rather than replace.
- Create the `chromis_pro_mode` one-time product in Play Console (see
  monetization-setup.md), with a **backward-compatible** purchase option. IAP
  only returns a product on a signed build that's on a Play track (internal
  testing is enough).

---

## 5. Play Data Safety form

All heavy processing (background removal, object erase, U²-Net / MobileSAM) runs
**on-device** - photos are never uploaded. The only network use is AdMob ad
requests and Google Play Billing. Fill the Data Safety form as:

| Question | Answer |
|---|---|
| Does your app collect or share user data? | **Yes** (via the AdMob SDK) |
| Data encrypted in transit? | **Yes** (ad/billing calls are HTTPS) |
| Users can request data deletion? | No account - N/A / no data retained by us |

**Data types** - declare what the Google Mobile Ads SDK handles (it, not our
code, collects these):

| Data type | Collected | Shared | Purpose |
|---|---|---|---|
| Device or other IDs (Advertising ID) | Yes | Yes | Advertising / marketing |
| App activity (ad interactions) | Yes | Yes | Advertising, analytics |
| Diagnostics (crash/performance) | Yes | No | App functionality |
| Purchase history | Yes | No | App functionality (Play Billing) |

**Photos & media:** **Not collected.** The user picks an image; it is edited
locally and only leaves the device if the user explicitly Shares/exports it.
Do **not** declare photos as collected - we never send them anywhere.

> That answer was true of *our* code and false of the app, until 1.3.0. Android
> Auto Backup is ON unless a manifest refuses it, and its default include-set
> covers `getApplicationDocumentsDirectory()` - which is precisely where
> `projects/assets/` keeps every imported photo and every AI cut-out mask. So
> installing the editor would have copied the user's photo library into their
> Drive, with no code of ours involved. The manifest now sets
> `android:allowBackup="false"` (Android 11 and below) **and**
> `android:dataExtractionRules` (Android 12+, which split cloud backup from
> phone-to-phone transfer and needs both refused separately). Neither attribute
> implies the other; check both are still present before an upload.

**The full permission list, which is not one entry.** The listing copy used to
say "one permission: internet", which the store page itself contradicts - Play
prints the real list beside it. The shipped bundle declares eleven:

| Permission | Comes from | Note |
|---|---|---|
| `INTERNET` | ours | ads + purchases |
| `WRITE_EXTERNAL_STORAGE` (`maxSdkVersion=28`) | ours | the pre-Q gallery save; **requested at runtime** on Android 8-9, so "no storage access" was false there |
| `ACCESS_NETWORK_STATE` | `google_mobile_ads` | |
| `AD_ID`, `ACCESS_ADSERVICES_AD_ID` / `_ATTRIBUTION` / `_TOPICS` | `google_mobile_ads` | drives the Advertising ID declaration below |
| `com.android.vending.BILLING` | `in_app_purchase` | |
| `WAKE_LOCK`, `FOREGROUND_SERVICE` | `androidx.work` (transitive) | |
| `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` | AndroidX | self-scoped, not user-visible |

**App content → Advertising ID** is a SEPARATE page from Data safety and is the
one people forget. Answer **Yes**, purpose *Advertising or marketing* (plus
*Analytics*, to match the table above). Play cross-checks it against the binary,
and the two pages against each other.

Notes:
- The shipped bundle declares `com.google.android.gms.permission.AD_ID` - merged
  in by `google_mobile_ads`, not written by hand, and required because
  `targetSdk` is 36 (the permission became mandatory at 33). Verified in the AAB
  itself, not just the source manifest:

  ```python
  import zipfile
  m = zipfile.ZipFile('build/app/outputs/bundle/release/app-release.aab')              .read('base/manifest/AndroidManifest.xml')   # protobuf in an AAB
  assert b'com.google.android.gms.permission.AD_ID' in m
  ```

  So "No" on either declaration contradicts the binary. If the app ever needs to
  drop the ad id (a child-directed release, say), the permission has to be
  removed with `tools:node="remove"` AND both declarations changed together.
- UMP (Google's consent SDK, bundled in `google_mobile_ads`) shows the EEA/UK
  consent form at first launch; no extra SDK or config needed.
- Google's own AdMob Data Safety guidance lists the exact types to declare:
  https://support.google.com/admob/answer/11150250

---

## 6. Upload from a GitHub release (automatic)

Publishing a **full** GitHub release (not a pre-release) runs
`.github/workflows/play.yml`, which checks out the tag, runs `flutter analyze`
and the tests, builds the signed bundle, and uploads it to the **production**
track at 100% with its R8 mapping and the "What's new". Nothing else in the
Play listing is touched. Promoting a pre-release to a full release counts as
publishing it.

**The notes are `docs/release/whatsnew-<version>.txt`, and only that.** The
GitHub release body is written for developers - issue numbers, file names,
how a thing was fixed - and is never sent to Play. The workflow stops before
building if the notes file is missing, lacks one of the six languages, runs
over 500 characters in any of them, or contains something only a developer
would write (an issue number, a link, a file name, GitHub, CI, Flutter, a
version code). Check a draft locally the same way:

```bash
python tool/play_release_notes.py docs/release/whatsnew-1.4.2.txt build/whatsnew
```

It also refuses a tag that is not `pubspec.yaml`'s version (`v1.4.2` must
build `version: 1.4.2+N`), so bump the version before tagging.

### A release, start to finish

1. Bump `version:` in `pubspec.yaml` and `AboutInfo.appVersion`.
2. Write `docs/release/whatsnew-<version>.txt` - user-facing, six languages.
3. Merge to `main`, tag `v<version>`, push the tag, publish the GitHub release.
4. Watch **Actions -> Google Play**. When it is green, the version is in
   Play's review queue; with managed publishing on, it then waits for you to
   press Publish in the console.

To retry a failed upload, or send a build to a test track, use **Run workflow**
on the Google Play workflow with the tag and a track. It only works for tags
that already contain the workflow - none from before it was added. A version
code Play has seen once is spent on every track, so a build sent to `internal`
cannot later go to production under the same code - promote it in the console
instead.

### One-time setup

**1. A service account Play accepts.**

1. In the Google Cloud console, pick (or create) a project and enable the
   **Google Play Android Developer API**.
2. **IAM & Admin -> Service accounts -> Create service account.** Give it no
   Cloud roles. Open it, **Keys -> Add key -> JSON**, and keep the downloaded
   file out of the repo (`secrets/` is ignored). If key creation is blocked by
   an organisation policy, use Workload Identity Federation instead - see the
   [upload-google-play README](https://github.com/r0adkll/upload-google-play#configure-access-via-service-account).
3. In the Play Console, **Users and permissions -> Invite new users**, enter the
   service account's e-mail, and under **App permissions** add Chromis with
   **Release to production, exclude devices, and use Play App Signing** and
   **Release apps to testing tracks**. Nothing else is needed: the notes are
   part of the release, not of the listing. A new account can take some hours
   before the API accepts it.

**2. An environment holding the secrets.** In GitHub, **Settings ->
Environments -> New environment** named `google-play`. Under deployment
branches and tags choose **Selected**, and allow the tag pattern `v*` (release
runs) and the branch `main` (Run workflow). Optionally add yourself as a
required reviewer, so every upload waits for a click. The repo is public, so
the secrets belong on the environment rather than on the repo.

Then set the five secrets from the repo root in Git Bash. They are read from the
files you already sign with, so nothing is typed or echoed:

```bash
E="--env google-play"
prop() { sed -n "s/^$1=//p" android/key.properties | tr -d '\r\n'; }
base64 -w0 secrets/chromis-upload.jks | gh secret set UPLOAD_KEYSTORE_BASE64 $E
prop storePassword | gh secret set UPLOAD_KEYSTORE_PASSWORD $E
prop keyAlias      | gh secret set UPLOAD_KEY_ALIAS $E
prop keyPassword   | gh secret set UPLOAD_KEY_PASSWORD $E
gh secret set PLAY_SERVICE_ACCOUNT_JSON $E < secrets/<service-account>.json
```

The keystore secret must be the **upload** key (the one `key.properties`
points at). Play App Signing re-signs for users; an upload signed with any
other key is refused.

### When the upload step fails

- **"Package not found"** - the service account is not yet active, or lacks
  the app permission above.
- **"Changes cannot be sent for review automatically"** - something else is
  pending in the console (a listing edit, a declaration). Send or discard it
  there, then Run workflow again.
- **A version code that has already been used** - the version was uploaded
  already, by hand or by an earlier run. Bump the version.
- **A staged rollout** instead of 100%: set `status: inProgress` and
  `userFraction: 0.2` (say) on the upload step, then raise it in the console.
