"""Run the app's OWN object-removal pipeline offline, for the promo art.

The 1.3.0 headline is that removing an object rebuilds the background behind it,
and the only honest way to put that in a graphic is to show a real result. So
this does what the app does, with the app's bundled models and the app's
numbers: a tap goes to MobileSAM, its mask goes to MI-GAN, and MI-GAN's fill is
composited back over the full-resolution photo.

**This is a PORT, not a re-imagining.** Every constant here is read off
`lib/features/segmentation/engines/inpaint/inpaint_engine.dart` and
`.../object/mobile_sam_engine.dart`, and the comments name the Dart it mirrors.
If the Dart changes, this drifts silently - the guard against that is that the
output is checked in and a regeneration that looks different is visible in the
diff.

Three things that are easy to get wrong, all of them load-bearing in the app:

- **The mask is DILATED before the model sees it.** A segmentation boundary is a
  blend of object and background and `alpha > 128` cuts inside it, so the raw
  mask leaves a rim of the object in the visible context; the model conditions
  on that rim and synthesises the hole in the object's own colour. `_GUARD`.
- **The model sees a WINDOW, not the whole photo.** At a fixed 512² input, a
  small object in a big frame would be synthesised a few dozen pixels wide and
  blown back up. The window is the object's bbox plus half its longer side.
- **The way back up is CUBIC.** `copyResize` defaults to nearest, and this is an
  upscale from 512 to the window's real size - nearest is what "the fill is
  terrible quality" actually was.

The photo is `assets/store/samples/landscape.jpg`, CC0 from Wikimedia Commons
and recorded in that directory's SOURCES.json - the same frame the Play
listing's Effects shot uses. A promo graphic is commercial use of every pixel in
it, exactly as a listing is.

    python tool/gen_fill_demo.py [--point X Y] [--preview]

Out: assets/store/social/fill-before.png, fill-after.png (and, with --preview,
a side-by-side contact sheet in build/ for checking the tap landed).
"""

from __future__ import annotations

import argparse
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.getcwd()
SAMPLES = os.path.join(ROOT, "assets", "store", "samples")
MODELS = os.path.join(ROOT, "assets", "models")
OUT = os.path.join(ROOT, "assets", "store", "social")

# --- constants ported from the Dart -----------------------------------------
SAM_SIDE = 1024        # mobile_sam_engine.dart: inputSide
LOW_RES = 256          # mobile_sam_engine.dart: lowResSide
MIGAN_SIDE = 512       # inpaint_engine.dart: _side
WINDOW_MARGIN = 0.5    # inpaint_engine.dart: _windowMargin
GUARD = 4              # inpaint_engine.dart: _guard
SEAM = 3               # inpaint_engine.dart: _seam

# Where the finger lands, in source-image pixels. The tower viewer in the
# foreground of the lake photo: a real object, in front of the background it
# has to be rebuilt from, which is the case the feature exists for.
DEFAULT_POINT = (786, 812)


def _session(name: str):
    import onnxruntime as ort

    path = os.path.join(MODELS, name)
    if not os.path.exists(path):
        sys.exit("missing %s - the bundled models are committed, is this a full clone?" % path)
    return ort.InferenceSession(path, providers=["CPUExecutionProvider"])


# --------------------------------------------------------------- MobileSAM
def sam_mask(img: Image.Image, point: tuple[int, int]) -> np.ndarray:
    """The app's tap-to-select: encoder once, decoder on one positive point.

    Mirrors `MobileSamEngine._prepareInput` / `_decode`: the photo is resized so
    its LONGEST side is 1024 (no padding is fed - the export takes a dynamic
    HWC), the prompt is expressed in that resized frame, and the 256² logit grid
    is bilinearly sampled back up with `logit > 0` as the cut.
    """
    src_w, src_h = img.size
    scale = SAM_SIDE / max(src_w, src_h)
    rw = max(1, min(SAM_SIDE, round(src_w * scale)))
    rh = max(1, min(SAM_SIDE, round(src_h * scale)))
    resized = img.resize((rw, rh), Image.BILINEAR)

    enc = _session("mobile_sam_encoder.onnx")
    hwc = np.asarray(resized, dtype=np.float32)  # normalization is baked in
    emb = enc.run(["image_embeddings"], {"input_image": hwc})[0]

    dec = _session("mobile_sam_decoder.onnx")
    # Prompt coords live in the RESIZED frame (mobile_sam_engine.dart:123).
    px, py = point[0] * scale, point[1] * scale
    out = dec.run(
        ["low_res_masks"],
        {
            "image_embeddings": emb.astype(np.float32),
            "point_coords": np.array([[[px, py]]], dtype=np.float32),
            "point_labels": np.array([[1]], dtype=np.float32),
            "mask_input": np.zeros((1, 1, LOW_RES, LOW_RES), dtype=np.float32),
            "has_mask_input": np.array([0], dtype=np.float32),
            "orig_im_size": np.array([rh, rw], dtype=np.float32),
        },
    )[0]
    logits = np.asarray(out).reshape(LOW_RES, LOW_RES)

    # The logit grid maps the PADDED 1024² frame, so only its top-left
    # (resized/4) region is valid (mobile_sam_engine.dart:458).
    vu = rw / 4.0
    vv = rh / 4.0
    ys = np.linspace(0, vv - 1, src_h, dtype=np.float32)
    xs = np.linspace(0, vu - 1, src_w, dtype=np.float32)
    y0 = np.clip(np.floor(ys).astype(int), 0, LOW_RES - 1)
    y1 = np.clip(y0 + 1, 0, LOW_RES - 1)
    x0 = np.clip(np.floor(xs).astype(int), 0, LOW_RES - 1)
    x1 = np.clip(x0 + 1, 0, LOW_RES - 1)
    fy = (ys - y0)[:, None]
    fx = (xs - x0)[None, :]
    top = logits[np.ix_(y0, x0)] * (1 - fx) + logits[np.ix_(y0, x1)] * fx
    bot = logits[np.ix_(y1, x0)] * (1 - fx) + logits[np.ix_(y1, x1)] * fx
    return ((top * (1 - fy) + bot * fy) > 0).astype(np.uint8)


# ------------------------------------------------------------------ MI-GAN
def _letterbox(w: int, h: int):
    """inpaint_engine.dart: inpaintLetterbox - fit-contain in the 512 field."""
    scale = MIGAN_SIDE / max(w, h)
    lw = max(1, min(MIGAN_SIDE, round(w * scale)))
    lh = max(1, min(MIGAN_SIDE, round(h * scale)))
    return ((MIGAN_SIDE - lw) // 2, (MIGAN_SIDE - lh) // 2, lw, lh)


def _window(iw: int, ih: int, bx: int, by: int, bw: int, bh: int):
    """inpaint_engine.dart: inpaintWindow - a square-ish crop around the object."""
    longer = max(bw, bh)
    side = min(longer + 2 * round(longer * WINDOW_MARGIN), iw, ih)
    cx, cy = bx + bw // 2, by + bh // 2
    x = min(max(cx - side // 2, 0), iw - side)
    y = min(max(cy - side // 2, 0), ih - side)
    return x, y, side, side


def _dilate(mask: np.ndarray, radius: int) -> np.ndarray:
    """Square dilation, separable - the Dart's `_dilate`."""
    if radius <= 0:
        return mask
    k = 2 * radius + 1
    pad = np.pad(mask, radius, mode="constant")
    out = np.zeros_like(mask)
    for dy in range(k):
        for dx in range(k):
            out |= pad[dy:dy + mask.shape[0], dx:dx + mask.shape[1]]
    return out


def _blur(mask: np.ndarray, radius: int) -> np.ndarray:
    """Separable box blur of a 0/1 mask into 0…255 weights - the Dart's `_blur`."""
    k = 2 * radius + 1
    m = (mask != 0).astype(np.float32) * 255.0
    pad = np.pad(m, ((0, 0), (radius, radius)), mode="edge")
    tmp = np.floor(sum(pad[:, i:i + m.shape[1]] for i in range(k)) / k)
    pad = np.pad(tmp, ((radius, radius), (0, 0)), mode="edge")
    out = np.floor(sum(pad[i:i + m.shape[0], :] for i in range(k)) / k)
    return np.clip(out, 0, 255).astype(np.uint8)


def fill(img: Image.Image, mask: np.ndarray) -> Image.Image:
    """Run MI-GAN and composite it back, exactly as `InpaintEngine` does."""
    w, h = img.size
    ys, xs = np.nonzero(mask)
    if len(xs) == 0:
        sys.exit("the tap selected nothing - move --point onto the object")
    bx, by = int(xs.min()), int(ys.min())
    bw, bh = int(xs.max()) - bx + 1, int(ys.max()) - by + 1
    wx, wy, ww, wh = _window(w, h, bx, by, bw, bh)

    crop = img.crop((wx, wy, wx + ww, wy + wh))
    lx, ly, lw, lh = _letterbox(ww, wh)
    fitted = np.asarray(crop.resize((lw, lh), Image.BOX), dtype=np.uint8)

    # Sample the mask into the 512 field FIRST, so it is grown before anything
    # conditions on it (inpaint_engine.dart:226).
    raw = np.zeros((MIGAN_SIDE, MIGAN_SIDE), np.uint8)
    yy = (wy + (np.arange(lh) * wh) // lh).clip(0, h - 1)
    xx = (wx + (np.arange(lw) * ww) // lw).clip(0, w - 1)
    raw[ly:ly + lh, lx:lx + lw] = mask[np.ix_(yy, xx)]

    hole = _dilate(raw, GUARD + 2 * SEAM)
    weight = _blur(_dilate(raw, GUARD + SEAM), SEAM)

    # Edge-replicate outside the window so padding is neutral known context.
    field = np.zeros((MIGAN_SIDE, MIGAN_SIDE, 3), np.uint8)
    gy = np.clip(np.arange(MIGAN_SIDE) - ly, 0, lh - 1)
    gx = np.clip(np.arange(MIGAN_SIDE) - lx, 0, lw - 1)
    field[:] = fitted[np.ix_(gy, gx)]

    keep = (hole == 0).astype(np.float32)
    rgb = (field.astype(np.float32) / 127.5 - 1.0) * keep[..., None]
    inp = np.concatenate([(keep - 0.5)[..., None], rgb], axis=2)
    inp = np.transpose(inp, (2, 0, 1))[None].astype(np.float32)

    out = _session("migan.onnx").run(["output"], {"input": inp})[0]
    synth = np.clip((np.transpose(out[0], (1, 2, 0)) + 1.0) * 127.5, 0, 255).astype(np.uint8)

    # Crop back to the letterboxed area, then CUBIC up to the window.
    filled = Image.fromarray(synth[ly:ly + lh, lx:lx + lw]).resize(
        (ww, wh), Image.BICUBIC
    )

    base = np.asarray(img.convert("RGB"), dtype=np.float32).copy()
    fw = np.asarray(filled, dtype=np.float32)
    # Full-res window pixel -> the 512 field the weight lives in.
    my = np.clip(ly + (np.arange(wh) * lh) // wh, 0, MIGAN_SIDE - 1)
    mx = np.clip(lx + (np.arange(ww) * lw) // ww, 0, MIGAN_SIDE - 1)
    a = (weight[np.ix_(my, mx)].astype(np.float32) / 255.0)[..., None]
    region = base[wy:wy + wh, wx:wx + ww]
    base[wy:wy + wh, wx:wx + ww] = region * (1 - a) + fw * a
    return Image.fromarray(base.astype(np.uint8), "RGB")


def main() -> None:
    ap = argparse.ArgumentParser()
    # Several taps, applied in sequence. This is not a shortcut around a bad
    # selection - it is what the app does. One tap selects one object, and a
    # tower viewer is a head, a post and a handle, so a user who wants the whole
    # thing gone taps it three times. Each fill re-encodes, because after a fill
    # the photo has changed and the next tap must see the new pixels.
    ap.add_argument("--points", nargs="+", default=["%d,%d" % DEFAULT_POINT],
                    help="one or more X,Y taps in source-image pixels")
    ap.add_argument("--preview", action="store_true")
    args = ap.parse_args()

    taps = []
    for p in args.points:
        try:
            x, y = (int(v) for v in p.replace(" ", "").split(","))
        except ValueError:
            sys.exit("--points takes X,Y pairs, e.g. --points 730,700 745,980")
        taps.append((x, y))

    src = os.path.join(SAMPLES, "landscape.jpg")
    before = Image.open(src).convert("RGB")
    print("photo   %s %dx%d  (CC0, see samples/SOURCES.json)" % (
        os.path.basename(src), *before.size))

    img = before
    marks = np.zeros((before.height, before.width), np.uint8)
    for i, tap in enumerate(taps, 1):
        mask = sam_mask(img, tap)
        cover = mask.mean()
        # A tap that comes back with a quarter of the picture has selected
        # scenery, not an object - on this photo, tapping the handle where it
        # crosses the shoreline returns the whole lake surface. MI-GAN will
        # cheerfully synthesise that and the result is a smear, so refuse it
        # here rather than discover it in the render.
        if cover > 0.10:
            sys.exit("tap %d (%d,%d) selected %.1f%% of the frame - that is "
                     "scenery, not an object. Move it onto the object's body."
                     % (i, tap[0], tap[1], cover * 100))
        ys, xs = np.nonzero(mask)
        if len(xs) == 0:
            sys.exit("tap %d selected nothing - move it onto the object" % i)
        print("tap %d   %-12s -> %5.2f%% of the frame, bbox %dx%d at (%d,%d)"
              % (i, "%d,%d" % tap, cover * 100,
                 xs.max() - xs.min() + 1, ys.max() - ys.min() + 1,
                 xs.min(), ys.min()))
        marks |= mask
        img = fill(img, mask)

    # Only the AFTER is written. The "before" IS `assets/store/samples/landscape.jpg`,
    # already in the repo, and a second copy of it would be a megabyte and a half
    # of duplication that can silently fall out of step with the original.
    #
    # PNG, not JPEG, even though this is a photograph. It is the model's output
    # and everything downstream re-encodes it: at q95 the ringing it picked up
    # cost the finished 1200² promo 200 KB MORE than the lossless source did,
    # which is the opposite of the trade JPEG is usually made for. Evidence is
    # stored exactly, the same way `samples/subject-mask.png` is.
    os.makedirs(OUT, exist_ok=True)
    dest = os.path.join(OUT, "fill-after.png")
    img.save(dest)
    print("wrote   %s  (%d tap%s, %d KB)"
          % (os.path.relpath(dest, ROOT), len(taps),
             "" if len(taps) == 1 else "s", os.path.getsize(dest) // 1024))

    if args.preview:
        os.makedirs(os.path.join(ROOT, "build"), exist_ok=True)
        m = np.asarray(before).copy()
        m[marks != 0] = (m[marks != 0] * 0.45
                         + np.array([255, 40, 140]) * 0.55).astype(np.uint8)
        sheet = Image.new("RGB", (before.width * 3 + 24, before.height), (18, 18, 20))
        sheet.paste(before, (0, 0))
        sheet.paste(Image.fromarray(m), (before.width + 12, 0))
        sheet.paste(img, (2 * before.width + 24, 0))
        sheet.thumbnail((1800, 1800), Image.LANCZOS)
        p = os.path.join(ROOT, "build", "fill-demo-preview.jpg")
        sheet.save(p, quality=88)
        print("preview %s  (before | what the taps selected | after)"
              % os.path.relpath(p, ROOT))


if __name__ == "__main__":
    main()
