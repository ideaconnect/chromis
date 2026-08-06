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

Announcement-led rather than a story: what shipped, what is in it, what it
costs, where it is going. LinkedIn renders no markdown, so there is no bold and
no bullet glyph in the text below - the numbering and the line breaks are the
whole structure.

> Chromis 1.3.0 is out on Google Play.
>
> What's new:
>
> 1. Object removal now fills the background back in. The panel opens with a Fill in / Erase choice and Fill is the default. Two tiers sit behind that one word: a bundled generative model (MI-GAN, about 28 MB, MIT-licensed) runs first, and a pure-Dart content-aware fill catches what it can't. Which one ran is never shown — it was never a decision worth handing to anyone. The model is in the APK, so the fill needs no network and the photo has nowhere to go.
>
> 2. Snapping. Drag a layer and it settles onto the nearest edge or centre — of every other visible layer, and of the canvas — with a guide showing what it caught. It measures in the layer's own frame rather than in bounding boxes, so two layers tilted to the same angle come out genuinely flush instead of corner-adjacent. It's a toggle in Adjust, on by default.
>
> 3. Placement sliders for a caption or a speech bubble, not just a photo. Scale, Rotation, Horizontal, Vertical. The canvas hit box IS the layer, so a caption pinched down by accident was smaller than a finger, and with a photo underneath there was nothing left to grab.
>
> 4. Pure black and pure white surfaces. Dark is true black rather than a dark grey, so an OLED pixel that should be off is off, and light is pure white so it stays readable outdoors.
>
> The before/after above is real output rather than a mock-up: a lakeside tower viewer taken out, and the background rebuilt from the rest of the photo.
>
> Chromis is free and ad-supported, with one optional purchase that removes the ads and unlocks nothing else, because nothing else is locked. No account, on-device AI, nothing uploaded.
>
> It's a slow project with a stubborn goal: to become the best photo editor on Google Play. 1.3.0 is one step of that.
>
> https://play.google.com/store/apps/details?id=tech.idct.chromis
>
> \#Android #Flutter #OnDeviceAI #PhotoEditing #ComputerVision

**No hex codes in the body.** `#000000` reads as a hashtag on LinkedIn - it
would render as a link and drag the post into a nonsense feed. The line says
"true black" instead.

**A note on the link.** It is in the body because that is what was asked for.
LinkedIn does throttle reach on posts carrying an outbound link; the usual
workaround is to move it to the first comment and say "link in comments". If
reach matters more than the click being one tap away, do that instead - the
post reads fine with the last line removed.

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
