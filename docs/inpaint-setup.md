# Generative fill (MI-GAN inpaint) - optional model

Object removal has two modes: **Erase** (cuts the object to transparency - always
available) and **Fill (AI)** (replaces the object with synthesized background).
Fill needs a bundled **MI-GAN** ONNX model; without it the Fill toggle is hidden
and everything else works unchanged. The engine + wiring are already built
(`lib/features/segmentation/engines/inpaint/inpaint_engine.dart`) - this is a
drop-in asset step, like the AdMob ids and the release keystore.

> Not yet exercised on-device - verify the model + output on a real device
> before shipping Fill.

## 1. Obtain a permissively-licensed model

Bundle **only** MIT / BSD / Apache-2.0 / SIL-OFL (project licensing policy -
no GPL/LGPL, no CC-BY-NC). MI-GAN's code is MIT, but **check the specific
weights' license** before bundling - some inpainting checkpoints are trained on
non-commercial datasets. A `places2` MI-GAN checkpoint exported to ONNX is the
usual choice.

Export/convert to ONNX at **512×512** (the model's native resolution). A
conversion script belongs alongside `model_conversion/convert_mobile_sam.py`.

## 2. Match the tensor signature

The engine feeds exactly this (adjust the constants in `inpaint_engine.dart` if
your export differs - `_inputName`, `_outputName`, `_side`):

| Tensor | Name | Shape | Content |
|---|---|---|---|
| input | `input` | `[1, 4, 512, 512]` f32 | ch0 = `keep - 0.5` (keep: 1 outside the hole, 0 inside); ch1-3 = `rgb/127.5 - 1`, multiplied by `keep` |
| output | `output` | `[1, 3, 512, 512]` f32 | inpainted RGB in `[-1, 1]` |

The engine **letterboxes** the photo (fit-contain, centered) into the 512²
field so the model sees undistorted geometry, builds that input, runs the model,
then crops the fill back out of the letterbox and composites it over the
**full-resolution original** (only the filled area is resampled). The letterbox
geometry is covered by `test/inpaint_letterbox_test.dart`.

## 3. Install

1. Put the file at `assets/models/migan.onnx`.
2. Uncomment the `- assets/models/migan.onnx` line in `pubspec.yaml`.
3. `flutter pub get` and rebuild.
4. Add its license text to `lib/features/about/bundled_licenses.dart`.

`inpaintAvailableProvider` checks the asset manifest, so the **Fill** toggle
appears automatically once the model is bundled.

## Known refinements (do after the model works on-device)

- ~~**Aspect ratio**~~ - done. The photo is letterboxed (fit-contain) into the
  512 field so the model sees undistorted geometry; `_postprocess` crops the
  fill back out of the same letterbox. See `inpaintLetterbox` +
  `test/inpaint_letterbox_test.dart`.
- **Perf** - `_postprocess` decodes the source a second time and scans every
  pixel to composite. Decode once and clamp the composite to the region's
  bounding box if fill latency is a problem. It's a one-shot, gated action, so
  this is low priority until measured on-device.
