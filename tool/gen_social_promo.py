"""Generate the LinkedIn/social promo graphic from existing brand assets.

Same philosophy as gen_branding.py: never hand-edit the output, change this
script and re-run it. Everything on the canvas comes from the repo - the logo,
the raw device captures, the app fonts and the AppColors palette.

Device GEOMETRY is shared with the Play screenshots, so the two cannot drift:
the corner radius is `gen_store_screens.PHONE_RADIUS_PER_PX` and the silhouette
is its `rounded_mask`. `framed` below deliberately does not call its `phone`,
and says why.

Do NOT rebuild the phones by cropping the finished screenshots in
assets/store/en-US/screenshots. A rectangular crop of an already-composited phone
keeps a sliver of the listing backdrop outside the device's rounded corner and
cuts it off square, which shows up as a hard notch at every corner.

Four things keep the edges smooth. Every one of them was learned by shipping it
wrong first, so none of them is decorative.

**The whole composition is rendered at SS times final size and downsampled once,
at the end.** ImageDraw does not antialias: every rounded_rectangle it draws -
the bezel, the CTA pill, the accent rule - comes out stair-cased, and a rotated
frame stair-cases its long straight edges too. One final LANCZOS downsample
averages all of it away at once.

**Anything resampled is premultiplied first.** PIL interpolates the four
channels independently, so rotating a straight-alpha image mixes the transparent
fill's RGB - black - into the boundary pixels and leaves a dark fringe once
composited. Premultiplied transparent black is the additive identity, so the
same interpolation is correct. Compositing is premultiplied too, which needs no
divide and so cannot amplify noise in nearly-transparent pixels.

**A stroke thinner than one final pixel cannot be smooth**, however good the
antialiasing is - see `framed`. Supersampling does not save it; supersampling is
what creates the problem, by shrinking a 2px stroke to 2/SS px.

**Near-vertical is worse than diagonal** - see PHONES. A one-degree tilt
staircases where seven degrees reads clean.

Usage: python tool/gen_social_promo.py
Output: assets/store/social/linkedin-promo.png (1200x1200)
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(Path(__file__).resolve().parent))

from gen_store_screens import (  # noqa: E402
    PHONE_RADIUS_PER_PX,
    drop_shadow,
    rounded_mask,
)

OUT = ROOT / "assets/store/social/linkedin-promo.png"
# The English raw captures, same directory tool/gen_store_screens.py builds
# the en-US listing from (tool/capture_store_shots.py writes it).
CAPTURES = ROOT / "build/shots-i18n/en/phone"

W, H = 1200, 1200
SS = 3  # supersample factor for the whole canvas; see the module docstring

# AppPalette.dark (lib/core/theme/app_palette.dart). The dark theme, because
# that is what the captures inside these frames are in.
PAGE_BG = (0x00, 0x00, 0x00)
BG = (0x10, 0x10, 0x13)
TEXT_PRIMARY = (0xF1, 0xF2, 0xF4)
TEXT_SECONDARY = (0xB6, 0xBA, 0xC2)
CYAN = (0x17, 0xB6, 0xD6)
INK = (0x08, 0x09, 0x0C)

# (capture, 1x frame height, tilt, 1x centre). Sized and placed so every frame
# sits whole inside the canvas - the back pair smaller and lower, the front one
# larger and raised.
#
# The front frame is upright rather than given a slight tilt, and that is an edge
# decision as much as a layout one: a tilt of a degree or two is the WORST case
# for a near-vertical line, because it holds the same pixel column for a long run
# and then jogs by a whole pixel, which the eye reads as a staircase. The back
# pair are tilted far enough that their jogs come often enough to read as a
# smooth diagonal, and upright is exactly crisp.
# The hero frame is `effects`, not `bubble`: the sticker contour stroke reads
# badly at this size, and a bright photo with the filter strip under it says
# "photo editor" at a glance. Not `layers` either - its canvas is the same
# four-photo grid as the back-right frame, so the two would look repetitive.
PHONES = [
    ("cutout_result", 553, -7.0, (335, 880)),
    ("grid", 553, 7.0, (865, 880)),
    ("effects", 613, 0.0, (600, 855)),
]


def s(v: float) -> int:
    """A 1x layout figure in supersampled pixels."""
    return round(v * SS)


def font(path: str, size: int, weight: int | None = None) -> ImageFont.FreeTypeFont:
    f = ImageFont.truetype(str(ROOT / path), s(size))
    if weight is not None:
        try:
            f.set_variation_by_axes([weight])
        except OSError:
            pass
    return f


def background() -> Image.Image:
    """The lit gradient, at SS size."""
    grad = Image.new("RGB", (1, H))
    for y in range(H):
        t = y / (H - 1)
        grad.putpixel(
            (0, y),
            tuple(round(PAGE_BG[i] + (BG[i] - PAGE_BG[i]) * t) for i in range(3)),
        )
    img = grad.resize((W, H))

    glow = Image.new("RGB", (W, H), (0, 0, 0))
    g = ImageDraw.Draw(glow)
    g.ellipse((520, 640, 1500, 1460), fill=(0x0B, 0x3A, 0x46))
    g.ellipse((-380, 820, 420, 1560), fill=(0x17, 0x1D, 0x40))
    lit = ImageChops.screen(img, glow.filter(ImageFilter.GaussianBlur(160)))

    # Drawn at 1x and upscaled, unlike everything else: it is a gradient under a
    # 160px blur, so there is no detail for the extra resolution to carry, and
    # blurring at SS would cost SS^2 the work for a pixel-identical result.
    return lit.resize((W * SS, H * SS), Image.BICUBIC)


def premultiplied(art: Image.Image) -> Image.Image:
    a = np.array(art.convert("RGBA"), dtype=np.float32)
    a[..., :3] *= a[..., 3:4] / 255.0
    return Image.fromarray(np.clip(a, 0, 255).round().astype(np.uint8), "RGBA")


def rotate_premultiplied(pm: Image.Image, angle: float) -> Image.Image:
    out = pm.rotate(angle, expand=True, resample=Image.BICUBIC)
    # Bicubic overshoots at a hard alpha step, which can push a colour channel
    # above its own alpha and break the premultiplied invariant (rgb <= a).
    arr = np.array(out, dtype=np.int16)
    arr[..., :3] = np.minimum(arr[..., :3], arr[..., 3:4])
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")


def over(canvas: np.ndarray, src: Image.Image, x0: int, y0: int) -> None:
    """Composite a PREMULTIPLIED RGBA image onto an opaque uint8 RGB canvas.

    Clipped to the canvas, so a shadow is free to hang off the edge.
    """
    full = np.asarray(src, dtype=np.float32)
    h, w = full.shape[:2]
    ch, cw = canvas.shape[:2]
    dx0, dy0 = max(0, x0), max(0, y0)
    dx1, dy1 = min(cw, x0 + w), min(ch, y0 + h)
    if dx0 >= dx1 or dy0 >= dy1:
        return
    part = full[dy0 - y0 : dy1 - y0, dx0 - x0 : dx1 - x0]
    alpha = part[..., 3:4] / 255.0
    region = canvas[dy0:dy1, dx0:dx1].astype(np.float32)
    canvas[dy0:dy1, dx0:dx1] = (
        np.clip(part[..., :3] + region * (1.0 - alpha), 0, 255).round().astype(np.uint8)
    )


def framed(capture: str, height: int, src: Path | None = None) -> Image.Image:
    """A device frame at SS size, built so the bezel survives the downsample.

    `src` defaults to the English captures; tool/gen_update_promo.py passes a
    different language's directory.

    This mirrors `gen_store_screens.phone` instead of calling it, for one
    reason. phone() draws its bezel a flat 2px wide, which is right at
    screenshot scale where the device is 1349px tall, but lands at 2/SS of a
    final pixel here - and a high-contrast line thinner than one pixel cannot
    look smooth, because its energy keeps re-splitting between columns as it
    drifts across the grid along a near-vertical edge. Compositing a second,
    wider stroke on top of phone()'s output was the obvious shortcut and is
    wrong: two 59% strokes stack into one 83% stroke, which reads as a bright
    silver wire rather than a hairline, and a bright edge advertises whatever
    stepping is left instead of hiding it.

    What must not drift from the Play screenshots is the GEOMETRY, and that is
    still shared - the corner radius comes from PHONE_RADIUS_PER_PX and the
    silhouette from rounded_mask. Only the stroke weight is local, and it is
    local on purpose.
    """
    shot = Image.open((src or CAPTURES) / f"{capture}.png").convert("RGB")
    h = s(height)
    w = round(shot.width * h / shot.height)
    radius = max(12, round(h * PHONE_RADIUS_PER_PX))

    art = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    art.paste(shot.resize((w, h), Image.LANCZOS), (0, 0))

    edge = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(edge).rounded_rectangle(
        [0, 0, w - 1, h - 1], radius=radius, outline=(120, 150, 175, 150), width=2 * SS
    )
    art = Image.alpha_composite(art, edge)

    # The silhouette is the mask, full stop. ImageDraw does not antialias, so the
    # stroke's outer boundary is stair-cased and pokes past a smooth mask; letting
    # it contribute alpha would put a hard 59%-opaque lip around the whole phone.
    # Taking colour from the stroke but alpha from the mask makes that impossible.
    art.putalpha(rounded_mask((w, h), radius))
    return art


def place(canvas: np.ndarray, capture: str, height: int, angle: float, center: tuple[int, int]):
    """One tilted phone plus its shadow. Returns the 1x bounding box."""
    art = rotate_premultiplied(premultiplied(framed(capture, height)), angle)
    shadow, pad = drop_shadow(art, blur=s(22), alpha=150)  # rgb=0, already premultiplied

    x0 = s(center[0]) - art.width // 2
    y0 = s(center[1]) - art.height // 2
    over(canvas, shadow, x0 - pad, y0 - pad + s(20))
    over(canvas, art, x0, y0)

    assert 0 <= x0 and 0 <= y0 and x0 + art.width <= W * SS and y0 + art.height <= H * SS, (
        f"{capture} escapes the canvas: {(x0, y0, x0 + art.width, y0 + art.height)}"
    )
    return (x0 / SS, y0 / SS, (x0 + art.width) / SS, (y0 + art.height) / SS)


def overlay() -> Image.Image:
    """Logo, wordmark, CTA pill, headline and feature line. Straight-alpha RGBA.

    Nothing here is ever resampled, so straight alpha is safe; it is
    premultiplied once at the point of compositing.
    """
    layer = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    logo = Image.open(ROOT / "assets/branding/logo.png").convert("RGBA")
    # Premultiplied before scaling for the same reason the phones are: the icon
    # has transparent corners, and straight-alpha LANCZOS darkens their fringe.
    small = premultiplied(logo).resize((s(92), s(92)), Image.LANCZOS)
    layer.paste(small, (s(72), s(60)))  # paste, not composite: the layer is empty here

    draw.text(
        (s(184), s(106)),
        "Chromis",
        font=font("assets/fonts/SpaceGrotesk-Variable.ttf", 50, 600),
        fill=TEXT_PRIMARY,
        anchor="lm",
    )

    pill_font = font("assets/fonts/Manrope-Variable.ttf", 28, 700)
    label = "Free on Google Play"
    px1, py0, py1 = s(1128), s(76), s(138)
    px0 = px1 - round(draw.textlength(label, font=pill_font)) - s(52)
    draw.rounded_rectangle((px0, py0, px1, py1), radius=(py1 - py0) // 2, fill=CYAN)
    draw.text(((px0 + px1) // 2, (py0 + py1) // 2), label, font=pill_font, fill=INK, anchor="mm")

    headline = font("assets/fonts/SpaceGrotesk-Variable.ttf", 82, 700)
    draw.text((s(72), s(190)), "Stop switching", font=headline, fill=TEXT_PRIMARY)
    draw.text((s(72), s(282)), "photo apps.", font=headline, fill=TEXT_PRIMARY)
    draw.rounded_rectangle((s(78), s(406), s(162), s(414)), radius=s(4), fill=CYAN)

    sub = font("assets/fonts/Manrope-Variable.ttf", 32, 500)
    draw.text((s(72), s(444)), "Layers, collage grids, comic bubbles, text", font=sub, fill=TEXT_SECONDARY)
    draw.text((s(72), s(488)), "and on-device AI cut-out. In one free editor.", font=sub, fill=TEXT_SECONDARY)

    return layer


def report_edges(img: Image.Image, boxes) -> None:
    """Measure edge smoothness, rather than eyeballing it.

    A single luminance profile across an edge proves nothing here: the bezel is a
    deliberately thin bright line, so ANY cross-section of it steps sharply. What
    distinguishes a smooth edge from a stair-cased one is behaviour ALONG the
    edge. So for a band of rows this finds the bezel's intensity-weighted centre
    to sub-pixel precision and looks at how that position moves.

    A correctly antialiased tilted edge drifts linearly with the tilt, so the
    second difference of the centre stays near zero. A stair-cased edge holds
    position for several rows and then jumps, which shows up as second
    differences approaching a whole pixel. Peak spread is the other tell: a
    sub-pixel-wide line keeps re-splitting between columns, so its peak
    brightness swings wildly from row to row.
    """
    px = img.convert("RGB").load()

    def lum(x: int, y: int) -> float:
        r, g, b = px[x, y]
        return 0.299 * r + 0.587 * g + 0.114 * b

    print("  edge smoothness - sub-pixel position of the left bezel, row by row")
    for (x0, y0, x1, y1), (capture, _h, angle, _c) in zip(boxes, PHONES):
        ymid = round((y0 + y1) / 2)
        # Located by brightness, not by gradient: the backdrop here sits near
        # lum 8-20 and the bezel near 90, while the screen content behind it
        # contains far stronger gradients that a steepest-edge search latches
        # onto instead - which is how an earlier version of this check ended up
        # measuring a photo border and reporting nonsense.
        start = next(
            (
                x
                for x in range(max(1, round(x0)), min(img.width - 2, round(x0) + 160))
                if lum(x, ymid) > 45
            ),
            None,
        )
        if start is None:
            print(f"  {capture:14s} no bezel found near x={round(x0)}")
            continue

        centres, track = [], start
        for y in range(ymid - 20, ymid + 21):
            xs = list(range(track - 5, track + 6))
            vals = [lum(x, y) for x in xs]
            floor = min(vals)
            wts = [v - floor for v in vals]
            total = sum(wts)
            if total <= 0:
                continue
            centre = sum(x * w for x, w in zip(xs, wts)) / total
            centres.append(centre)
            track = round(centre)

        jitter = [abs(centres[i + 2] - 2 * centres[i + 1] + centres[i]) for i in range(len(centres) - 2)]
        slope = (centres[-1] - centres[0]) / (len(centres) - 1)
        print(
            f"  {capture:14s} tilt={angle:+5.1f}  bezel x~{start:4d}  "
            f"slope={slope:+.3f}px/row (|tan|={abs(np.tan(np.radians(angle))):.3f})  "
            f"jitter max={max(jitter):.3f} mean={sum(jitter) / len(jitter):.3f}px"
        )


def main():
    canvas = np.array(background(), dtype=np.uint8)

    boxes = [place(canvas, *spec) for spec in PHONES]
    over(canvas, premultiplied(overlay()), 0, 0)

    img = Image.fromarray(canvas, "RGB").resize((W, H), Image.LANCZOS)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT, optimize=True)
    print(f"wrote {OUT} ({W}x{H}), rendered at {W * SS}x{H * SS}")
    report_edges(img, boxes)


if __name__ == "__main__":
    main()
