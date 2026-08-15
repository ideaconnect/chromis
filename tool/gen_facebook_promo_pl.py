"""Generate the Polish Facebook promo graphics.

Fourth in the social line, after `gen_social_promo.py` (LinkedIn, English,
general), `gen_release_promo.py` (a release) and `gen_wykop_promo.py` (one
Polish forum post). This one is the standing Polish pitch for Facebook, and
three things about it are deliberate:

- **Polish captures**, `build/shots-i18n/pl/phone` - the same directory the
  pl-PL Play listing is built from. A Polish post carrying an English
  screenshot is the tell that the app is not really translated, and it is.
- **Privacy is the payload, not a footnote.** The brief for this one is the
  features AND the fact that there is no account and nothing is uploaded, so
  the privacy line gets its own panel at the foot rather than a clause in the
  subtitle. Everything above it is the evidence that you give nothing up.
- **A pill is allowed here.** `gen_ads_assets.py` bans capsule CTAs because
  Google disapproves image assets that imitate interface features and draws its
  own Install button. Facebook does neither. Do not copy this composition back
  into the ad set.

Two formats, which is what Facebook actually shows:

- **1080x1350 (4:5)** for the feed. Portrait is the tallest thing the feed will
  give an uploaded image, so it is the one to post; the fan sits in the middle
  with copy above and the privacy panel below.
- **1200x630** for a link share, where the card is wide and short.

## Perspective and antialiasing

The phones are TILTED, and every edge in this file survives that for the same
four reasons `gen_social_promo`'s docstring sets out. They are not decoration:

1. **The whole canvas is composed at SS times final size and downsampled ONCE,
   at the end.** `ImageDraw` does not antialias - every `rounded_rectangle`
   here (chips, pills, the privacy panel, the rule) comes out stair-cased at
   1x, and a rotated phone stair-cases its long straight edges too. One final
   LANCZOS pass averages all of it away together.
2. **Anything rotated is PREMULTIPLIED first.** `place()` routes through
   `rotate_premultiplied`, because bicubic interpolates the four channels
   independently: on straight alpha that mixes the transparent fill's RGB -
   black - into the boundary pixels and leaves a dark fringe around the tilted
   device. Premultiplied transparent black is the additive identity, so the
   same interpolation is correct.
3. **Bicubic overshoot is clamped back.** Rotation at a hard alpha step can
   push a colour channel above its own alpha and break the premultiplied
   invariant; `rotate_premultiplied` re-clamps `rgb <= a`.
4. **`place()` asserts the rotated bounding box stays on the canvas.** A tilt
   grows the box, and the failure mode of forgetting that is a device clipped
   square along one edge, which reads as a rendering bug rather than a crop.

So: never rotate an image in this file by hand, and never resize the finished
composition twice. Use `place()`.

Run: python tool/gen_facebook_promo_pl.py
Out: assets/store/social/facebook-pl-{feed,link}.png
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(Path(__file__).resolve().parent))

from gen_ads_assets import BODY, DISPLAY, MUTED, TEXT, font, place  # noqa: E402
from gen_social_promo import CYAN, INK, SS, over, premultiplied, s  # noqa: E402
from gen_store_screens import backdrop  # noqa: E402

OUT = ROOT / "assets/store/social"
CAPTURES = ROOT / "build/shots-i18n/pl/phone"
LOGO = ROOT / "assets/branding/logo.png"

# --- the words --------------------------------------------------------------
# FEATURE-LED. An earlier cut led on privacy and carried the tools as a chip
# list; this one puts the tools in the headline and on five devices, and keeps
# the privacy claim to one line at the foot. What did NOT change is which
# claims are allowed, because those were checked once and the reasons stand:
#
# - **Privacy claims stay scoped to the PHOTOS.** No "bez chmury", no bare "nic
#   się nigdzie nie wysyła": true of the photos, false of an app that
#   initialises AdMob, fetches a UMP consent form and queries Play billing on
#   launch. The pl-PL listing is careful about this (details.md:67).
# - **The ads are still stated.** Two of the five features cost a rewarded ad
#   per session for a free user (`_ensureAiAllowed`), so "za darmo" on its own
#   would compose into "ad-free", which is the one thing this is not.
# - **No "liczone / liczy się na telefonie"** - a calque of English "computed
#   on your phone" that the app's own Polish never uses; it says "działa".
# - **Półpauza in a numeric range** - "2–5", as app_pl.arb:52 writes it.
# - **Every label is a control that exists.** Captions and chips below are the
#   pl ARB's own words, so the graphic names the buttons the app has.
EYEBROW = "EDYTOR ZDJĘĆ Z AI"
HEADLINE = ["Wytnij tło, zrób kolaż,"]
HEADLINE_ACCENT = "dodaj dymek."
# Not "Pięć narzędzi": the graphic names nine capabilities, the dock has seven
# tools, and none of them is bubbles - a count here is a number a reader can
# disprove by looking at the same image.
SUB = "Komplet narzędzi w jednej aplikacji. Wszystko działa na urządzeniu."

# The rest of the toolbox, under the fan. `Przyciąganie` and `Usuń obiekt` are
# 1.3.0's; the others have been there longer.
CHIPS = ["Usuwanie obiektów", "Przyciąganie warstw",
         "HDR i winieta", "Eksport i udostępnianie"]

# One line, not a panel: the brief for this cut is the tools.
PRIVACY_NOTE = "Bez konta i logowania. Zdjęcia nie są nigdzie wysyłane do obróbki."
PRICE_NOTE = "Za darmo, z reklamami, które usuwa jeden opcjonalny zakup."

CTA = "Pobierz z Google Play"

# --- the pictures --------------------------------------------------------------
# ONE DEVICE PER NAMED FEATURE, left to right in the order the copy introduces
# them, each with its own caption. Five across is what the width allows: at
# 1080 wide with 72 margins there are 936px for five slots of 187, and a phone
# 340 tall tilted 6 degrees has a bounding box 187 wide. The fan is a shallow
# sweep rather than five uprights, and the captions sit under each CENTRE so
# the tilt never makes it ambiguous which label belongs to which device.
#
# The in-device text is illegible at this size and that is expected - the
# devices say "these are five different screens of a real app" and the captions
# say which. What has to survive is the SHAPE of each: a cut-out on a
# checkerboard, a 2x2 collage, a speech bubble, a filter strip, a layer stack.
FEED_PHONES = [
    ("effects", "14 filtrów", -6.0),
    ("cutout_result", "Usuwanie tła", -3.0),
    ("layers", "Warstwy", 0.0),
    ("grid", "Siatka zdjęć", 3.0),
    ("bubble", "Dymki komiksowe", 6.0),
]
FEED_PHONE_H = 340
FEED_SLOT = 187
FEED_FAN_Y = 772

LINK_PHONES = [
    ("grid", 360, -8.0, (830, 300)),
    ("cutout_result", 430, 0.0, (990, 312)),
]
BLUR = 22


def fits(draw: ImageDraw.ImageDraw, text: str, f, limit: int, what: str) -> None:
    """Painted copy cannot wrap or ellipsize - it runs off the edge. Measure."""
    width = draw.textlength(text, font=f) / SS
    if width > limit:
        sys.exit("%s is %.0fpx drawn but only %dpx is available: %r"
                 % (what, width, limit, text))


def _luminance(rgb: np.ndarray) -> np.ndarray:
    c = np.asarray(rgb, dtype=np.float64) / 255.0
    c = np.where(c <= 0.03928, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    return 0.2126 * c[..., 0] + 0.7152 * c[..., 1] + 0.0722 * c[..., 2]


def contrast(bg: np.ndarray, text: str, f, xy: tuple[int, int], fill,
             what: str, large: bool = False) -> float:
    """Assert painted copy is legible against the pixels actually behind it.

    This is not belt-and-braces - it caught a real defect. `backdrop()` puts a
    teal bloom wherever it is told to, the first version of this file put it at
    (540, 300), and that is dead behind the headline: the cyan accent line
    measured **1.22:1** against its own background, which is invisible. Nothing
    else would have found it. The copy does not overflow, no assert fires, and
    on a dark thumbnail it looks like a design choice.

    Measured under the GLYPHS, not over their bounding band - a bounding box
    here includes the bloom's peak far to the right of where the words end and
    reports a failure that is not real. Rendered at 1x because only the glyph
    coverage matters, and a supersampled mask would measure the same pixels.
    """
    h, w = bg.shape[:2]
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).text(xy, text, font=f, fill=255)
    hit = np.asarray(mask) > 128
    if not hit.any():
        return 99.0
    fg = _luminance(np.array(fill, dtype=np.float64))
    behind = _luminance(bg[hit])
    hi = np.maximum(fg, behind)
    lo = np.minimum(fg, behind)
    worst = float(((hi + 0.05) / (lo + 0.05)).min())
    need = 3.0 if large else 4.5
    if worst < need:
        sys.exit("%s is %.2f:1 against the backdrop behind it, needs %.1f:1. "
                 "Move the bloom off the copy, or take this text off the bloom."
                 % (what, worst, need))
    return worst


def font_1x(path: str, size: int, weight: str):
    """The same face at 1x, for the contrast mask (which is measured at 1x)."""
    from PIL import ImageFont

    f = ImageFont.truetype(str(ROOT / path), size)
    try:
        f.set_variation_by_name(weight)
    except OSError:
        pass
    return f


def brand(draw: ImageDraw.ImageDraw, layer: Image.Image, x: int, y: int,
          size: int, mark: int) -> None:
    logo = premultiplied(Image.open(LOGO).convert("RGBA"))
    layer.paste(logo.resize((s(size), s(size)), Image.LANCZOS), (s(x), s(y)))
    draw.text((s(x + size + 16), s(y + size / 2)), "Chromis",
              font=font(DISPLAY, mark, "Bold"), fill=TEXT, anchor="lm")


def pill(draw: ImageDraw.ImageDraw, x: int, y: int, text: str, size: int,
         height: int, right: int | None = None) -> int:
    """A filled accent capsule, laid out from the measured label. Returns width."""
    f = font(BODY, size, "Bold")
    width = round(draw.textlength(text, font=f) / SS) + 2 * 26
    if right is not None:
        x = right - width
    draw.rounded_rectangle((s(x), s(y), s(x + width), s(y + height)),
                           radius=s(height / 2), fill=CYAN)
    draw.text((s(x + width / 2), s(y + height / 2)), text, font=f,
              fill=INK, anchor="mm")
    return width


def chips(draw: ImageDraw.ImageDraw, y: int, centre: int, limit: int) -> int:
    """One centred row of outlined capsules, laid out from measured widths.

    Returns the bottom y. Capsules rather than the dot-list the privacy cut
    used: these sit under five captioned devices, and a second column of bare
    dotted lines would read as more captions.
    """
    f = font(BODY, 20, "Medium")
    pad, gap, height = s(18), s(12), s(46)
    widths = [round(draw.textlength(c, font=f)) + 2 * pad for c in CHIPS]
    total = sum(widths) + gap * (len(CHIPS) - 1)
    if total > s(limit):
        sys.exit("the chip row is %.0fpx but only %dpx is available"
                 % (total / SS, limit))
    x = s(centre) - total // 2
    for chip, width in zip(CHIPS, widths):
        draw.rounded_rectangle((x, s(y), x + width, s(y) + height),
                               radius=height // 2,
                               fill=(0x11, 0x2A, 0x3A),
                               outline=(0x1D, 0x4A, 0x5E), width=max(1, SS))
        draw.text((x + width // 2, s(y) + height // 2), chip, font=f,
                  fill=TEXT, anchor="mm")
        x += width + gap
    return y + 46


def panel(draw: ImageDraw.ImageDraw, x: int, y: int, width: int, height: int) -> None:
    """The privacy block: a filled card with an accent edge down its left side.

    Filled and opaque rather than a hairline outline, because it is the one
    thing on the canvas that has to survive being seen at feed-thumbnail size.
    """
    draw.rounded_rectangle((s(x), s(y), s(x + width), s(y + height)),
                           radius=s(20), fill=(0x0E, 0x1E, 0x2A))
    draw.rounded_rectangle((s(x), s(y + 16), s(x + 7), s(y + height - 16)),
                           radius=s(4), fill=CYAN)


def feed() -> Image.Image:
    """1080x1350 (4:5) - the format the Facebook feed gives the most height."""
    W, H = 1080, 1350
    margin = 72
    col = W - 2 * margin

    # The bloom haloes the FAN, and both its centre and its radii are set by the
    # contrast guard rather than by eye. Two failures got it here: at (540, 300)
    # it sat behind the headline and took the cyan accent line to 1.22:1, and at
    # (540, 790) with the original wide radii it reached the captions and took
    # "Warstwy" to 4.15:1. Tightened, the captions measure 8.8:1 and the bloom
    # still lights the devices, which is the only job it has.
    bg = backdrop((W, H), (540, 700), (430.0, 470.0, 780.0, 760.0))
    flat = np.asarray(bg.convert("RGB"), dtype=np.float64)
    canvas = np.array(bg.resize((W * SS, H * SS), Image.BICUBIC), dtype=np.uint8)

    # One device per named feature, evenly spaced, in a shallow fan. place()
    # asserts each tilted box stays on the canvas.
    fan_left = margin + FEED_SLOT / 2
    centres = [fan_left + i * FEED_SLOT for i in range(len(FEED_PHONES))]
    for (capture, _label, angle), cx in zip(FEED_PHONES, centres):
        place(canvas, CAPTURES, capture, FEED_PHONE_H, angle,
              (round(cx), FEED_FAN_Y), BLUR, (W, H))

    layer = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    brand(draw, layer, margin, 64, 60, 32)
    pill(draw, 0, 74, CTA, 22, 50, right=W - margin)

    y = 168
    ef = font(BODY, 22, "Bold")
    fits(draw, EYEBROW, ef, col, "eyebrow")
    contrast(flat, EYEBROW, font_1x(BODY, 22, "Bold"), (margin, y), CYAN, "eyebrow")
    draw.text((s(margin), s(y)), EYEBROW, font=ef, fill=CYAN)

    y += 44
    hf = font(DISPLAY, 56, "Bold")
    for line in HEADLINE:
        fits(draw, line, hf, col, "headline")
        contrast(flat, line, font_1x(DISPLAY, 56, "Bold"), (margin, y), TEXT,
                 "headline", large=True)
        draw.text((s(margin), s(y)), line, font=hf, fill=TEXT)
        y += 66
    fits(draw, HEADLINE_ACCENT, hf, col, "headline accent")
    contrast(flat, HEADLINE_ACCENT, font_1x(DISPLAY, 56, "Bold"), (margin, y),
             CYAN, "headline accent", large=True)
    draw.text((s(margin), s(y)), HEADLINE_ACCENT, font=hf, fill=CYAN)
    y += 66 + 20

    draw.rounded_rectangle((s(margin), s(y), s(margin + 76), s(y + 7)),
                           radius=s(4), fill=CYAN)
    y += 7 + 22

    sf = font(BODY, 24, "Medium")
    fits(draw, SUB, sf, col, "subtitle")
    contrast(flat, SUB, font_1x(BODY, 24, "Medium"), (margin, y), MUTED, "subtitle")
    draw.text((s(margin), s(y)), SUB, font=sf, fill=MUTED)
    copy_bottom = y + 32

    # The fan's real extent, tilt included, so the asserts are about pixels
    # rather than about the nominal height.
    def _bbox_h(angle: float) -> float:
        a = math.radians(abs(angle))
        return (FEED_PHONE_H * math.cos(a)
                + FEED_PHONE_H * 1280 / 2856 * math.sin(a))

    half = max(_bbox_h(a) for _n, _l, a in FEED_PHONES) / 2
    fan_top, fan_bottom = FEED_FAN_Y - half, FEED_FAN_Y + half
    assert copy_bottom < fan_top, (
        "the subtitle at %d runs into the fan at %.0f" % (copy_bottom, fan_top))

    # --- one caption per device, under its own centre ---
    cf = font(BODY, 19, "Bold")
    cap_y = round(fan_bottom) + 30
    for (_capture, label, _angle), cx in zip(FEED_PHONES, centres):
        fits(draw, label, cf, FEED_SLOT - 8, "caption %r" % label)
        contrast(flat, label, font_1x(BODY, 19, "Bold"),
                 (round(cx - draw.textlength(label, font=cf) / SS / 2), cap_y),
                 TEXT, "caption %r" % label)
        draw.text((s(cx), s(cap_y)), label, font=cf, fill=TEXT, anchor="ma")

    # --- the rest of the toolbox ---
    y = chips(draw, cap_y + 64, W // 2, col)

    # --- the small print: privacy in one line, price in the next ---
    nf = font(BODY, 20, "Medium")
    y += 40
    for line in (PRIVACY_NOTE, PRICE_NOTE):
        fits(draw, line, nf, col, "note")
        contrast(flat, line, font_1x(BODY, 20, "Medium"),
                 (round(W / 2 - draw.textlength(line, font=nf) / SS / 2), y),
                 MUTED, "note")
        draw.text((s(W // 2), s(y)), line, font=nf, fill=MUTED, anchor="ma")
        y += 32
    assert y <= H - 48, "the small print ends at %d, past the %d margin" % (y, H - 48)

    over(canvas, premultiplied(layer), 0, 0)
    return Image.fromarray(canvas, "RGB").resize((W, H), Image.LANCZOS)


def link() -> Image.Image:
    """1200x630 - the link/OG card: copy in a left column, phones on the right."""
    W, H = 1200, 630
    margin = 72
    col = 600

    # The bloom is already over the fan on this format; the guards below hold
    # it there if the layout is ever retuned.
    bg = backdrop((W, H), (990, 312), (480.0, 520.0, 820.0, 620.0))
    flat = np.asarray(bg.convert("RGB"), dtype=np.float64)
    canvas = np.array(bg.resize((W * SS, H * SS), Image.BICUBIC), dtype=np.uint8)
    for capture, height, angle, centre in LINK_PHONES:
        place(canvas, CAPTURES, capture, height, angle, centre, BLUR, (W, H))

    layer = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    brand(draw, layer, margin, 56, 52, 28)

    y = 148
    ef = font(BODY, 20, "Bold")
    fits(draw, EYEBROW, ef, col, "link eyebrow")
    contrast(flat, EYEBROW, font_1x(BODY, 20, "Bold"), (margin, y), CYAN, "link eyebrow")
    draw.text((s(margin), s(y)), EYEBROW, font=ef, fill=CYAN)

    y += 40
    hf = font(DISPLAY, 46, "Bold")
    for line in HEADLINE:
        fits(draw, line, hf, col, "link headline")
        contrast(flat, line, font_1x(DISPLAY, 46, "Bold"), (margin, y), TEXT,
                 "link headline", large=True)
        draw.text((s(margin), s(y)), line, font=hf, fill=TEXT)
        y += 56
    fits(draw, HEADLINE_ACCENT, hf, col, "link headline accent")
    contrast(flat, HEADLINE_ACCENT, font_1x(DISPLAY, 46, "Bold"), (margin, y),
             CYAN, "link headline accent", large=True)
    draw.text((s(margin), s(y)), HEADLINE_ACCENT, font=hf, fill=CYAN)
    y += 56 + 18

    draw.rounded_rectangle((s(margin), s(y), s(margin + 68), s(y + 6)),
                           radius=s(3), fill=CYAN)
    y += 6 + 20

    # Three short lines rather than the feed's two: the column is 600px and
    # every one of these measures under 330, so they break cleanly on sentences
    # instead of being hyphenated by hand.
    sf = font(BODY, 21, "Medium")
    for line in ("Komplet narzędzi w jednej aplikacji.",
                 "Wszystko działa na urządzeniu. Bez konta.",
                 "Za darmo, z reklamami."):
        fits(draw, line, sf, col, "link privacy line")
        contrast(flat, line, font_1x(BODY, 21, "Medium"), (margin, y), MUTED,
                 "link privacy line")
        draw.text((s(margin), s(y)), line, font=sf, fill=MUTED)
        y += 30

    pill(draw, margin, y + 22, CTA, 21, 50)

    # Nothing painted may cross into the fan.
    box = layer.getbbox()
    right = box[2] / SS
    assert right <= margin + col, (
        "copy is %.0fpx wide and runs into the phones at %d" % (right - margin, col))

    over(canvas, premultiplied(layer), 0, 0)
    return Image.fromarray(canvas, "RGB").resize((W, H), Image.LANCZOS)


def main() -> None:
    wanted = {n for n, *_ in FEED_PHONES} | {n for n, *_ in LINK_PHONES}
    missing = [n for n in sorted(wanted) if not (CAPTURES / f"{n}.png").exists()]
    if missing:
        sys.exit("missing Polish captures in %s: %s\n"
                 "run: python tool/capture_store_shots.py phone pl"
                 % (CAPTURES, ", ".join(missing)))

    OUT.mkdir(parents=True, exist_ok=True)
    for name, img in (("facebook-pl-feed.png", feed()),
                      ("facebook-pl-link.png", link())):
        path = OUT / name
        img.save(path, optimize=True)
        print("  %-26s %dx%d  %d KB"
              % (name, img.width, img.height, path.stat().st_size // 1024))


if __name__ == "__main__":
    main()
