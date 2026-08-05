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
   so they cannot be handed to the browser. They are rendered by
   `tool/gen_effect_demos.dart`, which calls the app's own `paintImageLayer`
   and `paintLayerShadow` - this script only cuts the source frames and encodes
   the results. They used to be re-implemented here in Python, and that mirror
   under-rendered HDR by about a third on shadow-heavy photos.

Run from the repo root:

    flutter test tool/dump_filters.dart     # refresh build/filters.json
    python tool/gen_effects.py              # refresh the AI cut-out
    python tool/gen_filters.py --sources    # cut the demo frames
    flutter test tool/gen_effect_demos.dart # render them via the app
    python tool/gen_filters.py              # encode + patch index.html
"""

import html
import json
import os
import re
import sys

import numpy as np
from PIL import Image

ROOT = os.getcwd()
MATRICES = os.path.join(ROOT, "build", "filters.json")
WEB = os.path.join(ROOT, "website")
OUT_FX = os.path.join(WEB, "assets", "img", "effects")
INDEX = os.path.join(WEB, "index.html")

# The gallery and demo photo. CC0 from Wikimedia Commons, recorded in
# `assets/store/samples/SOURCES.json`, and the SAME frame the Play listing's
# Effects screenshot is taken on - so the filter a visitor clicks here and the
# filter they see in the store shot are the same look on the same photo.
#
# It is the landscape sample rather than the portrait subject because this
# section is 16:9 throughout: a 3:4 photo cropped to a 16:9 band keeps a strip
# across the middle, which on a portrait subject is the part without the face.
# The before/after slider up in the hero is the other way round and takes the
# portrait one (`gen_effects.py`); the README pins that at 3:4.
SRC = os.path.join(ROOT, "assets", "store", "samples", "landscape.jpg")

BEGIN = "<!-- BEGIN generated:filters -->"
END = "<!-- END generated:filters -->"

# The gallery photo. 16:9 so the stage stays a band rather than a wall on a
# desktop-width page. The source is already 3:2 landscape, so it needs no zoom
# to fill the band - the old value existed to pull a subject out of a portrait
# frame, and applied here it would throw away most of the picture.
HERO = (1280, 720)
HERO_CROP = dict(bias=0.5, zoom=1.0)
# Effect demos share the gallery's aspect so the section reads as one set.
FX = (960, 540)


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


# ---------------------------------------------------------------- effect demos
# Vignette, HDR, drop shadow and contour used to be re-implemented here. They
# are not any more: `tool/gen_effect_demos.dart` renders them through the app's
# own `paintImageLayer` / `paintLayerShadow`, so the pictures on the page are
# the app's actual output rather than a mirror of it. The mirror was quietly
# under-rendering HDR by about a third on shadow-heavy photos, which is exactly
# the kind of drift hand-copied render code produces.
#
# This script's job either side of that is to cut the source frames and to
# encode the results.
DEMO_DIR = os.path.join(ROOT, "build", "demo")


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


def on_panel(rgba, size, margin=0.11):
    """Letterbox an RGBA composite into `size`, **keeping its alpha**.

    Trimmed to its own content first (shadow and contour included), so the
    subject fills the card the same way whichever photo the generator picked -
    the padding those routines need to draw into is working space, not framing.
    `margin` is the breathing room left around it, as a fraction of the longer
    side, which also guarantees the stroke never reaches the edge.

    **The background is the page's job, not this file's.** These two used to be
    flattened onto the old navy panel colour, which baked one theme into the
    pixels: the app ships a light theme now and the site follows it, and a navy
    rectangle sitting in a white card is not a thing CSS can undo. Transparent,
    the card's own `--plate` shows through and the drop shadow has something to
    fall on in both themes - which is the whole point of that demo.
    """
    bbox = rgba.getbbox()
    if bbox:
        pad = round(max(bbox[2] - bbox[0], bbox[3] - bbox[1]) * margin)
        rgba = rgba.crop((
            max(0, bbox[0] - pad), max(0, bbox[1] - pad),
            min(rgba.width, bbox[2] + pad), min(rgba.height, bbox[3] + pad),
        ))
    fitted = rgba.copy()
    fitted.thumbnail(size, Image.LANCZOS)
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    out.paste(fitted, ((size[0] - fitted.width) // 2, (size[1] - fitted.height) // 2))
    return out


def save(im, name, quality=72):
    path = os.path.join(OUT_FX, name)
    # WebP carries alpha; `exact` keeps the fully-transparent pixels from having
    # their (invisible) colour resampled into the visible edge, which on a
    # feathered cut-out shows up as a dark halo along the silhouette.
    if im.mode == "RGBA":
        im.save(path, quality=quality, method=6, exact=True)
    else:
        im.save(path, quality=quality, method=6)
    print(f"  {name:24s} {os.path.getsize(path) // 1024:>4} KB")


def write_demo_sources(src):
    """Cut the frames `gen_effect_demos.dart` renders, into build/demo/."""
    os.makedirs(DEMO_DIR, exist_ok=True)
    crop_to(src, FX, **HERO_CROP).save(os.path.join(DEMO_DIR, "vignette_src.png"))
    # HDR gets its own framing: it lifts shadows and adds local contrast, so it
    # needs shadows in frame to show anything. This crop sits lower, over the
    # dog's shaded flank. Same photo, same 100%; only the framing differs.
    crop_to(src, FX, bias=0.30, zoom=1.45).save(
        os.path.join(DEMO_DIR, "hdr_src.png")
    )

    cut_path = os.path.join(OUT_FX, "dog-cutout.png")
    if not os.path.exists(cut_path):
        print("  (no dog-cutout.png - run tool/gen_effects.py first)")
        return
    cut = Image.open(cut_path).convert("RGBA")
    k = 820 / max(cut.size)
    cut = cut.resize((round(cut.width * k), round(cut.height * k)), Image.LANCZOS)
    # Split into photo + mask, which is how the app holds a cut-out: the stroke
    # is grown from the mask's alpha, so passing a single RGBA image would make
    # it frame the rectangle instead of hugging the subject.
    base = Image.new("RGB", cut.size, (0, 0, 0))
    base.paste(cut, (0, 0), cut)
    base.save(os.path.join(DEMO_DIR, "cut_base.png"))
    mask = Image.new("RGBA", cut.size, (255, 255, 255, 0))
    mask.putalpha(cut.split()[3])
    mask.save(os.path.join(DEMO_DIR, "cut_mask.png"))
    for n in ("vignette_src", "hdr_src", "cut_base", "cut_mask"):
        print(f"  build/demo/{n}.png")


def encode_demo_renders():
    """Turn what the Dart renderer produced into the page's WebP files."""
    jobs = [
        ("vignette_src.png", "fx-original.webp", None),
        ("vignette_out.png", "fx-vignette.webp", None),
        ("hdr_src.png", "fx-hdr-before.webp", None),
        ("hdr_out.png", "fx-hdr.webp", None),
        ("shadow_out.png", "fx-shadow.webp", FX),
        ("contour_out.png", "fx-contour.webp", FX),
    ]
    for name, out, panel in jobs:
        path = os.path.join(DEMO_DIR, name)
        if not os.path.exists(path):
            print(f"  (missing {name} - run: flutter test tool/gen_effect_demos.dart)")
            continue
        im = Image.open(path)
        save(on_panel(im.convert("RGBA"), panel) if panel else im.convert("RGB"), out)


DEFAULT_LOOK = "punch"

# Bumped whenever the generated images change, so GitHub Pages' 4-hour cache
# does not serve a stale tile against a new set of filters.
ASSET_V = 4


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

    if "--sources" in sys.argv:
        write_demo_sources(src)
        return

    print("effect demos (rendered by tool/gen_effect_demos.dart):")
    encode_demo_renders()

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
