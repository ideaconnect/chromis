# LinkedIn post - Chromis 1.3.0

**Graphics** (generated, do not hand-edit - see `tool/gen_release_promo.py`):

| File | Use |
|---|---|
| `assets/store/social/linkedin-update-1-3-0.png` (1200x1200) | native image post - **use this one** |
| `assets/store/social/linkedin-update-1-3-0-landscape.png` (1200x628) | link share / OG card |

Both carry a real before/after produced by `tool/gen_fill_demo.py`, which runs
the app's own MobileSAM and MI-GAN with the app's own window, dilation, seam and
composite. Nothing in them is retouched and the photograph is CC0.

To regenerate (the first step is several minutes of CPU ONNX per tap):

```bash
python tool/gen_fill_demo.py --points 730,700 745,980 625,860   # -> fill-after.png
python tool/gen_release_promo.py                                # -> both graphics
```

The three taps are the head, the post and the handle of the tower viewer. One
tap selects one object, which is why it takes three - and why the caption says
so. `--preview` writes a contact sheet to `build/` showing what each tap grabbed.

**Post the square image natively and put the Play link in the FIRST COMMENT.**
LinkedIn suppresses reach on posts carrying an outbound link in the body.

---

## The post

> "Remove object" used to cut a transparent hole in the photo.
>
> People filed that as a bug. They were right — nobody taps "remove" and means "make a hole".
>
> Taking something out of a photo is two questions. *Which pixels* was answered a long time ago. *What goes there* never was.
>
> Chromis 1.3.0 answers it. The panel now opens with a choice — Fill in or Erase — and Fill is the default, because "remove object" means a closed background to nearly everyone who taps it.
>
> Behind that one word sit two tiers. A bundled generative model runs first, and a pure-Dart content-aware fill catches what it can't. Which one ran is never shown, because it was never a decision worth handing to anyone — and having a floor is what lets Fill be offered at all, rather than only on the devices where the big model is happy.
>
> The picture is the real output, not a mock-up. The head, the post and the handle of a lakeside tower viewer, taken out one at a time, and the background rebuilt from the rest of the photo.
>
> The model ships inside the app — MI-GAN, about 28 MB, MIT-licensed — so the fill needs no network and the photo has nowhere to go. That is the part I actually care about. "On-device AI" is easy to put in a store listing and hard for anyone to check; a model you can point at inside the APK is the version of it that can be checked.
>
> Two more things in this release, both closing bad states rather than adding features.
>
> Snapping. Drag a layer and it settles onto the nearest edge or centre — of every other visible layer, and of the canvas — with a guide showing what it caught. It measures in the layer's own frame rather than in bounding boxes, which is the only way two layers tilted to the same angle come out genuinely flush instead of merely corner-adjacent.
>
> Placement sliders for a caption or a speech bubble, not just a photo. The canvas hit box IS the layer, so a caption pinched down by accident was smaller than a finger — and with a photo underneath it, there was nothing left to grab. A slider doesn't care how big the layer is.
>
> Free and ad-supported on Google Play. Link in the first comment.
>
> \#Android #Flutter #OnDeviceAI #PhotoEditing #ComputerVision

**First comment:**

> https://play.google.com/store/apps/details?id=tech.idct.chromis

---

## What was deliberately left out, and why

An adversarial pass over four independent drafts found the same failure modes in
all of them. Each of these is a claim the app does not support, and every one is
checkable by a reader:

- **The light theme and the six languages are NOT 1.3.0.** Both shipped in 1.2.0
  (`d8aba79`). Three of the four drafts listed them under "what's new", which is
  the one error here a real user could catch. What 1.3.0 did to the theme is
  make every screen-covering surface pure `#000000` / `#FFFFFF` (`06a777a`) -
  a smaller claim, and the one the graphic's chip now makes.
- **"Sliders for every layer" is an overclaim.** A photo filling a grid cell is
  clamped to cover its cell and gets none of the four. The post says "a caption
  or a speech bubble, not just a photo", which is the actual change.
- **"A guide drawn on whatever it caught" is only true of edges and centres.** A
  size or angle match has no line to draw - the canvas outlines the other layer
  instead. The post is scoped to "the nearest edge or centre".
- **The content-aware fill always RUNS; it does not always succeed.** A fill it
  cannot do returns null and the editor falls back to erasing and says so. The
  post says it "catches what it can't", not that it never fails.
- **The first segmentation tier is a connected component, not a model.** A draft
  that said "tap the thing, a segmentation model finds its outline" skipped the
  free tier. The post does not describe the ladder at all.
- **No adoption numbers, no "10x", no launch theatre.** 1.3.0 is an update to a
  live app, and none of the drafts had a real metric to quote.
- **No tap count, and no "try it in flight mode".** This one nearly shipped.
  Object removal sits behind the shared AI ad gate - `_ensureAiAllowed` at
  `lib/features/editor/editor_screen.dart:3277` - so on a free install the first
  AI action of a session opens a "watch a short ad / Go Pro" sheet, and a user
  who has declined ad consent is blocked outright rather than merely delayed.
  "Three taps, in flight mode" therefore describes a **Pro** session, and it
  invites exactly the reader most likely to test it - someone who installs
  because of the post - to meet an ad sheet in the middle of the demonstration.
  The post and both graphics now say where the work happens, which is
  unconditionally true, and count nothing.

**One unit to be aware of:** `assets/models/migan.onnx` is 28,026,346 bytes -
26.7 MiB, but **28.0 MB decimal**, which is what Play and a file manager report.
`CLAUDE.md`, `docs/release/1.3.0.md`, `pubspec.yaml` and `docs/inpaint-setup.md`
all say "26.7 MB", which
conflates the two. The post says "about 28 MB" so a reader who checks the store
sees the same number. Worth reconciling in the repo separately.

**Two things to check before posting, neither of them in the copy:**

- **Is 1.3.0 actually live on Play?** `pubspec.yaml` says `1.3.0+6` and the
  what's-new text exists, but nothing in the repo records the rollout state.
- **A stale comment contradicts the post, in the repo's favour.**
  `lib/features/editor/editor_screen.dart:3442-3444` still calls MI-GAN "an
  OPTIONAL bundled model … absent from the shipped app". It is bundled
  (`pubspec.yaml`) and committed. The post is right and the comment is out of
  date; worth fixing so the two stop disagreeing.
