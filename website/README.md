# Photo Editor AI — website

Static marketing site for the Photo Editor AI Android app. Plain HTML/CSS +
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

## Placeholders to fill before going live

Both are intentionally left as obvious placeholders:

| Placeholder | Where | Replace with |
|---|---|---|
| `G-XXXXXXXXXX` | `<head>` of every `.html` | Your **Google Analytics 4** Measurement ID |
| `YOUR_WEB3FORMS_ACCESS_KEY` | `index.html` contact form (`access_key`) | Your **Web3Forms** access key from [web3forms.com](https://web3forms.com) |

Quick find/replace, e.g.:

```bash
grep -rl "G-XXXXXXXXXX" website | xargs sed -i 's/G-XXXXXXXXXX/G-YOURID/g'
sed -i 's/YOUR_WEB3FORMS_ACCESS_KEY/your-real-key/' website/index.html
```

Both placeholders are **self-guarding**:

- **Google Analytics** loads only after the visitor accepts the cookie-consent
  banner *and* the ID is a real one — while it's still `G-XXXXXXXXXX` the
  analytics loader stays inert, so no requests are sent.
- Until the **Web3Forms** key is set, the contact form does not post to the API —
  it shows a friendly "email us instead" message.

## Notes

- The before/after slider expects the two effect images to share the **3:4**
  aspect ratio (`dog-before.jpg` / `dog-studio.jpg` are 900×1200). Keep new
  slider images at 3:4 so the reveal stays pixel-aligned.
- The app CTAs point at `#contact` ("Get notified at launch") because the app
  isn't on Google Play yet. At launch, swap them to the Play listing URL and
  relabel to "Get it on Google Play" (see the HTML comments in `index.html`).

## The AI example images

`assets/img/effects/*` are generated from the sample photos with the app's own
bundled model (`assets/models/u2netp.onnx`) using the same recipe the app uses
(squash-resize 320², ImageNet normalize, min-max normalize, bilinear upscale to
a soft alpha). Regenerate with `tool/gen_effects.py` (see repo).

## Deploy

Any static host works (the site is served at `idct.tech/photo-editor-ai`,
alongside Sticker Maker). Upload the `website/` contents; no server code needed.
External requests are only to Google Fonts, Google Analytics, and Web3Forms.
