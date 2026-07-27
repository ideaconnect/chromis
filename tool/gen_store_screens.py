"""Compose the eight Google Play screenshots from device captures.

Two sets, one caption list. Play accepts either orientation for a phone
screenshot and the two crop differently in its carousels, so both are built from
the same `SHOTS` table - the wording and the verified counts cannot drift apart:

  portrait   1080x1920  `assets/store/screenshots/portrait/`
  landscape  1920x1080  `assets/store/screenshots/landscape/`

Neither canvas matches the device. The captures are 1280x2856 (aspect 0.448),
portrait Play art is 0.5625 and landscape is 1.78, so the phone can never fill
the frame and the leftover is used deliberately: in landscape the phone takes one
side and the claim takes the other; in portrait the claim sits above a whole,
uncropped device. That padding is the layout, not an apology for it - at the size
Play actually renders these the UI inside the phone is illegible and the caption
is the only thing a browsing user reads.

Every number in the captions is verified against the source, not the website:
14 filter looks (`PhotoFilter` lists 15 including "Original"), 16 blend modes
(`LayerBlend`), 18 grid layouts (`gridTemplates`, 4+4+5+5), 5 bundled caption
fonts (`AppFonts.bundledFonts`).

The captures come from `adb exec-out screencap -p` with the Pro entitlement set,
so no ad is showing - an ad slot is not a product feature and Play crops these
into places an ad would only confuse. See the README.

Run: python tool/gen_store_screens.py [src-dir]   (default build/shots)
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = Path("assets/store/screenshots")
ICON = Path("assets/branding/appicon.png")
DISPLAY = Path("assets/fonts/SpaceGrotesk-Variable.ttf")
BODY = Path("assets/fonts/Manrope-Variable.ttf")

PHONE_RADIUS_PER_PX = 46 / 936  # the device corner, as a fraction of screen height

# The app's own surfaces (AppColors.pageBackground / background).
BG_TOP = (12, 30, 46)
BG_BOTTOM = (6, 13, 22)
TEXT = (236, 243, 249)
MUTED = (150, 180, 205)
CYAN = (23, 182, 214)

# (source capture, headline, supporting line, accent)
#
# Ordered as a pitch, not as a menu: the two AI shots lead because they are the
# reason to pick this app over the one already on the phone, breadth follows, and
# "free, no account" closes. Play renders the first three largest.
SHOTS = [
    (
        "cutout_result",
        "Cut the background\nout with AI",
        "Two on-device models, no upload and no account.\nEdge feather included.",
        CYAN,
    ),
    (
        "sticker",
        "Turn any photo\ninto a sticker",
        "Contour outline and drop shadow, both adjustable,\nexported as transparent PNG.",
        (120, 210, 160),
    ),
    (
        "effects",
        "14 one-tap looks,\nHDR and vignette",
        "Every look has a strength slider, and they stack\nwith the colour adjustments.",
        (240, 196, 90),
    ),
    (
        "layers",
        "Real layers, with\n16 blend modes",
        "Reorder by dragging, hide, duplicate, merge down\nor flatten the whole stack.",
        (150, 160, 255),
    ),
    (
        "grid",
        "Photo grids in\n18 layouts",
        "Drag the dividers to reweigh the cells. Every tool\nstill works inside one.",
        (120, 210, 160),
    ),
    (
        "objremove_panel",
        "Tap an object\nto remove it",
        "The segmentation model finds its outline for you.\nUndo brings it back.",
        CYAN,
    ),
    (
        "bubble",
        "Captions and\ncomic bubbles",
        "Speech, thought, shout and caption shapes,\nfive display fonts, outlines and colour.",
        (240, 140, 170),
    ),
    (
        "home",
        "Free, and it stays\non your phone",
        # NOT "no export limit": the free tier gates an export behind a rewarded
        # ad, and next to "free" that line reads as "no ads", which is a claim
        # this app cannot make.
        "No account and no watermark. Every edit is\nprocessed on the device, never uploaded.",
        (240, 196, 90),
    ),
]


def font(path: Path, size: int, weight: str) -> ImageFont.FreeTypeFont:
    f = ImageFont.truetype(str(path), size)
    try:
        f.set_variation_by_name(weight)
    except OSError:
        pass  # static font, or that named instance is absent
    return f


def backdrop(size: tuple[int, int], glow: tuple[int, int], radii) -> Image.Image:
    """Brand gradient with a teal bloom centred on `glow`.

    `radii` is (near_x, near_y, far_x, far_y) in pixels, given per format rather
    than derived from the canvas: deriving them re-tuned the landscape backdrop
    when the portrait layout was added, which would have quietly reissued eight
    already-approved store assets.
    """
    w, h = size
    near_x, near_y, far_x, far_y = radii
    yy = np.linspace(0, 1, h)[:, None]
    base = np.stack(
        [
            np.full((h, w), BG_TOP[i]) * (1 - yy) + np.full((h, w), BG_BOTTOM[i]) * yy
            for i in range(3)
        ],
        axis=-1,
    )
    gy, gx = np.mgrid[0:h, 0:w]
    # Two blooms: a bright one behind the phone so it reads as lit rather than
    # pasted on, and a wide dim one on the far side so that corner does not go
    # dead flat - a large field of near-black looks like a rendering fault.
    d = np.hypot((gx - glow[0]) / near_x, (gy - glow[1]) / near_y)
    base += (np.clip(1 - d, 0, 1) ** 1.9)[..., None] * np.array([30, 140, 166], float)
    far = np.hypot((gx - (w - glow[0])) / far_x, (gy - h * 0.62) / far_y)
    base += (np.clip(1 - far, 0, 1) ** 2.4)[..., None] * np.array([16, 52, 74], float)
    # Dither: these gradients cross each 8-bit step over ~40 px, and the eye
    # reads those steps as bands. Half a level of noise turns each into a soft
    # boundary no one can see.
    base += np.random.default_rng(11).uniform(-0.5, 0.5, base.shape)
    return Image.fromarray(np.clip(base, 0, 255).round().astype(np.uint8), "RGB")


def rounded_mask(size: tuple[int, int], radius: int, ss: int = 4) -> Image.Image:
    """Antialiased rounded-rect mask, drawn oversampled then downsampled."""
    big = Image.new("L", (size[0] * ss, size[1] * ss), 0)
    ImageDraw.Draw(big).rounded_rectangle(
        [0, 0, size[0] * ss - 1, size[1] * ss - 1], radius=radius * ss, fill=255
    )
    return big.resize(size, Image.LANCZOS)


def phone(capture: Path, height: int) -> Image.Image:
    """The capture at `height`, rounded, with a hairline bezel. RGBA."""
    shot = Image.open(capture).convert("RGB")
    w = round(shot.width * height / shot.height)
    shot = shot.resize((w, height), Image.LANCZOS)
    radius = max(12, round(height * PHONE_RADIUS_PER_PX))

    out = Image.new("RGBA", (w, height), (0, 0, 0, 0))
    out.paste(shot, (0, 0))
    out.putalpha(rounded_mask((w, height), radius))

    # A hairline lighter than the screen, so the black panel separates from the
    # dark background instead of bleeding into it.
    edge = Image.new("RGBA", (w, height), (0, 0, 0, 0))
    ImageDraw.Draw(edge).rounded_rectangle(
        [0, 0, w - 1, height - 1], radius=radius, outline=(120, 150, 175, 150), width=2
    )
    return Image.alpha_composite(out, edge)


def drop_shadow(rgba: Image.Image, blur: int, alpha: int):
    """Shadow from the artwork's own silhouette. Returns (layer, pad).

    Padded first, and that is not optional: the phone's alpha runs to the very
    edge of its bitmap, and PIL's GaussianBlur REPLICATES at the border, so
    blurring in place smears the edge rows outward as a hard rectangle instead of
    fading. The pad gives the blur somewhere to fall; the caller offsets by it.
    """
    pad = blur * 3 + 2
    big = Image.new("RGBA", (rgba.width + 2 * pad, rgba.height + 2 * pad), (0, 0, 0, 0))
    big.paste(rgba, (pad, pad))
    a = big.split()[3].filter(ImageFilter.GaussianBlur(blur)).point(lambda v: v * alpha // 255)
    shadow = Image.new("RGBA", big.size, (0, 0, 0, 0))
    shadow.putalpha(a)
    return shadow, pad


def render_landscape(src: Path, i: int, spec, fonts) -> Image.Image:
    """1920x1080: phone at full height on one side, claim on the other."""
    W, H, MARGIN, PHONE_H = 1920, 1080, 96, 936
    name, head, sub, accent = spec
    icon, h_font, s_font, n_font = fonts["landscape"]
    head_lh, sub_lh = 108, 50
    brand_h, gap_head, gap_rule, gap_sub = 58, 62, 38, 44

    # Alternate sides so the strip has a rhythm rather than eight identical
    # slides; Play shows them in one scrolling row.
    phone_right = i % 2 == 0
    art = phone(src / f"{name}.png", PHONE_H)
    px = W - MARGIN - art.width if phone_right else MARGIN
    py = (H - art.height) // 2

    img = backdrop((W, H), (px + art.width // 2, H // 2), (700.0, 780.0, 1150.0, 900.0))
    sh, pad = drop_shadow(art, 30, 165)
    img.paste(sh, (px + 6 - pad, py + 20 - pad), sh)
    img.paste(art, (px, py), art)

    tx = MARGIN if phone_right else px + art.width + 84
    d = ImageDraw.Draw(img)

    heads, subs = head.split("\n"), sub.split("\n")
    block = (
        brand_h + gap_head
        + len(heads) * head_lh + gap_rule + 5 + gap_sub
        + len(subs) * sub_lh
    )
    y = (H - block) // 2

    img.paste(icon, (tx, y), icon)
    d.text((tx + 76, y + 11), "Chromis", font=n_font, fill=MUTED)
    y += brand_h + gap_head

    for line in heads:
        d.text((tx, y), line, font=h_font, fill=TEXT)
        y += head_lh

    y += gap_rule
    d.rounded_rectangle([tx, y, tx + 68, y + 5], radius=2, fill=accent)
    y += 5 + gap_sub
    for line in subs:
        d.text((tx, y), line, font=s_font, fill=MUTED)
        y += sub_lh
    return img


def render_portrait(src: Path, i: int, spec, fonts) -> Image.Image:
    """1080x1920: centred claim above a whole, uncropped device.

    The device is 0.448 wide-to-tall and this canvas is 0.5625, so a phone tall
    enough to clear the caption is only ~620 px wide and leaves ~230 px of field
    either side. That is the padding the format forces; it is filled with the
    bloom rather than pretended away. The alternative - sizing the phone to the
    width and letting it run off the bottom - would cut the tool panel out of
    every shot, and the panel IS the feature being demonstrated.
    """
    W, H = 1080, 1920
    TOP, BOTTOM, SIDE_MIN = 84, 64, 72
    name, head, sub, accent = spec
    icon, h_font, s_font, n_font = fonts["portrait"]
    head_lh, sub_lh = 68, 38
    gap_head, gap_rule, gap_sub, gap_phone = 44, 28, 30, 52

    heads, subs = head.split("\n"), sub.split("\n")
    brand_h = icon.height

    # Lay the caption out first; the phone gets whatever height is left.
    caption_h = (
        brand_h + gap_head + len(heads) * head_lh
        + gap_rule + 5 + gap_sub + len(subs) * sub_lh
    )
    phone_top = TOP + caption_h + gap_phone
    ph = H - phone_top - BOTTOM

    shot = Image.open(src / f"{name}.png")
    pw = round(shot.width * ph / shot.height)
    if pw > W - 2 * SIDE_MIN:  # a squarer capture would be width-bound instead
        pw = W - 2 * SIDE_MIN
        ph = round(shot.height * pw / shot.width)
    art = phone(src / f"{name}.png", ph)
    px, py = (W - art.width) // 2, phone_top

    img = backdrop((W, H), (W // 2, py + art.height // 2), (540.0, 600.0, 900.0, 705.0))
    sh, pad = drop_shadow(art, 28, 165)
    img.paste(sh, (px + 4 - pad, py + 18 - pad), sh)
    img.paste(art, (px, py), art)

    d = ImageDraw.Draw(img)
    y = TOP

    # Icon + wordmark as one centred unit.
    gap = 18
    mark_w = icon.width + gap + round(n_font.getlength("Chromis"))
    mx = (W - mark_w) // 2
    img.paste(icon, (mx, y), icon)
    d.text((mx + icon.width + gap, y + 11), "Chromis", font=n_font, fill=MUTED)
    y += brand_h + gap_head

    for line in heads:
        d.text((W // 2, y), line, font=h_font, fill=TEXT, anchor="ma")
        y += head_lh

    y += gap_rule
    d.rounded_rectangle([W // 2 - 34, y, W // 2 + 34, y + 5], radius=2, fill=accent)
    y += 5 + gap_sub
    for line in subs:
        d.text((W // 2, y), line, font=s_font, fill=MUTED, anchor="ma")
        y += sub_lh
    return img


def main() -> None:
    src = Path(sys.argv[1] if len(sys.argv) > 1 else "build/shots")
    missing = [n for n, *_ in SHOTS if not (src / f"{n}.png").exists()]
    if missing:
        sys.exit(f"missing captures in {src}: {', '.join(missing)}")

    fonts = {
        "landscape": (
            Image.open(ICON).convert("RGBA").resize((58, 58), Image.LANCZOS),
            font(DISPLAY, 92, "Bold"),
            font(BODY, 36, "Medium"),
            font(DISPLAY, 31, "Bold"),
        ),
        "portrait": (
            Image.open(ICON).convert("RGBA").resize((52, 52), Image.LANCZOS),
            font(DISPLAY, 58, "Bold"),
            font(BODY, 27, "Medium"),
            font(DISPLAY, 28, "Bold"),
        ),
    }

    for kind, render, size in (
        ("portrait", render_portrait, (1080, 1920)),
        ("landscape", render_landscape, (1920, 1080)),
    ):
        out = OUT / kind
        out.mkdir(parents=True, exist_ok=True)
        for i, spec in enumerate(SHOTS):
            img = render(src, i, spec, fonts)
            assert (img.width, img.height) == size and img.mode == "RGB", (kind, img.size)
            dest = out / f"{i + 1:02d}-{spec[0].replace('_', '-')}.png"
            img.save(dest)
        print(f"  {kind:9s} {len(SHOTS)} x {size[0]}x{size[1]} -> {out}")


if __name__ == "__main__":
    main()
