"""Generate the 1.3.0 release promo graphics.

Third in the per-release line after `gen_update_promo.py` (1.2.0, six
languages). Same brand furniture as the general pitch - backdrop, logo,
wordmark, CTA pill, eyebrow, headline, accent rule - imported from
`gen_social_promo` rather than restated, so a change to one is a change to all.

**The composition is a before/after, not a rack of phones, because this release
is about a RESULT rather than a surface.** 1.2.0 could be shown with three
devices in three languages: the news was on the screen. 1.3.0's news is what
happens to the photo - the object is gone and the background behind it is
really there - and a phone bezel at this size shrinks that to a thumbnail of
itself. Two panels, side by side, at the size the change is legible.

**Both panels are real output of the app's own models**, produced by
`tool/gen_fill_demo.py`: MobileSAM turned three taps into three masks and MI-GAN
synthesised what was behind them, with the app's own window, dilation, seam and
composite. Nothing here is retouched, and the photograph is CC0 (see
`assets/store/samples/SOURCES.json`) because a promo graphic is commercial use
of every pixel in it, exactly as a Play listing is.

Two formats, for the two ways LinkedIn shows an image - the same split
`gen_linkedin_giveaway.py` makes and for the same reason:

- **1200x1200** for a native image post, where the feed gives an upload the most
  height. Copy on top, the pair beneath it.
- **1200x628** for a link share, where the card is wide and short. Copy takes a
  narrow left column and the pair takes the right.

The copy is PAINTED IN and cannot reflow, so `fits()` measures the drawn result
against the column it has to live in rather than trusting the layout numbers -
the same discipline `tool/store_copy.py` and `tool/measure_labels.py` apply.

Run: python tool/gen_release_promo.py
Out: assets/store/social/linkedin-update-1-3-0{,-landscape}.png
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(Path(__file__).resolve().parent))

from gen_social_promo import (  # noqa: E402
    CYAN,
    INK,
    SS,
    TEXT_PRIMARY,
    TEXT_SECONDARY,
    background,
    font,
    over,
    premultiplied,
    s,
)
from gen_store_screens import drop_shadow  # noqa: E402

SOCIAL = ROOT / "assets/store/social"
# The "before" is the untouched CC0 sample itself - the same file the Play
# listing's Effects shot is taken on - rather than a copy of it written out
# beside the result. One photo, one place.
BEFORE = ROOT / "assets/store/samples/landscape.jpg"
AFTER = SOCIAL / "fill-after.png"

VERSION = "UPDATE 1.3.0"
HEADLINE = ["Remove it.", "Keep the view."]
SUB = "Object removal now rebuilds the background behind what you take out."
# Under the pair. It does NOT count taps and does NOT say "flight mode", and
# both omissions are deliberate. Object removal sits behind the shared AI ad
# gate (`_ensureAiAllowed`, editor_screen.dart:3277): on a free install the
# first AI action of a session opens a "watch a short ad / Go Pro" sheet, and a
# user who has declined ad consent is blocked outright. So a caption promising
# "three taps, in flight mode" describes a Pro session and invites the one
# reader most likely to check - the person who installs because of this - to
# find an ad sheet in the middle of the demonstration. What is unconditionally
# true is where the work happens.
CAPTION = "Rebuilt on the phone, from the rest of the photo. Nothing uploaded."

# The rest of THIS release, in the order it matters. Two traps here, both caught
# by checking the git log rather than the release notes:
#
# - "Light & dark" belongs to 1.2.0 (d8aba79), as do the six languages. What
#   1.3.0 did to the theme is make every screen-covering surface pure #000000 /
#   #FFFFFF (06a777a), which is a different and smaller claim.
# - "Sliders for any layer" is the overclaim the website carried too: a photo
#   filling a grid cell is clamped to cover its cell and gets none of the four.
CHIPS = ["Fill in or Erase", "Snapping", "Placement sliders", "True black on OLED"]

# A 3:2 window on the demo photo, centred on where the tower viewer was. The
# same crop for both panels, or the pair stops being a comparison.
CROP = (230, 300, 1370, 1060)

CARD_RADIUS = 18
TAG_BEFORE = "BEFORE"
TAG_AFTER = "AFTER"


def fits(draw: ImageDraw.ImageDraw, text: str, f, limit_px: int, what: str) -> None:
    """Painted copy cannot wrap or ellipsize - it runs off the edge. Measure."""
    width = draw.textlength(text, font=f)
    if width > limit_px:
        sys.exit("%s is %.0fpx drawn but only %.0fpx is available: %r"
                 % (what, width / SS, limit_px / SS, text))


def panel(path: Path, width: int, height: int) -> Image.Image:
    """One card of the pair: the crop, resized, with rounded corners.

    Rounded by an alpha mask drawn at SS and never resampled afterwards, so the
    corner survives the single final downsample instead of stair-casing.
    """
    src = Image.open(path).convert("RGB").crop(CROP)
    art = src.resize((width, height), Image.LANCZOS)
    mask = Image.new("L", (width, height), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, width - 1, height - 1), radius=s(CARD_RADIUS), fill=255
    )
    out = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    out.paste(art, (0, 0))
    out.putalpha(mask)
    return out


def wipe(width: int, height: int, at: float = 0.5) -> Image.Image:
    """One card that is BEFORE on the left of a seam and AFTER on the right.

    The wide format cannot take two cards stacked - they overflow 628 - and side
    by side at this width they are too small to read the change in. A wipe is
    the same comparison in one frame, and it happens to be free here: the object
    sits at 0.31..0.68 of the crop, so a seam down the middle cuts through it
    and the two halves differ exactly where the eye is already looking.
    """
    before = Image.open(BEFORE).convert("RGB").crop(CROP).resize(
        (width, height), Image.LANCZOS)
    after = Image.open(AFTER).convert("RGB").crop(CROP).resize(
        (width, height), Image.LANCZOS)
    seam = round(width * at)
    art = before.copy()
    art.paste(after.crop((seam, 0, width, height)), (seam, 0))
    d = ImageDraw.Draw(art)
    d.rectangle((seam - max(1, SS), 0, seam + max(1, SS), height),
                fill=(0xF4, 0xF5, 0xF7))

    mask = Image.new("L", (width, height), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, width - 1, height - 1), radius=s(CARD_RADIUS), fill=255)
    out = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    out.paste(art, (0, 0))
    out.putalpha(mask)
    return out


def tag(draw: ImageDraw.ImageDraw, x: int, y: int, text: str, accent: bool) -> None:
    """A pill on the photo. OPAQUE: a translucent one over an arbitrary photo has
    no knowable contrast, which is the same trap the website's pills fell into."""
    f = font("assets/fonts/Manrope-Variable.ttf", 22, 700)
    pad_x, pad_y = s(16), s(9)
    w = round(draw.textlength(text, font=f))
    box = (x, y, x + w + 2 * pad_x, y + s(22) + 2 * pad_y)
    draw.rounded_rectangle(box, radius=(box[3] - box[1]) // 2,
                           fill=(0x0C, 0x0D, 0x11))
    draw.text(((box[0] + box[2]) // 2, (box[1] + box[3]) // 2), text, font=f,
              fill=CYAN if accent else TEXT_PRIMARY, anchor="mm")


def chips(draw: ImageDraw.ImageDraw, y: int, centre: int, limit: int) -> None:
    """One centred row of pills, laid out from their measured widths."""
    f = font("assets/fonts/Manrope-Variable.ttf", 25, 600)
    pad, gap, height = s(20), s(12), s(48)
    widths = [round(draw.textlength(c, font=f)) + 2 * pad for c in CHIPS]
    total = sum(widths) + gap * (len(CHIPS) - 1)
    if total > limit:
        sys.exit("the chip row is %.0fpx but only %.0fpx is available"
                 % (total / SS, limit / SS))
    x = centre - total // 2
    for chip, width in zip(CHIPS, widths):
        draw.rounded_rectangle((x, y, x + width, y + height),
                               radius=height // 2,
                               fill=(0x11, 0x2A, 0x3A),
                               outline=(0x1D, 0x4A, 0x5E), width=max(1, SS))
        draw.text((x + width // 2, y + height // 2), chip, font=f,
                  fill=TEXT_PRIMARY, anchor="mm")
        x += width + gap


def header(draw: ImageDraw.ImageDraw, layer: Image.Image, right: int) -> None:
    """Logo, wordmark and the store pill - identical across the promo family."""
    logo = Image.open(ROOT / "assets/branding/logo.png").convert("RGBA")
    layer.paste(premultiplied(logo).resize((s(92), s(92)), Image.LANCZOS),
                (s(72), s(60)))
    draw.text((s(184), s(106)), "Chromis",
              font=font("assets/fonts/SpaceGrotesk-Variable.ttf", 50, 600),
              fill=TEXT_PRIMARY, anchor="lm")

    f = font("assets/fonts/Manrope-Variable.ttf", 28, 700)
    label = "Free on Google Play"
    px1, py0, py1 = s(right), s(76), s(138)
    px0 = px1 - round(draw.textlength(label, font=f)) - s(52)
    draw.rounded_rectangle((px0, py0, px1, py1), radius=(py1 - py0) // 2, fill=CYAN)
    draw.text(((px0 + px1) // 2, (py0 + py1) // 2), label, font=f,
              fill=INK, anchor="mm")


def square() -> Image.Image:
    """1200x1200: copy on top, the pair beneath."""
    W = H = 1200
    canvas = np.asarray(background().convert("RGB")).copy()[: H * SS, : W * SS]

    pair_w, gap = 528, 24
    pair_h = round(pair_w * (CROP[3] - CROP[1]) / (CROP[2] - CROP[0]))
    left = (W - (2 * pair_w + gap)) // 2
    top = 596

    for i, src in enumerate((BEFORE, AFTER)):
        art = premultiplied(panel(src, s(pair_w), s(pair_h)))
        shadow, pad = drop_shadow(art, blur=s(18), alpha=140)
        x0 = s(left + i * (pair_w + gap))
        over(canvas, shadow, x0 - pad, s(top) - pad + s(14))
        over(canvas, art, x0, s(top))

    layer = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    header(draw, layer, 1128)

    draw.text((s(74), s(196)), VERSION,
              font=font("assets/fonts/Manrope-Variable.ttf", 24, 700), fill=CYAN)

    hf = font("assets/fonts/SpaceGrotesk-Variable.ttf", 82, 700)
    for i, line in enumerate(HEADLINE):
        fits(draw, line, hf, s(W - 144), "headline line %d" % (i + 1))
        draw.text((s(72), s(240 + i * 92)), line, font=hf, fill=TEXT_PRIMARY)
    draw.rounded_rectangle((s(78), s(456), s(162), s(464)), radius=s(4), fill=CYAN)

    sf = font("assets/fonts/Manrope-Variable.ttf", 31, 500)
    fits(draw, SUB, sf, s(W - 144), "subtitle")
    draw.text((s(72), s(492)), SUB, font=sf, fill=TEXT_SECONDARY)

    for i, text in enumerate((TAG_BEFORE, TAG_AFTER)):
        tag(draw, s(left + i * (pair_w + gap) + 16), s(top + pair_h - 56), text,
            accent=i == 1)

    cf = font("assets/fonts/Manrope-Variable.ttf", 27, 500)
    fits(draw, CAPTION, cf, s(W - 144), "caption")
    draw.text((s(W // 2), s(top + pair_h + 44)), CAPTION, font=cf,
              fill=TEXT_SECONDARY, anchor="mm")

    chips(draw, s(1078), s(W // 2), s(W - 120))

    arr = canvas.copy()
    over(arr, premultiplied(layer), 0, 0)
    return Image.fromarray(arr, "RGB").resize((W, H), Image.LANCZOS)


def landscape() -> Image.Image:
    """1200x628: a narrow copy column on the left, the pair stacked on the right."""
    W, H = 1200, 628
    full = np.asarray(background().convert("RGB"))
    canvas = full[: H * SS, : W * SS].copy()

    card_w = 520
    card_h = round(card_w * (CROP[3] - CROP[1]) / (CROP[2] - CROP[0]))
    x, top = 620, (H - card_h) // 2

    art = premultiplied(wipe(s(card_w), s(card_h)))
    shadow, pad = drop_shadow(art, blur=s(18), alpha=140)
    over(canvas, shadow, s(x) - pad, s(top) - pad + s(14))
    over(canvas, art, s(x), s(top))
    assert top + card_h <= H, "the card runs off a 628-tall canvas"

    layer = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    logo = Image.open(ROOT / "assets/branding/logo.png").convert("RGBA")
    layer.paste(premultiplied(logo).resize((s(64), s(64)), Image.LANCZOS), (s(64), s(56)))
    draw.text((s(144), s(88)), "Chromis",
              font=font("assets/fonts/SpaceGrotesk-Variable.ttf", 38, 600),
              fill=TEXT_PRIMARY, anchor="lm")

    col = s(540)  # the copy column, left of the cards
    draw.text((s(64), s(168)), VERSION,
              font=font("assets/fonts/Manrope-Variable.ttf", 22, 700), fill=CYAN)

    hf = font("assets/fonts/SpaceGrotesk-Variable.ttf", 62, 700)
    for i, line in enumerate(HEADLINE):
        fits(draw, line, hf, col, "landscape headline line %d" % (i + 1))
        draw.text((s(62), s(206 + i * 70)), line, font=hf, fill=TEXT_PRIMARY)
    draw.rounded_rectangle((s(66), s(360), s(140), s(367)), radius=s(3), fill=CYAN)

    # Two hand-broken lines: the column is 540 and the sentence does not fit one.
    sf = font("assets/fonts/Manrope-Variable.ttf", 25, 500)
    for i, line in enumerate(("Object removal now rebuilds the",
                              "background behind what you take out.")):
        fits(draw, line, sf, col, "landscape subtitle line %d" % (i + 1))
        draw.text((s(64), s(392 + i * 34)), line, font=sf, fill=TEXT_SECONDARY)

    cf = font("assets/fonts/Manrope-Variable.ttf", 22, 500)
    for i, line in enumerate(("Rebuilt on the phone,", "from the rest of the photo.")):
        fits(draw, line, cf, col, "landscape caption line %d" % (i + 1))
        draw.text((s(64), s(474 + i * 30)), line, font=cf, fill=TEXT_SECONDARY)

    pf = font("assets/fonts/Manrope-Variable.ttf", 24, 700)
    label = "Free on Google Play"
    px0, py0 = s(62), s(546)
    px1 = px0 + round(draw.textlength(label, font=pf)) + s(48)
    py1 = py0 + s(54)
    draw.rounded_rectangle((px0, py0, px1, py1), radius=(py1 - py0) // 2, fill=CYAN)
    draw.text(((px0 + px1) // 2, (py0 + py1) // 2), label, font=pf, fill=INK, anchor="mm")

    tag(draw, s(x + 14), s(top + card_h - 50), TAG_BEFORE, accent=False)
    tag(draw, s(x + card_w // 2 + 14), s(top + card_h - 50), TAG_AFTER, accent=True)

    arr = canvas.copy()
    over(arr, premultiplied(layer), 0, 0)
    return Image.fromarray(arr, "RGB").resize((W, H), Image.LANCZOS)


def main() -> None:
    missing = [p for p in (BEFORE, AFTER) if not p.exists()]
    if missing:
        sys.exit("missing %s\nrun: python tool/gen_fill_demo.py --points 730,700 "
                 "745,980 625,860" % ", ".join(str(p) for p in missing))

    SOCIAL.mkdir(parents=True, exist_ok=True)
    for name, img in (("linkedin-update-1-3-0.png", square()),
                      ("linkedin-update-1-3-0-landscape.png", landscape())):
        path = SOCIAL / name
        img.save(path)
        print("  %-38s %dx%d  %d KB"
              % (name, img.width, img.height, path.stat().st_size // 1024))


if __name__ == "__main__":
    main()
