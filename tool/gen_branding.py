"""Regenerate every Chromis brand asset from the icon design.

The design is `assets/branding/chromis-icon2.png`: a dark rounded tile carrying a
brush, a colour palette, "AI" with two sparkles, scissors and the CHROMIS
wordmark. That composition is the brand and nothing here re-draws or re-arranges
it - the assets differ only in SIZE, in whether the tile keeps its corners, and
in what sits behind it.

Three things the mock-up cannot be used as-is for:

  * It has no alpha. The transparency checkerboard is painted into the pixels, so
    the tile has to be located and everything outside it flooded with the tile's
    own fill before anything is resampled - otherwise light grey bleeds into the
    corners at every size.
  * Android masks an adaptive icon. So the tile's fill becomes a SQUARE
    full-bleed background (no corners - the launcher supplies them) and the
    artwork alone becomes the foreground, sized to fit the guaranteed circle.
  * The tile is #0A2127, which is the same dark as this app's own surfaces
    (`AppColors.panel` is #0E1C2C) and the website's. On our own dark ground the
    tile dissolves, so there it gets a light plate: see PLATE, and the matching
    treatment in `AppLogo` and in the site's `.brand img` / `.cta-icon`.

Outputs (assets/branding/, plus the website's copies):

  appicon.png           1024  tile, rounded, transparent outside
  icon_background.png   1024  flat fill, full-bleed SQUARE -> adaptive background
  icon_foreground.png   1024  artwork alone, in the adaptive safe circle
  store_icon.png         512  full-bleed, opaque, no alpha (Play listing)
  logo.png               512  tile, rounded (in-app AppLogo)
  splash.png             768  tile on its light plate (native splash)
  splash_android12.png   768  the same, pre-padded for the A12 circle mask
  splash_bg.png     720x1280  the dark gradient behind the pre-A12 splash

Run: python tool/gen_branding.py
"""

from __future__ import annotations

import numpy as np
from PIL import Image, ImageFilter
from pathlib import Path

SRC = Path("assets/branding/chromis-icon2.png")
OUT = Path("assets/branding")
WEB = Path("website/assets/img")

# Measured off the mock-up (see the module docstring on why it has to be
# measured rather than assumed): the tile is a centred 614px square, its flat
# fill is the modal interior colour, and its corner fits a rounded rect at 0.145
# of the side to IoU 0.9998. Fit that against the silhouette WITHOUT its
# antialiased rim - counting the rim as tile gives 0.13, whose arc then cuts
# outside the real corner and drags the mock-up's painted-on checkerboard into
# every asset as a pale crescent.
TILE_BOX = (77, 77, 614)  # left, top, side
CORNER = 0.145
FILL = (10, 33, 39)

# How far inside the tile the mock-up's edge antialiasing reaches, in its own
# pixels. Source pixels within this of the edge are discarded and replaced by
# flat fill, so the corner an asset shows is `rrect_mask`'s and nothing else.
RIM = 8

# The light ground the tile gets when it would otherwise sit on one of our own
# dark surfaces. AppColors.textPrimary, so the app, the site and the splash all
# name the same colour.
PLATE = (234, 241, 248)
PLATE_PAD = 0.075  # of the plate's side, per edge

# Everything is composited here. There is no point going above the mock-up's own
# resolution by much - 1024 is the largest output and already a 1.7x upscale.
MASTER = 1024

# Android hands the launcher a 108dp drawable, shows about 72dp of it, and
# guarantees only the central 66dp circle. The artwork's own circumscribed radius
# is ~0.507 of the tile, so 0.294 keeps it inside that guarantee while filling
# about two thirds of the visible icon.
ADAPTIVE_ART_R = 0.294
ADAPTIVE_SAFE_R = 66 / 108 / 2

# Android 12+ masks the splash icon to a circle of this diameter.
A12_MASK_RATIO = 2 / 3
A12_SAFETY = 0.97


# --------------------------------------------------------------------------
# Shapes
# --------------------------------------------------------------------------


def rrect_mask(size: int, radius: float) -> Image.Image:
    """An antialiased rounded-rect mask, `radius` as a fraction of the side.

    From the shape's signed distance rather than by supersampling: exact at any
    size, and a supersampled buffer for a 1024px tile would cost more than the
    whole rest of this script.
    """
    r = radius * size
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float64)
    qx = np.abs(xx + 0.5 - size / 2) - (size / 2 - r)
    qy = np.abs(yy + 0.5 - size / 2) - (size / 2 - r)
    d = (
        np.minimum(np.maximum(qx, qy), 0.0)
        + np.hypot(np.maximum(qx, 0.0), np.maximum(qy, 0.0))
        - r
    )
    return Image.fromarray((np.clip(0.5 - d, 0, 1) * 255).astype(np.uint8), "L")


# --------------------------------------------------------------------------
# The mock-up, cleaned up
# --------------------------------------------------------------------------


def source_tile() -> Image.Image:
    """The mock-up's tile as a clean RGB square: artwork on flat fill, corners
    and the painted-on checkerboard replaced by the fill.

    Flooding rather than cropping to the silhouette is what keeps every later
    resample honest. The mock-up's corner pixels are a blend of the tile and the
    checkerboard behind it, so resampling them directly drags light grey into the
    corners of every asset; here the corners are re-cut from `rrect_mask`
    instead, at whatever size is being written.
    """
    left, top, side = TILE_BOX
    sub = np.array(
        Image.open(SRC).convert("RGB").crop((left, top, left + side, top + side))
    )
    keep = np.array(rrect_mask(side, CORNER).filter(ImageFilter.MinFilter(2 * RIM + 1))) > 200
    out = np.where(keep[..., None], sub, np.array(FILL, np.uint8))
    return Image.fromarray(out, "RGB")


def artwork(source: Image.Image) -> tuple[np.ndarray, np.ndarray]:
    """The artwork lifted off the flat fill: premultiplied colour, and alpha.

    Alpha is keyed on distance from the fill, which for a pixel that is a mix of
    artwork and fill is proportional to the artwork's coverage. The colour is
    returned PREMULTIPLIED because that is what survives resampling: it falls to
    zero exactly where alpha does, whereas un-premultiplied colour is a division
    by ~0 out there and resampling would smear that noise back into the edges.
    """
    p = np.array(source).astype(np.float64)
    fill = np.array(FILL, np.float64)
    d = np.abs(p - fill).max(axis=2)
    a = np.clip((d - KEY_LO) / (KEY_HI - KEY_LO), 0, 1)
    # The mock-up's fill is not perfectly flat - it carries a few steps of noise,
    # heaviest out towards the corners, and at the key's floor that noise is
    # indistinguishable from a pixel with ~15% artwork coverage. Distinguish them
    # by POSITION instead of by value: a real antialiased rim is always within a
    # pixel or two of solid artwork, and the noise is nowhere near any. Without
    # this the foreground carries a faint ghost of the background's own noise out
    # to r=0.61, which is both wrong and enough to make the safe-circle
    # measurement below meaningless.
    solid = (a > EXTENT_A).astype(np.uint8) * 255
    near = np.array(Image.fromarray(solid).filter(ImageFilter.MaxFilter(2 * KEY_REACH + 1)))
    a = np.where(near > 0, a, 0.0)
    # premul = a * art, and art = fill + (p - fill)/a, so this needs no division.
    premul = (p - fill) + a[..., None] * fill
    return premul, a


# Distance-from-fill, in 8-bit channel units, over which alpha ramps 0 -> 1.
# KEY_HI sits below the artwork's real contrast against the fill (the dimmest
# artwork colour still clears ~130) so interior pixels saturate and only the
# antialiased rim is partial.
KEY_LO = 8.0
KEY_HI = 70.0

# Alpha above which a pixel counts as solid artwork, for measuring the artwork's
# extent and for anchoring the reach test above.
EXTENT_A = 0.35

# How far from solid artwork a partial pixel may sit and still be believed, in
# the mock-up's own pixels. Its antialiased rims are 1-2px wide.
KEY_REACH = 4


def artwork_layer(source: Image.Image, size: int, radius: float):
    """The artwork alone on transparency, centred and scaled so its circumscribed
    radius is `radius` of `size`.

    Returns the layer plus the (scale, offset) it was placed with, so the caller
    can rebuild the same placement out of the mock-up's tile and diff the two.
    """
    premul, a = artwork(source)
    n = a.shape[0]
    # Measure the extent off the artwork's SOLID pixels. The fill has a couple of
    # steps of noise in it, and at the alpha key's own floor that noise reads as
    # artwork - which inflates the radius and quietly shrinks the launcher icon
    # by a sixth.
    ys, xs = np.where(a > EXTENT_A)
    cx, cy = (xs.min() + xs.max() + 1) / 2 / n, (ys.min() + ys.max() + 1) / 2 / n
    have = float(np.hypot(xs / n - cx, ys / n - cy).max())
    scale = radius / have
    inner = max(1, round(size * scale))

    def resized(arr: np.ndarray, mode: str) -> np.ndarray:
        im = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), mode)
        return np.array(im.resize((inner, inner), Image.LANCZOS)).astype(np.float64)

    # Resample premultiplied, un-premultiply after - the other order divides by
    # ~0 outside the artwork and resampling would smear that noise into the edge.
    pm = resized(premul, "RGB")
    al = resized(a * 255, "L")
    rgb = np.clip(pm / np.maximum(al / 255, 1e-6)[..., None], 0, 255)
    art = Image.fromarray(np.dstack([rgb, al]).astype(np.uint8), "RGBA")

    off = (round(size * (0.5 - cx * scale)), round(size * (0.5 - cy * scale)))
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    # NO mask. `paste(art, off, art)` looks like the obvious call and silently
    # squares the alpha: PIL blends the destination's alpha band through the mask
    # too, so a rim pixel at a=128 lands at 128*128/255=64 with its colour pulled
    # towards the transparent canvas's black. That thinned every antialiased edge
    # in the launcher icon and left a dark fringe. An unmasked paste onto a
    # transparent canvas is a plain copy of all four bands, which is what is
    # wanted here.
    canvas.paste(art, off)
    return canvas, inner, off


# --------------------------------------------------------------------------
# Assets
# --------------------------------------------------------------------------


def tile(source: Image.Image, size: int, rounded: bool = True) -> Image.Image:
    """The whole tile at `size`. `rounded=False` gives the square, full-bleed
    version the adaptive background and the Play icon want."""
    im = source.resize((size, size), Image.LANCZOS).convert("RGBA")
    if rounded:
        im.putalpha(rrect_mask(size, CORNER))
    return im


def plate(badge: Image.Image, size: int) -> Image.Image:
    """`badge` on a light rounded plate, concentric with the tile's own corners.

    The tile is within a couple of steps of AppColors.panel, so on the splash -
    or any of our own surfaces - it needs a ground of its own or it reads as a
    faintly different dark rather than as an icon.
    """
    inner = round(size * (1 - 2 * PLATE_PAD))
    pad = (size - inner) // 2
    # Concentric: the plate's radius is the tile's, plus the padding.
    ground = Image.new("RGBA", (size, size), PLATE + (255,))
    ground.putalpha(rrect_mask(size, CORNER * (1 - 2 * PLATE_PAD) + PLATE_PAD))
    # alpha_composite, not a masked paste: the badge has to blend OVER the plate,
    # and `paste(art, box, art)` would drag the plate's own alpha down towards the
    # badge's wherever the badge's rim is partial - punching a semi-transparent
    # ring through an opaque plate.
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    layer.paste(badge.resize((inner, inner), Image.LANCZOS), (pad, pad))
    return Image.alpha_composite(ground, layer)


def circumscribed_ratio(im: Image.Image, floor: int = 16) -> float:
    """Radius of the smallest centred circle covering every opaque pixel, as a
    fraction of the side. A square gives ~0.707; the rounder the art, the less."""
    a = np.array(im.split()[3])
    h, w = a.shape
    ys, xs = np.where(a > floor)
    return float(np.hypot(xs - (w - 1) / 2, ys - (h - 1) / 2).max()) / max(w, h)


def a12_padded(badge: Image.Image, size: int) -> tuple[Image.Image, float]:
    """`badge` shrunk so it fits ENTIRELY inside the Android-12 circular splash
    mask - measured off the art, so it keeps its own corner radius instead of
    being re-cut into a circle by the OS."""
    scale = (A12_MASK_RATIO / 2) / circumscribed_ratio(badge) * A12_SAFETY
    inner = round(size * scale)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    art = badge.resize((inner, inner), Image.LANCZOS)
    # Unmasked, for the same reason as in artwork_layer: onto transparency this is
    # a copy, whereas passing `art` as its own mask would square its alpha.
    canvas.paste(art, ((size - inner) // 2, (size - inner) // 2))
    return canvas, scale


def gradient_bg(w: int, h: int, stops) -> Image.Image:
    """Vertical multi-stop gradient, built as a 1-px column then stretched."""
    col = Image.new("RGB", (1, h))
    px = col.load()
    for y in range(h):
        t = y / (h - 1)
        rgb = stops[-1][1]
        for (p0, c0), (p1, c1) in zip(stops, stops[1:]):
            if p0 <= t <= p1:
                f = (t - p0) / (p1 - p0) if p1 > p0 else 0.0
                rgb = tuple(round(a + (b - a) * f) for a, b in zip(c0, c1))
                break
        px[0, y] = rgb
    return col.resize((w, h))


def save(im: Image.Image, size: int, path: Path, note: str = "") -> None:
    im.resize((size, size), Image.LANCZOS).save(path)
    print(f"  wrote {path} ({size}x{size}){note and '  - ' + note}")


def check_foreground(fg: Image.Image, source: Image.Image, inner: int, off) -> None:
    """Composite the adaptive pair the way a launcher does, and diff it against
    the mock-up's own tile placed identically.

    Worth doing because the alpha key is an ESTIMATE - it reads coverage off the
    distance from the fill colour, which is only exactly right where the artwork
    contrasts strongly with it. This says how wrong that estimate is in the only
    place it matters: on screen, over the background it will actually sit on. It
    also asserts the artwork still clears Android's guaranteed circle.
    """
    # Measured at the SAME coverage the scale was derived from. Reading it at a
    # lower floor compares two different things, and the mismatch is how this
    # assertion once passed for the wrong reason: a bug that squared the alpha
    # eroded the faint outer pixels below the default floor, so the check saw
    # 0.294 where an honest measurement saw 0.355.
    r = circumscribed_ratio(fg, floor=round(EXTENT_A * 255))
    assert r <= ADAPTIVE_SAFE_R, (
        f"artwork radius {r:.3f} escapes Android's {ADAPTIVE_SAFE_R:.3f} safe circle"
    )
    faint = circumscribed_ratio(fg, floor=8)
    assert faint <= 0.5, f"foreground carries ink out to r={faint:.3f} - the key is leaking fill noise"
    n = fg.width
    got = Image.alpha_composite(Image.new("RGBA", (n, n), FILL + (255,)), fg)
    ref = Image.new("RGB", (n, n), FILL)
    ref.paste(source.resize((inner, inner), Image.LANCZOS), off)
    err = np.abs(np.array(got.convert("RGB")).astype(int) - np.array(ref).astype(int)).max(axis=2)
    ink = np.array(fg.split()[3]) > 8
    # Split the two, because they mean opposite things. Error where the foreground
    # has ink is the alpha key getting an edge slightly wrong - the number to keep
    # small. Error where it is transparent is the mock-up's fill noise, which this
    # deliberately does not reproduce, so a small figure there is the point.
    print(
        f"  composited vs the mock-up, on its ink: mean {err[ink].mean():.2f}/255, "
        f"max {err[ink].max()} over {ink.sum():,} px "
        f"({(err >= 32).sum()} px >=32 anywhere, {(err >= 64).sum()} >=64)"
    )
    print(
        f"  dropped fill noise: mean {err[~ink].mean():.2f}/255 over the flat area. "
        f"Artwork radius {r:.3f} of {ADAPTIVE_SAFE_R:.3f} safe; faint ink ends at {faint:.3f}"
    )


def main() -> None:
    print("mock-up")
    src = source_tile()
    print(f"  tile {src.size[0]}px, fill #{FILL[0]:02X}{FILL[1]:02X}{FILL[2]:02X}, corner {CORNER}")

    badge = tile(src, MASTER)
    plated = plate(badge, MASTER)

    print("assets/branding")
    save(badge, 1024, OUT / "appicon.png", "tile, rounded")
    save(badge, 512, OUT / "logo.png", "in-app AppLogo")

    # Adaptive icon. The fill fills the whole drawable SQUARE - the launcher's
    # mask draws the corners, so baking our own in would only get cut twice.
    flat = Image.new("RGBA", (MASTER, MASTER), FILL + (255,))
    save(flat, 1024, OUT / "icon_background.png", "adaptive background, no corners")
    fg, inner, off = artwork_layer(src, MASTER, ADAPTIVE_ART_R)
    save(fg, 1024, OUT / "icon_foreground.png", "adaptive foreground")
    check_foreground(fg, src, inner, off)

    # Play wants 512x512 with no alpha and rounds it itself. The artwork already
    # clears a 20% rounded-square mask at the mock-up's own scale, so this is
    # simply the tile without its corners.
    save(tile(src, MASTER, rounded=False).convert("RGB"), 512, OUT / "store_icon.png", "Play listing")

    save(plated, 768, OUT / "splash.png", "tile on its light plate")
    a12, scale = a12_padded(plated, 768)
    a12.save(OUT / "splash_android12.png")
    print(
        f"  wrote {OUT / 'splash_android12.png'} (768x768)  - plate at "
        f"{scale:.3f}, uncut by the A12 circle"
    )
    gradient_bg(720, 1280, [(0.0, (16, 42, 56)), (0.5, (10, 21, 38)), (1.0, (18, 20, 48))]).save(
        OUT / "splash_bg.png"
    )
    print(f"  wrote {OUT / 'splash_bg.png'} (720x1280)  - pre-A12 splash backdrop")

    print("website/assets/img")
    save(badge, 256, WEB / "logo.png", "header + footer mark")
    save(badge, 32, WEB / "favicon-32.png", "favicon")
    save(badge, 180, WEB / "apple-touch-icon.png", "iOS home screen")
    save(badge, 512, WEB / "icon-full.png", "CTA brand tile")


if __name__ == "__main__":
    main()
