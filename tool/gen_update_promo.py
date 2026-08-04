"""Generate the release promo graphic for 1.2.0 (six languages).

Companion to gen_social_promo.py, which pitches the app in general and does not
change between releases. This one has a single job: say what a given update
added, with a picture that proves it.

Same brand furniture as the general promo - backdrop, logo, wordmark, CTA pill,
headline, accent rule - and it imports them rather than restating them, so a
change to one is a change to both. What is different is the composition:

- **Three phones, upright and apart, not fanned.** The general promo overlaps
  its phones because it is showing "one app, many tools". This one is showing
  "one app, many languages", which only reads if each device is separate and
  labelled, and a caption cannot sit under a phone that another phone is lying
  on top of.
- **Each phone is a different language**, taken from that language's own
  capture set - the same directories the Play listing is built from, so nothing
  here is a mock-up.
- The chip row names all six, because three phones cannot.

The in-device text is far too small to read at this size, and that is expected:
the phones say "this is a real app in a language that is not English" and the
labels say which. Legibility lives in the headline and the chips.

Run: python tool/gen_update_promo.py
Output: assets/store/social/linkedin-update-1-2-0.png (1200x1200)
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
    H,
    INK,
    SS,
    TEXT_PRIMARY,
    TEXT_SECONDARY,
    W,
    background,
    font,
    framed,
    over,
    premultiplied,
    s,
)
from gen_store_screens import drop_shadow  # noqa: E402

OUT = ROOT / "assets/store/social/linkedin-update-1-2-0.png"
SHOTS = ROOT / "build/shots-i18n"

HEADLINE = ["Now in six", "languages."]
SUB = "Every screen, every hint, every screen reader label."

# Named in their own language, which is the point: someone who cannot read the
# rest of the graphic can still find themselves in this row. Same list, same
# order as kAppLanguages in lib/core/settings/locale_controller.dart.
CHIPS = ["English", "Polski", "Deutsch", "Español", "Français", "Čeština"]

# (locale, capture, caption). Three different SCREENS as well as three
# different languages - three copies of the same screen in different words
# reads as one screenshot repeated, which is the opposite of the claim.
PHONES = [
    ("pl", "home", "Polski"),
    ("de", "effects", "Deutsch"),
    ("fr", "grid", "Français"),
]

PHONE_H = 480          # 1x, giving 215 wide at the capture's 1280x2856
PHONE_GAP = 100
PHONE_TOP = 640
CHIPS_Y = 548
LABEL_Y = 1152


def columns() -> tuple[int, int]:
    """(phone width, x of the left phone). Used by both halves of the render,
    so the captions cannot drift away from the phones they name."""
    phone_w = round(PHONE_H * 1280 / 2856)
    return phone_w, (W - (3 * phone_w + 2 * PHONE_GAP)) // 2


def chips(draw: ImageDraw.ImageDraw, y: int) -> None:
    """One centred row of pills. Measured, then laid out from the true width."""
    f = font("assets/fonts/Manrope-Variable.ttf", 26, 600)
    pad, gap, height = s(22), s(14), s(50)
    widths = [round(draw.textlength(c, font=f)) + 2 * pad for c in CHIPS]
    x = (W * SS - sum(widths) - gap * (len(CHIPS) - 1)) // 2
    for chip, width in zip(CHIPS, widths):
        draw.rounded_rectangle(
            (x, s(y), x + width, s(y) + height),
            radius=height // 2,
            fill=(0x11, 0x2A, 0x3A),
            outline=(0x1D, 0x4A, 0x5E),
            width=max(1, SS),
        )
        draw.text((x + width // 2, s(y) + height // 2), chip, font=f,
                  fill=TEXT_PRIMARY, anchor="mm")
        x += width + gap


def overlay() -> Image.Image:
    """Everything drawn rather than photographed. Straight-alpha RGBA."""
    layer = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    logo = Image.open(ROOT / "assets/branding/logo.png").convert("RGBA")
    layer.paste(premultiplied(logo).resize((s(92), s(92)), Image.LANCZOS), (s(72), s(60)))
    draw.text((s(184), s(106)), "Chromis",
              font=font("assets/fonts/SpaceGrotesk-Variable.ttf", 50, 600),
              fill=TEXT_PRIMARY, anchor="lm")

    pill_font = font("assets/fonts/Manrope-Variable.ttf", 28, 700)
    label = "Free on Google Play"
    px1, py0, py1 = s(1128), s(76), s(138)
    px0 = px1 - round(draw.textlength(label, font=pill_font)) - s(52)
    draw.rounded_rectangle((px0, py0, px1, py1), radius=(py1 - py0) // 2, fill=CYAN)
    draw.text(((px0 + px1) // 2, (py0 + py1) // 2), label, font=pill_font,
              fill=INK, anchor="mm")

    eyebrow = font("assets/fonts/Manrope-Variable.ttf", 24, 700)
    draw.text((s(74), s(196)), "UPDATE 1.2.0", font=eyebrow, fill=CYAN)

    headline = font("assets/fonts/SpaceGrotesk-Variable.ttf", 82, 700)
    draw.text((s(72), s(240)), HEADLINE[0], font=headline, fill=TEXT_PRIMARY)
    draw.text((s(72), s(332)), HEADLINE[1], font=headline, fill=TEXT_PRIMARY)
    draw.rounded_rectangle((s(78), s(456), s(162), s(464)), radius=s(4), fill=CYAN)

    draw.text((s(72), s(492)), SUB,
              font=font("assets/fonts/Manrope-Variable.ttf", 32, 500),
              fill=TEXT_SECONDARY)

    chips(draw, CHIPS_Y)

    caption = font("assets/fonts/Manrope-Variable.ttf", 27, 600)
    phone_w, left = columns()
    for i, (_loc, _shot, text) in enumerate(PHONES):
        cx = left + i * (phone_w + PHONE_GAP) + phone_w // 2
        draw.text((s(cx), s(LABEL_Y)), text, font=caption,
                  fill=TEXT_SECONDARY, anchor="mm")
    return layer


def main() -> None:
    missing = [
        f"{loc}/{shot}" for loc, shot, _ in PHONES
        if not (SHOTS / loc / "phone" / f"{shot}.png").exists()
    ]
    if missing:
        sys.exit(f"missing captures under {SHOTS}: {', '.join(missing)}\n"
                 "run tool/capture_store_shots.py first")

    canvas = np.asarray(background().convert("RGB")).copy()

    phone_w, left = columns()
    for i, (loc, shot, _text) in enumerate(PHONES):
        art = premultiplied(framed(shot, PHONE_H, src=SHOTS / loc / "phone"))
        shadow, pad = drop_shadow(art, blur=s(20), alpha=150)
        x0 = s(left + i * (phone_w + PHONE_GAP))
        y0 = s(PHONE_TOP)
        over(canvas, shadow, x0 - pad, y0 - pad + s(18))
        over(canvas, art, x0, y0)
        assert y0 + art.height <= s(LABEL_Y) - s(16), "a phone runs into its caption"

    img = Image.fromarray(canvas, "RGB")
    layer = premultiplied(overlay())
    arr = np.asarray(img).copy()
    over(arr, layer, 0, 0)
    img = Image.fromarray(arr, "RGB").resize((W, H), Image.LANCZOS)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT)
    print(f"wrote {OUT} ({img.width}x{img.height}), rendered at {W * SS}x{H * SS}")


if __name__ == "__main__":
    main()
