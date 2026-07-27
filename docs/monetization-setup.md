# Monetization setup - what you must configure

The app ships with Google's **test** ad units and a not-yet-active IAP product so
it runs immediately. Before release you must create the real entries below and
paste the IDs into the app.

## A. Google AdMob (ads)

Wired in **M7** via `google_mobile_ads` (banner on Home, interstitial on export,
rewarded to run AI features) behind a UMP consent flow.

1. Create/att an **AdMob account** (admob.google.com) using the **same Google
   account** as your Play Console.
2. **Register the app** in AdMob → get the **App ID** `ca-app-pub-XXXX~YYYY`.
   Put it in `android/app/src/main/AndroidManifest.xml`
   (`com.google.android.gms.ads.APPLICATION_ID`) - currently the Google test id.
3. Create **ad units** → each gives `ca-app-pub-XXXX/ZZZZ`:
   - Banner (Home), Interstitial (export), **Rewarded interstitial** (the export
     gate and the AI actions - see step 5 for why that exact format).
4. Paste all IDs into `lib/config/ads_config.dart` (added in M7).
5. **The rewarded slot must be a Rewarded INTERSTITIAL unit**, because that is
   what `AdsService` loads. AdMob has two reward formats and the SDK will not
   accept one for the other:

   | Console format | Polish console label | Dart class |
   |---|---|---|
   | Rewarded | Reklama z nagrodą | `RewardedAd` |
   | Rewarded interstitial | Reklama pełnoekranowa z nagrodą | `RewardedInterstitialAd` |

   The live unit `…/3027192977` is a **Rewarded interstitial**, so `AdsService`
   uses `RewardedInterstitialAd`. Loading it as a plain `RewardedAd` failed every
   time (verified on an emulator, 2026-07-26):

   ```
   code 3 com.google.android.gms.ads: Ad unit doesn't match format
   ```

   and because `AdsService.showRewarded()` is deliberately fail-open, **every
   gated action then passed for free, silently** - the "I exported without
   watching the ad" symptom. If you ever swap the console unit to a plain
   *Rewarded* (a better fit for this app's hand-built opt-in sheet - see the note
   below), you must change `AdsService` and `_testRewarded` back in the same
   commit. The banner is unaffected; it fills and shows "Test Ad" on an emulator,
   which the SDK auto-registers as a test device.

   > **Format fit.** The export gate shows its own "Watch a short ad to export"
   > sheet, and a rewarded interstitial then shows the SDK's own intro/opt-out on
   > top of it - two consecutive opt-ins. Plain *Rewarded* is the format designed
   > for a publisher-built opt-in; rewarded interstitial is designed for
   > automatic transitions where the SDK supplies the opt-in. Working as-is, but
   > worth revisiting before launch.

6. **Register a physical dev device** in `AdsConfig.testDeviceIds`. Emulators are
   test devices automatically; real hardware is not, and a production unit asked
   for an ad by an unregistered device normally returns **no fill** - which,
   thanks to the same fail-open, looks identical to the bug above. Grab the id
   from the SDK's own log line on the first request:

   ```bash
   adb logcat -s Ads | grep -i setTestDeviceIds
   ```

   Check logcat for `AdsService:` before assuming the gate is wired wrong - it
   prints Google's own reason for each failed load and each fail-open pass.
   (Clicking a live ad on an unregistered device is invalid traffic and risks the
   account - registering is the safe path, not `useTestAds`, which stops
   exercising your real unit ids at all.)
7. **Consent (EEA/UK):** AdMob → *Privacy & messaging* → create a GDPR/UMP
   message. The Privacy screen already references this.
8. **Play Data safety:** declare the **Advertising ID** (the SDK adds the
   `AD_ID` permission automatically). See M9.

## B. Go Pro - in-app purchase

Wired in **M8** via `in_app_purchase`. One-time, non-consumable; removes all ads;
includes a **Restore** button.

1. **Play Console** account with a **payments/merchant profile** (required to sell).
2. Create the app in Play Console with applicationId **`tech.idct.chromis`**,
   and upload a signed build to at least **Internal testing** (products don't
   return until a matching signed build is on a track).
3. **Monetize → Products → In-app products:** create id **`pro_remove_ads`**,
   type **one-time (non-consumable)**, set price, **Activate**.
4. Add yourself under **Setup → License testing** so test buys aren't charged.
5. Nothing else in code - purchase/restore/acknowledge is handled by the app
   (acknowledged within Google's 3-day window via `completePurchase`).

## Identifiers summary

| Thing | Value / where |
|-------|---------------|
| applicationId | `tech.idct.chromis` |
| AdMob App ID | AndroidManifest meta-data (test id → real at release) |
| Ad unit IDs | `lib/config/ads_config.dart` (M7) |
| IAP product | `pro_remove_ads` (one-time, non-consumable) |
