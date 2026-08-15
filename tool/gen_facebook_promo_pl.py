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
# Three independent Polish drafts were written and each judged by a native
# reader against the source. Everything below is either lifted from the app's
# own pl ARB / the pl-PL listing, or is a line all three passes agreed on. Four
# corrections are baked in, and each was a real fault:
#
# - **No blanket "nic się nigdzie nie wysyła" and no "bez chmury".** True of the
#   PHOTOS, false of the app: it initialises AdMob, fetches a UMP consent form
#   and queries Play billing on launch. The pl-PL listing is careful about this
#   ("Internet służy do reklam i zakupów", details.md:67) and so is the app's own
#   privacy screen. Every privacy claim here is scoped to the photos.
# - **No "liczone/liczy się na telefonie".** A word-for-word calque of English
#   "computed on your phone" that the app's Polish never uses; the listing heads
#   its section "AI, KTÓRE DZIAŁA NA TWOIM TELEFONIE".
# - **Półpauza in a numeric range**, not a hyphen - "2–5", the way app_pl.arb:52
#   already writes it.
# - **The chips name controls that exist.** "Usuwanie tła przez AI" is
#   app_pl.arb:362 verbatim; "Eksport i udostępnianie" is :416. There is no panel
#   called "Usuwanie obiektów" - it is a tab, "Usuń obiekt" (:240).
EYEBROW = "PRYWATNY EDYTOR ZDJĘĆ"
HEADLINE = ["Twoje zdjęcia"]
HEADLINE_ACCENT = "zostają w telefonie."
SUB = "Każde narzędzie AI działa na urządzeniu. Bez konta."

FEATURES = [
    "Usuwanie tła przez AI",
    "Usuń obiekt, tło zostaje",
    "Warstwy, tekst i dymki",
    "14 filtrów, HDR i winieta",
    "Kolaż z 2–5 zdjęć",
    "Eksport i udostępnianie",
]

PRIVACY_TITLE = "Prywatność nie jest tu dodatkiem"
PRIVACY_BODY = "Zdjęcia nie opuszczają telefonu. Bez konta i logowania."
# Said out loud, because the graphic leads with two features that cost a
# rewarded ad per session for a free user. "Za darmo" beside a privacy panel and
# no mention of ads composes into "ad-free and tracker-free", which is the one
# thing this app is not - and the listing discloses it in full.
PRIVACY_NOTE = "Za darmo. Reklamy usuwa jeden opcjonalny zakup."

# Neutral rather than "Za darmo w Google Play": the free/ads trade is stated in
# the panel above, and the official Polish badge wording is this.
CTA = "Pobierz z Google Play"

# --- the pictures -----------------------------------------------------------
# Back to front. The cut-out result is the front phone because it is the single
# most legible thing the app does at thumbnail size; the collage and the
# object-removal panel behind it say there is more than one trick. Tilt is 8
# degrees, not one or two - a small angle reads as a mistake (gen_ads_assets).
# (capture, height, tilt, centre). Heights are chosen against the vertical
# budget in `feed()`, not by eye: a TILTED phone's bounding box is taller than
# the phone, by height*cos(a) + width*sin(a), and forgetting that is how a
# device ends up clipped square along one edge.
FEED_PHONES = [
    ("grid", 384, -9.0, (296, 762)),
    ("objremove_panel", 384, 9.0, (784, 762)),
    ("cutout_result", 442, 0.0, (540, 752)),
]
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


def bullets(draw: ImageDraw.ImageDraw, x: int, y: int, width: int,
            cols: int, size: int, row_h: int, gap: int) -> int:
    """The feature list, as a grid of dot-marked lines. Returns the bottom y.

    A dot rather than a chip outline: six capsules at this size is a lot of
    stroked geometry competing with the phones, and the list reads as a list
    without them.
    """
    f = font(BODY, size, "Medium")
    col_w = (width - gap * (cols - 1)) // cols
    rows = (len(FEATURES) + cols - 1) // cols
    for i, item in enumerate(FEATURES):
        cx = x + (i % cols) * (col_w + gap)
        cy = y + (i // cols) * row_h
        r = 5
        draw.ellipse((s(cx), s(cy + size / 2 - r + 2), s(cx + 2 * r), s(cy + size / 2 + r + 2)),
                     fill=CYAN)
        fits(draw, item, f, col_w - 2 * r - 14, "feature %d" % (i + 1))
        draw.text((s(cx + 2 * r + 14), s(cy)), item, font=f, fill=MUTED)
    return y + rows * row_h


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

    # The bloom haloes the PHONES, not the type. At (540, 300) it sat directly
    # behind the headline and took the cyan accent line to 1.22:1; the guard
    # below is what says so, and moving it here is the fix.
    bg = backdrop((W, H), (540, 790), (520.0, 620.0, 900.0, 1000.0))
    flat = np.asarray(bg.convert("RGB"), dtype=np.float64)
    canvas = np.array(bg.resize((W * SS, H * SS), Image.BICUBIC), dtype=np.uint8)

    # The fan sits under the copy; place() asserts each tilted box stays on the
    # canvas, and FAN_TOP/FAN_BOTTOM below assert it stays clear of the copy.
    for capture, height, angle, centre in FEED_PHONES:
        place(canvas, CAPTURES, capture, height, angle, centre, BLUR, (W, H))

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
    hf = font(DISPLAY, 58, "Bold")
    for line in HEADLINE:
        fits(draw, line, hf, col, "headline")
        contrast(flat, line, font_1x(DISPLAY, 58, "Bold"), (margin, y), TEXT,
                 "headline", large=True)
        draw.text((s(margin), s(y)), line, font=hf, fill=TEXT)
        y += 68
    fits(draw, HEADLINE_ACCENT, hf, col, "headline accent")
    contrast(flat, HEADLINE_ACCENT, font_1x(DISPLAY, 58, "Bold"), (margin, y),
             CYAN, "headline accent", large=True)
    draw.text((s(margin), s(y)), HEADLINE_ACCENT, font=hf, fill=CYAN)
    y += 68 + 22

    draw.rounded_rectangle((s(margin), s(y), s(margin + 76), s(y + 7)),
                           radius=s(4), fill=CYAN)
    y += 7 + 24

    sf = font(BODY, 25, "Medium")
    fits(draw, SUB, sf, col, "subtitle")
    contrast(flat, SUB, font_1x(BODY, 25, "Medium"), (margin, y), MUTED, "subtitle")
    draw.text((s(margin), s(y)), SUB, font=sf, fill=MUTED)
    copy_bottom = y + 34

    # The fan's real extent, tilt included, so the two asserts below are about
    # the pixels rather than about the nominal heights.
    fan_top = min(c[1] - (h * math.cos(math.radians(abs(a)))
                          + h * 1280 / 2856 * math.sin(math.radians(abs(a)))) / 2
                  for _n, h, a, c in FEED_PHONES)
    fan_bottom = max(c[1] + (h * math.cos(math.radians(abs(a)))
                             + h * 1280 / 2856 * math.sin(math.radians(abs(a)))) / 2
                     for _n, h, a, c in FEED_PHONES)
    assert copy_bottom < fan_top, (
        "the subtitle at %d runs into the fan at %.0f" % (copy_bottom, fan_top))

    # --- below the fan ---
    y = round(fan_bottom) + 34
    y = bullets(draw, margin, y, col, 2, 21, 40, 28)

    py = y + 24
    ph = 148
    panel(draw, margin, py, col, ph)
    tf = font(DISPLAY, 26, "Bold")
    bf = font(BODY, 21, "Medium")
    nf = font(BODY, 19, "Medium")
    fits(draw, PRIVACY_TITLE, tf, col - 76, "privacy title")
    fits(draw, PRIVACY_BODY, bf, col - 76, "privacy body")
    fits(draw, PRIVACY_NOTE, nf, col - 76, "privacy note")
    draw.text((s(margin + 34), s(py + 26)), PRIVACY_TITLE, font=tf, fill=TEXT)
    draw.text((s(margin + 34), s(py + 66)), PRIVACY_BODY, font=bf, fill=MUTED)
    draw.text((s(margin + 34), s(py + 100)), PRIVACY_NOTE, font=nf, fill=MUTED)
    assert py + ph <= H - 48, (
        "the privacy panel ends at %d, past the %d bottom margin" % (py + ph, H - 48))

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

    sf = font(BODY, 21, "Medium")
    for line in (SUB, PRIVACY_BODY.split(". ")[0] + "."):
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
