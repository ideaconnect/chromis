#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Measure translated labels against the slots that cannot grow.

    python3 tool/measure_labels.py            # check every slot, every locale
    python3 tool/measure_labels.py --verbose  # print every measurement

Why this exists
---------------
A translation that does not fit does NOT throw. It ellipsizes, silently, and
no test goes red - "+ Hinzu..." where the German said "Hinzufuegen". A widget
test cannot catch it either: flutter_test substitutes a monospaced font in
which every glyph is a full em wide, and a `FontLoader` over the variable font
pins it at its default instance rather than the weight the widget asks for. A
probe built that way called English "Untitled" truncated in the editor top bar,
which every screenshot shows fitting.

So the measurement is done here instead, off the real TTF at the real weight
and size, using the same advance widths the engine uses. Numbers produced this
way have matched the device every time they have been checked.

Slots are listed below with the geometry they come from. When you add a
fixed-width text slot, add it here; when a label goes over, either widen the
slot (if it has give) or shorten the string (if it does not).

The six below are the COMPLETE set as of this writing - every `SizedBox` with
a literal width that contains text was enumerated, and everything else that
matched is a spacer, a spinner or a gap. Two of them were found one review
round apart, both the same way: a slot sized around English, where the longest
English label left 20dp of slack and four translations were being cut.

Needs fonttools (`pip install fonttools`); it is a dev-time check, not a build
step, and nothing in the app depends on it.
"""
import io
import json
import sys

try:
    from fontTools.ttLib import TTFont
    from fontTools.varLib.instancer import instantiateVariableFont
except ImportError:  # pragma: no cover
    sys.exit("needs fonttools:  pip install fonttools")

LOCALES = ["en", "pl", "de", "es", "fr", "cs"]

UI_FONT = "assets/fonts/Manrope-Variable.ttf"

# name -> (dp budget, font size, weight, why that budget, keys)
SLOTS = {
    "grid template strip": (
        # 72, not the 74 the SizedBox declares. Measured on the device,
        # "Wysokie u gory" (69.7dp) fits and "Szerokie z lewej" (73.5dp) is
        # cut, so the usable width is short of the declared box - rounding and
        # the ellipsis threshold eat the last couple of dp. Leave the margin.
        72.0, 9.5, 700,
        "SizedBox(width: _tileWidth + 12) in grid_template_strip.dart, with "
        "_tileWidth = (tileHeight * aspect).clamp(40, 104) and tileHeight 62 - "
        "so 74dp on the square canvas the setup sheet opens on, 61.6 portrait, "
        "52 Story",
        [
            "gridSideBySide", "gridStacked", "gridWideLeft", "gridTallTop",
            "gridColumns", "gridRows", "gridBigLeft", "gridBigTop",
            "gridTwoByTwo", "gridTwoOverThree", "gridThreeOverTwo",
            "gridTwoLeftThreeRight",
        ],
    ),
    "bubble panel format row": (
        # _kBubbleRowTile (116) less the tile's 8dp horizontal padding a side
        # and the 1dp border a side that Container folds in via
        # decoration.padding: 116 - 16 - 2 = 98. This slot was sized around
        # English and cut de "Sprechblase", de "Fluesterblase",
        # es "Pensamiento" and fr "Chuchotement" at its old 92.
        98.0, 12.5, 700,
        "SizedBox(width: _kBubbleRowTile) in editor_screen.dart, less the "
        "tile's 8dp padding and 1dp border each side",
        [
            "bubbleSpeech", "bubbleThought", "bubbleShout", "bubbleCaption",
            "bubbleWhisper",
        ],
    ),
    "bubble/text colour rows": (
        # SizedBox(width: 84) in _swatchRow, editor_screen.dart. Widened from
        # 52 after Polish "Wypelnienie" was broken mid-word - a single word
        # cannot wrap, so a box narrower than it splits it. No inner padding.
        84.0, 12.0, 400,
        "SizedBox(width: 84) holding the label beside the scrolling swatches",
        ["color", "fill", "outline"],
    ),
    "editor dock": (
        64.0, 9.5, 700,
        "a hard SizedBox(width: 64) around each _DockItem label "
        "(editor_screen.dart, Text at 9.5sp w700)",
        [
            "goPro", "toolGrid", "addLayer", "toolText", "bubble", "aiCut",
            "erase", "crop", "toolAdjust", "toolEffects", "toolLayers",
        ],
    ),
    "crop buttons": (
        # Full panel width now: 360 - 36 of _panel padding - 48 of M3
        # OutlinedButton padding. They used to share a 2:1 Row, which left
        # Reset crop about 72dp of text - enough for English "Reset crop" and
        # for none of its translations. Stacking them is what fixed it; this
        # row is here so the slot cannot quietly narrow again.
        276.0, 13.0, 700,
        "each button is full width in _panel's Column: 360 - 36 - 48",
        ["cropPhoto", "editCrop", "resetCrop"],
    ),
    "export format chip": (
        101.0, 9.5, 400,
        "three Expanded chips share the export row, which is padded "
        "LTRB(20, .., 20, ..) with two 8dp gaps: (360 - 40 - 16) / 3",
        ["formatPngSub", "formatJpgSub", "formatWebpSub"],
    ),
}


def measure_fn(size, weight):
    font = TTFont(UI_FONT)
    try:
        font = instantiateVariableFont(font, {"wght": weight}, inplace=False)
    except Exception:
        pass  # static font, or no wght axis - default instance is close enough
    upem = font["head"].unitsPerEm
    cmap = font.getBestCmap()
    hmtx = font["hmtx"]
    known = set(font.getGlyphOrder())

    def width(text):
        total = 0
        for ch in text:
            name = cmap.get(ord(ch))
            if name not in known:
                name = ".notdef"
            total += hmtx[name][0]
        return total / upem * size

    return width


def main():
    verbose = "--verbose" in sys.argv
    arb = {
        loc: json.load(io.open("lib/l10n/app_%s.arb" % loc, encoding="utf-8"))
        for loc in LOCALES
    }

    over = []
    for slot, (budget, size, weight, why, keys) in SLOTS.items():
        width = measure_fn(size, weight)
        print("%s - %.0fdp at %.1fsp/w%d" % (slot, budget, size, weight))
        print("  %s" % why)
        for key in keys:
            cells = []
            for loc in LOCALES:
                value = arb[loc].get(key)
                if value is None:
                    continue
                w = width(value)
                if w > budget:
                    over.append((slot, loc, key, value, w, budget))
                cells.append("%s %.0f%s" % (loc, w, "!" if w > budget else ""))
            if verbose:
                print("    %-24s %s" % (key, "  ".join(cells)))
        print()

    if not over:
        print("every label fits its slot in every language")
        return 0
    print("OVER BUDGET: %d" % len(over))
    for slot, loc, key, value, w, budget in sorted(over, key=lambda r: -r[4]):
        print("  %s  %s %s  %.1f/%.0fdp  %r" % (slot, loc, key, w, budget, value))
    return 1


if __name__ == "__main__":
    sys.exit(main())
