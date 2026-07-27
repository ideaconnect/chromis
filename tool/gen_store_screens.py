"""Compose the eight Google Play screenshots (1920x1080) from device captures.

Play wants a landscape canvas here, and the app is a portrait phone app, so the
screenshot cannot fill it: the phone is framed at full height on one side and the
rest of the canvas carries the claim. That padding is the point of the layout,
not an apology for it - the caption is what a browsing user actually reads at
thumbnail size, where the UI inside the phone is illegible.

Every number in the captions is verified against the source, not the website:
14 filter looks (`PhotoFilter` lists 15 including "Original"), 16 blend modes
(`LayerBlend`), 18 grid layouts (`gridTemplates`, 4+4+5+5), 5 bundled caption
fonts (`AppFonts.bundledFonts`).

The captures come from `adb exec-out screencap -p` on a 1280x2856 phone with the
Pro entitlement set, so no ad is showing - an ad slot is not a product feature
and Play crops these into places an ad would only confuse. See the README.

Run: python tool/gen_store_screens.py [src-dir]   (default build/shots)
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1920, 1080
OUT = Path("assets/store/screenshots")
ICON = Path("assets/branding/appicon.png")
DISPLAY = Path("assets/fonts/SpaceGrotesk-Variable.ttf")
BODY = Path("assets/fonts/Manrope-Variable.ttf")

MARGIN = 96
PHONE_H = 936          # leaves 72 px of breathing room top and bottom
PHONE_RADIUS = 46      # ~ the device's own corner, at this scale

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


def backdrop(glow_x: int) -> Image.Image:
    """Brand gradient with a teal bloom centred behind wherever the phone sits."""
    yy = np.linspace(0, 1, H)[:, None]
    base = np.stack(
        [
            np.full((H, W), BG_TOP[i]) * (1 - yy) + np.full((H, W), BG_BOTTOM[i]) * yy
            for i in range(3)
        ],
        axis=-1,
    )
    gy, gx = np.mgrid[0:H, 0:W]
    # Two blooms: a bright one behind the phone so it reads as lit rather than
    # pasted on, and a wide dim one under the type so the far corner does not go
    # dead flat - a 1920x1080 field of near-black looks like a rendering fault.
    d = np.hypot((gx - glow_x) / 700.0, (gy - H / 2) / 780.0)
    base += (np.clip(1 - d, 0, 1) ** 1.9)[..., None] * np.array([30, 140, 166], float)
    far = np.hypot((gx - (W - glow_x)) / 1150.0, (gy - H * 0.62) / 900.0)
    base += (np.clip(1 - far, 0, 1) ** 2.4)[..., None] * np.array([16, 52, 74], float)
    # Dither: this gradient crosses each 8-bit step over ~40 px, and the eye reads
    # those steps as bands. Half a level of noise turns each into a soft boundary.
    base += np.random.default_rng(11).uniform(-0.5, 0.5, base.shape)
    return Image.fromarray(np.clip(base, 0, 255).round().astype(np.uint8), "RGB")


def rounded_mask(size: tuple[int, int], radius: int, ss: int = 4) -> Image.Image:
    """Antialiased rounded-rect mask, drawn oversampled then downsampled."""
    big = Image.new("L", (size[0] * ss, size[1] * ss), 0)
    ImageDraw.Draw(big).rounded_rectangle(
        [0, 0, size[0] * ss - 1, size[1] * ss - 1], radius=radius * ss, fill=255
    )
    return big.resize(size, Image.LANCZOS)


def phone(capture: Path) -> Image.Image:
    """The capture at PHONE_H, rounded, with a hairline bezel. RGBA."""
    shot = Image.open(capture).convert("RGB")
    w = round(shot.width * PHONE_H / shot.height)
    shot = shot.resize((w, PHONE_H), Image.LANCZOS)

    mask = rounded_mask((w, PHONE_H), PHONE_RADIUS)
    out = Image.new("RGBA", (w, PHONE_H), (0, 0, 0, 0))
    out.paste(shot, (0, 0))
    out.putalpha(mask)

    # A hairline lighter than the screen, so the black panel separates from the
    # dark background instead of bleeding into it.
    edge = Image.new("RGBA", (w, PHONE_H), (0, 0, 0, 0))
    ImageDraw.Draw(edge).rounded_rectangle(
        [0, 0, w - 1, PHONE_H - 1], radius=PHONE_RADIUS, outline=(120, 150, 175, 150), width=2
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


def main() -> None:
    src = Path(sys.argv[1] if len(sys.argv) > 1 else "build/shots")
    OUT.mkdir(parents=True, exist_ok=True)

    missing = [n for n, *_ in SHOTS if not (src / f"{n}.png").exists()]
    if missing:
        sys.exit(f"missing captures in {src}: {', '.join(missing)}")

    icon = Image.open(ICON).convert("RGBA").resize((58, 58), Image.LANCZOS)
    h_font = font(DISPLAY, 92, "Bold")
    s_font = font(BODY, 36, "Medium")
    n_font = font(DISPLAY, 31, "Bold")
    # Line advances and gaps, kept here because the block is centred as a whole
    # and every one of them feeds that height.
    head_lh, sub_lh = 108, 50
    brand_h, gap_head, gap_rule, gap_sub = 58, 62, 38, 44

    for i, (name, head, sub, accent) in enumerate(SHOTS):
        # Alternate sides so the strip has a rhythm rather than eight identical
        # slides; Play shows them in one scrolling row.
        phone_right = i % 2 == 0
        art = phone(src / f"{name}.png")
        px = W - MARGIN - art.width if phone_right else MARGIN
        py = (H - art.height) // 2

        img = backdrop(px + art.width // 2)
        sh, pad = drop_shadow(art, 30, 165)
        img.paste(sh, (px + 6 - pad, py + 20 - pad), sh)
        img.paste(art, (px, py), art)

        # Text column fills whatever the phone left, inside the margins.
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

        dest = OUT / f"{i + 1:02d}-{name.replace('_', '-')}.png"
        img.save(dest)
        print(f"  {dest.name:28s} {img.width}x{img.height} {img.mode}")


if __name__ == "__main__":
    main()
