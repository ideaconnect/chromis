"""Turn raw device screenshots into the website's screenshot set.

Takes 1280x2856 (portrait) / 2856x1280 (landscape) captures from the phone
emulator, crops off the ad slot where one is showing - a house/test ad is not
something to put on a landing page - downscales to roughly 2x the size the site
renders them at, and writes WebP.

Usage (paths are whatever adb dumped):

    python tool/gen_screens.py <src-dir>

`SHOTS` below names each source file and what it becomes.
"""

import os
import sys

from PIL import Image

ROOT = os.getcwd()
OUT = os.path.join(ROOT, "website", "assets", "img", "screens")

# name in -> (name out, target width, crop fraction off the bottom)
#
# The ad slot plus its "Remove ads" row is the bottom ~9% of Home; every other
# screen ends in the tool dock, which is part of the product.
SHOTS = {
    "s09_fx.png": ("effects.webp", 620, 0.0),
    "s23_grid.png": ("grid.webp", 620, 0.0),
    "s24_layers.png": ("layers.webp", 620, 0.0),
    "q19_aicut.png": ("cutout.webp", 620, 0.0),
    "s05.png": ("adjust.webp", 620, 0.0),
    "s25_home.png": ("home.webp", 620, 0.125),
    "s10_landscape.png": ("landscape.webp", 1240, 0.0),
}


def main():
    if len(sys.argv) < 2:
        sys.exit(f"usage: python {sys.argv[0]} <dir-with-screenshots>")
    src_dir = sys.argv[1]
    os.makedirs(OUT, exist_ok=True)

    missing = [n for n in SHOTS if not os.path.exists(os.path.join(src_dir, n))]
    if missing:
        print("missing sources:", ", ".join(missing))

    for name, (out_name, width, crop_bottom) in SHOTS.items():
        path = os.path.join(src_dir, name)
        if not os.path.exists(path):
            continue
        im = Image.open(path).convert("RGB")
        if crop_bottom:
            im = im.crop((0, 0, im.width, round(im.height * (1 - crop_bottom))))
        h = round(im.height * width / im.width)
        im = im.resize((width, h), Image.LANCZOS)
        dest = os.path.join(OUT, out_name)
        im.save(dest, quality=78, method=6)
        kb = os.path.getsize(dest) // 1024
        print(f"  {out_name:18s} {im.width}x{im.height}  {kb:>4} KB")


if __name__ == "__main__":
    main()
