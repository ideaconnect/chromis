# Chromis - website

Static marketing site for the Chromis Android app. Plain HTML/CSS +
a little vanilla JS, no build step. Matches the app's dark theme and palette
(`lib/core/theme/app_colors.dart`).

```
website/
├── index.html          # landing page (hero, filter gallery, effects, features,
│                       #   screens, FAQ, contact)
├── privacy.html        # Privacy Policy
├── terms.html          # Terms of Use
├── styles.css          # shared styles
└── assets/img/
    ├── logo.png        # app mark
    ├── effects/        # AI composites, the filter-gallery photo, and the
    │                   #   vignette/HDR/shadow/contour demos
    └── screens/        # real app screenshots (WebP)
```

## The filter gallery is the app's own maths

The Effects section lets a visitor click through all 15 one-tap looks. It does
**not** ship 15 rendered photos - it ships one photo plus the app's own colour
matrices, as SVG `feColorMatrix` filters, and the browser applies them live.
Same numbers, same result, ~13 KB per look instead of ~150.

The pipeline, all from the repo root. Note the image steps need the raw source
photos in `assets/branding/dog/`, which are gitignored for size - a fresh clone
has the committed outputs but cannot regenerate them without those originals.

```bash
flutter test tool/dump_filters.dart   # ColorMatrix.filter -> build/filters.json
python tool/gen_effects.py            # U²-Netp cut-out composites (needs onnxruntime)
python tool/gen_filters.py            # gallery images + patches index.html
python tool/verify_svg_filters.py     # proves the SVG filters == the Dart ones
```

`gen_filters.py` rewrites everything between `<!-- BEGIN generated:filters -->`
and `<!-- END generated:filters -->` in `index.html` - the SVG `<defs>`, the
per-look CSS and the chip strip. **Don't hand-edit inside those markers**; add a
look in `PhotoFilter`/`ColorMatrix.filter` and re-run instead.

Two conversions make the SVG match Skia, and both are easy to get wrong, which
is why `verify_svg_filters.py` exists: SVG channels are 0..1 so the matrix's
translation column is divided by 255, and every filter must declare
`color-interpolation-filters="sRGB"` (SVG defaults to linearRGB). The verifier
renders a strip of known colours through each look twice - once by multiplying
the matrix in Python, once in headless Edge - and fails if any channel differs
by more than 1/255.

## The painted effects are rendered by the app

Vignette, HDR, drop shadow and contour are Canvas routines rather than matrices,
so they can't be handed to the browser. `tool/gen_effect_demos.dart` renders
them by calling the app's own `paintImageLayer` and `paintLayerShadow`;
`gen_filters.py` only cuts the source frames and encodes the results. The
settings the page advertises live at the top of that Dart file, next to the
render, so the numbers on the page and the numbers in the picture can't
disagree.

They used to be re-implemented in Python. That mirror looked right - it matched
the app to ~1/255 on an evenly lit crop - and was under-rendering HDR by about a
third on a shadow-heavy one, which is exactly the failure mode hand-copied
render code has. Calling the real painter removes the question rather than
policing it.

HDR runs at 1.0, which is the app's slider maximum (`hdrTone` clamps there and
the local-contrast pass caps at 0.85). There is no stronger setting to show.

`gen_effects.py` picks which source photo becomes the cut-out. It scores the
matte on **margin** (how much room the subject leaves inside the frame, which is
literally the space a contour has to grow into), vetoes mattes that grabbed
scenery via **solidity**, and only breaks ties on coverage. Coverage alone used
to win with a photo whose matte had swallowed a blurred shape behind the dog -
which showed up as a straight cut through the silhouette the moment a stroke was
drawn around it.

## Screenshots

`tool/gen_screens.py <dir>` turns raw `adb exec-out screencap` PNGs into the
WebP set in `assets/img/screens/`: it crops the ad slot off Home (a test ad is
not landing-page material), downscales to ~2x the rendered size, and encodes.
The `SHOTS` map at the top names each source file and its output.

## Checking a change

`tool/measure_page.py [width] [selector ...]` reports the real rendered box of
each element at a given viewport, using headless Edge. It measures inside an
iframe because headless Edge won't make its own window narrower than ~490px,
and phones are the whole audience:

```bash
python tool/measure_page.py 390     # phone
python tool/measure_page.py 1280    # desktop
```

It flags horizontal overflow, and it is how the "every screenshot rendered at
full intrinsic height" bug was found - the `width`/`height` attributes on the
`<img>` tags need `img { height: auto }` in the CSS or the attribute wins.

## Analytics & contact form

Both are **configured** (values live in the HTML, which is fine - a GA4
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
  aspect ratio (`dog-before.webp` / `dog-studio.webp`). Keep new
  slider images at 3:4 so the reveal stays pixel-aligned.
- The download CTAs use a **Google Play badge** (`.store-badge`, matching
  idct.tech/sticker-maker). Its `href` is a placeholder Play URL for this app id
  (`play.google.com/store/apps/details?id=tech.idct.chromis`). When the final
  store link is provided, replace that URL on every `.store-badge` - header, hero,
  CTA band, and the nav on both legal pages. A "Coming soon to Google Play" note
  sits under the hero badge until launch.

## The AI example images

`assets/img/effects/dog-*` are generated from the sample photos with the app's
own bundled model (`assets/models/u2netp.onnx`) using the same recipe the app
uses (squash-resize 320², ImageNet normalize, min-max normalize, bilinear
upscale to a soft alpha). Regenerate with `tool/gen_effects.py`.

The page serves the `.webp` siblings (`gen_filters.py` writes them); the `.jpg`
originals stay because `og:image` points at one and not every link scraper
decodes WebP. `dog-cutout.png` is the input `gen_filters.py` builds the shadow
and contour demos from, and `dog-chip.png` is unused - neither is referenced by
a page, so a deploy can skip both.

## Cache-busting

GitHub Pages serves CSS and images with a long cache (`Cache-Control: max-age=14400`
= 4 h). After you change `styles.css` or an image, **bump the `?v=N` query** on
its `<link>` / `<img>` reference so browsers fetch the new file instead of a
stale cached copy. `styles.css` and the screenshots are at `?v=4`; the
generated filter tiles use `ASSET_V` in `tool/gen_filters.py`. The HTML pages
revalidate quickly, so the new versioned URLs propagate on the next visit.

## Deploy

Any static host works (the site is served at `idct.tech/chromis`,
alongside Sticker Maker). Upload the `website/` contents; no server code needed.
External requests are only to Google Fonts, Google Analytics, and Web3Forms.
