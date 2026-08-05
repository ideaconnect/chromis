"""Turn the device capture session into the website's screenshot set.

Source is `build/shots-i18n/<lang>/<profile>/`, which is what
`tool/capture_store_shots.py` writes and what `tool/gen_store_screens.py`
composes the Play listing from - **one capture session feeds both**, so a
screenshot on the landing page and the same screenshot on Play cannot be of two
different builds. That is the whole reason this reads from there rather than
from a hand-picked directory of `adb` dumps.

    python tool/gen_screens.py [src-dir] [lang]
    (default build/shots-i18n, en)

`SHOTS` names each capture and what it becomes. Phone captures are 1280x2856 and
go out at 620 wide (1383 high, ~2x the rendered size); the 10-inch tablet is
2560x1600 and goes out at 1240 for the one wide slot.

**No crop.** The captures are taken with the Pro entitlement set, so there is no
ad slot anywhere to cut off - Home used to lose its bottom ~12% to a test ad, and
a house ad is not landing-page material. If a session is ever re-captured without
Pro, that crop has to come back AND the tap tables are already wrong (the rail
grows a Go Pro entry and pushes every tool down a slot), so the fix is to re-run
`capture_store_shots.py prepare`, not to crop here.

The source directory is gitignored for size; the committed artifacts are the
WebPs under `website/assets/img/screens/`. A fresh clone has the outputs and
cannot regenerate them without a capture session, which is the same deal the
effects images are on.
"""

from __future__ import annotations

import os
import sys

from PIL import Image

ROOT = os.getcwd()
OUT = os.path.join(ROOT, "website", "assets", "img", "screens")

# capture -> (profile, output name, target width)
#
# `objremove` and `bubble` are new in 1.3.0's set: object removal grew the
# Fill in / Erase chooser, which is the release's headline and needs a picture
# of the actual control rather than prose about it. `adjust` left the set with
# the same change - the capture session has no Adjust state, and the panel's own
# news (Scale/Rotation/Horizontal/Vertical on any layer, the Snap toggle) is
# visible in `cutout_result` anyway.
#
# The wide slot is the 10-inch tablet rather than a phone on its side: both show
# the rail-plus-folding-panel layout, and 16:10 is a better block on the page
# than a 2.23:1 letterbox.
SHOTS = {
    "cutout_result": ("phone", "cutout.webp", 620),
    "objremove_panel": ("phone", "objremove.webp", 620),
    "effects": ("phone", "effects.webp", 620),
    "grid": ("phone", "grid.webp", 620),
    "layers": ("phone", "layers.webp", 620),
    "bubble": ("phone", "bubble.webp", 620),
    "home": ("phone", "home.webp", 620),
    "effects@tab10": ("tab10", "landscape.webp", 1240),
}


def main() -> None:
    src_root = sys.argv[1] if len(sys.argv) > 1 else os.path.join("build", "shots-i18n")
    lang = sys.argv[2] if len(sys.argv) > 2 else "en"
    os.makedirs(OUT, exist_ok=True)

    missing = []
    for key, (profile, out_name, width) in SHOTS.items():
        stem = key.split("@")[0]
        path = os.path.join(src_root, lang, profile, f"{stem}.png")
        if not os.path.exists(path):
            missing.append(path)
            continue
        im = Image.open(path).convert("RGB")
        height = round(im.height * width / im.width)
        im = im.resize((width, height), Image.LANCZOS)
        dest = os.path.join(OUT, out_name)
        im.save(dest, quality=78, method=6)
        kb = os.path.getsize(dest) // 1024
        print(f"  {out_name:18s} {im.width}x{im.height}  {kb:>4} KB")

    if missing:
        print("\nmissing captures (run tool/capture_store_shots.py first):")
        for path in missing:
            print("  " + path)
        sys.exit(1)


if __name__ == "__main__":
    main()
