# Object removal: the two fill tiers

Removing an object asks a question before it asks anything else: what should be
*there* afterwards? The cut-out tool's Remove-object mode makes that an explicit
choice, shown before the tap that acts on it:

- **Fill in** (default) - the background is rebuilt over the object.
- **Erase** - the object is cut out to transparency, leaving a hole.

Erase is the original behaviour and is still one tap away. It was for a long
time the ONLY behaviour, because the chooser was built behind a model no shipped
build bundled - see "How it got this way" below.

## The two fill tiers

`_tryInpaint` (editor_screen.dart) tries them in order and takes the first
non-null result:

| Tier | File | Bundled? | What it does |
|---|---|---|---|
| Generative | `engines/inpaint/inpaint_engine.dart` | MI-GAN ONNX, 26.7 MB | Synthesizes plausible new content |
| Content-aware | `engines/inpaint/content_fill_engine.dart` | Always - pure Dart | Rebuilds from texture the photo already contains |

Content-aware fill is the FLOOR, not the answer: it is what makes Fill safe to
offer unconditionally - no asset to be missing, no ONNX runtime to fail on - so
the feature degrades instead of disappearing. The generative tier is what makes
it good. It is PatchMatch (Barnes et al. 2009) driving Wexler-style coarse-to-fine
patch voting - `engines/inpaint/patch_match.dart`, pure byte arrays in and out so
it runs inside `Isolate.run` and is unit-testable without decoding an image.

It only ever copies what is already in the frame. Grass, sky, sand, a wall, a
carpet - the cases people actually shoot - come back seamless; a structure that
had to be *invented* (a face behind the object, a continuing straight line) comes
back as coherent texture rather than as the right answer. That is a fair trade
for a tier that always runs, and it is the reason MI-GAN stays worth bundling.

### Why the fill runs on a window

`ContentFillEngine` fills a **crop around the object**, not the whole photo:
the object's bounding box plus 75% of its longer side as context, downscaled
only if that exceeds 512 px (`contentFillWindow`, covered by
`test/segmentation/content_fill_test.dart`).

This is the difference between a patch and a smudge: a small object stays at
native resolution, and matching locally finds better patches anyway - the
texture right next to the object is what should replace it.

The generative tier does NOT do this yet: `_preprocess` letterboxes the whole
photo into 512², so a person filling 7% of a 2048 px frame is synthesized ~64 px
wide. Cropping a window first measures at 90 px for the same ~530 ms - a real
+40% and an obvious follow-up, but the whole-photo path already looks good, so
it is an improvement rather than a defect.

The composite is weighted, not a hard swap: the region synthesized runs one blur
radius wider than the region weighted at full strength, so the seam fades into
clean photo rather than back into the object's own colour fringe. Everything
outside the window is untouched byte for byte.

### What it costs

Measured by `integration_test/content_fill_device_test.dart`, which prints a
breakdown, on an x86_64 Android 17 emulator in a **debug** build - so these are
an upper bound, not the shipping figure: debug Dart is JIT'd with bounds checks
everywhere, and a release AOT build on ARM runs this kind of typed-data loop
several times faster.

Filling a 90 px object in a 1600×1200 photo, warm:

| | before | after |
|---|---|---|
| PNG decode + encode | ~1.6 s | ~1.3 s |
| patch search + composite | 5.3 s | **2.4 s** |
| total | 6.9 s | **3.7 s** |

The halving is one change: `_patchDistance` no longer calls `clamp()`. It is
declared on `num`, so its result is **boxed even when every argument is an
`int`** - and that call sat in the innermost loop of the patch search, running
a few hundred thousand times per pyramid level. A target patch entirely inside
the image now needs no bounds work at all and walks both patches on a running
offset; only a patch hanging off an edge clamps, with comparisons.

Worth knowing before optimising further: the FIRST fill in a process is
noticeably slower than the rest (8.8 s against 3.7 s here) because it pays JIT
warm-up for the whole search. Measure the second one.

### When it refuses

`fill` returns null when nothing is marked, or when the window is over 90% hole -
there is no known texture left to rebuild from, and a uniform blur is not a fill.
The editor then erases instead and says so (`fillUnavailable`). A refusal is a
result, not a failure.

## How it got this way

The Fill/Erase chooser was written with the MI-GAN tier and gated on
`inpaintAvailableProvider`, an asset-manifest check for `assets/models/migan.onnx`.
That asset has never shipped, so the branch was dead: every tap erased the object
to a transparent hole, with nothing on screen saying which of the two things
"Remove object" was about to do. People read the hole as a broken fill and
reported it as one.

Two things were wrong and both are fixed: the feature is no longer *conditional*
on an optional asset (there is now an unconditional tier under it), and the
choice is no longer *invisible* (the chooser and its one-line explainer are
always built). `test/editor/object_fill_mode_test.dart` is the coverage whose
absence let a dead branch ship - the panel renders fine either way, and no test
had ever entered the mode.

## The MI-GAN tier, as bundled

`assets/models/migan.onnx` (26.7 MB) is produced by
`model_conversion/convert_migan.py` from `migan_512_places2.pt`. See
`model_conversion/README.md` for provenance, both sha256s, and the reproduce
step. **Nothing in the UI changes when it is present** - the tier is an
implementation detail of "Fill in", not a mode anyone picks, which is why
`inpaintAvailableProvider` gates it silently.

### Licensing: the concrete rule

The old wording here said "check the specific weights' license… some
checkpoints are trained on non-commercial datasets", which is true and
unactionable. The rule that actually decides it:

- **An unmodified permissive licence with no carve-out covers the weights the
  authors distribute under it.** MI-GAN is MIT (© 2024 Picsart AI Research),
  the LICENSE has no scope limitation, and the README ships the checkpoints
  with no separate terms. That is a grant.
- **The training dataset is a disclosed, accepted risk, not a veto.** Places2's
  own terms say research/education. Reading that as encumbering the weights
  would also disqualify **MobileSAM**, which this app already ships and which
  Meta licenses Apache-2.0 despite SA-1B being research-only. The app cannot
  hold both positions; it holds this one.
- **`places2` ships. `ffhq` and CelebA-HQ never do.** FFHQ is CC BY-NC-SA 4.0
  outright and CelebA's agreement reaches "any portion of derived data", which
  is written to catch weights. `migan_256_ffhq.pt` is in the same download
  folder and is the checkpoint a search for "person removal" surfaces first -
  it is the single most likely way to get this wrong.

### The tensor signature

`convert_migan.py` asserts all of this at export time, because a mismatch is
silent - `InpaintEngine` catches broadly and the app just quietly serves
content-aware fill instead.

| Tensor | Name | Shape | Content |
|---|---|---|---|
| input | `input` | `[1, 4, 512, 512]` f32 | ch0 = `keep - 0.5` (keep: 1 outside the hole, 0 inside); ch1-3 = `rgb/127.5 - 1`, multiplied by `keep` |
| output | `output` | `[1, 3, 512, 512]` f32 | inpainted RGB in `[-1, 1]` |

This matches upstream's own `scripts/export_inference_model.py`
(`x = cat([mask - 0.5, img * mask])` with `img = (ToTensor() - 0.5) * 2`,
decoded `* 127.5 + 127.5`) exactly. **Do not "fix" either half independently.**

The engine **letterboxes** the photo (fit-contain, centered) into the 512²
field so the model sees undistorted geometry, then crops the fill back out and
composites it over the **full-resolution original** (only the filled area is
resampled). Covered by `test/inpaint_letterbox_test.dart`.

### What it is worth

Measured against the content-aware tier on the same photo and the same mask, a
tall person-shaped hole: PatchMatch pastes a slab of grass through the subject
and leaves a hard-edged rectangle; MI-GAN reconstructs the body, the collar and
the rock underneath seamlessly. This is not a marginal upgrade - it is the
difference between "why is it broken" and "I cannot tell anything was removed".
Desktop CPU inference is ~600 ms at 512².

## Known refinements

- **Content-aware fill perf** - the boxing in `_patchDistance` is gone (see
  "What it costs"); what is left is `_vote` allocating its accumulators fresh
  per EM sweep. Everything past that trades quality for speed - fewer sweeps at
  the finest level, or a subsampled patch - so it wants a real-photo quality
  signal first, not another synthetic measurement.
- **MI-GAN perf** - `_postprocess` decodes the source a second time and scans
  every pixel to composite. Decode once and clamp the composite to the region's
  bounding box if fill latency is a problem.
- ~~**Aspect ratio**~~ - done. The photo is letterboxed (fit-contain) into the
  512 field so the model sees undistorted geometry; `_postprocess` crops the
  fill back out of the same letterbox. See `inpaintLetterbox` +
  `test/inpaint_letterbox_test.dart`.
