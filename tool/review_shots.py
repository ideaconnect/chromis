#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Lay one profile's captures out as a single contact sheet, to be looked at.

    python tool/review_shots.py en phone

A capture that came out wrong - a panel that did not open, a toast still on
screen, a tap that landed on the wrong tile - is not detectable from the file
size or the exit code, only by looking. Eight files is eight round trips;
one sheet is one.
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SHOTS = ["cutout_result", "sticker", "effects", "layers",
         "grid", "objremove_panel", "bubble", "home"]
CELL_H = 620


def main() -> int:
    locale = sys.argv[1] if len(sys.argv) > 1 else "en"
    profile = sys.argv[2] if len(sys.argv) > 2 else "phone"
    src = ROOT / "build" / "shots-i18n" / locale / profile
    tiles = []
    for name in SHOTS:
        path = src / ("%s.png" % name)
        if not path.exists():
            print("  missing: %s" % name)
            continue
        img = Image.open(path).convert("RGB")
        w = round(img.width * CELL_H / img.height)
        tiles.append((name, img.resize((w, CELL_H), Image.LANCZOS)))
    if not tiles:
        sys.exit("no captures in %s" % src)

    cols = 4 if tiles[0][1].width < CELL_H else 2
    rows = (len(tiles) + cols - 1) // cols
    cw = max(t.width for _, t in tiles) + 12
    sheet = Image.new("RGB", (cols * cw + 12, rows * (CELL_H + 30) + 12), (16, 16, 20))
    draw = ImageDraw.Draw(sheet)
    for i, (name, tile) in enumerate(tiles):
        x = 12 + (i % cols) * cw
        y = 12 + (i // cols) * (CELL_H + 30)
        sheet.paste(tile, (x, y))
        draw.text((x + 2, y + CELL_H + 8), "%d %s" % (i + 1, name), fill=(215, 219, 226))
    out = ROOT / "build" / "shots-i18n" / ("review-%s-%s.jpg" % (locale, profile))
    sheet.save(out, "JPEG", quality=86)
    print("  -> %s  (%dx%d)" % (out, sheet.width, sheet.height))
    return 0


if __name__ == "__main__":
    sys.exit(main())
