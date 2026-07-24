"""Generate website AI-effect example images from the sample dog photos, using
the SAME bundled U2-Netp model + recipe the app uses (squash-resize 320,
ImageNet normalize, min-max normalize output, bilinear upscale to soft alpha).

Outputs web-optimised images into website/assets/img/effects/.
Run from repo root:  python <this>.py
"""

import os
import sys
import glob
import numpy as np
from PIL import Image, ImageFilter, ImageDraw
import onnxruntime as ort

ROOT = os.getcwd()
MODEL = os.path.join(ROOT, "assets", "models", "u2netp.onnx")
SRC_DIR = os.path.join(ROOT, "assets", "branding", "dog")
OUT = os.path.join(ROOT, "website", "assets", "img", "effects")
os.makedirs(OUT, exist_ok=True)

SIZE = 320
MEAN = np.array([0.485, 0.456, 0.406], dtype=np.float32)
STD = np.array([0.229, 0.224, 0.225], dtype=np.float32)

_sess = ort.InferenceSession(MODEL, providers=["CPUExecutionProvider"])
_in = _sess.get_inputs()[0].name


def matte(im: Image.Image) -> Image.Image:
    """Return an 'L' soft alpha matte at im's size (app recipe)."""
    W, H = im.size
    small = im.resize((SIZE, SIZE), Image.BILINEAR)  # squash (ignore aspect)
    arr = np.asarray(small, dtype=np.float32) / 255.0
    arr = (arr - MEAN) / STD
    chw = np.transpose(arr, (2, 0, 1))[None, ...].astype(np.float32)
    out = _sess.run(None, {_in: chw})[0][0, 0]  # 320x320 sigmoid
    mn, mx = float(out.min()), float(out.max())
    out = (out - mn) / (mx - mn + 1e-8)
    m = Image.fromarray((out * 255).astype(np.uint8), "L")
    return m.resize((W, H), Image.BILINEAR)


def firm(mask: Image.Image, lo=40, hi=210) -> Image.Image:
    """Firm up edges: push lows to 0 / highs to 255, keep a soft transition,
    then a tiny feather so the cut-out doesn't look jagged."""
    a = np.asarray(mask, dtype=np.float32)
    a = np.clip((a - lo) / (hi - lo), 0, 1) * 255.0
    m = Image.fromarray(a.astype(np.uint8), "L")
    return m.filter(ImageFilter.GaussianBlur(0.8))


def coverage(mask: Image.Image) -> float:
    a = np.asarray(mask, dtype=np.float32) / 255.0
    return float(a.mean())


def fit(im: Image.Image, maxdim=1200) -> Image.Image:
    W, H = im.size
    s = min(1.0, maxdim / max(W, H))
    return im if s == 1.0 else im.resize((round(W * s), round(H * s)), Image.LANCZOS)


def drop_shadow(cut: Image.Image, blur=18, dy=16, dx=0, alpha=120):
    """Soft drop shadow layer the size of cut (RGBA), from its alpha."""
    W, H = cut.size
    pad = blur * 3
    sh = Image.new("RGBA", (W + 2 * pad, H + 2 * pad), (0, 0, 0, 0))
    a = cut.split()[3]
    solid = Image.new("RGBA", cut.size, (10, 12, 24, alpha))
    solid.putalpha(a.point(lambda v: int(v * alpha / 255)))
    sh.paste(solid, (pad + dx, pad + dy), solid)
    return sh.filter(ImageFilter.GaussianBlur(blur)), pad


def radial(size, inner, outer):
    """Vignette-ish radial gradient background."""
    W, H = size
    cx, cy = W / 2, H * 0.42
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    d = np.sqrt(((xx - cx) / (W * 0.75)) ** 2 + ((yy - cy) / (H * 0.75)) ** 2)
    d = np.clip(d, 0, 1)
    bg = np.zeros((H, W, 3), dtype=np.float32)
    for c in range(3):
        bg[..., c] = inner[c] + (outer[c] - inner[c]) * d
    return Image.fromarray(bg.astype(np.uint8), "RGB")


def linear_v(size, top, bot):
    W, H = size
    t = np.linspace(0, 1, H, dtype=np.float32)[:, None]
    bg = np.zeros((H, W, 3), dtype=np.float32)
    for c in range(3):
        bg[..., c] = (top[c] + (bot[c] - top[c]) * t)
    return Image.fromarray(bg.astype(np.uint8), "RGB")


def compose_on(cut: Image.Image, bg: Image.Image, scale=0.92, shadow=True):
    """Center cut on bg (bg already cut's canvas size), with drop shadow."""
    W, H = bg.size
    c = cut.copy()
    cw, ch = c.size
    s = min(W * scale / cw, H * scale / ch)
    c = c.resize((round(cw * s), round(ch * s)), Image.LANCZOS)
    canvas = bg.convert("RGBA")
    x = (W - c.width) // 2
    y = (H - c.height) // 2
    if shadow:
        sh, pad = drop_shadow(c)
        canvas.alpha_composite(sh, (x - pad, y - pad))
    canvas.alpha_composite(c, (x, y))
    return canvas.convert("RGB")


def checkerboard(size, sq=24):
    W, H = size
    bg = Image.new("RGB", (W, H), (60, 66, 82))
    d = ImageDraw.Draw(bg)
    for y in range(0, H, sq):
        for x in range(0, W, sq):
            if (x // sq + y // sq) % 2 == 0:
                d.rectangle([x, y, x + sq, y + sq], fill=(44, 49, 63))
    return bg


def main():
    photos = sorted(glob.glob(os.path.join(SRC_DIR, "*.jpg")))
    if not photos:
        print("no source photos found in", SRC_DIR)
        sys.exit(1)
    # Score each by foreground coverage; a good subject sits ~0.12..0.55.
    scored = []
    for p in photos:
        im = Image.open(p).convert("RGB")
        m = matte(im)
        cov = coverage(m)
        scored.append((abs(cov - 0.3), cov, p, im, m))
        print(f"  {os.path.basename(p)}  coverage={cov:.3f}")
    scored.sort(key=lambda t: t[0])
    _, cov, p, im, m = scored[0]
    print(f"chosen: {os.path.basename(p)} (coverage={cov:.3f})")

    im = fit(im, 1200)
    m = m.resize(im.size, Image.BILINEAR)
    m = firm(m)
    cut = im.convert("RGBA")
    cut.putalpha(m)
    # tight crop to subject bbox (+ small margin) so composites frame nicely
    bbox = m.getbbox()
    if bbox:
        pad = int(0.04 * max(im.size))
        x0 = max(0, bbox[0] - pad); y0 = max(0, bbox[1] - pad)
        x1 = min(im.width, bbox[2] + pad); y1 = min(im.height, bbox[3] + pad)
        cut = cut.crop((x0, y0, x1, y1))

    # 1) before (web original) + 2) transparent cut-out
    im.save(os.path.join(OUT, "dog-before.jpg"), quality=86, optimize=True)
    cut.save(os.path.join(OUT, "dog-cutout.png"), optimize=True)

    # 3) cut-out on checkerboard (proof of real transparency), same size as before
    canvas_size = im.size
    compose_on(cut, checkerboard(canvas_size), scale=0.96, shadow=False).save(
        os.path.join(OUT, "dog-checker.jpg"), quality=86, optimize=True)

    # 4) studio (brand radial) - the "after" for the before/after slider + hero
    studio = radial(canvas_size, inner=(30, 44, 92), outer=(9, 14, 30))
    compose_on(cut, studio, scale=0.9).save(
        os.path.join(OUT, "dog-studio.jpg"), quality=86, optimize=True)

    # 5) sunset sticker
    sunset = linear_v(canvas_size, top=(255, 150, 90), bot=(120, 40, 120))
    compose_on(cut, sunset, scale=0.9).save(
        os.path.join(OUT, "dog-sunset.jpg"), quality=86, optimize=True)

    # 6) pop (bold cyan) sticker
    pop = radial(canvas_size, inner=(34, 224, 224), outer=(12, 120, 150))
    compose_on(cut, pop, scale=0.9).save(
        os.path.join(OUT, "dog-pop.jpg"), quality=86, optimize=True)

    # square thumbnail of the cut-out for a "sticker chip"
    sq = 512
    chip = Image.new("RGBA", (sq, sq), (0, 0, 0, 0))
    c = cut.copy()
    s = min(sq * 0.92 / c.width, sq * 0.92 / c.height)
    c = c.resize((round(c.width * s), round(c.height * s)), Image.LANCZOS)
    chip.alpha_composite(c, ((sq - c.width) // 2, (sq - c.height) // 2))
    chip.save(os.path.join(OUT, "dog-chip.png"), optimize=True)

    for f in sorted(os.listdir(OUT)):
        kb = os.path.getsize(os.path.join(OUT, f)) // 1024
        print(f"  wrote {f} ({kb} KB)")


if __name__ == "__main__":
    main()
