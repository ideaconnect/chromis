"""Prove the website's SVG feColorMatrix filters equal the app's own matrices.

The site renders its filter gallery by handing `ColorMatrix.filter`'s numbers to
the browser as `feColorMatrix`. That conversion has two ways to go silently
wrong - the translation column is 0-255 in Flutter but 0-1 in SVG, and SVG
filters default to linearRGB while Skia works in sRGB - and either would ship a
gallery whose colours are not the app's.

So: render a strip of known colour patches through every filter twice - once in
Python by multiplying the matrix directly, once in a headless browser through
the generated SVG - and compare the pixels.

    python tool/verify_svg_filters.py
"""

import json
import os
import subprocess
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_filters import apply_matrix, svg_values  # noqa: E402

ROOT = os.getcwd()
MATRICES = os.path.join(ROOT, "build", "filters.json")
WORK = os.path.join(ROOT, "build", "svgcheck")
EDGE = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"

# Colour patches chosen to exercise every coefficient: primaries and secondaries
# catch the 3x3, the greys catch the translation column, and the near-clipping
# values catch anything that only shows up at the ends of the range.
PATCHES = [
    (255, 0, 0), (0, 255, 0), (0, 0, 255),
    (255, 255, 0), (0, 255, 255), (255, 0, 255),
    (0, 0, 0), (64, 64, 64), (128, 128, 128), (192, 192, 192), (255, 255, 255),
    (231, 154, 96), (44, 90, 160), (120, 200, 90), (250, 240, 230), (18, 22, 30),
]
CELL = 20  # px per patch in the rendered strip

# The browser's own JPEG-free PNG path is exact, but sub-pixel filter maths and
# 8-bit rounding still leave a channel or two off by one.
TOLERANCE = 2


def strip_image() -> Image.Image:
    a = np.zeros((CELL, CELL * len(PATCHES), 3), dtype=np.uint8)
    for i, c in enumerate(PATCHES):
        a[:, i * CELL:(i + 1) * CELL] = c
    return Image.fromarray(a, "RGB")


def build_page(filters) -> str:
    defs, rows = [], []
    for f in filters:
        if f["name"] == "none":
            continue
        defs.append(
            f'<filter id="fx-{f["name"]}" color-interpolation-filters="sRGB">'
            f'<feColorMatrix type="matrix" values="{svg_values(f["matrix"])}"/>'
            f"</filter>"
        )
        rows.append(
            f'<img src="strip.png" style="filter:url(#fx-{f["name"]})">'
        )
    return (
        "<!doctype html><meta charset=utf-8>"
        "<style>html,body{margin:0;padding:0;background:#fff}"
        # The defs svg must not be an inline box: at 0x0 it still generates a
        # line box the height of the line-height, which pushes every row down
        # and makes each one sample its neighbour's filter.
        "svg{position:absolute;width:0;height:0}"
        "img{display:block;image-rendering:pixelated}</style>"
        f'<svg width="0" height="0"><defs>{"".join(defs)}</defs></svg>'
        + "".join(rows)
    )


def main():
    if not os.path.exists(EDGE):
        sys.exit(f"headless browser not found at {EDGE}")
    if not os.path.exists(MATRICES):
        sys.exit(f"{MATRICES} missing - run: flutter test tool/dump_filters.dart")
    filters = json.load(open(MATRICES))["filters"]
    tested = [f for f in filters if f["name"] != "none"]

    os.makedirs(WORK, exist_ok=True)
    strip = strip_image()
    strip.save(os.path.join(WORK, "strip.png"))
    page = os.path.join(WORK, "index.html")
    open(page, "w", encoding="utf-8").write(build_page(filters))

    shot = os.path.join(WORK, "shot.png")
    if os.path.exists(shot):
        os.remove(shot)
    width = CELL * len(PATCHES)
    height = CELL * len(tested)
    subprocess.run(
        [EDGE, "--headless=new", "--disable-gpu", "--force-device-scale-factor=1",
         f"--screenshot={shot}", f"--window-size={width},{height}",
         "--virtual-time-budget=4000", f"file:///{page.replace(os.sep, '/')}"],
        check=True, capture_output=True, timeout=180,
    )
    if not os.path.exists(shot):
        sys.exit("browser produced no screenshot")

    got = np.asarray(Image.open(shot).convert("RGB"), dtype=np.int16)
    if got.shape[0] < height or got.shape[1] < width:
        sys.exit(f"screenshot too small: {got.shape} < ({height}, {width})")

    failures = 0
    for i, f in enumerate(tested):
        want = np.asarray(apply_matrix(strip, f["matrix"]), dtype=np.int16)
        band = got[i * CELL:(i + 1) * CELL, :width]
        # Sample each patch's centre; edges can carry the browser's own AA.
        worst, where = 0, ""
        for p in range(len(PATCHES)):
            gx = band[CELL // 2, p * CELL + CELL // 2]
            wx = want[CELL // 2, p * CELL + CELL // 2]
            d = int(np.abs(gx - wx).max())
            if d > worst:
                worst, where = d, f"patch {PATCHES[p]} browser={tuple(gx)} dart={tuple(wx)}"
        status = "ok " if worst <= TOLERANCE else "FAIL"
        if worst > TOLERANCE:
            failures += 1
        print(f"  {status} {f['label']:<9} max channel delta {worst:>3}  {where if worst else ''}")

    print()
    if failures:
        sys.exit(f"{failures} of {len(tested)} filters do not match the app")
    print(f"all {len(tested)} SVG filters match ColorMatrix.filter (<= {TOLERANCE}/255)")


if __name__ == "__main__":
    main()
