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

## Commands

```bash
flutter analyze        # keep clean
flutter test           # keep green
dart format .          # CI enforces formatting
flutter build apk --debug
```

Identity: applicationId `tech.idct.chromis`, namespace `tech.idct.chromis`, minSdk 26.
