"""Subset the site's two typefaces to woff2, so the page contacts nobody.

The site used to pull Manrope and Space Grotesk from `fonts.googleapis.com`,
which is a request to Google - carrying the visitor's IP, user agent and
referrer - on **every page load, before the cookie banner and regardless of what
they answer**. On a site whose entire claim is that the app talks to nobody, an
unconditional third-party call for a font is the wrong shape, and it is the one
piece of the page a Decline could not switch off.

Both faces are already in this repo under the SIL Open Font License, which
permits redistribution, so self-hosting costs nothing but the bytes - and after
subsetting it costs fewer bytes than the round trip did.

**Subset to Latin-1 plus the punctuation the copy actually uses.** These are
variable fonts, and shipping the full character set of one is ~150 KB where the
page needs a few hundred glyphs. The range below is Basic Latin + Latin-1
Supplement + Latin Extended-A (so European names in the footer and any German or
Polish quoted in the copy still render) + the typographic marks the pages use -
curly quotes, the en/em dashes, the middot the trustbar and footer are built
from, the arrows in the before/after knob, and the bullet.

**The weight axis is kept, not instanced.** `styles.css` asks for 400/500/600/700
of Manrope and 500/600/700 of Space Grotesk; pinning one instance would silently
render every other weight as a synthetic smear. `--variations` keeps the `wght`
axis and `font-variation-settings` is not needed, because a `@font-face` that
declares `font-weight: 400 700` lets the browser drive the axis from the ordinary
`font-weight` property.

    python tool/gen_web_fonts.py

Writes website/assets/fonts/*.woff2. Re-run if the families or the copy's
character set change; the CSS `@font-face` block lives in styles.css.
"""

from __future__ import annotations

import os
import sys

from fontTools import subset
from fontTools.ttLib import TTFont

ROOT = os.getcwd()
SRC = os.path.join(ROOT, "assets", "fonts")
OUT = os.path.join(ROOT, "website", "assets", "fonts")

# Basic Latin + Latin-1 Supplement + Latin Extended-A, then the marks the pages
# actually contain. Anything not listed renders from the fallback stack, which is
# why the extras are enumerated rather than guessed at.
UNICODES = "U+0020-007E,U+00A0-00FF,U+0100-017F"
EXTRA = [
    0x2018, 0x2019, 0x201C, 0x201D,  # curly quotes - the legal pages use them
    0x2013, 0x2014,                  # en dash, em dash
    0x00B7, 0x2022,                  # middot (trustbar, footer), bullet
    0x00A9,                          # (c) in the footer
    0x00B2,                          # superscript two - "U²-Netp"
    0x21C4, 0x2192,                  # the before/after knob's arrows
    0x2026,                          # ellipsis
]

FACES = [
    ("Manrope-Variable.ttf", "manrope.woff2"),
    ("SpaceGrotesk-Variable.ttf", "space-grotesk.woff2"),
]


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    missing = [n for n, _ in FACES if not os.path.exists(os.path.join(SRC, n))]
    if missing:
        sys.exit("missing source fonts in %s: %s" % (SRC, ", ".join(missing)))

    total_before = total_after = 0
    for src_name, out_name in FACES:
        src = os.path.join(SRC, src_name)
        dest = os.path.join(OUT, out_name)

        opts = subset.Options()
        opts.flavor = "woff2"
        # Keep the weight axis: the CSS asks for four weights of Manrope, and an
        # instanced font would have the browser synthesise the other three.
        opts.retain_gids = False
        opts.desubroutinize = False
        opts.layout_features = ["*"]
        opts.name_IDs = ["*"]
        opts.notdef_outline = True
        opts.recalc_bounds = True

        font = TTFont(src)
        subsetter = subset.Subsetter(options=opts)
        subsetter.populate(
            unicodes=subset.parse_unicodes(UNICODES) + EXTRA,
        )
        subsetter.subset(font)
        font.flavor = "woff2"
        font.save(dest)
        font.close()

        before = os.path.getsize(src)
        after = os.path.getsize(dest)
        total_before += before
        total_after += after
        print("  %-22s %6.1f KB -> %5.1f KB  (%.0f%% smaller)"
              % (out_name, before / 1024, after / 1024,
                 100 * (1 - after / before)))

    print("  %-22s %6.1f KB -> %5.1f KB"
          % ("total", total_before / 1024, total_after / 1024))


if __name__ == "__main__":
    main()
