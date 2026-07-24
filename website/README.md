# Chromis — website

Static marketing site for the Chromis Android app. Plain HTML/CSS +
a little vanilla JS, no build step. Matches the app's dark theme and palette
(`lib/core/theme/app_colors.dart`).

```
website/
├── index.html          # landing page (hero, effects, features, FAQ, contact)
├── privacy.html        # Privacy Policy
├── terms.html          # Terms of Use
├── styles.css          # shared styles
└── assets/img/
    ├── logo.png        # app mark
    ├── effects/        # AI before/after + sticker composites (real U²-Netp output)
    └── screens/        # real app screenshots
```

## Analytics & contact form

Both are **configured** (values live in the HTML, which is fine — a GA4
Measurement ID and a Web3Forms access key are public, client-side identifiers):

| Service | Where | Value |
|---|---|---|
| **Google Analytics 4** | `window.PE_GA_ID` in the `<head>` of every `.html` | `G-WE6KSP5S15` |
| **Web3Forms** | `index.html` contact form (`access_key`) | set |

Guards that remain in place:

- **Google Analytics** loads only after the visitor accepts the cookie-consent
  banner (and never while the ID is a placeholder), so nothing is sent without
  consent.
- The contact form posts to Web3Forms; if the key were ever reset to the
  `YOUR_WEB3FORMS_ACCESS_KEY` sentinel it falls back to an "email us" message.

## Notes

- The before/after slider expects the two effect images to share the **3:4**
  aspect ratio (`dog-before.jpg` / `dog-studio.jpg` are 900×1200). Keep new
  slider images at 3:4 so the reveal stays pixel-aligned.
- The download CTAs use a **Google Play badge** (`.store-badge`, matching
  idct.tech/sticker-maker). Its `href` is a placeholder Play URL for this app id
  (`play.google.com/store/apps/details?id=tech.idct.chromis`). When the final
  store link is provided, replace that URL on every `.store-badge` — header, hero,
  CTA band, and the nav on both legal pages. A "Coming soon to Google Play" note
  sits under the hero badge until launch.

## The AI example images

`assets/img/effects/*` are generated from the sample photos with the app's own
bundled model (`assets/models/u2netp.onnx`) using the same recipe the app uses
(squash-resize 320², ImageNet normalize, min-max normalize, bilinear upscale to
a soft alpha). Regenerate with `tool/gen_effects.py` (see repo).

## Cache-busting

GitHub Pages serves CSS and images with a long cache (`Cache-Control: max-age=14400`
= 4 h). After you change `styles.css` or an image, **bump the `?v=N` query** on
its `<link>` / `<img>` reference (currently `?v=2`) so browsers fetch the new
file instead of a stale cached copy (currently `?v=3`). The HTML pages revalidate
quickly, so the new versioned URLs propagate on the next visit.

## Deploy

Any static host works (the site is served at `idct.tech/chromis`,
alongside Sticker Maker). Upload the `website/` contents; no server code needed.
External requests are only to Google Fonts, Google Analytics, and Web3Forms.
