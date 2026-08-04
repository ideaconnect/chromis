"""Generate the Google Ads video assets for an App campaign.

The same five concepts as tool/gen_ads_assets.py, as 15-second silent H.264
files in the three orientations Google serves:

    landscape  1920x1080  16:9
    square     1080x1080  1:1
    portrait   1080x1920  9:16

App campaigns take video from YouTube - "videos must be uploaded to YouTube
before they can be used" - so these are files to upload there and then point
the campaign at. Unlisted is enough and is the normal choice; PRIVATE is not,
and re-privatising or deleting a video that a campaign already references is an
automatic disapproval. Fifteen seconds sits inside Google's recommended 10-60
and inside the window that makes a vertical asset Shorts-eligible.

They carry a silent AAC track on purpose: no Google policy requires audio, but
a stream with no audio at all is the kind of thing an ingest pipeline handles
as a special case, and digital silence costs nothing. Adding a licence-clean
music bed is worth doing before these run - Google reports sound-on assets
converting materially better on Shorts - but a bed has to clear Content ID, so
it is not something to generate blind.

**One device, whose screen changes.** Every beat dissolves the capture inside a
phone that never moves, rather than sliding a new phone in. That is both the
honest reading of the product - it is one app doing all of this - and the only
composition where a dissolve is legible at 1:1 on a 1080-wide frame.

Three things about the motion are deliberate:

- **The dissolve is a linear blend of the two PREMULTIPLIED sprites, done
  before the composite, not two composites in a row.** Compositing A at alpha a
  and then B at 1-a over the same pixels gives a*a*A + ..., because the second
  composite re-attenuates what the first one laid down; the phone visibly dips
  darker in the middle of every transition. Blending first and compositing once
  is exactly a*A + (1-a)*B.
- **Nothing is re-scaled per frame.** The slow rise that keeps the frame alive
  is a sub-pixel TRANSLATION (one bilinear affine on the sprite), because a
  scale would mean a fresh LANCZOS resize 450 times per video for a change of
  under a pixel a second.
- **Sub-pixel is the point.** The phone drifts 26 px over eleven seconds - a
  fourteenth of a pixel per frame. Rounded to integers that is a 1 px jump
  every fourteen frames, which reads as a stutter rather than a drift.

The overlay layers (brand mark, claim, end card) are drawn at 2x and
downsampled once by area average: ImageDraw does not antialias, so the accent
rule's rounded ends come out stair-cased at 1x. They are premultiplied BEFORE
that downsample, or the transparent black around every glyph bleeds into its
edge - and the filter is BOX rather than LANCZOS, because pale text on a dark
field is all hard edges and LANCZOS rings a bright rim around every glyph. See
`tight`.

**No fake install button on the end card** - see tool/gen_ads_assets.py for
why; Google draws its own, and an imitation of one is a disapproval.

The words are in tool/store_copy.py (`ADS`, `ADS_BEATS`, `ADS_CLOSER`) and
`python tool/store_copy.py` measures every line against the column it lands in.

Needs ffmpeg on PATH with libx264.

Run: python tool/gen_ads_video.py [--formats landscape,square,portrait] [locale ...]
     (default: every format, en only)
Out: assets/store/ads/<play-locale>/video/<format>/NN-<concept>.mp4
"""

from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(Path(__file__).resolve().parent))

import store_copy  # noqa: E402  - sibling module, not a package
from gen_store_screens import backdrop, drop_shadow, phone  # noqa: E402

OUT = ROOT / "assets/store/ads"
CAPTURES = ROOT / "build/shots-i18n"
LOGO = ROOT / "assets/branding/logo.png"
DISPLAY = "assets/fonts/SpaceGrotesk-Variable.ttf"
BODY = "assets/fonts/Manrope-Variable.ttf"

TEXT = (234, 241, 248)
MUTED = (159, 188, 214)

FPS = 30
DURATION = 15.0
# Boundaries of the three screens, then the end card. Three and a half seconds
# is about the floor for a line of copy plus a screenshot; two seconds reads as
# a flicker and nobody finishes the sentence.
BOUNDS = [0.0, 4.2, 7.8, 11.4]
END_AT = BOUNDS[-1]
XFADE = 0.5      # screen-to-screen dissolve
RISE = 26.0      # total sub-pixel drift of the phone across the three beats
ENTER = 44.0     # how far below its mark the phone starts
LAYER_SS = 2     # overlays are drawn at 2x and downsampled once

RULE_H = 6

# One entry per orientation. `claim` is (x, y, column width, anchor), and the
# anchor differs by orientation because the copy has a different neighbour in
# each. The brand mark is pinned for the whole run, so it cannot re-centre with
# the copy; that leaves beat one's four lines and beat two's single line to be
# reconciled some other way. Where the phone sits BELOW the copy (square,
# portrait) the block is centred in the gap between the two, which keeps both
# beats evenly spaced. In landscape there is nothing under the copy at all, so
# a centred block leaves a one-line beat floating in the middle of an empty
# column - there it hangs from a fixed top edge instead, and reads as one group
# with the mark above it.
#
# `bitrate` is YouTube's own recommendation for the frame size at 30 fps -
# 8 Mbit for 1080p SDR, scaled by pixel count for the square. Constant quality
# would encode this synthetic, mostly-flat footage far leaner, which looks fine
# here and then falls apart after YouTube re-encodes it; the point of hitting
# their number is to give that second encoder something to work with.
#
# The portrait frame keeps a fifth of its height clear at the bottom: the same
# 1080x1920 asset is what runs on Shorts, and the Shorts UI - title, channel,
# buttons - sits over exactly that band.
FORMATS = {
    "landscape": {
        "size": (1920, 1080),
        "brand": (160, 286, 76, 44),
        "claim": (160, 426, 1140, "top"),
        "phone": (1598, 540, 900),
        "head": 78, "head_lh": 96, "sub": 34, "sub_lh": 50, "beat": 46,
        "rule": 78, "gap_rule": 30, "gap_sub": 28,
        "end": {"logo": 150, "mark": 84, "closer": 40, "rule": 92, "gap": 34},
        "radii": (760.0, 820.0, 1300.0, 980.0),
        "blur": 34,
        "bitrate": "8M",
    },
    "square": {
        "size": (1080, 1080),
        "brand": (96, 72, 64, 36),
        "claim": (96, 302, 888, "centre"),
        "phone": (540, 755, 562),
        "head": 56, "head_lh": 68, "sub": 25, "sub_lh": 36, "beat": 34,
        "rule": 60, "gap_rule": 26, "gap_sub": 24,
        "end": {"logo": 120, "mark": 64, "closer": 29, "rule": 72, "gap": 26},
        "radii": (560.0, 620.0, 900.0, 780.0),
        "blur": 26,
        "bitrate": "4500k",
    },
    "portrait": {
        "size": (1080, 1920),
        "brand": (96, 120, 76, 40),
        "claim": (96, 396, 888, "centre"),
        "phone": (540, 1094, 960),
        "head": 62, "head_lh": 76, "sub": 27, "sub_lh": 40, "beat": 38,
        "rule": 66, "gap_rule": 30, "gap_sub": 28,
        "end": {"logo": 140, "mark": 72, "closer": 31, "rule": 80, "gap": 30},
        "radii": (600.0, 900.0, 950.0, 1200.0),
        "blur": 30,
        "bitrate": "8M",
    },
}


# ------------------------------------------------------------------- envelopes

def clamp01(v: float) -> float:
    return 0.0 if v < 0.0 else 1.0 if v > 1.0 else v


def ease_out(t: float) -> float:
    """Cubic ease-out: fast off the mark, settles gently onto its position."""
    return 1.0 - (1.0 - clamp01(t)) ** 3


def ramp(t: float, start: float, length: float) -> float:
    return ease_out((t - start) / length) if length > 0 else float(t >= start)


# --------------------------------------------------------------- image helpers

def premultiplied(art: Image.Image) -> Image.Image:
    a = np.array(art.convert("RGBA"), dtype=np.float32)
    a[..., :3] *= a[..., 3:4] / 255.0
    return Image.fromarray(np.clip(a, 0, 255).round().astype(np.uint8), "RGBA")


def over(canvas: np.ndarray, src: np.ndarray, x0: int, y0: int, alpha: float = 1.0) -> None:
    """Composite a PREMULTIPLIED float32 RGBA block onto an RGB float32 canvas.

    Clipped, so a shadow or an entering sprite is free to hang off the edge.
    `alpha` scales the whole source, which is correct on premultiplied data:
    scaling colour and coverage together is what fading an object does.
    """
    if alpha <= 0.001:
        return
    h, w = src.shape[:2]
    ch, cw = canvas.shape[:2]
    dx0, dy0 = max(0, x0), max(0, y0)
    dx1, dy1 = min(cw, x0 + w), min(ch, y0 + h)
    if dx0 >= dx1 or dy0 >= dy1:
        return
    part = src[dy0 - y0:dy1 - y0, dx0 - x0:dx1 - x0]
    a = part[..., 3:4] * (alpha / 255.0)
    region = canvas[dy0:dy1, dx0:dx1]
    region *= 1.0 - a
    region += part[..., :3] * alpha


def shift(sprite: np.ndarray, dx: float, dy: float) -> np.ndarray:
    """Sub-pixel translate of a premultiplied float32 RGBA block.

    Bilinear, done in numpy rather than through PIL, so the array never has to
    round-trip to uint8 mid-animation and lose the fraction that is the whole
    point of doing this.
    """
    if abs(dx) < 1e-4 and abs(dy) < 1e-4:
        return sprite
    out = np.zeros_like(sprite)
    ix, iy = int(np.floor(dx)), int(np.floor(dy))
    fx, fy = dx - ix, dy - iy
    h, w = sprite.shape[:2]
    for oy, wy in ((0, 1.0 - fy), (1, fy)):
        if wy == 0.0:
            continue
        for ox, wx in ((0, 1.0 - fx), (1, fx)):
            if wx == 0.0:
                continue
            sy0, sy1 = max(0, -(iy + oy)), min(h, h - (iy + oy))
            sx0, sx1 = max(0, -(ix + ox)), min(w, w - (ix + ox))
            if sy0 >= sy1 or sx0 >= sx1:
                continue
            out[sy0 + iy + oy:sy1 + iy + oy, sx0 + ix + ox:sx1 + ix + ox] += (
                sprite[sy0:sy1, sx0:sx1] * (wx * wy)
            )
    return out


def font(path: str, size: int, weight: str, ss: int = LAYER_SS) -> ImageFont.FreeTypeFont:
    f = ImageFont.truetype(str(ROOT / path), size * ss)
    try:
        f.set_variation_by_name(weight)
    except OSError:
        pass  # static font, or that named instance is absent
    return f


def tight(layer: Image.Image) -> tuple[np.ndarray, int, int] | None:
    """Premultiply, downsample from LAYER_SS, and crop to what was drawn.

    Premultiplied BEFORE the resize: PIL interpolates the four channels
    independently, so a straight-alpha downsample mixes the transparent fill's
    black into every glyph edge. Cropped because these are composited every
    frame and most of the canvas is empty.

    **BOX, not LANCZOS.** At an integer reduction BOX is the exact area
    average, which is what supersampling means; LANCZOS has negative lobes that
    overshoot at a hard edge, and pale text on a dark field is nothing but hard
    edges. Side by side at 2x it puts a bright rim around every glyph - it
    reads as a cheap outline effect, and at video bitrates that rim is also the
    most expensive thing in the frame. LANCZOS is still right for the STILLS,
    where the downsample also has to carry photographic screen content.
    """
    small = premultiplied(layer).resize(
        (layer.width // LAYER_SS, layer.height // LAYER_SS), Image.BOX
    )
    box = small.getbbox()
    if box is None:
        return None
    return np.asarray(small.crop(box), dtype=np.float32), box[0], box[1]


# ------------------------------------------------------------------- the layers

def brand_layer(fmt: str) -> tuple[np.ndarray, int, int]:
    """Logo and wordmark, pinned for the whole run of the three beats."""
    W, H = FORMATS[fmt]["size"]
    x, y, logo_px, mark = FORMATS[fmt]["brand"]
    ss = LAYER_SS
    layer = Image.new("RGBA", (W * ss, H * ss), (0, 0, 0, 0))
    logo = premultiplied(Image.open(LOGO).convert("RGBA")).resize(
        (logo_px * ss, logo_px * ss), Image.LANCZOS
    )
    layer.paste(logo, (x * ss, y * ss))
    ImageDraw.Draw(layer).text(
        ((x + logo_px + 18) * ss, (y + logo_px / 2) * ss),
        "Chromis",
        font=font(DISPLAY, mark, "Bold"),
        fill=MUTED,
        anchor="lm",
    )
    return tight(layer)


def claim_layer(fmt: str, head: str, sub: str | None, accent) -> tuple[np.ndarray, int, int]:
    """One beat's copy: headline lines, accent rule, optional supporting lines.

    Laid out to its own height, then hung from or centred on the format's claim
    anchor - see FORMATS for why that differs by orientation.
    """
    cfg = FORMATS[fmt]
    W, H = cfg["size"]
    x, anchor, _width, mode = cfg["claim"]
    ss = LAYER_SS

    heads = head.split("\n")
    subs = sub.split("\n") if sub else []
    head_size = cfg["head"] if subs else cfg["beat"]
    head_lh = cfg["head_lh"] if subs else round(cfg["beat"] * 1.3)

    block = len(heads) * head_lh + cfg["gap_rule"] + RULE_H
    if subs:
        block += cfg["gap_sub"] + len(subs) * cfg["sub_lh"]
    y = anchor if mode == "top" else anchor - block / 2

    layer = Image.new("RGBA", (W * ss, H * ss), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    head_font = font(DISPLAY, head_size, "Bold")
    for line in heads:
        draw.text((x * ss, round(y * ss)), line, font=head_font, fill=TEXT)
        y += head_lh

    y += cfg["gap_rule"]
    draw.rounded_rectangle(
        (x * ss, round(y * ss), (x + cfg["rule"]) * ss, round((y + RULE_H) * ss)),
        radius=RULE_H * ss / 2,
        fill=accent,
    )
    y += RULE_H

    if subs:
        y += cfg["gap_sub"]
        sub_font = font(BODY, cfg["sub"], "Medium")
        for line in subs:
            draw.text((x * ss, round(y * ss)), line, font=sub_font, fill=MUTED)
            y += cfg["sub_lh"]

    return tight(layer)


def end_layer(fmt: str, closer: str, accent) -> tuple[np.ndarray, int, int]:
    """The closing card: mark, accent rule and one line, centred in the frame."""
    cfg = FORMATS[fmt]
    W, H = cfg["size"]
    end = cfg["end"]
    ss = LAYER_SS

    mark_font = font(DISPLAY, end["mark"], "Bold")
    closer_font = font(BODY, end["closer"], "Medium")
    mark_h = round(end["mark"] * 1.05)
    closer_h = round(end["closer"] * 1.4)
    block = end["logo"] + end["gap"] + mark_h + end["gap"] + RULE_H + end["gap"] + closer_h
    y = (H - block) / 2

    layer = Image.new("RGBA", (W * ss, H * ss), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    logo = premultiplied(Image.open(LOGO).convert("RGBA")).resize(
        (end["logo"] * ss, end["logo"] * ss), Image.LANCZOS
    )
    layer.paste(logo, (round((W - end["logo"]) / 2 * ss), round(y * ss)))
    y += end["logo"] + end["gap"]

    draw.text((W / 2 * ss, y * ss), "Chromis", font=mark_font, fill=TEXT, anchor="ma")
    y += mark_h + end["gap"]

    draw.rounded_rectangle(
        ((W - end["rule"]) / 2 * ss, y * ss, (W + end["rule"]) / 2 * ss, (y + RULE_H) * ss),
        radius=RULE_H * ss / 2,
        fill=accent,
    )
    y += RULE_H + end["gap"]

    draw.text((W / 2 * ss, y * ss), closer, font=closer_font, fill=MUTED, anchor="ma")
    return tight(layer)


def phone_sprites(fmt: str, src: Path, captures: list[str]):
    """The three screens as premultiplied float32 blocks, plus one shadow.

    All three are the same device at the same size, so the silhouette - and
    therefore the shadow - is shared; casting it once also means the shadow does
    not pulse during a dissolve.
    """
    cfg = FORMATS[fmt]
    cx, cy, height = cfg["phone"]
    arts = [premultiplied(phone(src / f"{c}.png", height)) for c in captures]
    shadow, pad = drop_shadow(arts[0], blur=cfg["blur"], alpha=150)

    w, h = arts[0].size
    x0, y0 = round(cx - w / 2), round(cy - h / 2)
    return (
        [np.asarray(a, dtype=np.float32) for a in arts],
        np.asarray(shadow, dtype=np.float32),
        (x0, y0),
        (x0 - pad, y0 - pad + round(cfg["blur"] * 0.6)),
    )


# ---------------------------------------------------------------- the timeline

def screen_mix(t: float) -> list[tuple[int, float]]:
    """Which capture(s) the phone shows at time t, and with what weight."""
    k = max(i for i in range(len(BOUNDS) - 1) if t >= BOUNDS[i])
    u = (t - BOUNDS[k]) / XFADE
    if k > 0 and u < 1.0:
        return [(k - 1, 1.0 - u), (k, u)]
    return [(k, 1.0)]


def settle(t: float) -> float:
    """A damped bounce on the device at each screen change.

    Without it the device is a still frame for eleven seconds with its contents
    cross-fading, which is the exact shape of the "silent slideshow of static
    screenshots" a video reviewer flags as low effort. Eight pixels, gone in
    half a second - it registers as the object reacting, not as an animation.
    """
    out = 0.0
    for b in BOUNDS[1:-1]:
        u = t - b
        if 0.0 <= u < 0.8:
            out += 8.0 * np.exp(-6.0 * u) * np.sin(2.0 * np.pi * u / 0.35)
    return out


def phone_state(t: float) -> tuple[float, float]:
    """(alpha, dy) for the device."""
    if t >= END_AT:
        u = clamp01((t - END_AT) / 0.45)
        return 1.0 - ease_out(u), -RISE + 30.0 * ease_out(u)
    enter = ramp(t, 0.0, 0.75)
    return enter, ENTER * (1.0 - enter) - RISE * clamp01(t / END_AT) + settle(t)


def claim_state(j: int, t: float) -> tuple[float, float]:
    """(alpha, dy) for beat j's copy block."""
    start, stop = BOUNDS[j], (END_AT if j == len(BOUNDS) - 2 else BOUNDS[j + 1])
    fade_in = ramp(t, start + 0.15, 0.45)
    fade_out = ramp(t, stop - 0.30, 0.35)
    return fade_in * (1.0 - fade_out), 26.0 * (1.0 - fade_in) - 20.0 * fade_out


# --------------------------------------------------------------------- encoding

def encode(dest: Path, size: tuple[int, int], bitrate: str, frames) -> None:
    """YouTube's documented upload recipe, which is the only spec that applies.

    App campaigns take video from YouTube, so there is no Google Ads transcode
    to satisfy - Google consumes whatever YouTube ingested. That makes
    support.google.com/youtube/answer/1722171 the target: MP4, H.264 High,
    CABAC, 4:2:0, two consecutive B-frames, a CLOSED GOP of half the frame rate
    (15 at 30 fps, hence keyint=15 with scenecut off, so every GOP really is 15
    and not "up to"), moov atom at the front, and AAC-LC stereo at 48 kHz.

    The audio is digital silence and is here deliberately: no Google policy
    requires a sound track, but a stream with no audio at all is the kind of
    thing an ingest pipeline handles as a special case, and 384 kbit of nothing
    removes the question. It is worth adding a licence-clean music bed later -
    Google measures sound-on assets converting materially better on Shorts -
    but a bed has to clear Content ID, so it is not something to generate blind.
    """
    W, H = size
    cmd = [
        "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
        "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "pipe:0",
        "-f", "lavfi", "-i", "anullsrc=channel_layout=stereo:sample_rate=48000",
        "-shortest",
        "-c:v", "libx264", "-preset", "slow",
        "-b:v", bitrate, "-maxrate", bitrate, "-bufsize", "16M",
        "-pix_fmt", "yuv420p", "-profile:v", "high", "-level", "4.1",
        "-x264-params", f"keyint={FPS // 2}:min-keyint={FPS // 2}:scenecut=0:"
                        "open-gop=0:bframes=2:cabac=1",
        "-c:a", "aac", "-b:a", "384k", "-ar", "48000", "-ac", "2",
        "-movflags", "+faststart",
        str(dest),
    ]
    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    try:
        for frame in frames:
            proc.stdin.write(frame.tobytes())
    finally:
        proc.stdin.close()
    if proc.wait() != 0:
        sys.exit(f"ffmpeg failed writing {dest}")


def build(fmt: str, locale: str, concept: str, head: str, sub: str, accent,
          captures: list[str], dest: Path) -> None:
    cfg = FORMATS[fmt]
    W, H = cfg["size"]
    src = CAPTURES / locale / "phone"
    cx, cy, _h = cfg["phone"]

    bg = np.asarray(
        backdrop((W, H), (cx, cy), cfg["radii"]), dtype=np.float32
    )
    arts, shadow, (px, py), (sx, sy) = phone_sprites(fmt, src, captures)

    beats = store_copy.ADS_BEATS[locale][concept]
    claims = [
        claim_layer(fmt, head, sub, accent),
        claim_layer(fmt, beats[0], None, accent),
        claim_layer(fmt, beats[1], None, accent),
    ]
    brand = brand_layer(fmt)
    ending = end_layer(fmt, store_copy.ADS_CLOSER[locale], accent)

    def frames():
        canvas = np.empty_like(bg)
        for i in range(round(DURATION * FPS)):
            t = i / FPS
            np.copyto(canvas, bg)

            alpha, dy = phone_state(t)
            if alpha > 0.001:
                mix = screen_mix(min(t, END_AT - 1e-6))
                sprite = arts[mix[0][0]] * mix[0][1]
                for k, w in mix[1:]:
                    sprite = sprite + arts[k] * w
                idy = int(np.floor(dy))
                over(canvas, shadow, sx, sy + idy, alpha)
                over(canvas, shift(sprite, 0.0, dy - idy), px, py + idy, alpha)

            for j, layer in enumerate(claims):
                a, ldy = claim_state(j, t)
                if a > 0.001:
                    block, lx, ly = layer
                    over(canvas, block, lx, ly + round(ldy), a)

            block, lx, ly = brand
            over(canvas, block, lx, ly,
                 ramp(t, 0.25, 0.5) * (1.0 - ramp(t, END_AT, 0.35)))

            block, lx, ly = ending
            a = ramp(t, END_AT + 0.35, 0.55)
            if a > 0.001:
                over(canvas, block, lx, ly + round(24 * (1.0 - a)), a)

            yield np.clip(canvas, 0, 255).astype(np.uint8)

    dest.parent.mkdir(parents=True, exist_ok=True)
    encode(dest, (W, H), cfg["bitrate"], frames())


def build_locale(locale: str, formats: list[str]) -> None:
    src = CAPTURES / locale / "phone"
    wanted = {c for _k, _h, _s, _a, caps in store_copy.ads(locale) for c in caps}
    missing = sorted(c for c in wanted if not (src / f"{c}.png").exists())
    if missing:
        sys.exit(f"missing captures in {src}: {', '.join(missing)}")

    play = store_copy.PLAY[locale]
    for fmt in formats:
        W, H = FORMATS[fmt]["size"]
        out = OUT / play / "video" / fmt
        for i, (concept, head, sub, accent, captures) in enumerate(store_copy.ads(locale)):
            dest = out / f"{i + 1:02d}-{concept}.mp4"
            build(fmt, locale, concept, head, sub, accent, captures, dest)
            print(f"  {play}  {fmt:9s} {dest.name:16s} {W}x{H}  "
                  f"{DURATION:.0f}s  {dest.stat().st_size / 1024:6.0f} KB")


def main() -> None:
    if shutil.which("ffmpeg") is None:
        sys.exit("ffmpeg is not on PATH")

    args = list(sys.argv[1:])
    formats = list(FORMATS)
    if "--formats" in args:
        i = args.index("--formats")
        formats = args[i + 1].split(",")
        del args[i:i + 2]
    unknown = [f for f in formats if f not in FORMATS]
    if unknown:
        sys.exit("unknown format(s): %s" % ", ".join(unknown))

    locales = args or ["en"]
    unknown = [loc for loc in locales if loc not in store_copy.LOCALES]
    if unknown:
        sys.exit("unknown locale(s): %s" % ", ".join(unknown))

    for locale in locales:
        build_locale(locale, formats)


if __name__ == "__main__":
    main()
