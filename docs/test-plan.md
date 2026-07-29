# Test Plan - Chromis

Extensive coverage across **all features and all paths**, derived from a full
codebase survey. Organized into three tiers by how a test must run.

## Tiers

| Tier | Where it runs | Command | In this pass |
|---|---|---|---|
| **1. Host unit/widget** | Host VM (no device) | `flutter test test/` | **Write + run green now** |
| **2. On-device BDD** | Real Android device | `./e2e.ps1` | **Write now, run on device later** (per instruction) |
| **3. Manual-only** | Human + real hardware | - | Documented, not automated |

Finder conventions (Tier 2): the app has almost no `Key`s, so `find.text('<label>')`
is the primary finder (`GradientButton`/`PillChip`/`dockButton` all render a visible
`Text`). Toasts (`showSmToast`) are transient (~1.5s) - assert app/provider **state**
rather than toast text where possible. `pumpAndSettle` hangs (splash spinner / banner
slot) → use the fixed-frame `settle(tester)` helper.

---

## Tier 1 - Host unit/widget tests (device-free)

Runnable now with `flutter test test/`. None require a real image file (the
`EditorController` never opens `assetPath` - a fake path string suffices);
persistence uses an injected temp `baseDir`; plugin-backed classes use fakes.

### 1.1 Models - `test/models/`
- **`layer_test.dart`** - `ImageLayer`/`TextLayer`/`BubbleLayer`:
  `copyWith` per field; `toJson`→`fromJson` round-trip (incl. `crop` list,
  `outlineColor`/`color`/`fill`/`stroke`/`text` colors via `toARGB32`, bubble
  `shape.name`, `tailDx/Dy`); `fromJson` defaults (missing visible/opacity/
  adjustments/outline → identity; `_cropFromJson` missing/invalid → full rect;
  bubble unknown shape → `speech`); `copyWith(clearMask:true)` wins over
  `maskPath`; `isCropped`/`hasOutline`; `==`/`hashCode` sensitivity (cropRect,
  adjustments, transform, colors, maskPath); `Layer.fromJson` dispatch + unknown
  type → `FormatException`.
- **`project_test.dart`** - `Project.empty` clamps dims (8→16, 10000→8192) and
  sets one frame; `canvasCenter`/`canvasAspect`/`safeFrameIndex` clamp; JSON
  round-trip incl. ISO dates; migration: v1 (no version/dims) → 512² legacy;
  `version>schemaVersion` → `FormatException`; `fps` clamp; bad dates → null;
  the min/max/default constants.
- **`frame_test.dart`** - `copyWith`, JSON round-trip mixed layers, order-
  sensitive `==`/`hashCode`, default `const []`.
- **`layer_transform_test.dart`** - `identity`, `copyWith`, JSON round-trip,
  `==`/`hashCode`, `fromJson` requires all keys.
- **`image_adjustments_test.dart`** - `identity`/`isIdentity`, `copyWith`, JSON
  round-trip + defaults, `==`/`hashCode`.

### 1.2 Rendering - `test/rendering/color_matrix_test.dart`
`ColorMatrix.identity`; `brightness(1)`/`contrast(1)`/`saturation(1)`/`hueRotate(0)`
≈ identity; `contrast` translation `t=127.5*(1-c)`; `saturation(0)` = Rec.709
greyscale rows; `multiply(identity, m)==m`; `ImageAdjustmentsMatrix.toColorMatrix`
identity short-circuit + fixed compose order (brightness∘contrast∘saturation∘hue).

### 1.3 Mask pipeline - `test/segmentation/`
- **`alpha_mask_test.dart`** - constructor asserts; `filled` clamps 0..255;
  `empty` all-0; `at(x,y)` row-major; `coverage(cutoff)` fraction; `copyWith`;
  `==`/`hashCode`.
- **`mask_brush_test.dart`** - empty points / `radius<=0` → unchanged; hard brush
  sets target (0 erase / 255 restore); soft brush monotonic toward target
  (overlapping dabs don't fight); `_densify` midpoints; edge clamping.
- **`mask_processing_test.dart`** - `threshold`, `feather` (radius<=0 no-op,
  border-clamped), `keepLargestComponent` (4-conn BFS, all-below → empty),
  `subtract` = min(a,255-b) + size assert, **`removeObjectAt` three outcomes**
  (`miss`/`subject`/`removed`), `process` chain order.
- **`mask_tensor_test.dart`** - `packTensor` NCHW `((px/255)-mean)/std` planar +
  length assert; `unpackMask` low-range guard branch (flat→uniform by mean) vs
  min-max normalize + bilinear upscale + quantize; `ModelConfig` defaults.
- **`mask_store_test.dart`** - `encodePng`↔`decodeAlpha` round-trip (alpha
  preserved); `SupersededMaskCollector` queue/collect (deletes only unreferenced).
  *(needs `TestWidgetsFlutterBinding` for `dart:ui`, still host-only.)*

### 1.4 Bubble geometry - `test/editor/bubble_view_test.dart`
`kBubbleBaseSize`; `bubbleBodyRect` insets; `bubbleTailTip`↔`bubbleTailFromLocal`
inverse within clamp; `bubbleCaptionMaxLines` (fontSize/height<=0 → 1);
`bubbleFitFontSize` (fits → maxSize; oversize → shrinks toward 6.0). *(TextPainter
paths need the test binding.)*

Creation is separate - `test/editor/bubble_creation_test.dart`: the Bubble dock
entry opens the format picker (all five offered, each drawn by `BubblePainter`,
nothing added yet); the Add-layer menu's "Add bubble" reaches the same picker;
picking any format creates a layer with *that* shape; dismissing adds none; a
created bubble announces itself (toast + "Comic bubble" header + a pink badge on
the dock's Bubble, while Text stays honestly lit); the panel opens scrolled to
the format just picked (Whisper is past the fold); the panel's format row still
reshapes in place; and `bubbleShapeTileHeight` keeps a tile inside its measured
box at text scales 1.0-2.0, with and without the description. *(That last group
pumps the tile alone: `EditorScreen` has its own pre-existing large-font
overflows - top bar, outer column - which would mask it.)*

### 1.5 Editor controller - `test/editor/editor_controller_test.dart`
Via `ProviderContainer` + `loadProject(Project.empty(...))`, fake asset paths:
- Add: `addTextLayer`/`addBubbleLayer`(name rule)/`addEmoji`/`addImageLayer`
  (auto-name "Photo","Photo 2", cascade offset) - all select the new layer.
- Layer ops: `removeLayer` (deselect), `duplicateLayer` (nudge+select, missing→no-op),
  `reorderLayer` (clamp), `toggleVisibility`, `setOpacity`, `updateTransform`,
  `renameLayer`.
- Image ops: `updateImageAdjustments`, `updateImageOutline`, `setImageMask`
  (null→clearMask), `setImageCrop`, `replaceImageAsset` (keeps transform/mask/
  crop/adjustments); other layer types untouched.
- Text/bubble: `updateTextLayer` mirrors name=text; `updateBubbleLayer` never
  renames to blank; per-group coalesce.
- Tool/selection: `setTool` clears coalesce; `selectLayer(null)`.
- **Undo/redo**: `canUndo`/`canRedo`; coalesce folds same-key edits into one step;
  `endEdit` resets key; `_maxHistory=50` cap (push 51, oldest dropped); undo/redo
  clear selection; redo cleared by new commit.
- `loadProject` resets stacks + `_bumpSeqPast` (new ids beyond loaded max).
- Canvas: `setCanvasSize` (no-op unchanged; scaleContent scales pos/scale; clamp),
  `cropCanvas` centered, `cropCanvasRect` shift + no-op identical.
- Frames (dead UI but live logic): `addFrame`/`deleteFrame`(≥1)/`duplicateFrame`/
  `reorderFrame`/`selectFrame` bounds.
- `isMaskReferenced` (live project OR any undo/redo snapshot).

### 1.6 Persistence - `test/persistence/`
- **`project_repository_test.dart`** - `ProjectRepository(baseDir: tmp)`:
  save↔load round-trip, atomic `.json.tmp`, `list()` recency sort, corrupt
  manifest → `.json.corrupt` quarantine (skipped), `load(missing)`→null,
  `duplicate` (fresh ids, `<name> copy`, shared asset paths), `delete`,
  `sweepOrphanAssets(Duration.zero)` (deletes only unreferenced `img_*`/`mask_*`;
  aborts if any manifest unparseable / `.corrupt` present; young files kept).
- **`settings_store_test.dart`** - `SettingsStore(baseDir: tmp)`: onboardingSeen
  default false→persist true; segmentationModelId null→persist; proEntitled;
  corrupt `settings.json` → treated as `{}` (never throws).

### 1.7 Config / registry / entitlement - `test/config/`
- **`ads_config_test.dart`** - `useTestAds==true` → banner/interstitial/rewarded
  return the Google test ids.
- **`bundled_licenses_test.dart`** - `registerBundledLicenses(fakeBundle)` yields
  one `LicenseEntryWithLineBreaks` per entry; 6 fonts + 2 AI-model Apache assets;
  no GPL/CC-BY-NC (complements the existing about_data license test).
- **`seg_model_test.dart`** - `SegModel.fromId`/`fromEngineId` mappings + unknown
  fallbacks; enum data.
- **`segmentation_registry_test.dart`** - fake engines: `resolve` prioritizes
  `preferredId`, returns first available; `segment` falls through on
  `SegmentationException`, null when none available.
- **`ai_capability_test.dart`** - fake `platformServicesProvider.memoryInfo`:
  null→allowed; lowRam→denied; <3 GiB→denied (GiB reason); else allowed.
- **`entitlement_test.dart`** - `EntitlementController.grant()` idempotent +
  persists (fake settings store); `IapService.loadProduct` null on empty list
  (fake `InAppPurchase`).

### 1.9 Export output - `test/export/export_output_test.dart`
The artefact the user keeps, decoded by an **independent** decoder
(`package:image`, not the engine that produced the bytes): PNG signature +
alpha kept + the corner transparent + the content opaque and the right colour;
"not blank" (>5% of pixels painted); JPEG SOI marker + transparency flattened
onto **white**, not black; WebP RIFF/WEBP container; `outputWidth` honoured with
height from the canvas aspect; half-res is half in both axes AND the composition
scales with it (not just the frame); a grid export fills its margin with the
border colour at the chosen width; and PNG vs WebP agree on a semi-transparent
layer - the straight-vs-premultiplied alpha trap `_rasterize` warns about.
*Mutation-checked: flattening JPG onto black and dropping the output scale each
fail exactly one of these.*

### 1.10 Visual regression - `test/rendering/project_render_golden_test.dart`
Four goldens driven through `ProjectRenderer` itself, so a golden **is** an
export: all five bubble formats; compositing (shadow / rotation / opacity /
a multiply blend **over a backdrop**, without which the blend is
indistinguishable from normal); a photo grid proving border-as-fill, per-cell
clipping and the free layer on top; and captions, which pin the #79 auto-fit's
size and line count. Photo layers are avoided on purpose - an `ImageLayer` would
make the golden depend on a fixture file and an async decode.

`test/flutter_test_config.dart` swaps in a comparator with a **0.5%** pixel
tolerance, because a developer's Windows machine and CI's Linux differ by a few
anti-aliased pixels along curves and byte-exact goldens would teach everyone to
ignore failures. It is tight enough to bite: a 0.72→0.80 change to the shout
star's spike ratio produces a 3.72% diff. Regenerate with
`flutter test --update-goldens test/rendering` and **look at the PNGs** before
committing.

The file is `@Tags(['golden'])`, so CI's `flutter test --exclude-tags golden`
skips it - the policy `dart_test.yaml` has always documented. (ci.yml ran a bare
`flutter test` until the first golden was written, at which point the two would
have disagreed in the worst way.)

### 1.11 Accessibility - `test/a11y_test.dart`
`labeledTapTargetGuideline` over the editor (with layers + a selection, on the
Layers panel, and on the bubble panel), Home and All projects - pumped at
412x915 **with real insets**, because a zero-inset surface makes the guideline
skip edge-flush nodes and pass vacuously. Plus direct size assertions on the two
controls the audit named: the canvas delete handle (>=48dp) and each colour
swatch (>=40dp).

`androidTapTargetGuideline` is deliberately NOT applied wholesale - it also
fails the Export pill (37dp) and the editable project title (21dp), which are
the approved design.

### 1.8 Extend existing
- **`mask_mapper_test.dart`** (extend): rotation≠0 (un-rotate), layerScale≠1,
  non-square imageSize, top/bottom crops (dy), `boxSize` override, and
  **`radiusToMask`** (currently untested).
- **`smoke_test.dart`** (extend/`about_data_test.dart`): assert remaining
  `AboutInfo` fields, each `privacyHighlights` bullet, and per-category
  `licenseNotices` rows.

---

## Tier 2 - On-device BDD integration (`integration_test/bdd/`)

Gherkin `.feature` + `bdd_widget_test`-generated tests, run via `./e2e.ps1`.
**Written now, launched on device later.** Shared infra to add first:

- **`test/step/_e2e_support.dart`** (extend): add `preSeedPro()` - write
  `{"proEntitled":true,"onboardingSeen":true}` to
  `getApplicationDocumentsDirectory()/settings.json` **before** `app.main()`
  (opens the AI gate + skips onboarding); add `seedPhoto(tester)` -
  `storeBytes(rootBundle 'assets/branding/logo.png')` → `addImageLayer(assetPath:)`
  → `settle`.
- New "Given" steps: `the app is launched as Pro with a photo project`,
  `a photo layer is added`, etc.

### Feature files & scenarios
- **`app_launch.feature`** *(exists)* - cold start → Home.
- **`onboarding.feature`** - first-run shows page 1; Next advances to page 2/3;
  Get started → Home; Skip from page 1 → Home; (fresh settings each: needs a step
  that clears the seen-flag).
- **`home.feature`** - Home shows New project + empty Recent ("No projects yet");
  hamburger opens drawer; drawer "All projects" → All Projects screen; "About" →
  About sheet; New project → size sheet → editor.
- **`canvas_size.feature`** - size sheet presets set W×H; invalid (0 / <16 / >8192)
  disables Create; custom valid enables it; editor "Canvas size" resize + "Scale
  layers to fit".
- **`editor_layers.feature`** - Add text adds a `TextLayer`; Add bubble adds a
  `BubbleLayer`; Layers panel lists them; duplicate adds a copy; visibility toggle;
  delete removes; undo restores a deleted layer; redo re-deletes; delete-handle
  removes selected.
- **`editor_text.feature`** - add text, type a caption (assert `TextLayer.text`),
  pick a font (assert `fontFamily`), change size/color via provider state.
- **`export.feature`** - the save scenarios now assert **the image was saved to
  the device** (the `Saved · <location>` confirmation), not merely that nothing
  threw. `ExportScreen._save` catches everything and answers with a snack, so the
  old "no unhandled error occurred" passed on a device where saving never worked.
- **`editor_bubble.feature`** - the Bubble tool opens the format picker; each of
  the five formats can be created from it (outline over `BubbleShape.values`);
  dismissing it adds nothing; then change format (Speech→Thought), type text,
  set fill/outline colors - assert `BubbleLayer` state.
- **`editor_photo_adjust.feature`** *(seeded photo, Pro)* - brightness/contrast/
  saturation/hue/opacity/outline sliders update `ImageLayer.adjustments`/opacity/
  outlineWidth; Reset restores identity.
- **`editor_crop.feature`** *(seeded photo)* - `setImageCrop` state path: crop →
  `isCropped` true, "Edit crop"/"Reset crop" appear; Reset crop → full rect.
- **`editor_erase.feature`** *(seeded photo)* - Erase tool → canvas drag → a
  `maskPath` is set (pure-Dart brush, no gate); Restore mode.
- **`editor_ai_cut.feature`** *(seeded photo, Pro)* - AI Cut sheet → Remove
  background → a mask is applied (real on-device ML). *(Device-hardware dependent.)*
- **`editor_object_removal.feature`** *(seeded photo, Pro)* - object-removal tap
  paths + subject-guard toast + capability fallback. *(Hardware dependent.)*
- **`export.feature`** *(seeded photo, Pro)* - Export screen: format PNG/JPG/WebP,
  resolution chips update the output summary; Save renders bytes (assert no
  exception / a saved-location or a produced file).
- **`go_pro.feature`** - not-Pro shows Go Pro + Restore; drawer/About upsell
  visible; (Pro-seeded) upsell hidden, "You're Pro" shown.
- **`about.feature`** - drawer → Privacy screen (policy link, on-device banner);
  drawer → Licenses screen (category cards, "View full license texts").
- **`photo_grid.feature`** - a seeded collage opens on the Grid tool; layout /
  photo count / border sliders drive it; a collage exports. The collage is
  seeded through the controller because the create flow ends in the system
  photo picker (Tier 3).
- **`editor_effects.feature`** *(seeded photo)* - the Effects panel offers
  filter / HDR / vignette / shadow / blend; a filter applies, fades by
  strength, and can be taken back off; HDR + vignette; a shadow with
  direction/distance/blur/density; a contour; blend mode; Reset clears the lot;
  and a caption gets a shadow + outline of its own.
- **`editor_merge.feature`** - Merge down and Flatten are hidden with a single
  layer, fold a stack into one photo layer, and undo in a single step.
- **`tablet_layout.feature`** - resizes the VIEW either side of the 600-px
  breakpoint and asserts both branches on real hardware: a tablet in portrait
  gives the editor canvas the width while a phone keeps the 460 cap, Home pairs
  its start cards only on a tablet, and the tool panel still hugs its content.
  Runs on whatever device is attached, since it sets the size itself.
- **`editor_landscape.feature`** - rotating turns the dock into a vertical rail,
  the tool panel folds away and comes back, tools still work, and rotating back
  restores the horizontal bar. The rotation resizes the test surface rather than
  driving the real sensor - see the note in the feature.

**Run the suite in both orientations.** The device's own rotation decides how
the app lays out, so `adb shell settings put system user_rotation 1` and a
second pass is a genuinely different run - it is what found the overflowing
sheets, the drawer's lost footer, and three step definitions that only worked
because nothing had ever been below the fold.

---

## Tier 3 - Manual-only (documented, not automated)

- **System photo picker & camera** (`_pickPhoto` → image_picker) - real OS UI.
  This covers the Photo Grid create flow end to end (New project → Photo grid →
  count/layout/size → multi-pick fills the cells) and the tap-an-empty-cell
  import, both of which end in the picker.
- **Clipboard paste** (`_pastePhoto` → Pasteboard) - needs real clipboard image.
- **Effects on real photographs** - the automated coverage proves the controls
  drive the model and that preview and export agree; whether a look is *good*
  is a human call. `./tool/seed_device_photos.ps1` puts a spread of landscapes,
  animals and a low-light portrait in the device gallery for exactly that.
- **Generative Fill / MI-GAN** - no bundled `migan.onnx`; option hidden.
- **MobileSAM object removal on <3 GiB devices** - capability-denied by hardware.
- **Frames / animation UI** - exists in code but is **UI-unreachable** (no dock
  entry / no `setTool(frames)`); do not write E2E until product exposes it.
- **Real AdMob fill & UMP consent form** - test units + best-effort consent; the
  rewarded gate fail-opens in tests (so we pre-seed Pro instead).

---

## Execution

```bash
flutter test test/            # Tier 1 - host, no device, must be green
./e2e.ps1                      # Tier 2 - on the connected device (later)
```

CI note: Tier 1 is the CI gate (fast, deterministic, no device). Tier 2 is a
device/emulator job. Regenerate BDD tests after editing features:
`dart run build_runner build`.
