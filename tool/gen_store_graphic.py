"""Generate the Google Play feature graphic (1024x500).

Three real app screens, fanned in perspective, with the pitch beside them: this
is a general photo editor - layers, filters, collages, text - that happens to
have AI cut-out, not an AI cut-out app that also crops. The cards are the same
captures the store screenshots use (`build/shots`, see the README), so nothing
here is a mock-up: Play rejects listings whose graphics promise something the
app does not do.

The perspective is a real y-axis rotation, not a shear: each card's near edge is
drawn taller than its far edge and the source is resampled through the matching
projective transform, which is why the UI inside converges the way a photograph
of a phone would.

Play crops and overlays this image differently across its surfaces, so all text
sits inside SAFE_X / SAFE_Y and the cards carry the right-hand side, where a crop
costs the least. The output is opaque RGB: the feature graphic must not have an
alpha channel.

Run: python tool/gen_store_graphic.py [src-dir]   (default build/shots)
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1024, 500
OUT = Path("assets/branding/feature_graphic.png")
ICON = Path("assets/branding/appicon.png")
DISPLAY = Path("assets/fonts/SpaceGrotesk-Variable.ttf")
BODY = Path("assets/fonts/Manrope-Variable.ttf")

# Keep every glyph this far from the edges; Play crops this graphic to several
# aspect ratios and puts its own chrome over parts of it.
SAFE_X, SAFE_Y = 64, 52

# The app's own surfaces (AppColors.pageBackground / background), so the store
# tile and the first screen a user sees are the same colour.
BG_TOP = (12, 30, 46)
BG_BOTTOM = (6, 13, 22)
TEXT = (234, 241, 248)
MUTED = (159, 188, 214)
CYAN = (23, 182, 214)

CARD_RADIUS = 26  # in source-capture pixels, before the perspective transform

# (capture, centre x, centre y, width, height, roll°, yaw)
#
# Back cards first: they are composited in this order, so the last one is the
# one in front. Yaw is the fraction by which the far vertical edge shrinks - the
# outer two turn away from the viewer, the front one is nearly square on.
# Three different screens on purpose: a collage, a cut-out and a filtered photo.
# The first draft used grid and layers behind, and both are captures of the same
# collage project - side by side they read as one screen printed twice.
#
# All three run off the bottom edge. A fan that stops short of it floats; letting
# it bleed is what makes the cards look like objects on a surface.
# The fan sits far enough right to clear the headline. Measured, not eyeballed:
# the back-left card's leading edge is a slanted line, so its bounding box says
# nothing useful - at the first placement that edge crossed x=541 at the very row
# where "that runs on your phone" ends at x=541, i.e. exactly touching.
CARDS = [
    ("grid", 674, 300, 176, 456, -11.0, +0.10),
    ("sticker", 940, 298, 176, 456, +11.0, -0.10),
    ("effects", 810, 300, 206, 500, -3.0, +0.03),
]


def font(path: Path, size: int, weight: str) -> ImageFont.FreeTypeFont:
    f = ImageFont.truetype(str(path), size)
    try:
        f.set_variation_by_name(weight)
    except OSError:
        pass  # static font, or that named instance is absent
    return f


def backdrop() -> Image.Image:
    """Vertical brand gradient with a teal bloom behind the cards."""
    yy = np.linspace(0, 1, H)[:, None]
    base = np.stack(
        [np.full((H, W), BG_TOP[i]) * (1 - yy) + np.full((H, W), BG_BOTTOM[i]) * yy for i in range(3)],
        axis=-1,
    )
    # Centred on the cards rather than the middle, so they read as lit rather
    # than pasted on.
    gy, gx = np.mgrid[0:H, 0:W]
    d = np.hypot((gx - 810) / 460.0, (gy - 250) / 360.0)
    base += (np.clip(1 - d, 0, 1) ** 2.0)[..., None] * np.array([26, 124, 146], float)
    # Dither before quantising. A gradient this shallow crosses each 8-bit step
    # over ~30 px, and the eye reads those steps as horizontal bands; a little
    # noise breaks the step into a boundary no one can see.
    base += np.random.default_rng(7).uniform(-0.5, 0.5, base.shape)
    return Image.fromarray(np.clip(base, 0, 255).round().astype(np.uint8), "RGB")


def rounded_mask(size: tuple[int, int], radius: int, ss: int = 4) -> Image.Image:
    """Antialiased rounded-rect mask, drawn oversampled then downsampled."""
    big = Image.new("L", (size[0] * ss, size[1] * ss), 0)
    ImageDraw.Draw(big).rounded_rectangle(
        [0, 0, size[0] * ss - 1, size[1] * ss - 1], radius=radius * ss, fill=255
    )
    return big.resize(size, Image.LANCZOS)


def card(capture: Path, height_px: int) -> Image.Image:
    """A capture as a rounded card with a hairline edge, RGBA.

    Rendered at roughly twice the size it will occupy so the projective
    transform - which samples the source - has detail to work with; PIL's
    PERSPECTIVE resample is bilinear, and feeding it an already-minified source
    is what makes mockup screens look mushy.
    """
    shot = Image.open(capture).convert("RGB")
    h = height_px * 2
    w = round(shot.width * h / shot.height)
    shot = shot.resize((w, h), Image.LANCZOS)

    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.paste(shot, (0, 0))
    out.putalpha(rounded_mask((w, h), CARD_RADIUS * 2))

    # A hairline lighter than the screen, so a black panel separates from the
    # dark background instead of bleeding into it.
    edge = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(edge).rounded_rectangle(
        [0, 0, w - 1, h - 1], radius=CARD_RADIUS * 2, outline=(125, 155, 180, 165), width=3
    )
    return Image.alpha_composite(out, edge)


def quad(cx: float, cy: float, w: float, h: float, roll: float, yaw: float):
    """Destination corners (TL, TR, BR, BL) for a card rotated about y then z.

    `yaw` shrinks one vertical edge relative to the other, which is what a
    y-axis rotation does to a rectangle in a pinhole projection; `roll` then
    spins the whole quad in the picture plane.
    """
    hl, hr = h * (1 - yaw) / 2, h * (1 + yaw) / 2
    pts = [(-w / 2, -hl), (w / 2, -hr), (w / 2, hr), (-w / 2, hl)]
    a = math.radians(roll)
    ca, sa = math.cos(a), math.sin(a)
    return [(cx + x * ca - y * sa, cy + x * sa + y * ca) for x, y in pts]


def perspective_coeffs(dst, src):
    """Coefficients for Image.transform(PERSPECTIVE), which maps dst -> src."""
    a, b = [], []
    for (dx, dy), (sx, sy) in zip(dst, src):
        a.append([dx, dy, 1, 0, 0, 0, -sx * dx, -sx * dy])
        b.append(sx)
        a.append([0, 0, 0, dx, dy, 1, -sy * dx, -sy * dy])
        b.append(sy)
    return np.linalg.lstsq(np.array(a, float), np.array(b, float), rcond=None)[0]


def project(img: Image.Image, dst, size: tuple[int, int]) -> Image.Image:
    """Warp `img` so its corners land on `dst`, on a transparent `size` canvas."""
    src = [(0, 0), (img.width, 0), (img.width, img.height), (0, img.height)]
    return img.transform(
        size, Image.PERSPECTIVE, perspective_coeffs(dst, src), Image.BICUBIC, fillcolor=(0, 0, 0, 0)
    )


def drop_shadow(rgba: Image.Image, blur: int, alpha: int) -> Image.Image:
    """Shadow cast by the artwork's own silhouette, same size as the input.

    The input is already a full-canvas layer with the card somewhere inside it,
    so there is room for the blur to fall - which matters, because PIL's
    GaussianBlur REPLICATES at the border and would smear any alpha touching an
    edge outward as a hard rectangle instead of fading it.
    """
    a = rgba.split()[3].filter(ImageFilter.GaussianBlur(blur)).point(lambda v: v * alpha // 255)
    shadow = Image.new("RGBA", rgba.size, (0, 0, 0, 0))
    shadow.putalpha(a)
    return shadow


def main() -> None:
    src_dir = Path(sys.argv[1] if len(sys.argv) > 1 else "build/shots")
    missing = [c[0] for c in CARDS if not (src_dir / f"{c[0]}.png").exists()]
    if missing:
        sys.exit(f"missing captures in {src_dir}: {', '.join(missing)}")

    img = backdrop()

    # ---- the cards, back to front
    for name, cx, cy, w, h, roll, yaw in CARDS:
        art = card(src_dir / f"{name}.png", h)
        dst = quad(cx, cy, w, h, roll, yaw)
        layer = project(art, dst, (W, H))
        # Offset down and away from the light, which sits with the bloom.
        shifted = project(art, [(x + 5, y + 13) for x, y in dst], (W, H))
        img.paste(drop_shadow(shifted, 16, 170), (0, 0), drop_shadow(shifted, 16, 170))
        img.paste(layer, (0, 0), layer)

    d = ImageDraw.Draw(img)

    # ---- wordmark and pitch, centred as one block.
    #
    # The wordmark is deliberately SMALLER than the headline: an icon plus a name
    # is identification, the headline is the argument, and setting the name
    # larger inverts that - which is exactly how the first draft read.
    head = ["A real photo editor", "that runs on your phone"]
    sub = [
        "Layers, 14 filters, HDR, collages, text",
        "and AI cut-out. Free, and no account.",
    ]
    brand_h, gap_head, gap_rule, gap_sub, head_lh, sub_lh = 44, 40, 22, 28, 50, 28
    block = (
        brand_h + gap_head + len(head) * head_lh + gap_rule + 4 + gap_sub + len(sub) * sub_lh
    )
    y = (H - block) // 2

    icon = Image.open(ICON).convert("RGBA").resize((brand_h, brand_h), Image.LANCZOS)
    img.paste(icon, (SAFE_X, y), icon)
    d.text((SAFE_X + 58, y + 8), "Chromis", font=font(DISPLAY, 29, "Bold"), fill=MUTED)
    y += brand_h + gap_head

    for line in head:
        d.text((SAFE_X, y), line, font=font(DISPLAY, 40, "Bold"), fill=TEXT)
        y += head_lh

    y += gap_rule
    d.rounded_rectangle([SAFE_X, y, SAFE_X + 56, y + 4], radius=2, fill=CYAN)
    y += 4 + gap_sub
    for line in sub:
        d.text((SAFE_X, y), line, font=font(BODY, 19, "Medium"), fill=MUTED)
        y += sub_lh

    assert img.mode == "RGB", "Play rejects a feature graphic with an alpha channel"
    img.save(OUT)
    print(f"wrote {OUT} ({img.width}x{img.height}, {img.mode})")


if __name__ == "__main__":
    main()
