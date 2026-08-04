"""Regenerate every Chromis brand asset from the icon design.

The design is `assets/branding/modern.png`: a camera aperture whose blades run
blue through cyan to amber, a gridded lens at its centre, a magic wand with two
sparkles, and a dashed cut-out contour - on a teal-to-blue gradient tile. That
composition is the brand and nothing here re-draws or re-arranges it. The assets
differ only in SIZE, in whether the tile keeps its corners, and in how the tile
is split for Android.

Three things stand between that file and a shippable set:

  * It is a MOCK-UP, not an icon. The 1024px file is the tile presented on a
    white card on a grey backdrop, both with drop shadows. The tile has to be
    located (it is the only saturated region) and everything else discarded.
  * The tile's background is a GRADIENT, so the artwork cannot be keyed off one
    flat colour the way a solid tile could. `gradient_surface` recovers it
    instead - a degree-3 polynomial fitted iteratively, rejecting the artwork as
    outliers until only the background is left (residual settles at ~4/255).
    Everything downstream keys against that surface per pixel.
  * Android masks adaptive icons. The tile goes in at exactly the proportions the
    design has, filling the visible 72 of the drawable's 108dp, which puts the
    artwork's circumscribed radius at ~0.27 - inside the 0.306 circle Android
    guarantees. The gradient fills the rest, so a mask cuts gradient.

No plate this time. The previous icon's tile was #0A2127, a couple of steps from
the old dark panel colour, and needed a light ground to read on our own surfaces.
This tile is mid-tone teal (~#2A6A83 at its darkest corner, ~3:1 against the
panel and over 4:1 across its lighter half) and reads on dark unaided - checked
by eye at 160/96/46/34/32px against both the app panel and the site surface. A
white plate behind it only fought the artwork.

Outputs (assets/branding/, plus the website's copies):

  appicon.png           1024  tile, rounded, transparent outside
  icon_background.png   1024  the gradient alone, full-bleed SQUARE -> adaptive bg
  icon_foreground.png   1024  the artwork alone -> adaptive foreground
  store_icon.png         512  tile, full-bleed, opaque, no alpha (Play listing)
  logo.png               512  tile, rounded (in-app AppLogo)
  splash.png             768  tile, rounded (native splash)
  splash_android12.png   768  the same, pre-padded for the A12 circle mask
  splash_bg.png     720x1280  the dark gradient behind the pre-A12 splash

Run: python tool/gen_branding.py
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

SRC = Path("assets/branding/modern.png")
OUT = Path("assets/branding")
WEB = Path("website/assets/img")

# Measured off the mock-up. The tile is the only saturated thing in the file, so
# it is found by chroma; its corner fits a rounded rect at 0.155 of the side to
# IoU 0.992. See the module docstring for what the rest of the file is.
TILE_BOX = (158, 158, 708)  # left, top, side
CORNER = 0.155

# How far inside the tile its own edge is untrustworthy, in mock-up pixels: a
# bevel highlight along the top and left, plus the antialiasing where the tile
# meets the card. Excluded from the gradient fit and from the artwork.
RIM = 14

# The background surface. Degree 3 is enough for this gradient (residual settles
# around 4/255) and stiff enough that the artwork cannot pull it. Fitted by
# repeatedly rejecting whatever sits more than KEEP_RESID off the current fit.
SURFACE_DEG = 3
SURFACE_PASSES = 5
KEEP_RESID = 18.0

# Distance from the recovered background, in 8-bit channel units, over which the
# artwork's alpha ramps 0 -> 1.
KEY_LO = 10.0
KEY_HI = 46.0
# Alpha above which a pixel counts as solid artwork, for measuring extent and for
# anchoring the reach test.
EXTENT_A = 0.35
# How far from solid artwork a partial pixel may sit and still be believed. The
# gradient fit is not perfect, and its error looks exactly like faint coverage;
# a real antialiased rim is always within a pixel or two of something solid.
KEY_REACH = 4

# Android hands the launcher a 108dp drawable and shows about 72dp of it. Putting
# the tile in at exactly that ratio makes the visible icon the design, unaltered.
ADAPTIVE_VISIBLE = 72 / 108
# ...and it must still clear the central 66dp circle, which is all Android
# actually guarantees. Asserted after the file is written.
ADAPTIVE_SAFE_R = 66 / 108 / 2

# Android 12+ masks the splash icon to a circle of this diameter.
A12_MASK_RATIO = 2 / 3
A12_SAFETY = 0.97

MASTER = 1024


# --------------------------------------------------------------------------
# Shapes
# --------------------------------------------------------------------------


def rrect_mask(size: int, radius: float) -> Image.Image:
    """An antialiased rounded-rect mask, `radius` as a fraction of the side.

    From the shape's signed distance rather than by supersampling: exact at any
    size, and no second buffer.
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


def _trusted(side: int) -> np.ndarray:
    """The tile's interior, minus RIM. Where the mock-up can be believed.

    The explicit margin is not redundant with the erosion: PIL's rank filters
    replicate at the image border, so eroding a mask that runs to the edge of its
    own canvas does not pull the straight edges in at all - only the corners.
    """
    base = (np.array(rrect_mask(side, CORNER)) > 250).astype(np.uint8) * 255
    inside = np.array(Image.fromarray(base).filter(ImageFilter.MinFilter(2 * RIM + 1))) > 0
    yy, xx = np.mgrid[0:side, 0:side]
    return inside & (xx >= RIM) & (xx < side - RIM) & (yy >= RIM) & (yy < side - RIM)


def _basis(u: np.ndarray, v: np.ndarray) -> np.ndarray:
    return np.stack(
        [u**i * v**j for i in range(SURFACE_DEG + 1) for j in range(SURFACE_DEG + 1 - i)],
        axis=-1,
    )


def _uv(side: int, span: float = 1.0):
    """Normalised coordinates covering `span` tiles' worth of area, centred."""
    yy, xx = np.mgrid[0:side, 0:side]
    u = ((xx + 0.5) / side * 2 - 1) * span
    v = ((yy + 0.5) / side * 2 - 1) * span
    return u, v


# --------------------------------------------------------------------------
# The mock-up, taken apart
# --------------------------------------------------------------------------


def raw_tile() -> np.ndarray:
    left, top, side = TILE_BOX
    return np.array(
        Image.open(SRC).convert("RGB").crop((left, top, left + side, top + side))
    ).astype(np.float64)


def gradient_surface(tile: np.ndarray):
    """Coefficients of the tile's background gradient, with the artwork rejected.

    Iteratively reweighted: fit, measure, keep only what the fit already explains,
    refit. The artwork covers a third of the tile, so it would drag a plain
    least-squares fit badly; after a few passes it is excluded entirely and the
    residual over the surviving pixels is the gradient's own noise.
    """
    side = tile.shape[0]
    u, v = _uv(side)
    basis = _basis(u, v)
    trusted = _trusted(side)
    keep = trusted.copy()
    for _ in range(SURFACE_PASSES):
        coefs = [np.linalg.lstsq(basis[keep], tile[..., k][keep], rcond=None)[0] for k in range(3)]
        resid = np.abs(np.stack([basis @ c for c in coefs], -1) - tile).max(axis=2)
        keep = trusted & (resid < KEEP_RESID)
    print(
        f"  gradient: degree {SURFACE_DEG} on {keep.sum():,} px "
        f"({100 * keep.sum() / trusted.sum():.0f}% of the tile survived as background), "
        f"residual mean {resid[keep].mean():.1f}/255, p99 {np.percentile(resid[keep], 99):.0f}"
    )
    return coefs


def render_surface(coefs, side: int, span: float = 1.0) -> np.ndarray:
    """The gradient over `span` tiles' worth of area.

    Beyond the tile the COORDINATES are clamped, not the colours - so the surface
    replicates its own edge outward instead of being extrapolated. A degree-3
    polynomial run 50% past its fit domain is not a gradient any more: it took the
    left corners to (20,0,102), a purple this design does not contain, in exactly
    the bleed band a launcher can reveal when it animates the icon.
    """
    u, v = _uv(side, span)
    if span > 1.0:
        u, v = np.clip(u, -1.0, 1.0), np.clip(v, -1.0, 1.0)
    return np.clip(np.stack([_basis(u, v) @ c for c in coefs], -1), 0, 255)


def source_tile(tile: np.ndarray, coefs) -> Image.Image:
    """The tile as clean RGB: artwork on its gradient, with everything the mock-up
    put outside it - or at its untrustworthy edge - replaced by the fitted
    gradient.

    Substituting the surface rather than a flat colour is what makes this work for
    a gradient tile: the replaced band is continuous with its neighbours, so the
    corner an asset shows is `rrect_mask`'s and carries no trace of the white
    presentation card the mock-up sat on.
    """
    side = tile.shape[0]
    keep = _trusted(side)
    return Image.fromarray(
        np.where(keep[..., None], tile, render_surface(coefs, side)).astype(np.uint8), "RGB"
    )


def artwork(tile: np.ndarray, coefs):
    """The artwork lifted off its gradient: premultiplied colour, and alpha.

    Alpha is keyed on distance from the recovered background - per pixel, since
    the background varies. The colour comes back PREMULTIPLIED because that is
    what survives resampling: it falls to zero exactly where alpha does, whereas
    un-premultiplied colour out there is a division by ~0 and a resample would
    smear that noise back into the edges.
    """
    side = tile.shape[0]
    bg = render_surface(coefs, side)
    d = np.abs(tile - bg).max(axis=2)
    a = np.clip((d - KEY_LO) / (KEY_HI - KEY_LO), 0, 1)
    a = np.where(_trusted(side), a, 0.0)
    # The fit's own error is indistinguishable in VALUE from faint coverage, so
    # separate them by POSITION: keep only what sits near something solid.
    solid = (a > EXTENT_A).astype(np.uint8) * 255
    near = np.array(Image.fromarray(solid).filter(ImageFilter.MaxFilter(2 * KEY_REACH + 1)))
    a = np.where(near > 0, a, 0.0)
    # premul = a*art, and art = bg + (tile-bg)/a, so this needs no division.
    return (tile - bg) + a[..., None] * bg, a


def artwork_layer(tile: np.ndarray, coefs, size: int, span: float):
    """The artwork alone on transparency, placed as if the whole tile had been
    scaled to `span` of `size` and centred - so the visible icon is the design.

    Returns the layer plus its placement, so the caller can rebuild the same thing
    out of the mock-up and diff the two.
    """
    premul, a = artwork(tile, coefs)
    inner = max(1, round(size * span))

    def resized(arr: np.ndarray, mode: str) -> np.ndarray:
        im = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), mode)
        return np.array(im.resize((inner, inner), Image.LANCZOS)).astype(np.float64)

    pm = resized(premul, "RGB")
    al = resized(a * 255, "L")
    rgb = np.clip(pm / np.maximum(al / 255, 1e-6)[..., None], 0, 255)
    art = Image.fromarray(np.dstack([rgb, al]).astype(np.uint8), "RGBA")

    off = ((size - inner) // 2, (size - inner) // 2)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    # NO mask. `paste(art, off, art)` looks like the obvious call and silently
    # squares the alpha: PIL blends the destination's alpha band through the mask
    # too, so a rim pixel at 128 lands at 64 with its colour pulled towards the
    # transparent canvas's black, thinning every antialiased edge. Onto
    # transparency an unmasked paste is a plain copy of all four bands.
    canvas.paste(art, off)
    return canvas, inner, off


# --------------------------------------------------------------------------
# Assets
# --------------------------------------------------------------------------


def tile_image(source: Image.Image, size: int, rounded: bool = True) -> Image.Image:
    """The whole tile at `size`. `rounded=False` gives the square, full-bleed
    version the Play icon wants."""
    im = source.resize((size, size), Image.LANCZOS).convert("RGBA")
    if rounded:
        im.putalpha(rrect_mask(size, CORNER))
    return im


def circumscribed_ratio(im: Image.Image, floor: int = 16) -> float:
    """Radius of the smallest centred circle covering every opaque pixel, as a
    fraction of the side. A square gives ~0.707; the rounder the art, the less."""
    a = np.array(im.split()[3])
    h, w = a.shape
    ys, xs = np.where(a > floor)
    return float(np.hypot(xs - (w - 1) / 2, ys - (h - 1) / 2).max()) / max(w, h)


def a12_padded(badge: Image.Image, size: int):
    """`badge` shrunk so it fits ENTIRELY inside the Android-12 circular splash
    mask - measured off the art, so it keeps its own corner radius instead of
    being re-cut into a circle by the OS."""
    scale = (A12_MASK_RATIO / 2) / circumscribed_ratio(badge) * A12_SAFETY
    inner = round(size * scale)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    # Unmasked, for the same reason as in artwork_layer.
    canvas.paste(badge.resize((inner, inner), Image.LANCZOS), ((size - inner) // 2,) * 2)
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


def check_adaptive(fg: Image.Image, bg: Image.Image, source: Image.Image, inner: int, off) -> None:
    """Composite the adaptive pair the way a launcher does and diff it against the
    mock-up's own tile, placed identically.

    Worth doing because BOTH halves are estimates - the background is a fitted
    surface, the alpha is keyed off that same surface - and this is the only place
    their errors are visible together: on screen, over each other. It also asserts
    the artwork clears Android's guaranteed circle, measured at the same coverage
    the placement was derived from. Reading it at a lower floor compares two
    different things, and that mismatch is exactly how such an assert can pass for
    the wrong reason.
    """
    r = circumscribed_ratio(fg, floor=round(EXTENT_A * 255))
    assert r <= ADAPTIVE_SAFE_R, (
        f"artwork radius {r:.3f} escapes Android's {ADAPTIVE_SAFE_R:.3f} safe circle"
    )
    faint = circumscribed_ratio(fg, floor=8)
    assert faint <= 0.45, f"foreground carries ink out to r={faint:.3f} - the key is leaking"

    n = fg.width
    got = Image.alpha_composite(bg.convert("RGBA").resize((n, n), Image.LANCZOS), fg)
    ref = got.copy()
    ref.paste(source.resize((inner, inner), Image.LANCZOS), off)
    err = np.abs(
        np.array(got.convert("RGB")).astype(int) - np.array(ref.convert("RGB")).astype(int)
    ).max(axis=2)
    box = np.zeros((n, n), bool)
    box[off[1] : off[1] + inner, off[0] : off[0] + inner] = True
    print(
        f"  adaptive pair vs the mock-up, over the tile: mean {err[box].mean():.2f}/255, "
        f"max {err[box].max()}, {(err[box] >= 32).sum()} px >=32, {(err[box] >= 64).sum()} >=64"
    )
    print(
        f"  artwork radius {r:.3f} of {ADAPTIVE_SAFE_R:.3f} safe "
        f"(faint ink ends at {faint:.3f}); tile spans {inner / n:.3f} of the drawable"
    )


def main() -> None:
    print("mock-up")
    tile = raw_tile()
    print(f"  tile {tile.shape[0]}px at {TILE_BOX[:2]}, corner {CORNER}")
    coefs = gradient_surface(tile)
    source = source_tile(tile, coefs)

    badge = tile_image(source, MASTER)

    print("assets/branding")
    save(badge, 1024, OUT / "appicon.png", "tile, rounded")
    save(badge, 512, OUT / "logo.png", "in-app AppLogo")
    save(badge, 768, OUT / "splash.png", "native splash")

    a12, scale = a12_padded(badge, 768)
    a12.save(OUT / "splash_android12.png")
    print(
        f"  wrote {OUT / 'splash_android12.png'} (768x768)  - tile at "
        f"{scale:.3f}, uncut by the A12 circle"
    )

    # Adaptive icon. The gradient fills the whole drawable as a SQUARE - the
    # launcher's mask draws the corners, so baking ours in would only get them cut
    # twice - and it is RENDERED over the wider domain rather than stretched, so
    # the visible 72dp carries the design's gradient at the design's own rate.
    bg_arr = render_surface(coefs, MASTER, span=1 / ADAPTIVE_VISIBLE)
    corners = [tuple(int(x) for x in bg_arr[y, x]) for y, x in ((1, 1), (1, -2), (-2, 1), (-2, -2))]
    print(
        f"  adaptive background over {1 / ADAPTIVE_VISIBLE:.2f} tiles: "
        f"range {bg_arr.min():.0f}..{bg_arr.max():.0f}, bleed corners {corners}"
    )
    bg = Image.fromarray(bg_arr.astype(np.uint8), "RGB")
    save(bg.convert("RGBA"), 1024, OUT / "icon_background.png", "adaptive background, no corners")
    fg, inner, off = artwork_layer(tile, coefs, MASTER, ADAPTIVE_VISIBLE)
    save(fg, 1024, OUT / "icon_foreground.png", "adaptive foreground")
    check_adaptive(fg, bg, source, inner, off)

    # Play wants 512x512 with no alpha and rounds it itself.
    save(
        tile_image(source, MASTER, rounded=False).convert("RGB"),
        512,
        OUT / "store_icon.png",
        "Play listing",
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
