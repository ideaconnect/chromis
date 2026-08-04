"""Generate the Google Ads image assets for an App campaign.

Five concepts x three accepted ratios, built from the same real device captures
the Play listing uses (`build/shots-i18n/<loc>/phone`), so an ad and the store
page a tap lands on show the same app:

    landscape  1200x628   1.91:1
    square     1200x1200  1:1
    portrait   1200x1500  4:5

Those are Google's recommended pixel sizes for App campaigns, rendered exactly
rather than resized into: "deviation of image aspect ratios should not exceed
1%", and an off-ratio upload is refused outright (ASPECT_RATIO_NOT_ALLOWED).
Nothing here is a mock-up and nothing is hand-retouched - change this script and
re-run it, same rule as tool/gen_branding.py.

**Two sets, and the plain one is not a lesser one.** Google's App campaign
guidance asks for images with little or no superimposed text - "to ensure
placement across all channels, upload images without any superimposed text or
logos", and it recommends keeping any overlay under 20% of the surface. So each
concept is rendered twice: `<ratio>/` carries the claim, `<ratio>-clean/` is the
same device art with nothing written on it, sized to fill the frame. Upload
both. The captioned ones say something in placements that show them; the clean
ones are what reaches every placement, and the campaign draws the app name,
icon, headline and Install button around them anyway.

**No button, no badge, no fake chrome, and never the words Download or
Install.** Google disapproves image assets that imitate ad or interface
features, and superimposing "Download" or "Install" on an app-promo image is a
documented automatic disapproval. So the only furniture here is the brand mark,
the accent rule and the claim; "Free" is a word in the copy, not a pill. The
LinkedIn promo's cyan "Free on Google Play" capsule is deliberately not reused.

**Text lives in the centre 80%, art may use the rest.** Google crops these to
fit placements it does not name in advance - "place the most important content
in the center 80% of the image" - so `check_safe_area` asserts that every
painted glyph is inside that box, at render time, in every language. The device
art is allowed into the outer band on purpose: a phone whose edge is clipped by
a placement crop still reads as a phone, whereas a clipped word is a typo.

**A phone is never cropped by US, though.** tool/gen_store_screens.py explains
why for the Play portrait shot and it holds harder in an ad: the tool panel at
the bottom of the screen IS the feature being demonstrated, so a composition
that bleeds the device off the canvas cuts the argument out of the picture. The
padding a ratio forces is filled with the bloom instead.

Geometry, edge handling and compositing are shared with the other promo art
rather than re-derived - `framed`, the premultiplied `over` and the
supersample-then-downsample rule come from tool/gen_social_promo.py, the
backdrop and shadow from tool/gen_store_screens.py.

The words are in tool/store_copy.py (`ADS`) with every other painted string, and
`python tool/store_copy.py` measures each line against the column it is drawn
into - a caption in a picture does not wrap, it runs into the phone beside it.

Run: python tool/gen_ads_assets.py [--formats landscape,square,portrait]
                                   [--no-clean] [locale ...]
     (default: every format, both sets, en only - pass `pl de es fr cs` for the rest)
Out: assets/store/ads/<play-locale>/<ratio>/NN-<concept>.png
     assets/store/ads/<play-locale>/<ratio>-clean/NN-<concept>.png
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(Path(__file__).resolve().parent))

import store_copy  # noqa: E402  - sibling module, not a package
from gen_social_promo import (  # noqa: E402
    SS,
    framed,
    over,
    premultiplied,
    rotate_premultiplied,
    s,
)
from gen_store_screens import backdrop, drop_shadow  # noqa: E402

OUT = ROOT / "assets/store/ads"
CAPTURES = ROOT / "build/shots-i18n"
LOGO = ROOT / "assets/branding/logo.png"
DISPLAY = "assets/fonts/SpaceGrotesk-Variable.ttf"
BODY = "assets/fonts/Manrope-Variable.ttf"

TEXT = (234, 241, 248)
MUTED = (159, 188, 214)

# Google's help pages say "5MB" and its policy page and API say "5120 KB"; the
# two differ by 120 KB and nobody reconciles them. Stay under five million
# bytes and the ambiguity never bites. Ours land near 1-2 MB, so this is a
# tripwire for a future change, not a tuning knob.
MAX_BYTES = 5_000_000

# The share of each edge that a placement may crop. Google asks for the
# important content in the centre 80%, i.e. a tenth off every side.
SAFE = 0.10

# ratio -> canvas, and the two fans that fill it.
#
# `phones` is the captioned set and `clean` the unwritten one; both are drawn
# back to front, each entry being (which capture of the concept's three, 1x
# frame height, tilt, 1x centre). The concept's FRONT capture is index 0 and is
# always drawn last and largest.
#
# The captioned landscape shows ONE phone where the square and portrait fan
# three. At 1200x628 with the copy holding the left half there is room for
# either one large device or two small ones, and an ad seen at thumbnail size
# is won by fewer, bigger elements. The clean landscape, having no copy to make
# room for, fans three across the whole frame.
#
# Tilts are +-7/8 degrees, never one or two: a near-vertical edge holds the same
# pixel column for a long run and then jogs by a whole pixel, which reads as a
# staircase, while the front phone at exactly 0 is exactly crisp. That is
# tool/gen_social_promo.py's finding.
FORMATS = {
    "landscape": {
        "size": (1200, 628),
        "phones": [(0, 490, 0.0, (970, 314))],
        "clean": [(1, 470, -8.0, (330, 314)), (2, 470, 8.0, (870, 314)),
                  (0, 560, 0.0, (600, 314))],
        "radii": (480.0, 520.0, 820.0, 620.0),
        "clean_radii": (620.0, 560.0, 1000.0, 640.0),
        "blur": 22,
    },
    "square": {
        "size": (1200, 1200),
        "phones": [(1, 505, -7.0, (340, 900)), (2, 505, 7.0, (860, 900)),
                   (0, 562, 0.0, (600, 882))],
        "clean": [(1, 660, -7.0, (330, 600)), (2, 660, 7.0, (870, 600)),
                  (0, 730, 0.0, (600, 600))],
        "radii": (620.0, 700.0, 1000.0, 900.0),
        "clean_radii": (660.0, 700.0, 1050.0, 900.0),
        "blur": 22,
    },
    "portrait": {
        "size": (1200, 1500),
        "phones": [(1, 660, -7.0, (322, 1080)), (2, 660, 7.0, (878, 1080)),
                   (0, 732, 0.0, (600, 1050))],
        "clean": [(1, 900, -7.0, (310, 780)), (2, 900, 7.0, (890, 780)),
                  (0, 1000, 0.0, (600, 770))],
        "radii": (640.0, 820.0, 1050.0, 1150.0),
        "clean_radii": (700.0, 900.0, 1100.0, 1200.0),
        "blur": 24,
    },
}

# The copy block. `y=None` centres it vertically, which is what the landscape
# wants; the two tall formats hang it from the top so the fan below always
# starts at the same place. x and width are inside the centre-80% box and the
# widths are repeated in store_copy.ADS_BUDGETS - keep the two in step, that is
# what measures the lines.
COPY = {
    "landscape": dict(x=120, y=None, width=690, brand=52, mark=30,
                      head=46, head_lh=58, sub=21, sub_lh=32, rule=64,
                      gap_head=34, gap_rule=26, gap_sub=24),
    "square": dict(x=120, y=120, width=960, brand=76, mark=38,
                   head=64, head_lh=80, sub=28, sub_lh=42, rule=84,
                   gap_head=38, gap_rule=30, gap_sub=28),
    "portrait": dict(x=120, y=150, width=960, brand=84, mark=42,
                     head=70, head_lh=88, sub=31, sub_lh=46, rule=92,
                     gap_head=44, gap_rule=34, gap_sub=32),
}
RULE_H = 6


def font(path: str, size: int, weight: str) -> ImageFont.FreeTypeFont:
    """A variable font at `size` in 1x points, instanced at `weight`."""
    f = ImageFont.truetype(str(ROOT / path), s(size))
    try:
        f.set_variation_by_name(weight)
    except OSError:
        pass  # static font, or that named instance is absent
    return f


def copy_height(cfg: dict, heads: list[str], subs: list[str]) -> int:
    return (
        cfg["brand"] + cfg["gap_head"]
        + len(heads) * cfg["head_lh"] + cfg["gap_rule"] + RULE_H + cfg["gap_sub"]
        + len(subs) * cfg["sub_lh"]
    )


def overlay(fmt: str, head: str, sub: str, accent) -> Image.Image:
    """Brand mark, headline, accent rule and supporting line. Straight-alpha.

    Nothing in here is ever resampled after it is drawn, so straight alpha is
    safe; it is premultiplied once, at the point of compositing.
    """
    W, H = FORMATS[fmt]["size"]
    cfg = COPY[fmt]
    heads, subs = head.split("\n"), sub.split("\n")

    layer = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    x = cfg["x"]
    y = cfg["y"]
    if y is None:
        y = (H - copy_height(cfg, heads, subs)) // 2

    # Premultiplied before scaling: the logo has transparent corners, and a
    # straight-alpha LANCZOS mixes their black RGB into the fringe.
    logo = premultiplied(Image.open(LOGO).convert("RGBA"))
    logo = logo.resize((s(cfg["brand"]), s(cfg["brand"])), Image.LANCZOS)
    layer.paste(logo, (s(x), s(y)))  # paste, not composite: the layer is empty here
    draw.text(
        (s(x + cfg["brand"] + 18), s(y + cfg["brand"] / 2)),
        "Chromis",
        font=font(DISPLAY, cfg["mark"], "Bold"),
        fill=MUTED,
        anchor="lm",
    )
    y += cfg["brand"] + cfg["gap_head"]

    head_font = font(DISPLAY, cfg["head"], "Bold")
    for line in heads:
        draw.text((s(x), s(y)), line, font=head_font, fill=TEXT)
        y += cfg["head_lh"]

    y += cfg["gap_rule"]
    draw.rounded_rectangle(
        (s(x), s(y), s(x + cfg["rule"]), s(y + RULE_H)), radius=s(RULE_H / 2), fill=accent
    )
    y += RULE_H + cfg["gap_sub"]

    sub_font = font(BODY, cfg["sub"], "Medium")
    for line in subs:
        draw.text((s(x), s(y)), line, font=sub_font, fill=MUTED)
        y += cfg["sub_lh"]

    return layer


def check_safe_area(layer: Image.Image, fmt: str, locale: str, concept: str) -> None:
    """Every painted pixel must sit in the centre 80% Google may crop to.

    Measured off the rendered layer rather than off the layout numbers, because
    what escapes is never the box - it is one long German headline or a Czech
    line with a descender, in one of six languages, and only the bitmap knows.
    """
    W, H = FORMATS[fmt]["size"]
    box = layer.getbbox()
    if box is None:
        return
    x0, y0, x1, y1 = (v / SS for v in box)
    lo_x, hi_x = W * SAFE, W * (1 - SAFE)
    lo_y, hi_y = H * SAFE, H * (1 - SAFE)
    assert lo_x <= x0 and x1 <= hi_x and lo_y <= y0 and y1 <= hi_y, (
        f"{locale}/{fmt}/{concept}: copy runs outside the centre 80% - "
        f"drawn {(round(x0), round(y0), round(x1), round(y1))}, "
        f"safe {(round(lo_x), round(lo_y), round(hi_x), round(hi_y))}"
    )


def place(canvas: np.ndarray, src: Path, capture: str, height: int, angle: float,
          centre: tuple[int, int], blur: int, size: tuple[int, int]) -> None:
    """One phone and its shadow, at SS scale. Asserts it stays on the canvas."""
    art = rotate_premultiplied(premultiplied(framed(capture, height, src)), angle)
    shadow, pad = drop_shadow(art, blur=s(blur), alpha=150)  # rgb=0, already premultiplied

    x0 = s(centre[0]) - art.width // 2
    y0 = s(centre[1]) - art.height // 2
    over(canvas, shadow, x0 - pad, y0 - pad + s(18))
    over(canvas, art, x0, y0)

    W, H = size
    assert 0 <= x0 and 0 <= y0 and x0 + art.width <= W * SS and y0 + art.height <= H * SS, (
        f"{capture} escapes the canvas: "
        f"{(x0 / SS, y0 / SS, (x0 + art.width) / SS, (y0 + art.height) / SS)} in {W}x{H}"
    )


def build(fmt: str, locale: str, concept: str, head: str, sub: str, accent,
          captures: list[str], clean: bool) -> Image.Image:
    spec = FORMATS[fmt]
    W, H = spec["size"]
    src = CAPTURES / locale / "phone"

    fan = spec["clean" if clean else "phones"]
    front = fan[-1]
    bg = backdrop((W, H), (front[3][0], front[3][1]),
                  spec["clean_radii" if clean else "radii"])
    # Drawn at 1x and upscaled, unlike everything else on the canvas: it is a
    # broad gradient with no detail for the extra resolution to carry, and the
    # final LANCZOS pass takes it back to where it started.
    canvas = np.array(bg.resize((W * SS, H * SS), Image.BICUBIC), dtype=np.uint8)

    for which, height, angle, centre in fan:
        place(canvas, src, captures[which], height, angle, centre, spec["blur"], (W, H))

    if not clean:
        layer = overlay(fmt, head, sub, accent)
        check_safe_area(layer, fmt, locale, concept)
        over(canvas, premultiplied(layer), 0, 0)

    return Image.fromarray(canvas, "RGB").resize((W, H), Image.LANCZOS)


def build_locale(locale: str, formats: list[str], sets: list[bool]) -> None:
    src = CAPTURES / locale / "phone"
    wanted = {c for _k, _h, _s, _a, caps in store_copy.ads(locale) for c in caps}
    missing = sorted(c for c in wanted if not (src / f"{c}.png").exists())
    if missing:
        sys.exit(f"missing captures in {src}: {', '.join(missing)}")

    play = store_copy.PLAY[locale]
    for fmt in formats:
        W, H = FORMATS[fmt]["size"]
        for clean in sets:
            out = OUT / play / (f"{fmt}-clean" if clean else fmt)
            out.mkdir(parents=True, exist_ok=True)
            for i, (concept, head, sub, accent, captures) in enumerate(store_copy.ads(locale)):
                img = build(fmt, locale, concept, head, sub, accent, captures, clean)
                assert (img.width, img.height) == (W, H) and img.mode == "RGB", (fmt, img.size)
                dest = out / f"{i + 1:02d}-{concept}.png"
                img.save(dest, optimize=True)
                size = dest.stat().st_size
                assert size <= MAX_BYTES, (
                    f"{dest} is {size / 1e6:.2f} MB, over the Ads 5 MB limit"
                )
                print(f"  {play}  {out.name:17s} {dest.name:16s} "
                      f"{W}x{H}  {size / 1024:6.0f} KB")


def main() -> None:
    args = list(sys.argv[1:])
    formats = list(FORMATS)
    if "--formats" in args:
        i = args.index("--formats")
        formats = args[i + 1].split(",")
        del args[i:i + 2]
    unknown = [f for f in formats if f not in FORMATS]
    if unknown:
        sys.exit("unknown format(s): %s" % ", ".join(unknown))

    sets = [False, True]
    if "--no-clean" in args:
        args.remove("--no-clean")
        sets = [False]

    locales = args or ["en"]
    unknown = [loc for loc in locales if loc not in store_copy.LOCALES]
    if unknown:
        sys.exit("unknown locale(s): %s" % ", ".join(unknown))

    for locale in locales:
        build_locale(locale, formats, sets)


if __name__ == "__main__":
    main()
