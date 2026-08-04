"""Generate the LinkedIn giveaway graphics (25 Pro codes).

Third sibling to gen_social_promo.py (the standing LinkedIn pitch) and
gen_wykop_promo.py (the Polish forum post). This one announces a specific
giveaway, so the code count is the headline rather than a line of body copy,
and the call to action names the only step a reader has to take.

English, and English captures from build/shots-i18n/en/phone, because the
LinkedIn audience is not the pl-PL one. That is the same rule the Wykop
generator follows in the other direction.

Two formats from one composition, because LinkedIn shows images two ways and
the difference is not cosmetic:

- **1200x1200** for a native image post, which is what a giveaway should be.
  The square crop is what the feed gives an uploaded image the most height for,
  so the copy sits on top and the fan of three phones underneath.
- **1200x628** for a link share, where the card is wide and short. The phones
  move to the right and the copy takes a narrow left column.

Geometry, edges and compositing come from gen_ads_assets.place, so a phone here
is framed, tilted, shadowed and bounds-checked exactly as in the ad set.

The copy is painted in and cannot reflow, so `fits` measures the drawn result
against its column rather than trusting the layout numbers. Same offline
measurement discipline as tool/measure_labels.py and tool/store_copy.py.

Run: python tool/gen_linkedin_giveaway.py
Out: assets/store/social/linkedin-giveaway-{square,landscape}.png
"""

from __future__ import annotations

import sys
from math import cos, radians, sin
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(Path(__file__).resolve().parent))

from gen_ads_assets import BODY, DISPLAY, MUTED, TEXT, font, place  # noqa: E402
from gen_social_promo import CYAN, INK, SS, over, premultiplied, s  # noqa: E402
from gen_store_screens import backdrop  # noqa: E402

OUT_DIR = ROOT / "assets/store/social"
CAPTURES = ROOT / "build/shots-i18n/en/phone"
LOGO = ROOT / "assets/branding/logo.png"

# The words, shared by both formats so the two cannot say different things.
# Every claim here is one the en-US listing already makes.
EYEBROW = "GIVEAWAY"
HEADLINE = ["25 free codes", "that remove the ads"]
SUB = [
    "A photo editor with AI that runs on your phone.",
    "Layers, filters, collages, cut-outs.",
]
BADGE = "Message me and I'll send one"

# Back to front. The cut-out result is the front phone in both formats because
# it is the single clearest picture of what the app does; the others say the
# app is more than one trick.
FORMATS = {
    "square": {
        "size": (1200, 1200),
        "phones": [
            ("grid", 400, -8.0, (400, 940)),
            ("effects", 400, 8.0, (800, 940)),
            ("cutout_result", 470, 0.0, (600, 950)),
        ],
        "glow": (600, 950),
        "radii": (600.0, 650.0, 900.0, 700.0),
        "column": (80, 1040),
        "centred": False,
        "top": 80,
        "brand": 60, "mark": 34, "eyebrow": 26,
        "head": 76, "head_lh": 92, "sub": 28, "sub_lh": 42,
        "badge": 30, "badge_h": 68, "rule_w": 84, "rule_h": 7,
        "gaps": (34, 24, 32, 26, 38),
    },
    "landscape": {
        "size": (1200, 628),
        "phones": [
            ("grid", 400, -8.0, (830, 300)),
            ("cutout_result", 490, 0.0, (985, 314)),
        ],
        "glow": (985, 314),
        "radii": (480.0, 520.0, 820.0, 620.0),
        "column": (72, 606),
        "centred": True,
        "top": 0,
        "brand": 50, "mark": 28, "eyebrow": 22,
        "head": 46, "head_lh": 58, "sub": 22, "sub_lh": 32,
        "badge": 26, "badge_h": 56, "rule_w": 68, "rule_h": 6,
        "gaps": (26, 20, 26, 22, 32),
    },
}
BLUR = 22


def render(name: str, cfg: dict) -> None:
    W, H = cfg["size"]
    missing = [n for n, *_ in cfg["phones"] if not (CAPTURES / f"{n}.png").exists()]
    if missing:
        sys.exit(f"missing English captures in {CAPTURES}: {', '.join(missing)}\n"
                 "run tool/capture_store_shots.py first")

    bg = backdrop((W, H), cfg["glow"], cfg["radii"])
    canvas = np.array(bg.resize((W * SS, H * SS), Image.BICUBIC), dtype=np.uint8)
    for capture, height, angle, centre in cfg["phones"]:
        place(canvas, CAPTURES, capture, height, angle, centre, BLUR, (W, H))

    layer = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    badge_font = font(BODY, cfg["badge"], "Bold")
    badge_w = round(draw.textlength(BADGE, font=badge_font) / SS) + 2 * 28
    g_eyebrow, g_head, g_rule, g_sub, g_badge = cfg["gaps"]

    block = (
        cfg["brand"] + g_eyebrow + cfg["eyebrow"] + g_head
        + len(HEADLINE) * cfg["head_lh"] + g_rule + cfg["rule_h"] + g_sub
        + len(SUB) * cfg["sub_lh"] + g_badge + cfg["badge_h"]
    )
    x, col_w = cfg["column"]
    y = (H - block) // 2 if cfg["centred"] else cfg["top"]

    logo = premultiplied(Image.open(LOGO).convert("RGBA"))
    layer.paste(logo.resize((s(cfg["brand"]), s(cfg["brand"])), Image.LANCZOS), (s(x), s(y)))
    draw.text((s(x + cfg["brand"] + 16), s(y + cfg["brand"] / 2)), "Chromis",
              font=font(DISPLAY, cfg["mark"], "Bold"), fill=MUTED, anchor="lm")
    y += cfg["brand"] + g_eyebrow

    draw.text((s(x), s(y)), EYEBROW, font=font(BODY, cfg["eyebrow"], "Bold"), fill=CYAN)
    y += cfg["eyebrow"] + g_head

    head_font = font(DISPLAY, cfg["head"], "Bold")
    for line in HEADLINE:
        draw.text((s(x), s(y)), line, font=head_font, fill=TEXT)
        y += cfg["head_lh"]

    y += g_rule
    draw.rounded_rectangle((s(x), s(y), s(x + cfg["rule_w"]), s(y + cfg["rule_h"])),
                           radius=s(cfg["rule_h"] / 2), fill=CYAN)
    y += cfg["rule_h"] + g_sub

    sub_font = font(BODY, cfg["sub"], "Medium")
    for line in SUB:
        draw.text((s(x), s(y)), line, font=sub_font, fill=MUTED)
        y += cfg["sub_lh"]

    y += g_badge
    draw.rounded_rectangle((s(x), s(y), s(x + badge_w), s(y + cfg["badge_h"])),
                           radius=s(cfg["badge_h"] / 2), fill=CYAN)
    draw.text((s(x + badge_w / 2), s(y + cfg["badge_h"] / 2)), BADGE,
              font=badge_font, fill=INK, anchor="mm")

    box = layer.getbbox()
    right = box[2] / SS
    assert right <= x + col_w, (
        f"{name}: copy is {right - x:.0f}px wide and overruns its {col_w}px "
        "column - shorten a line or move the phones"
    )
    # The square stacks copy over phones, so the two can collide vertically -
    # place() only proves a phone is on the canvas, not that it clears the text.
    # A tilted frame is taller than its own height, hence the rotated extent.
    if not cfg["centred"]:
        tops = []
        for _c, height, angle, centre in cfg["phones"]:
            rad = radians(abs(angle))
            width = height * 1280 / 2856
            tops.append(centre[1] - (width * sin(rad) + height * cos(rad)) / 2)
        assert box[3] / SS <= min(tops) - 12, (
            f"{name}: copy runs to {box[3] / SS:.0f}px and the highest phone "
            f"starts at {min(tops):.0f}px"
        )

    over(canvas, premultiplied(layer), 0, 0)
    img = Image.fromarray(canvas, "RGB").resize((W, H), Image.LANCZOS)

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out = OUT_DIR / f"linkedin-giveaway-{name}.png"
    img.save(out, optimize=True)
    print(f"wrote {out.name} ({W}x{H}), widest painted line {right - x:.0f}/{col_w}px, "
          f"{out.stat().st_size / 1024:.0f} KB")


def main() -> None:
    for name, cfg in FORMATS.items():
        render(name, cfg)


if __name__ == "__main__":
    main()
