# CLAUDE.md - Chromis

Guidance for AI coding sessions on this repo.

## What this is

Free, ad-supported Flutter **Android** photo editor with on-device AI (BG removal,
object removal, layers, text, comic bubbles, export). Built from the approved
Claude Design mockup, reusing IDCT Sticker Maker's engine code.

## Architecture

Feature-first: `lib/app` (root + `go_router`), `lib/core` (theme, models,
rendering, widgets), `lib/features/*`. State via `flutter_riverpod`. Dark-only
theme - read colors from `AppColors` and design tokens from `context.sm`
(`SmTokens`); fonts are **Manrope** (body) + **Space Grotesk** (`AppFonts`).

### Photo Grid (collage)

A grid is a **partition of the canvas**, not a document type and not a layer
type: `Project.grid` holds a `GridSpec` (null = ordinary project) and each
`Layer.cellId` says which cell it lives in (null = free layer, drawn above the
grid unclipped). Layer transforms stay in canvas-logical units - cells only
clip - which is what lets every existing tool keep working inside a cell.

Cells are a tree of n-ary splits (`lib/core/models/grid.dart`), so dragging one
divider exchanges weight between exactly two siblings and every other cell keeps
its rect by construction. `layoutGrid` is the single source of cell rects, read
by both painters, the hit-tester and the template previews. The border renders
as a background FILL with the cells drawn on top, so gaps and the outer margin
ARE the border. Every reshape goes through `applyGridSpec`, which maps content
from the rects before/after (never incrementally, so drags cannot drift).

See `docs/photo-grid-plan.md`.

### Layer effects

`LayerEffects` (blend / shadow / stroke) is ONE field on the sealed `Layer`
base, so a new shared effect touches one class instead of three; photo-only
effects (filter, HDR, vignette) hang off `ImageLayer`/`ImageAdjustments`
because they describe pixels rather than compositing. Filters and the HDR tone
curve fold into the SAME colour matrix as the Adjust sliders, so a layer costs
one `ColorFilter` however many looks are stacked on it.

The photo chain is one function - `paintImageLayer` in
`core/rendering/layer_effects_painter.dart` - called by both the preview and
the export, so those cannot drift. Compositing (blend / opacity / shadow)
cannot be shared that way and is written twice, guarded by
`test/rendering/effects_render_parity_test.dart`.

The widget half (`core/widgets/layer_effects_box.dart`) MUST use raw
`saveLayer` render objects: a blend mode has no engine-layer representation, so
it has to live inside one recorded picture, and `Opacity`/`ColorFiltered`/
`ImageFiltered` each push a compositing layer that would split it.

### Landscape

`EditorScreen` branches on `maxWidth > maxHeight`: the dock becomes a rail down
the left, the tool panel a folding column beside it, the rest is canvas.
Portrait is unchanged. Rotation is allowed by `supportedOrientations` in
`main.dart` - it was locked to portrait, which made the whole layout dead code.

A short viewport is now a real path, so **bottom sheets use `SheetBody`**
(caps the height, scrolls, clears the keyboard and gesture bar) rather than a
bare `Column`. `test/landscape_overflow_test.dart` pumps every screen and sheet
at landscape sizes; add new ones to it.

### Branding

Every brand asset - launcher icon and its adaptive layers, splash, Play listing
icon, in-app logo, website mark, favicon - is produced by `tool/gen_branding.py`
from the icon design in `assets/branding/modern.png`. **Never retouch an
output**; change the generator and re-run it, then
`dart run flutter_launcher_icons` + `flutter_native_splash:create`.

The composition is never re-arranged - assets differ only in size, in whether the
tile keeps its corners, and in how the tile is split for Android. Three things
worth knowing:

- The source is a **mock-up**: the tile on a white presentation card. The tile is
  found by chroma (the only saturated region); the card and backdrop are dropped.
- The tile's background is a **gradient**, so nothing can key off a single flat
  colour. `gradient_surface` recovers it as a degree-3 polynomial fitted
  iteratively with the artwork rejected as outliers; the artwork is then keyed
  and unmatted against that surface per pixel.
- The **adaptive icon** splits the design: the recovered gradient is a square
  full-bleed background, the artwork alone is the foreground, placed so the
  visible 72 of 108dp is the design at its own proportions - which lands it
  inside Android's guaranteed 66dp circle. A launcher's mask cuts gradient.

**No plate.** This tile is mid-tone teal and reads on our dark surfaces unaided;
the assets carry their own corners, so nothing should clip or chip them. The icon
before it was `#0A2127`, a couple of steps from `AppColors.panel`, and did need a
light ground - if the artwork ever goes dark again, that is the fix.

### Persistence

Anything the user cannot re-enter is written through `writeFileAtomically`
(`core/persistence/atomic_file.dart`): tmp + flush + rename, so a kill or a full
disk leaves the previous file rather than a truncated one. Both the project
manifests and `settings.json` use it - `settings.json` reads back as `{}` on any
error, and `{}` means "Pro was never bought".

Two GC rules that are easy to break:

- **A duplicated project owns its masks.** Photos (`img_*`) are shared and
  refcounted across manifests by `sweepOrphanAssets`; masks are NOT, because the
  editor also runs an in-session mask GC that can only see the open document.
  `ProjectRepository.duplicate` copies each `mask_*` for that reason.
- **A quarantined `.json.corrupt` is read, not skipped.** Most quarantines are
  schema rejections whose raw JSON still names its assets, and skipping them
  aborted the sweep - which disabled orphan cleanup for the life of the install.
  Only bytes that will not decode as JSON abort it. `list()` also un-quarantines
  a manifest that parses again, so a downgrade is recoverable.

### Ads and consent

Nothing may request an ad before UMP has answered. `AdsService.consentSettled`
is the gate; the Home banner and `showRewarded` both await it, and
`canRequestAds` decides whether a load happens at all. Consent is NOT awaited
inside `init()` - that would stall ads for the whole network timeout on every
offline launch. `PrivacyScreen` carries the permanent "Ad privacy choices" entry
point, rendered only where UMP reports it is required.

## Milestones

Planned as GitHub milestones **M0-M9** with issues. Work one milestone at a time;
**after each milestone, stop and ask the user to test-deploy on their physical
device** before starting the next (device deploys need their acknowledgement).

## On-device AI (reused from Sticker Maker)

`lib/features/segmentation/**` - engine abstraction + registry, ML Kit engine,
bundled U²-Netp (ONNX) engine, MobileSAM object engine, mask brush/processing.
Models in `assets/models/*.onnx` (Apache-2.0). Runs via `flutter_onnxruntime`.

## Monetization

`google_mobile_ads` (banner/interstitial/rewarded + UMP) and `in_app_purchase`
(one-time `pro_remove_ads`). Ad unit IDs live in one config file; Google **test**
IDs are placeholders until the real ones are set. See `docs/monetization-setup.md`.

## Licensing policy (closed-source app)

Bundle **only** MIT / BSD / Apache-2.0 / SIL-OFL. No GPL/LGPL (ffmpeg dropped),
no CC-BY-NC (no `u2net_portrait` / BRIA RMBG). Register bundled font + model
license texts in `lib/features/about/bundled_licenses.dart`.

## Website (`website/`)

Plain HTML/CSS - no Jekyll, no build. `.github/workflows/pages.yml` uploads the
folder as-is on any push touching `website/**`, publishing it at
**idct.tech/chromis/**. Pages there are flat files: `index.html`, `privacy.html`,
`terms.html`.

**`website/sitemap.xml` is hand-maintained and must always be correct.** Unlike
the other IDCT sites - helena and gentastic generate theirs from a Liquid loop,
nuts uses `jekyll-sitemap` - this one is a literal list, so it is the only one
that goes stale on its own. Adding, renaming or deleting a page in `website/`
means editing `sitemap.xml` **in the same change**. Nothing catches it if you
forget: no build fails, no test goes red, the page simply never gets indexed.

It is not just this site's sitemap. `idct.tech/sitemap.xml` is a sitemap *index*
(repo `ideaconnect/ideaconnect.github.io`) that references this file directly and
is submitted to Google Search Console - so if this file 404s or goes malformed,
it is a hard error against the whole domain, not just `/chromis/`.

Two rules that go with it:

- **Every page needs a `<link rel="canonical">`, and it must match its `<loc>`
  here exactly.** GitHub Pages answers both `/chromis/privacy` and
  `/chromis/privacy.html` with a 200, so without a canonical the same page can
  be indexed twice. The canonical for the home page is the bare directory,
  `https://idct.tech/chromis/`, not `index.html`.
- **`changefreq` / `priority` are omitted on purpose.** Google ignores both;
  don't reintroduce them.

Check after any page change:

```bash
python3 -c "import xml.etree.ElementTree as ET; \
print([e[0].text for e in ET.parse('website/sitemap.xml').getroot()])"
grep -l 'rel="canonical"' website/*.html   # every page must be listed
```

## Commands

```bash
flutter analyze        # keep clean
flutter test           # keep green
dart format .          # CI enforces formatting
flutter build apk --debug
```

Identity: applicationId `tech.idct.chromis`, namespace `tech.idct.chromis`, minSdk 26.
