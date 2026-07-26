"""Build the website's Effects section from the app's OWN transforms.

Two halves, because the app's effects come in two kinds:

1. **The 15 one-tap looks are pure colour matrices**, so the site does not ship
   15 rendered photos - it ships ONE photo plus the matrices as SVG
   `feColorMatrix` filters, and the browser applies them live. Same numbers,
   same result, a fraction of the bytes, and switching looks is instant.

   The matrices are never re-typed here: `tool/dump_filters.dart` writes what
   `ColorMatrix.filter` actually returns to build/filters.json, and this script
   patches the generated block in index.html from it. Change a look in Dart,
   re-run, and the site follows - it cannot drift.

2. **Vignette, HDR, drop shadow and contour are Canvas routines**, not matrices,
   so they cannot be handed to the browser. Those are rendered here, each
   function mirroring its counterpart in
   `core/rendering/layer_effects_painter.dart` (radial falloff, overlay
   high-pass, dilate + blur silhouette).

Run from the repo root:

    flutter test tool/dump_filters.dart     # refresh build/filters.json
    python tool/gen_effects.py              # refresh the AI cut-out
    python tool/gen_filters.py
"""

import html
import json
import os
import re
import sys

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.getcwd()
MATRICES = os.path.join(ROOT, "build", "filters.json")
SRC = os.path.join(ROOT, "assets", "branding", "dog", "photo_2026-07-24_11-13-17.jpg")
WEB = os.path.join(ROOT, "website")
OUT_FX = os.path.join(WEB, "assets", "img", "effects")
INDEX = os.path.join(WEB, "index.html")

BEGIN = "<!-- BEGIN generated:filters -->"
END = "<!-- END generated:filters -->"

# The gallery photo. 16:9 so the stage stays a band rather than a wall on a
# desktop-width page, and zoomed in so the subject reads at thumbnail size too.
HERO = (1280, 720)
HERO_CROP = dict(bias=0.42, zoom=1.45)
# Effect demos share the gallery's aspect so the section reads as one set.
FX = (960, 540)
# Both painted demos run at full strength.
HDR_AMOUNT = 1.0


# --------------------------------------------------------------- colour matrix
def apply_matrix(im: Image.Image, m) -> Image.Image:
    """`ColorFilter.matrix` on 0-255 channels: rgb' = M[:3,:3] @ rgb + M[:3,4]."""
    a = np.asarray(im.convert("RGB"), dtype=np.float32)
    m = np.asarray(m, dtype=np.float32).reshape(4, 5)
    out = a @ m[:3, :3].T + m[:3, 4]
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGB")


def svg_values(m) -> str:
    """A Flutter 4x5 matrix as an SVG feColorMatrix `values` list.

    Two conversions and nothing else: SVG works on 0..1 channels, so the
    translation column (the 5th of each row) is divided by 255; and the filter
    must declare `color-interpolation-filters="sRGB"`, because SVG's default of
    linearRGB would silently apply the coefficients in a different space than
    Skia does and every look would come out wrong.
    """
    m = np.asarray(m, dtype=np.float64).reshape(4, 5)
    rows = []
    for r in range(4):
        vals = [f"{m[r, c]:.5g}" for c in range(4)] + [f"{m[r, 4] / 255.0:.6g}"]
        rows.append(" ".join(vals))
    return "\n              ".join(rows)


# ------------------------------------------------------------------- vignette
def vignette(im, amount=1.0, size=0.40, softness=0.45, color=(0, 0, 0)):
    """`vignetteShader`: a radial ramp over the rect's half-diagonal with stops
    [0 @ size, amount*0.28 @ mid, amount @ 1.0], composited srcATop, where
    mid = size + (1 - size) * (0.75 - 0.45 * softness).
    """
    W, H = im.size
    radius = np.hypot(W, H) / 2
    mid = size + (1 - size) * (0.75 - 0.45 * softness)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    d = np.clip(np.hypot(xx - W / 2, yy - H / 2) / radius, 0, 1)
    alpha = np.interp(d, [size, mid, 1.0], [0.0, amount * 0.28, amount],
                      left=0.0, right=amount)
    a = np.asarray(im.convert("RGB"), dtype=np.float32)
    out = a * (1 - alpha[..., None]) + np.array(color, np.float32) * alpha[..., None]
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGB")


# ------------------------------------------------------------------------ HDR
_LUMA = np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)
_HDR_BLUR_FRACTION = 0.06
_HDR_MAX_STRENGTH = 0.85


def _overlay(dst, src):
    """Skia's Overlay, on 0..1 floats."""
    return np.where(dst < 0.5, 2 * src * dst, 1 - 2 * (1 - src) * (1 - dst))


def hdr(im, tone_matrix, amount=1.0):
    """`ColorMatrix.hdrTone` + `_paintLocalContrast`.

    The tone half is the matrix dumped from Dart. The texture half is a
    high-pass blended back in Overlay: the blended layer is the photo averaged
    with a large-radius blurred *inverse* of its luma (the app draws that
    inverse over the photo at 50% alpha), composited at 0.85 * amount.
    """
    toned = np.asarray(apply_matrix(im, tone_matrix), np.float32) / 255.0
    raw = np.asarray(im.convert("RGB"), np.float32)

    sigma = min(im.size) * _HDR_BLUR_FRACTION
    inv = Image.fromarray(
        np.clip(255.0 - raw @ _LUMA, 0, 255).astype(np.uint8), "L"
    ).filter(ImageFilter.GaussianBlur(sigma))
    inv = np.asarray(inv, np.float32)[..., None] / 255.0

    layer = 0.5 * inv + 0.5 * (raw / 255.0)
    strength = min(_HDR_MAX_STRENGTH * amount, 1.0)
    out = toned + strength * (_overlay(toned, layer) - toned)
    return Image.fromarray(np.clip(out * 255, 0, 255).astype(np.uint8), "RGB")


# --------------------------------------------------------- shadow and contour
def _dilate(alpha, radius):
    """`ImageFilter.dilate` - a max filter over the given radius."""
    r = max(1, int(round(radius)))
    return alpha.filter(ImageFilter.MaxFilter(size=r * 2 + 1))


def drop_shadow(cut, angle=90.0, distance=26.0, blur=16.0, density=0.0,
                color=(0, 0, 0), opacity=0.5, pad=150):
    """`paintLayerShadow` + `shadowImageFilter`: recolour the silhouette,
    thicken by `density`, blur by `blur`, offset by `distance` at `angle`
    degrees clockwise from east, draw under the layer.
    """
    rad = np.deg2rad(angle)
    dx, dy = np.cos(rad) * distance, np.sin(rad) * distance
    W, H = cut.size
    canvas = Image.new("RGBA", (W + 2 * pad, H + 2 * pad), (0, 0, 0, 0))

    a = cut.split()[3]
    if density > 0.01:
        a = _dilate(a, density)
    sil = Image.new("RGBA", cut.size, tuple(color) + (255,))
    sil.putalpha(a.point(lambda v: int(v * opacity)))
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shadow.paste(sil, (pad + round(dx), pad + round(dy)), sil)
    if blur > 0.01:
        shadow = shadow.filter(ImageFilter.GaussianBlur(blur))

    canvas.alpha_composite(shadow)
    canvas.alpha_composite(cut, (pad, pad))
    return canvas


def contour(cut, width=16.0, color=(255, 255, 255), opacity=1.0, pad=150):
    """`_paintStroke`: the subject's alpha dilated by `width`, flattened to the
    stroke colour and drawn behind the layer - the sticker die-cut.
    """
    W, H = cut.size
    canvas = Image.new("RGBA", (W + 2 * pad, H + 2 * pad), (0, 0, 0, 0))
    a = Image.new("L", canvas.size, 0)
    a.paste(cut.split()[3], (pad, pad))
    ring = Image.new("RGBA", canvas.size, tuple(color) + (255,))
    ring.putalpha(_dilate(a, width).point(lambda v: int(v * opacity)))
    canvas.alpha_composite(ring)
    canvas.alpha_composite(cut, (pad, pad))
    return canvas


# ----------------------------------------------------------------------- misc
def crop_to(im, size, bias=0.5, zoom=1.0):
    """Crop to `size`'s aspect and resize.

    `zoom` > 1 takes a tighter window (the subject fills more of the frame),
    `bias` slides that window vertically, 0 = top .. 1 = bottom.
    """
    tw, th = size
    W, H = im.size
    target = tw / th
    if W / H > target:
        w, h = round(H * target), H
    else:
        w, h = W, round(W / target)
    w, h = round(w / zoom), round(h / zoom)
    left = round((W - w) * 0.5)
    top = round((H - h) * bias)
    return im.crop((left, top, left + w, top + h)).resize(size, Image.LANCZOS)


def on_panel(rgba, size, bg=(15, 27, 43), margin=0.07):
    """Flatten an RGBA composite onto the site's panel colour, letterboxed.

    Trimmed to its own content first (shadow and contour included), so the
    subject fills the card the same way whichever photo the generator picked -
    the padding those routines need to draw into is working space, not framing.
    `margin` is the breathing room left around it, as a fraction of the longer
    side, which also guarantees the stroke never reaches the edge.
    """
    bbox = rgba.getbbox()
    if bbox:
        pad = round(max(bbox[2] - bbox[0], bbox[3] - bbox[1]) * margin)
        rgba = rgba.crop((
            max(0, bbox[0] - pad), max(0, bbox[1] - pad),
            min(rgba.width, bbox[2] + pad), min(rgba.height, bbox[3] + pad),
        ))
    flat = Image.new("RGB", rgba.size, bg)
    flat.paste(rgba, (0, 0), rgba)
    flat.thumbnail(size, Image.LANCZOS)
    out = Image.new("RGB", size, bg)
    out.paste(flat, ((size[0] - flat.width) // 2, (size[1] - flat.height) // 2))
    return out


def save(im, name, quality=72):
    path = os.path.join(OUT_FX, name)
    im.save(path, quality=quality, method=6)
    print(f"  {name:24s} {os.path.getsize(path) // 1024:>4} KB")


DEFAULT_LOOK = "punch"

# Bumped whenever the generated images change, so GitHub Pages' 4-hour cache
# does not serve a stale tile against a new set of filters.
ASSET_V = 3


def build_block(filters) -> str:
    """The generated SVG defs, CSS and chips that get spliced into index.html.

    All three are derived from the same list, so the gallery is a pure function
    of what `ColorMatrix.filter` returns: add a look in Dart and it appears
    here, matrices and all.

    Switching looks is plain CSS - a radio group plus `:checked ~` - so the
    gallery works with JavaScript disabled and costs one photo download rather
    than fifteen.
    """
    defs, css, chips = [], [], []
    for f in filters:
        name = f["name"]
        fid = f"fx-{name}"
        is_none = name == "none"
        if not is_none:
            defs.append(
                f'        <filter id="{fid}" color-interpolation-filters="sRGB">\n'
                f'          <feColorMatrix type="matrix" values="\n'
                f'              {svg_values(f["matrix"])}"/>\n'
                f"        </filter>"
            )
            css.append(
                f"      #look-{name}:checked ~ .fx-stage .fx-stage-img "
                f"{{ filter: url(#{fid}); }}"
            )
        css.append(
            f"      #look-{name}:checked ~ .fx-strip [for=look-{name}] "
            f"{{ --on: 1; }}"
        )
        css.append(
            f'      #look-{name}:checked ~ .fx-stage figcaption::after '
            f'{{ content: "{f["label"]}"; }}'
        )
        style = "" if is_none else f' style="filter:url(#{fid})"'
        checked = " checked" if name == DEFAULT_LOOK else ""
        chips.append(
            f'      <input class="fx-radio" type="radio" name="look" '
            f'id="look-{name}"{checked}>'
        )
        # One 260px tile, reused by all 15 chips with a different filter on
        # each - so the strip costs a single ~13 KB download.
        chips.append(
            f'        <label class="fx-chip" for="look-{name}">'
            f'<img src="assets/img/effects/look-tile.webp?v={ASSET_V}" alt=""'
            f' width="260" height="260" loading="lazy"{style}>'
            f'<span>{html.escape(f["label"])}</span></label>'
        )
    # Radios first (so `~` can reach both the strip and the stage), then the
    # strip they label. The strip is placed visually under the stage with
    # `order`, which does not affect DOM order and so does not affect `~`.
    radios = [c for c in chips if c.lstrip().startswith("<input")]
    labels = [c for c in chips if not c.lstrip().startswith("<input")]
    return (
        f"{BEGIN}\n"
        "      <!-- Generated by tool/gen_filters.py from the app's own\n"
        "           ColorMatrix.filter output - do not hand-edit. -->\n"
        '      <svg class="fx-defs" aria-hidden="true" focusable="false">\n'
        "        <defs>\n" + "\n".join(defs) + "\n        </defs>\n      </svg>\n"
        "      <style>\n" + "\n".join(css) + "\n      </style>\n"
        + "\n".join(radios)
        + '\n      <div class="fx-strip" role="group" aria-label="Photo looks">\n'
        + "\n".join(labels)
        + "\n      </div>\n"
        f"      {END}"
    )


def patch_index(block: str):
    if not os.path.exists(INDEX):
        print(f"  (skipped index.html - {INDEX} missing)")
        return
    src = open(INDEX, encoding="utf-8").read()
    if BEGIN not in src or END not in src:
        print(f"  (skipped index.html - markers {BEGIN} / {END} not found)")
        return
    out = re.sub(
        re.escape(BEGIN) + r".*?" + re.escape(END), lambda _: block, src,
        flags=re.S,
    )
    open(INDEX, "w", encoding="utf-8", newline="\n").write(out)
    print("  patched index.html generated:filters block")


def main():
    if not os.path.exists(MATRICES):
        sys.exit(f"{MATRICES} missing - run: flutter test tool/dump_filters.dart")
    data = json.load(open(MATRICES))
    os.makedirs(OUT_FX, exist_ok=True)

    src = Image.open(SRC).convert("RGB")
    print("gallery photo:")
    save(crop_to(src, HERO, **HERO_CROP), "look.webp", quality=72)
    # The chip tile is square and tiny, so it gets its own tighter crop -
    # the 16:9 band shrunk to 86px would be a green smear.
    save(crop_to(src, (260, 260), bias=0.46, zoom=1.9), "look-tile.webp", quality=70)

    print("effect demos:")
    fx_src = crop_to(src, FX, **HERO_CROP)
    save(fx_src, "fx-original.webp")
    save(vignette(fx_src), "fx-vignette.webp")
    # Full strength on both, so the split before/after reads at a glance rather
    # than needing the visitor to hunt for the difference. The tone matrix has
    # to be the one dumped for THIS amount - scaling a composed matrix is not
    # the same transform (see tool/dump_filters.dart).
    save(hdr(fx_src, data["hdrTone"][str(HDR_AMOUNT)], amount=HDR_AMOUNT),
         "fx-hdr.webp")

    cut_path = os.path.join(OUT_FX, "dog-cutout.png")
    if os.path.exists(cut_path):
        cut = Image.open(cut_path).convert("RGBA")
        s = 820 / max(cut.size)
        cut = cut.resize((round(cut.width * s), round(cut.height * s)), Image.LANCZOS)
        save(on_panel(drop_shadow(cut), FX), "fx-shadow.webp")
        save(on_panel(contour(cut), FX), "fx-contour.webp")
    else:
        print(f"  (skipped shadow/contour - run tool/gen_effects.py first)")

    # gen_effects.py writes the AI composites as JPEG. The page serves WebP
    # siblings (roughly a third of the bytes at the same quality); the JPEGs
    # stay for the og:image, because not every link scraper decodes WebP.
    print("webp siblings for the AI composites:")
    for name in ("dog-before", "dog-studio", "dog-sunset", "dog-pop", "dog-checker"):
        jpg = os.path.join(OUT_FX, f"{name}.jpg")
        if os.path.exists(jpg):
            save(Image.open(jpg).convert("RGB"), f"{name}.webp", quality=74)

    print("markup:")
    patch_index(build_block(data["filters"]))


if __name__ == "__main__":
    main()
