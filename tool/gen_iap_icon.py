"""Generate the Play in-app-product icon for `pro_remove_ads` (1024x1024).

Writes TWO images, both to spec (32-bit PNG, 1:1, 512-1080 px a side, <8 MB):

  pro_remove_ads.png             crown over the app tile   <- the one to upload
  pro_remove_ads_crown_only.png  crown alone               <- fallback

Both exist because Play's guidance for this slot asks for no text, no
promotional content and **no brand markings**, and the app tile is a brand
marking. Enforcement is inconsistent and logo-derived product icons are common,
so the crown-over-tile version is the default; if a reviewer objects, swap in the
crown-only file and nothing else has to change.

Either way the subject is the app's own crown. `CrownIcon` is what the user taps
to reach this purchase (the dock's Go Pro item, and the Go Pro screen's buy
button), so the path here is the SAME geometry as
`lib/core/widgets/crown_icon.dart`, authored on the same 24x24 grid, in the same
`AppColors.gold`. Someone who has seen the crown in the dock recognises the
product in the store, and if the crown is ever redrawn this file has to be
redrawn with it.

Run: python tool/gen_iap_icon.py
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024  # inside Play's 512-1080
OUT_DIR = Path("assets/store/iap")
ICON = Path("assets/branding/appicon.png")

# Crown-above-tile geometry, as fractions of the canvas. The crown sits clear of
# the tile: an overlap put the crown's base bar down across the tile's top edge,
# where it read as a separate floating bar rather than as one badged object.
TILE_SPAN = 0.52
CROWN_BADGE_SPAN = 0.34
CROWN_GAP = 0.10  # clear space below the crown, as a fraction of its own height

# The app's own surfaces and Go Pro accent (AppColors.pageBackground /
# background / gold). A palette is not a brand marking - no mark, no wordmark.
BG_TOP = (12, 30, 46)
BG_BOTTOM = (6, 13, 22)
GOLD = (243, 195, 60)

# Fraction of the canvas the crown's bounding box spans. Play renders this small
# in the purchase sheet, so the subject is deliberately large.
CROWN_SPAN = 0.54

SS = 4  # supersample factor for the crown paths


def backdrop() -> Image.Image:
    """Brand gradient with a warm bloom behind the crown."""
    yy = np.linspace(0, 1, SIZE)[:, None]
    base = np.stack(
        [
            np.full((SIZE, SIZE), BG_TOP[i]) * (1 - yy)
            + np.full((SIZE, SIZE), BG_BOTTOM[i]) * yy
            for i in range(3)
        ],
        axis=-1,
    )
    gy, gx = np.mgrid[0:SIZE, 0:SIZE]
    d = np.hypot((gx - SIZE / 2) / 620.0, (gy - SIZE * 0.46) / 620.0)
    base += (np.clip(1 - d, 0, 1) ** 2.0)[..., None] * np.array([70, 52, 16], float)
    # Dither before quantising: this gradient crosses each 8-bit step over ~30 px
    # and the eye reads those steps as bands.
    base += np.random.default_rng(5).uniform(-0.5, 0.5, base.shape)
    return Image.fromarray(np.clip(base, 0, 255).round().astype(np.uint8), "RGB")


def crown_layer(span: float = CROWN_SPAN, cy: float | None = None) -> Image.Image:
    """The crown as an RGBA layer, drawn oversampled then downsampled.

    Geometry copied from `_CrownPainter`: a 24x24 grid, a seven-point band and a
    separate rounded base. The hairline gap between them is what reads as a crown
    rather than a jagged blob, and it survives the downsample here for the same
    reason it survives at 20 px in the dock.

    [span] is the crown's width as a fraction of the canvas; [cy] its vertical
    centre in pixels (default: the canvas centre).
    """
    band_pts = [
        (2.4, 6.6), (7.7, 11.2), (12, 4.2), (16.3, 11.2),
        (21.6, 6.6), (20.1, 16.8), (3.9, 16.8),
    ]
    base = (3.4, 18.2, 3.4 + 17.2, 18.2 + 2.9)  # l, t, r, b
    base_r = 1.1

    # Fit the whole crown (band + base) into CROWN_SPAN of the canvas.
    xs = [p[0] for p in band_pts] + [base[0], base[2]]
    ys = [p[1] for p in band_pts] + [base[1], base[3]]
    gw, gh = max(xs) - min(xs), max(ys) - min(ys)
    k = SIZE * span / gw
    ox = (SIZE - gw * k) / 2 - min(xs) * k
    centre = SIZE / 2 if cy is None else cy
    oy = centre - gh * k / 2 - min(ys) * k

    def pt(x, y):
        return ((ox + x * k) * SS, (oy + y * k) * SS)

    big = Image.new("RGBA", (SIZE * SS, SIZE * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    d.polygon([pt(*p) for p in band_pts], fill=GOLD + (255,))
    d.rounded_rectangle(
        [*pt(base[0], base[1]), *pt(base[2], base[3])],
        radius=base_r * k * SS,
        fill=GOLD + (255,),
    )
    return big.resize((SIZE, SIZE), Image.LANCZOS)


def glow_under(layer: Image.Image, blur: int, alpha: int, colour) -> Image.Image:
    """A soft coloured bloom shaped like `layer`, so it sits IN the field.

    The layer is already canvas-sized with the subject inside it, so the blur has
    somewhere to fall - PIL's GaussianBlur replicates at the border and would
    otherwise smear any alpha touching an edge outward as a hard rectangle.
    """
    a = layer.split()[3].filter(ImageFilter.GaussianBlur(blur)).point(lambda v: v * alpha // 255)
    out = Image.new("RGBA", layer.size, colour + (255,))
    out.putalpha(a)
    return out


def compose(with_logo: bool) -> Image.Image:
    img = backdrop().convert("RGBA")

    if not with_logo:
        crown = crown_layer()
        img = Image.alpha_composite(img, glow_under(crown, 46, 90, GOLD))
        return Image.alpha_composite(img, crown)

    tile_px = round(SIZE * TILE_SPAN)
    crown_h = SIZE * CROWN_BADGE_SPAN * (16.9 / 19.2)   # the crown's own aspect
    gap = crown_h * CROWN_GAP
    # Stack crown + gap + tile as one block and centre THAT, not each piece:
    # centring the tile alone would leave the composition sitting low.
    block = crown_h + gap + tile_px
    top = (SIZE - block) / 2
    crown_cy = top + crown_h / 2
    tile_y = round(top + crown_h + gap)

    tile = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    tile.paste(
        Image.open(ICON).convert("RGBA").resize((tile_px, tile_px), Image.LANCZOS),
        ((SIZE - tile_px) // 2, tile_y),
    )
    img = Image.alpha_composite(img, glow_under(tile, 40, 130, (0, 0, 0)))
    img = Image.alpha_composite(img, tile)

    crown = crown_layer(CROWN_BADGE_SPAN, crown_cy)
    img = Image.alpha_composite(img, glow_under(crown, 34, 120, GOLD))
    return Image.alpha_composite(img, crown)


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, with_logo in (("pro_remove_ads", True), ("pro_remove_ads_crown_only", False)):
        img = compose(with_logo)
        # Play wants a 32-BIT png here, i.e. RGBA - the opposite of the feature
        # graphic, which it rejects if an alpha channel is present. The alpha is
        # fully opaque; it is the bit depth that is being asked for.
        assert img.mode == "RGBA", "Play wants a 32-bit (RGBA) PNG for a product icon"
        assert img.width == img.height and 512 <= img.width <= 1080
        dest = OUT_DIR / f"{name}.png"
        img.save(dest)
        print(f"wrote {dest} ({img.width}x{img.height}, {img.mode})")


if __name__ == "__main__":
    main()
