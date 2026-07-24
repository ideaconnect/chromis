"""Regenerate the in-app logo + splash images from assets/branding/appicon.png.

The launcher icon uses appicon.png directly (badge on white) via
flutter_launcher_icons. The in-app logo + splash sit on the dark UI, so they
need the badge with a TRANSPARENT background (no white box). The outer white is
removed by flood-filling from the four corners, which leaves the white elements
*inside* the art (camera ring, clouds) untouched.

Also generates the native-splash assets:
  - splash_bg.png       : a vivid vertical gradient behind the pre-Android-12 splash
  - splash_android12.png : the badge PADDED so the Android-12 circular splash
                           mask doesn't clip its corners

Run: python tool/gen_branding.py
"""

from PIL import Image, ImageDraw

SRC = "assets/branding/appicon.png"
SENTINEL = (255, 0, 255)


def badge_on_transparent(im: Image.Image, thresh: int = 60) -> Image.Image:
    """Flood-fill the outer (corner-connected) white to transparent."""
    im = im.convert("RGBA")
    rgb = im.convert("RGB")
    w, h = im.size
    for corner in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]:
        ImageDraw.floodfill(rgb, corner, SENTINEL, thresh=thresh)
    src_px = list(im.getdata())
    flood_px = list(rgb.getdata())
    im.putdata(
        [
            (r, g, b, 0 if flood == SENTINEL else a)
            for (r, g, b, a), flood in zip(src_px, flood_px)
        ]
    )
    return im.crop(im.getbbox() or (0, 0, w, h))


def to_square(im: Image.Image) -> Image.Image:
    w, h = im.size
    s = max(w, h)
    sq = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    sq.paste(im, ((s - w) // 2, (s - h) // 2))
    return sq


def padded(badge: Image.Image, size: int, scale: float = 0.62) -> Image.Image:
    """Badge scaled to `scale` of `size`, centered on a transparent square — so
    it fits inside the Android-12 circular splash mask without clipping."""
    inner = round(size * scale)
    art = badge.resize((inner, inner), Image.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(art, ((size - inner) // 2, (size - inner) // 2), art)
    return canvas


def gradient_bg(w: int, h: int, stops) -> Image.Image:
    """Vertical multi-stop gradient. `stops` = [(pos 0..1, (r, g, b)), ...].
    Built as a 1×h column then stretched — fast and smooth."""
    col = Image.new("RGB", (1, h))
    px = col.load()
    for y in range(h):
        t = y / (h - 1)
        r = g = b = 0
        for i in range(len(stops) - 1):
            p0, c0 = stops[i]
            p1, c1 = stops[i + 1]
            if p0 <= t <= p1:
                f = (t - p0) / (p1 - p0) if p1 > p0 else 0.0
                r = round(c0[0] + (c1[0] - c0[0]) * f)
                g = round(c0[1] + (c1[1] - c0[1]) * f)
                b = round(c0[2] + (c1[2] - c0[2]) * f)
                break
        else:
            r, g, b = stops[-1][1]
        px[0, y] = (r, g, b)
    return col.resize((w, h))


def save(im: Image.Image, size: int, path: str) -> None:
    im.resize((size, size), Image.LANCZOS).save(path)
    print(f"  wrote {path} ({size}x{size})")


def main() -> None:
    src = Image.open(SRC).convert("RGBA")
    floating = to_square(badge_on_transparent(src))
    print(f"badge (transparent bg): {floating.size}")
    save(floating, 512, "assets/branding/logo.png")
    save(floating, 768, "assets/branding/splash.png")
    padded(floating, 768).save("assets/branding/splash_android12.png")
    print("  wrote assets/branding/splash_android12.png (768, padded for A12)")
    gradient_bg(
        720,
        1280,
        [(0.0, (27, 37, 80)), (0.5, (10, 21, 38)), (1.0, (26, 15, 48))],
    ).save("assets/branding/splash_bg.png")
    print("  wrote assets/branding/splash_bg.png (720x1280 gradient)")
    # On-white full badge for the legacy square launcher (adaptive uses appicon).
    src.resize((1024, 1024), Image.LANCZOS).save(
        "assets/branding/icon_launcher.png"
    )
    print("  wrote assets/branding/icon_launcher.png (1024x1024)")


if __name__ == "__main__":
    main()
