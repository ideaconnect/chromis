# Monetization setup — what you must configure

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
   (`com.google.android.gms.ads.APPLICATION_ID`) — currently the Google test id.
3. Create **ad units** → each gives `ca-app-pub-XXXX/ZZZZ`:
   - Banner (Home), Interstitial (export), Rewarded (AI features).
4. Paste all IDs into `lib/config/ads_config.dart` (added in M7).
5. **Consent (EEA/UK):** AdMob → *Privacy & messaging* → create a GDPR/UMP
   message. The Privacy screen already references this.
6. **Play Data safety:** declare the **Advertising ID** (the SDK adds the
   `AD_ID` permission automatically). See M9.

## B. Go Pro — in-app purchase

Wired in **M8** via `in_app_purchase`. One-time, non-consumable; removes all ads;
includes a **Restore** button.

1. **Play Console** account with a **payments/merchant profile** (required to sell).
2. Create the app in Play Console with applicationId **`tech.idct.photoeditor`**,
   and upload a signed build to at least **Internal testing** (products don't
   return until a matching signed build is on a track).
3. **Monetize → Products → In-app products:** create id **`pro_remove_ads`**,
   type **one-time (non-consumable)**, set price, **Activate**.
4. Add yourself under **Setup → License testing** so test buys aren't charged.
5. Nothing else in code — purchase/restore/acknowledge is handled by the app
   (acknowledged within Google's 3-day window via `completePurchase`).

## Identifiers summary

| Thing | Value / where |
|-------|---------------|
| applicationId | `tech.idct.photoeditor` |
| AdMob App ID | AndroidManifest meta-data (test id → real at release) |
| Ad unit IDs | `lib/config/ads_config.dart` (M7) |
| IAP product | `pro_remove_ads` (one-time, non-consumable) |
