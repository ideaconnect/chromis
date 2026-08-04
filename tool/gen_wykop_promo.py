"""Generate the Wykop promo graphic for the Polish launch post.

Companion to gen_social_promo.py (LinkedIn, English, general pitch) and
gen_update_promo.py (a release). This one is for one post on one Polish forum,
so three things are different and all three are deliberate:

- **Polish captures.** `build/shots-i18n/pl/phone`, the same directory the
  pl-PL Play listing is built from. A Polish post carrying an English
  screenshot is the tell that the app is not really translated, and this one
  is - so show it.
- **The giveaway is the headline furniture.** The reason someone stops on a
  Wykop wpis is the rozdajo, so the code count gets its own pill rather than
  being a line of body copy that scrolls past.
- **A pill is allowed here.** tool/gen_ads_assets.py bans capsule CTAs because
  Google disapproves image assets that imitate interface features and draws its
  own Install button. Wykop does neither. Do not copy this composition back
  into the ad set.

1200x628 because that is what a link-sized image in a feed wants, and it is the
one ratio already proven out in the ad set.

Geometry, edges and compositing come from the ad generator rather than being
restated - `place` frames, tilts, shadows and asserts a phone stays on the
canvas; the backdrop and the supersample-then-downsample rule come with it.

The copy is Polish and painted in, so it cannot wrap: `fits` measures the drawn
result against the column instead of trusting the layout numbers, the same job
tool/store_copy.py does for the store and ad art.

Run: python tool/gen_wykop_promo.py
Out: assets/store/social/wykop-promo.png (1200x628)
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(Path(__file__).resolve().parent))

from gen_ads_assets import BODY, DISPLAY, MUTED, TEXT, font, place  # noqa: E402
from gen_social_promo import CYAN, INK, SS, over, premultiplied, s  # noqa: E402
from gen_store_screens import backdrop  # noqa: E402

OUT = ROOT / "assets/store/social/wykop-promo.png"
CAPTURES = ROOT / "build/shots-i18n/pl/phone"
LOGO = ROOT / "assets/branding/logo.png"

W, H = 1200, 628

# The words. Everything here is a claim the pl-PL listing already makes -
# assets/store/pl-PL/details.md - so the post, the graphic and the store page
# cannot say three different things.
EYEBROW = "ROZDAJO DLA MIRKÓW I MIRABELEK"
HEADLINE = ["Prawdziwy edytor zdjęć,", "który działa w telefonie"]
SUB = ["Wycinanie AI, warstwy, 14 filtrów, kolaże i dymki.",
       "Wszystko liczone na telefonie. Bez konta."]
BADGE = "50 kodów PRO do rozdania"

# Back to front. The front phone is the cut-out result because that is the
# thing the post is actually selling; the collage behind it says the app does
# more than one trick. Tilt is 8 degrees, not one or two - see gen_ads_assets.
PHONES = [("grid", 400, -8.0, (830, 300)), ("cutout_result", 490, 0.0, (985, 314))]
BLUR = 22

# The back phone's leading edge, less a gutter. Nothing painted may cross it.
COLUMN_X = 72
COLUMN_W = 606

BRAND = 50
EYEBROW_SZ, HEAD, SUB_SZ, BADGE_SZ, MARK = 22, 46, 22, 26, 28
HEAD_LH, SUB_LH = 58, 32
GAP_EYEBROW, GAP_HEAD, GAP_RULE, GAP_SUB, GAP_BADGE = 26, 20, 26, 22, 32
RULE_W, RULE_H, BADGE_H = 68, 6, 56


def main() -> None:
    missing = [n for n, *_ in PHONES if not (CAPTURES / f"{n}.png").exists()]
    if missing:
        sys.exit(f"missing Polish captures in {CAPTURES}: {', '.join(missing)}\n"
                 "run tool/capture_store_shots.py first")

    front = PHONES[-1][3]
    bg = backdrop((W, H), front, (480.0, 520.0, 820.0, 620.0))
    canvas = np.array(bg.resize((W * SS, H * SS), Image.BICUBIC), dtype=np.uint8)
    for capture, height, angle, centre in PHONES:
        place(canvas, CAPTURES, capture, height, angle, centre, BLUR, (W, H))

    layer = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    badge_font = font(BODY, BADGE_SZ, "Bold")
    badge_w = round(draw.textlength(BADGE, font=badge_font) / SS) + 2 * 28

    block = (
        BRAND + GAP_EYEBROW + EYEBROW_SZ + GAP_HEAD
        + len(HEADLINE) * HEAD_LH + GAP_RULE + RULE_H + GAP_SUB
        + len(SUB) * SUB_LH + GAP_BADGE + BADGE_H
    )
    y = (H - block) // 2
    x = COLUMN_X

    logo = premultiplied(Image.open(LOGO).convert("RGBA"))
    layer.paste(logo.resize((s(BRAND), s(BRAND)), Image.LANCZOS), (s(x), s(y)))
    draw.text((s(x + BRAND + 16), s(y + BRAND / 2)), "Chromis",
              font=font(DISPLAY, MARK, "Bold"), fill=MUTED, anchor="lm")
    y += BRAND + GAP_EYEBROW

    draw.text((s(x), s(y)), EYEBROW, font=font(BODY, EYEBROW_SZ, "Bold"), fill=CYAN)
    y += EYEBROW_SZ + GAP_HEAD

    head_font = font(DISPLAY, HEAD, "Bold")
    for line in HEADLINE:
        draw.text((s(x), s(y)), line, font=head_font, fill=TEXT)
        y += HEAD_LH

    y += GAP_RULE
    draw.rounded_rectangle((s(x), s(y), s(x + RULE_W), s(y + RULE_H)),
                           radius=s(RULE_H / 2), fill=CYAN)
    y += RULE_H + GAP_SUB

    sub_font = font(BODY, SUB_SZ, "Medium")
    for line in SUB:
        draw.text((s(x), s(y)), line, font=sub_font, fill=MUTED)
        y += SUB_LH

    y += GAP_BADGE
    draw.rounded_rectangle((s(x), s(y), s(x + badge_w), s(y + BADGE_H)),
                           radius=s(BADGE_H / 2), fill=CYAN)
    draw.text((s(x + badge_w / 2), s(y + BADGE_H / 2)), BADGE,
              font=badge_font, fill=INK, anchor="mm")

    box = layer.getbbox()
    right = box[2] / SS
    assert right <= COLUMN_X + COLUMN_W, (
        f"copy is {right - COLUMN_X:.0f}px wide and runs into the phones "
        f"at {COLUMN_X + COLUMN_W} - shorten a line or move the fan"
    )

    over(canvas, premultiplied(layer), 0, 0)
    img = Image.fromarray(canvas, "RGB").resize((W, H), Image.LANCZOS)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT, optimize=True)
    print(f"wrote {OUT} ({W}x{H}), widest painted line {right - COLUMN_X:.0f}"
          f"/{COLUMN_W}px, {OUT.stat().st_size / 1024:.0f} KB")


if __name__ == "__main__":
    main()
