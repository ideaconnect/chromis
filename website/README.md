# Chromis - website

Static marketing site for the Chromis Android app. Plain HTML/CSS +
a little vanilla JS, no build step. Matches the app's palette and BOTH its
themes (`lib/core/theme/app_palette.dart`).

```
website/
├── index.html          # landing page (hero, filter gallery, effects, features,
│                       #   screens, FAQ, contact)
├── privacy.html        # Privacy Policy
├── terms.html          # Terms of Use
├── styles.css          # shared styles
└── assets/img/
    ├── logo.png              # app icon, 256px (header + footer, drawn at 34)
    ├── favicon-32.png        # the same tile at 32px
    ├── apple-touch-icon.png  # the same tile at 180px
    ├── icon-full.png         # the same tile at 512px (CTA band, drawn at 104)
    ├── effects/              # AI composites, the filter-gallery photo, and the
    │                         #   vignette/HDR/shadow/contour demos
    └── screens/              # real app screenshots (WebP)
```

## The fonts are ours, and that is the point

Manrope and Space Grotesk are served from this domain, not from
`fonts.googleapis.com`. That was a request to Google - IP, user agent, referrer -
on **every page load, fired before the cookie banner and regardless of what the
visitor answered it**. On a site whose whole claim is that the app talks to
nobody, it was the one thing on the page a Decline could not switch off.

`python tool/gen_web_fonts.py` subsets both from `assets/fonts/` (they are
already in the repo, under the OFL, which permits redistribution) to
`website/assets/fonts/*.woff2`: 295 KB of TTF becomes **57 KB**, less than the
round trip it replaces. Re-run it if the families change or the copy starts
using a character outside its range - the range is enumerated at the top of that
script rather than guessed, so a missing glyph falls back to the system stack
instead of erroring.

The `@font-face` blocks declare `font-weight` as a **range**, because these are
variable fonts with the `wght` axis kept. Pin a single instance and every other
weight the CSS asks for is rendered as a synthetic smear.

**The OFL texts ship beside them and are linked from the footer.** Serving a font
makes this page a redistributor, and the licence requires its text to travel with
the font it covers - present on disk is the obligation, linked is what makes it
findable. `gen_web_fonts.py` does not copy them; if a face is ever added, copy its
`OFL-*.txt` out of `assets/fonts/` by hand and add the footer link.

**The page now makes no third-party request at all** until a visitor accepts
analytics. `privacy.html` says so; keep that true, and if anything is ever added
that reaches another host, either gate it behind consent or self-host it.

## Light and dark

The site follows the visitor's system theme and a header toggle can pin either,
which is the same three states as the app's Settings - System / Light / Dark.
"System" is stored as the ABSENCE of `data-theme` on `<html>`, not as a third
value, so a visitor who never touches the control has nothing stored about them
and the stylesheet's `prefers-color-scheme` rule stays in charge.

Three things in `styles.css` that are easy to get wrong:

- **The light block is written twice** - once under `@media
  (prefers-color-scheme: light)`, once as `:root[data-theme="light"]`.
  `light-dark()` would fold them into one, and in a browser that does not know
  that function *every* custom property resolves to nothing, which is an
  unstyled page rather than a stale-looking one.
- **`data-theme` is set by an inline script in the `<head>`**, before the
  stylesheet. The deferred script at the end of the body would be a frame too
  late, and a visitor who pinned the opposite theme would see it flash.
- **Anything drawn ON a photograph takes `--on-glass`, not `--text`.** A
  photo has no theme, but the translucent pill behind the label does - it is
  the page's own colour at low alpha - so the two have to flip together or a
  black pill lands on a white page with white text on it.

`--plate` is deliberately lighter than every other dark surface: the drop-shadow
demo is a black shadow, and on a near-black plate that card shows nothing at
all.

**A label pill drawn on a photograph is opaque (`--pill`), not glass.** This one
was measured, not eyeballed: translucent, a pill's effective background is
whatever the photo happens to be behind it, so its contrast is unknowable - the
accent text on the old 66%/72% glass ranged from 9.7:1 down to **2.4:1**, and it
failed in *both* themes (dark over a pale photo, light over a dark one). Solid,
the number is one we can hold. `--glass-strong` survives only for the sticky
header, which sits on the page's own colour and so composites predictably.

**`--border` and `--border-ui` are two tokens because WCAG 1.4.11 governs only
the second.** A decorative card hairline at 1.3:1 is fine; the edge that tells
you where a text field is has to reach 3:1, and `--border-ui` is the alpha that
does, computed rather than chosen.

## The brand marks are generated

Those four icon files are **outputs of `tool/gen_branding.py`**, which takes the
app icon from `assets/branding/modern.png` and writes the app's copies and the
site's from the same picture - so the favicon cannot drift from the launcher
icon. Don't retouch them; change the generator and re-run it from the repo root.
All four are the same tile, differing only in size.

Each carries its own 15.5% corners with transparency outside them, so **no
`border-radius` and no plate**: rounding them again trims the silhouette, and the
tile's mid-tone teal already reads on `--surface` without a light ground behind
it. `.cta-icon` uses `filter: drop-shadow` rather than `box-shadow` for the same
reason - box-shadow follows the border box and would draw a hard rectangle behind
a rounded tile.

(The icon before this one was `#0A2127`, a couple of steps from `--surface`, and
did need a plate. If the artwork ever goes dark again, that is the fix, and the
app's `AppLogo` needs the same treatment at the same time.)

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

`python tool/gen_screens.py` turns the capture session into the WebP set in
`assets/img/screens/`: it downscales to ~2x the rendered size and encodes. It
reads `build/shots-i18n/en/<profile>/`, which is what
`tool/capture_store_shots.py` writes and what `tool/gen_store_screens.py`
composes the Play listing from - **one capture session feeds both**, so a
screenshot here and the same screenshot on Play cannot be of two different
builds. The `SHOTS` map at the top of the script names each capture and its
output.

The six phone shots go out at 620x1383 and the wide one is the **10-inch
tablet** at 1240x775 - both form factors show the rail-plus-folding-panel
landscape layout, and 16:10 is a better block on the page than a phone on its
side at 2.23:1. Changing which capture feeds the wide slot changes its aspect,
so the `height` attribute in `index.html` has to follow.

Capture with the **Pro entitlement set** so no ad is on screen anywhere -
`python tool/capture_store_shots.py prepare <profile>` does it, along with
disabling the Play Store so the entitlement is not revoked a second after
launch. Nothing here crops, because with Pro there is nothing to crop. **If a
capture is ever re-taken without Pro the images are wrong in a way a crop cannot
fix**: the editor's rail grows a Go Pro entry that pushes every tool down one
slot, so the script's tap tables open the wrong panels.

`capture_store_shots.py prepare` also tames the status bar, so the shots do not
carry whatever notification icon happened to be up that day.

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
  idct.tech/sticker-maker), pointing at
  `play.google.com/store/apps/details?id=tech.idct.chromis`. It appears four
  times - header, hero, CTA band, and the nav on both legal pages - so a change
  of URL is a change in five places.
- The **"coming soon" wording is gone** from the hero note and the CTA band. It
  outlived the launch by a release, which is the usual fate of a date written
  into prose: nothing breaks and no test goes red, the page just quietly says
  something untrue. Prefer copy that does not need a launch to become
  accurate.

## The AI example images

**The photographs are CC0 and committed.** `assets/store/samples/` holds them,
with each one's title, licence and Wikimedia Commons URL in `SOURCES.json` - the
same set the Play listing uses. A landing page is commercial use of every pixel
on it, exactly as a store listing is, so which photograph is on it belongs in
version control; these used to come from personal photos in
`assets/branding/dog/`, which is gitignored for size and therefore could not be
regenerated by anyone who did not already have the originals.

`assets/img/effects/dog-*` are composited from `samples/subject.jpg` and
`samples/subject-mask.png`, and **that mask is a real output of the app's own AI
Cut**, kept from a device run rather than drawn by hand. So no model runs in the
generator at all: `tool/gen_effects.py` only composites. Point it at a directory
of raw photos instead (`python tool/gen_effects.py assets/branding/dog`) and it
falls back to scoring them through the bundled U²-Netp, which is what it used to
do always and which is the only path that needs `onnxruntime`.

The filter gallery and the vignette/HDR demos take `samples/landscape.jpg`
instead - that whole section is 16:9, and a 3:4 portrait cropped to a 16:9 band
keeps the strip without the subject's face in it.

The page serves the `.webp` siblings (`gen_filters.py` writes them); the `.jpg`
originals stay because `og:image` points at one and not every link scraper
decodes WebP. `dog-cutout.png` is the input `gen_filters.py` builds the shadow
and contour demos from, and `dog-chip.png` is unused - neither is referenced by
a page, so a deploy can skip both.

## Cache-busting

GitHub Pages serves CSS and images with a long cache (`Cache-Control: max-age=14400`
= 4 h). After you change `styles.css` or an image, **bump the `?v=N` query** on
its `<link>` / `<img>` reference so browsers fetch the new file instead of a
stale cached copy. `styles.css` is at `?v=11`, the brand marks at `?v=10`, the
screenshots at `?v=8`, the AI composites at `?v=7` and the painted-effect demos
at `?v=6`; the generated filter tiles use `ASSET_V` in `tool/gen_filters.py`. The HTML pages revalidate quickly, so the new versioned
URLs propagate on the next visit. (Grep the HTML rather than trusting this line -
if the two ever disagree, the HTML is the truth.)

## Deploy

Any static host works (the site is served at `idct.tech/chromis`,
alongside Sticker Maker). Upload the `website/` contents; no server code needed.
External requests are only to Google Fonts, Google Analytics, and Web3Forms.

`.github/workflows/pages.yml` does exactly that on every push to `main` that
touches `website/`: GitHub Pages for this repo publishes it as a *project* site,
which the org's own Pages site (`ideaconnect/ideaconnect.github.io`, custom
domain `idct.tech`) exposes at `idct.tech/chromis/`.

`app-ads.txt` here is a **mirror**, served at `idct.tech/chromis/app-ads.txt`
because that is the URL the Play listing points at. The copy AdMob verifies is
the one at `https://idct.tech/app-ads.txt`, in the `ideaconnect.github.io` repo -
a crawler reduces the listing's website to its root domain and reads only
`/app-ads.txt`, so a subpath copy is never the one that counts. **Edit the two
together**; a mirror that contradicts the root is worse than no mirror at all.
See [docs/monetization-setup.md](../docs/monetization-setup.md).
