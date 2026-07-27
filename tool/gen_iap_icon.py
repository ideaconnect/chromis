"""Generate the Play in-app-product icon for `pro_remove_ads` (1024x1024).

Play's rules for this image are narrow: 32-bit PNG, 1:1, 512-1080 px a side, no
text, no promotional content, no brand markings. So it cannot be the app icon,
a wordmark or a "REMOVE ADS" badge - it has to be a picture of the thing being
sold.

That picture is the app's own crown. `CrownIcon` is what the user taps to reach
this purchase (the dock's Go Pro item, and the Go Pro screen's buy button), so
the path here is the SAME geometry as `lib/core/widgets/crown_icon.dart`,
authored on the same 24x24 grid, in the same `AppColors.gold`. Someone who has
seen the crown in the dock recognises the product in the store, and if the crown
is ever redrawn this file has to be redrawn with it.

Run: python tool/gen_iap_icon.py
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024  # inside Play's 512-1080
OUT = Path("assets/store/iap/pro_remove_ads.png")

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


def crown_layer() -> Image.Image:
    """The crown as an RGBA layer, drawn oversampled then downsampled.

    Geometry copied from `_CrownPainter`: a 24x24 grid, a seven-point band and a
    separate rounded base. The hairline gap between them is what reads as a crown
    rather than a jagged blob, and it survives the downsample here for the same
    reason it survives at 20 px in the dock.
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
    k = SIZE * CROWN_SPAN / gw
    ox = (SIZE - gw * k) / 2 - min(xs) * k
    oy = (SIZE - gh * k) / 2 - min(ys) * k

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


def main() -> None:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    img = backdrop().convert("RGBA")

    crown = crown_layer()
    # A soft warm glow under the crown so it sits in the field rather than on it.
    glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    glow.putalpha(crown.split()[3].filter(ImageFilter.GaussianBlur(46)).point(lambda v: v * 90 // 255))
    glow = Image.composite(Image.new("RGBA", (SIZE, SIZE), GOLD + (255,)), glow, glow.split()[3])
    img = Image.alpha_composite(img, glow)
    img = Image.alpha_composite(img, crown)

    # Play wants a 32-BIT png here, i.e. RGBA - the opposite of the feature
    # graphic, which it rejects if an alpha channel is present. The alpha is
    # fully opaque; it is the bit depth that is being asked for.
    assert img.mode == "RGBA", "Play wants a 32-bit (RGBA) PNG for a product icon"
    assert img.width == img.height and 512 <= img.width <= 1080
    img.save(OUT)
    print(f"wrote {OUT} ({img.width}x{img.height}, {img.mode})")


if __name__ == "__main__":
    main()
