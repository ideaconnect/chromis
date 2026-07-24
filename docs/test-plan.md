# Test Plan — Photo Editor AI

Extensive coverage across **all features and all paths**, derived from a full
codebase survey. Organized into three tiers by how a test must run.

## Tiers

| Tier | Where it runs | Command | In this pass |
|---|---|---|---|
| **1. Host unit/widget** | Host VM (no device) | `flutter test test/` | **Write + run green now** |
| **2. On-device BDD** | Real Android device | `./e2e.ps1` | **Write now, run on device later** (per instruction) |
| **3. Manual-only** | Human + real hardware | — | Documented, not automated |

Finder conventions (Tier 2): the app has almost no `Key`s, so `find.text('<label>')`
is the primary finder (`GradientButton`/`PillChip`/`dockButton` all render a visible
`Text`). Toasts (`showSmToast`) are transient (~1.5s) — assert app/provider **state**
rather than toast text where possible. `pumpAndSettle` hangs (splash spinner / banner
slot) → use the fixed-frame `settle(tester)` helper.

---

## Tier 1 — Host unit/widget tests (device-free)

Runnable now with `flutter test test/`. None require a real image file (the
`EditorController` never opens `assetPath` — a fake path string suffices);
persistence uses an injected temp `baseDir`; plugin-backed classes use fakes.

### 1.1 Models — `test/models/`
- **`layer_test.dart`** — `ImageLayer`/`TextLayer`/`BubbleLayer`:
  `copyWith` per field; `toJson`→`fromJson` round-trip (incl. `crop` list,
  `outlineColor`/`color`/`fill`/`stroke`/`text` colors via `toARGB32`, bubble
  `shape.name`, `tailDx/Dy`); `fromJson` defaults (missing visible/opacity/
  adjustments/outline → identity; `_cropFromJson` missing/invalid → full rect;
  bubble unknown shape → `speech`); `copyWith(clearMask:true)` wins over
  `maskPath`; `isCropped`/`hasOutline`; `==`/`hashCode` sensitivity (cropRect,
  adjustments, transform, colors, maskPath); `Layer.fromJson` dispatch + unknown
  type → `FormatException`.
- **`project_test.dart`** — `Project.empty` clamps dims (8→16, 10000→8192) and
  sets one frame; `canvasCenter`/`canvasAspect`/`safeFrameIndex` clamp; JSON
  round-trip incl. ISO dates; migration: v1 (no version/dims) → 512² legacy;
  `version>schemaVersion` → `FormatException`; `fps` clamp; bad dates → null;
  the min/max/default constants.
- **`frame_test.dart`** — `copyWith`, JSON round-trip mixed layers, order-
  sensitive `==`/`hashCode`, default `const []`.
- **`layer_transform_test.dart`** — `identity`, `copyWith`, JSON round-trip,
  `==`/`hashCode`, `fromJson` requires all keys.
- **`image_adjustments_test.dart`** — `identity`/`isIdentity`, `copyWith`, JSON
  round-trip + defaults, `==`/`hashCode`.

### 1.2 Rendering — `test/rendering/color_matrix_test.dart`
`ColorMatrix.identity`; `brightness(1)`/`contrast(1)`/`saturation(1)`/`hueRotate(0)`
≈ identity; `contrast` translation `t=127.5*(1-c)`; `saturation(0)` = Rec.709
greyscale rows; `multiply(identity, m)==m`; `ImageAdjustmentsMatrix.toColorMatrix`
identity short-circuit + fixed compose order (brightness∘contrast∘saturation∘hue).

### 1.3 Mask pipeline — `test/segmentation/`
- **`alpha_mask_test.dart`** — constructor asserts; `filled` clamps 0..255;
  `empty` all-0; `at(x,y)` row-major; `coverage(cutoff)` fraction; `copyWith`;
  `==`/`hashCode`.
- **`mask_brush_test.dart`** — empty points / `radius<=0` → unchanged; hard brush
  sets target (0 erase / 255 restore); soft brush monotonic toward target
  (overlapping dabs don't fight); `_densify` midpoints; edge clamping.
- **`mask_processing_test.dart`** — `threshold`, `feather` (radius<=0 no-op,
  border-clamped), `keepLargestComponent` (4-conn BFS, all-below → empty),
  `subtract` = min(a,255-b) + size assert, **`removeObjectAt` three outcomes**
  (`miss`/`subject`/`removed`), `process` chain order.
- **`mask_tensor_test.dart`** — `packTensor` NCHW `((px/255)-mean)/std` planar +
  length assert; `unpackMask` low-range guard branch (flat→uniform by mean) vs
  min-max normalize + bilinear upscale + quantize; `ModelConfig` defaults.
- **`mask_store_test.dart`** — `encodePng`↔`decodeAlpha` round-trip (alpha
  preserved); `SupersededMaskCollector` queue/collect (deletes only unreferenced).
  *(needs `TestWidgetsFlutterBinding` for `dart:ui`, still host-only.)*

### 1.4 Bubble geometry — `test/editor/bubble_view_test.dart`
`kBubbleBaseSize`; `bubbleBodyRect` insets; `bubbleTailTip`↔`bubbleTailFromLocal`
inverse within clamp; `bubbleCaptionMaxLines` (fontSize/height<=0 → 1);
`bubbleFitFontSize` (fits → maxSize; oversize → shrinks toward 6.0). *(TextPainter
paths need the test binding.)*

### 1.5 Editor controller — `test/editor/editor_controller_test.dart`
Via `ProviderContainer` + `loadProject(Project.empty(...))`, fake asset paths:
- Add: `addTextLayer`/`addBubbleLayer`(name rule)/`addEmoji`/`addImageLayer`
  (auto-name "Photo","Photo 2", cascade offset) — all select the new layer.
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

### 1.6 Persistence — `test/persistence/`
- **`project_repository_test.dart`** — `ProjectRepository(baseDir: tmp)`:
  save↔load round-trip, atomic `.json.tmp`, `list()` recency sort, corrupt
  manifest → `.json.corrupt` quarantine (skipped), `load(missing)`→null,
  `duplicate` (fresh ids, `<name> copy`, shared asset paths), `delete`,
  `sweepOrphanAssets(Duration.zero)` (deletes only unreferenced `img_*`/`mask_*`;
  aborts if any manifest unparseable / `.corrupt` present; young files kept).
- **`settings_store_test.dart`** — `SettingsStore(baseDir: tmp)`: onboardingSeen
  default false→persist true; segmentationModelId null→persist; proEntitled;
  corrupt `settings.json` → treated as `{}` (never throws).

### 1.7 Config / registry / entitlement — `test/config/`
- **`ads_config_test.dart`** — `useTestAds==true` → banner/interstitial/rewarded
  return the Google test ids.
- **`bundled_licenses_test.dart`** — `registerBundledLicenses(fakeBundle)` yields
  one `LicenseEntryWithLineBreaks` per entry; 6 fonts + 2 AI-model Apache assets;
  no GPL/CC-BY-NC (complements the existing about_data license test).
- **`seg_model_test.dart`** — `SegModel.fromId`/`fromEngineId` mappings + unknown
  fallbacks; enum data.
- **`segmentation_registry_test.dart`** — fake engines: `resolve` prioritizes
  `preferredId`, returns first available; `segment` falls through on
  `SegmentationException`, null when none available.
- **`ai_capability_test.dart`** — fake `platformServicesProvider.memoryInfo`:
  null→allowed; lowRam→denied; <3 GiB→denied (GiB reason); else allowed.
- **`entitlement_test.dart`** — `EntitlementController.grant()` idempotent +
  persists (fake settings store); `IapService.loadProduct` null on empty list
  (fake `InAppPurchase`).

### 1.8 Extend existing
- **`mask_mapper_test.dart`** (extend): rotation≠0 (un-rotate), layerScale≠1,
  non-square imageSize, top/bottom crops (dy), `boxSize` override, and
  **`radiusToMask`** (currently untested).
- **`smoke_test.dart`** (extend/`about_data_test.dart`): assert remaining
  `AboutInfo` fields, each `privacyHighlights` bullet, and per-category
  `licenseNotices` rows.

---

## Tier 2 — On-device BDD integration (`integration_test/bdd/`)

Gherkin `.feature` + `bdd_widget_test`-generated tests, run via `./e2e.ps1`.
**Written now, launched on device later.** Shared infra to add first:

- **`test/step/_e2e_support.dart`** (extend): add `preSeedPro()` — write
  `{"proEntitled":true,"onboardingSeen":true}` to
  `getApplicationDocumentsDirectory()/settings.json` **before** `app.main()`
  (opens the AI gate + skips onboarding); add `seedPhoto(tester)` —
  `storeBytes(rootBundle 'assets/branding/logo.png')` → `addImageLayer(assetPath:)`
  → `settle`.
- New "Given" steps: `the app is launched as Pro with a photo project`,
  `a photo layer is added`, etc.

### Feature files & scenarios
- **`app_launch.feature`** *(exists)* — cold start → Home.
- **`onboarding.feature`** — first-run shows page 1; Next advances to page 2/3;
  Get started → Home; Skip from page 1 → Home; (fresh settings each: needs a step
  that clears the seen-flag).
- **`home.feature`** — Home shows New project + empty Recent ("No projects yet");
  hamburger opens drawer; drawer "All projects" → All Projects screen; "About" →
  About sheet; New project → size sheet → editor.
- **`canvas_size.feature`** — size sheet presets set W×H; invalid (0 / <16 / >8192)
  disables Create; custom valid enables it; editor "Canvas size" resize + "Scale
  layers to fit".
- **`editor_layers.feature`** — Add text adds a `TextLayer`; Add bubble adds a
  `BubbleLayer`; Layers panel lists them; duplicate adds a copy; visibility toggle;
  delete removes; undo restores a deleted layer; redo re-deletes; delete-handle
  removes selected.
- **`editor_text.feature`** — add text, type a caption (assert `TextLayer.text`),
  pick a font (assert `fontFamily`), change size/color via provider state.
- **`editor_bubble.feature`** — add bubble, set shape (Speech→Thought), type text,
  set fill/outline colors — assert `BubbleLayer` state.
- **`editor_photo_adjust.feature`** *(seeded photo, Pro)* — brightness/contrast/
  saturation/hue/opacity/outline sliders update `ImageLayer.adjustments`/opacity/
  outlineWidth; Reset restores identity.
- **`editor_crop.feature`** *(seeded photo)* — `setImageCrop` state path: crop →
  `isCropped` true, "Edit crop"/"Reset crop" appear; Reset crop → full rect.
- **`editor_erase.feature`** *(seeded photo)* — Erase tool → canvas drag → a
  `maskPath` is set (pure-Dart brush, no gate); Restore mode.
- **`editor_ai_cut.feature`** *(seeded photo, Pro)* — AI Cut sheet → Remove
  background → a mask is applied (real on-device ML). *(Device-hardware dependent.)*
- **`editor_object_removal.feature`** *(seeded photo, Pro)* — object-removal tap
  paths + subject-guard toast + capability fallback. *(Hardware dependent.)*
- **`export.feature`** *(seeded photo, Pro)* — Export screen: format PNG/JPG/WebP,
  resolution chips update the output summary; Save renders bytes (assert no
  exception / a saved-location or a produced file).
- **`go_pro.feature`** — not-Pro shows Go Pro + Restore; drawer/About upsell
  visible; (Pro-seeded) upsell hidden, "You're Pro" shown.
- **`about.feature`** — drawer → Privacy screen (policy link, on-device banner);
  drawer → Licenses screen (category cards, "View full license texts").

---

## Tier 3 — Manual-only (documented, not automated)

- **System photo picker & camera** (`_pickPhoto` → image_picker) — real OS UI.
- **Clipboard paste** (`_pastePhoto` → Pasteboard) — needs real clipboard image.
- **Generative Fill / MI-GAN** — no bundled `migan.onnx`; option hidden.
- **MobileSAM object removal on <3 GiB devices** — capability-denied by hardware.
- **Frames / animation UI** — exists in code but is **UI-unreachable** (no dock
  entry / no `setTool(frames)`); do not write E2E until product exposes it.
- **Real AdMob fill & UMP consent form** — test units + best-effort consent; the
  rewarded gate fail-opens in tests (so we pre-seed Pro instead).

---

## Execution

```bash
flutter test test/            # Tier 1 — host, no device, must be green
./e2e.ps1                      # Tier 2 — on the connected device (later)
```

CI note: Tier 1 is the CI gate (fast, deterministic, no device). Tier 2 is a
device/emulator job. Regenerate BDD tests after editing features:
`dart run build_runner build`.
