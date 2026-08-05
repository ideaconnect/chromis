#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Check every Play listing in assets/store/<locale>/details.md.

    python tool/check_store_listings.py

Three things go wrong with a translated store listing, and none of them is
visible until Play rejects the upload or a user reads it:

1. **Length.** Play truncates the title at 30 characters and the short
   description at 80 - silently, in the console form. German and Spanish run
   20-35% longer than English, which is exactly the margin those two fields
   do not have.

2. **A feature count that drifted.** The long description promises 14 looks,
   16 blend modes, 18 layouts, 5 bubble shapes. Those are counted from the
   source here, not trusted, because the listing is the one place a stale
   number is a false advertising claim rather than a typo.

3. **A control named in a language the app does not use.** The description
   walks the user through named buttons - the filters, the bubble shapes, the
   canvas presets. Those come from `lib/l10n/localized_labels.dart`, and a
   description that names "Vivid" to a Polish reader is naming a button that
   says "Żywy". Every label the copy quotes must be the one the ARB gives for
   that locale.

4. **Release notes over 500 characters.** `docs/release/whatsnew-<version>.txt`
   holds all six languages in Play's `<en-US>…</en-US>` block format, and the
   cap is **per language**, not per file. Measured with the newlines counted
   twice, because a paste that converts LF to CRLF adds one character per line
   and Play measures what it received, not what was typed.

Nothing here needs Flutter or a device; it reads the ARBs and the Dart enums.
"""
from __future__ import annotations

import io
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STORE = os.path.join(ROOT, "assets", "store")

# Play's own limits.
LIMITS = {"title": 30, "short": 80, "long": 4000}

LOCALES = {"en-US": "en", "pl-PL": "pl", "de-DE": "de", "es-ES": "es",
           "fr-FR": "fr", "cs-CZ": "cs"}

# ARB keys whose value the long description quotes, grouped by the sentence
# that has to list all of them. A locale's copy must contain every one.
QUOTED = {
    "filters": ["filterVivid", "filterPunch", "filterChrome", "filterWarm",
                "filterCool", "filterSunset", "filterDawn", "filterDusk",
                "filterFade", "filterMatte", "filterRetro", "filterSepia",
                "filterMono", "filterNoir"],
    "bubble shapes": ["bubbleSpeech", "bubbleThought", "bubbleShout",
                      "bubbleCaption", "bubbleWhisper"],
    "blend ends": ["blendMultiply", "blendLuminosity"],
    "canvas presets": ["presetSquare", "presetPortrait", "presetStory"],
}

# Claims that are numbers. Counted from the source rather than trusted; the
# count is what the copy must contain, spelled as digits.
COUNTED = {
    "filters": ("lib/core/models/photo_filter.dart", r"^\s+(\w+)\(", 1),
    "blends": ("lib/core/models/layer_effects.dart", None, 0),
}

ASPECTS = ["1:1", "4:5", "9:16", "16:9", "3:2", "2:3"]

WHATSNEW_LIMIT = 500
RELEASE_DIR = os.path.join(ROOT, "docs", "release")


def check_whatsnew(problems):
    """Every language block in the newest whatsnew file, against Play's cap."""
    files = sorted(f for f in os.listdir(RELEASE_DIR) if f.startswith("whatsnew-"))
    if not files:
        return
    path = os.path.join(RELEASE_DIR, files[-1])
    text = read(path)
    blocks = re.findall(r"<([a-z]{2}-[A-Z]{2})>\n(.*?)\n</\1>", text, re.S)
    print("\n%s" % files[-1])
    seen = {tag for tag, _ in blocks}
    for tag in LOCALES:
        if tag not in seen:
            problems.append("%s: no <%s> block in %s" % (tag, tag, files[-1]))
    for tag, body in blocks:
        # +1 per line: a paste that converts LF to CRLF is what Play measures.
        n = len(body) + body.count("\n")
        print("  %-6s %d/%d%s" % (tag, n, WHATSNEW_LIMIT,
                                  "!" if n > WHATSNEW_LIMIT else ""))
        if n > WHATSNEW_LIMIT:
            problems.append("%s: release notes are %d chars, Play allows %d"
                            % (tag, n, WHATSNEW_LIMIT))


def read(path):
    with io.open(path, encoding="utf-8") as fh:
        return fh.read()


def sections(text):
    """Split details.md into title / short / long."""
    out, key = {}, None
    buf = []
    for line in text.splitlines():
        low = line.lower()
        if low.startswith("# title"):
            key, buf = "title", []
        elif low.startswith("# short description"):
            out[key] = "\n".join(buf).strip()
            key, buf = "short", []
        elif low.startswith("# long description"):
            out[key] = "\n".join(buf).strip()
            key, buf = "long", []
        elif key:
            buf.append(line)
    out[key] = "\n".join(buf).strip()
    return out


def enum_values(text, name):
    """The value list of `enum name { ... ; ... }`, which ends at the semicolon
    - past it are the constructor and the getters, and counting those is how a
    16-mode enum reports 21."""
    body = text.split("enum %s {" % name, 1)[1].split(";", 1)[0]
    return re.findall(r"^\s{2}(\w+)\(", body, re.M)


def counts():
    """The numbers the copy claims, counted from the source."""
    filters = read(os.path.join(ROOT, "lib/core/models/photo_filter.dart"))
    # minus `none`, which is the "Original" tile rather than a look
    n_filters = len(enum_values(filters, "PhotoFilter")) - 1
    blends = read(os.path.join(ROOT, "lib/core/models/layer_effects.dart"))
    n_blends = len(enum_values(blends, "LayerBlend"))
    grids = read(os.path.join(ROOT, "lib/features/grid/grid_templates.dart"))
    # only the ones the switch actually offers, not the class or the helpers
    switch = grids.split("gridTemplatesFor(int count) => switch", 1)[1]
    n_grids = len(re.findall(r"GridTemplate\(", switch.split("\n};", 1)[0]))
    fonts = read(os.path.join(ROOT, "lib/core/theme/app_typography.dart"))
    block = fonts.split("bundledFonts")[1].split("]")[0]
    n_fonts = len([ln for ln in block.splitlines() if ln.strip().endswith(",")])
    return {"looks": n_filters, "blend modes": n_blends,
            "grid layouts": n_grids, "bundled fonts": n_fonts}


def names(label, copy):
    """Does `copy` name the control `label`?

    Not an exact substring: a label is a nominative noun and the copy is
    running prose, so Polish turns "Mnożenie" into "od Mnożenia" and Spanish
    lowercases "Cuadrado" mid-sentence. Match on a case-folded stem instead -
    enough to prove the copy is not quoting the English button, which is the
    failure this is here to catch.
    """
    stem = label.casefold()
    if len(stem) > 4:
        stem = stem[:-2]
    return stem in copy.casefold()


def check_website(claim, problems):
    """The landing page counts the same things, so it can be wrong the same way.

    It said "15 filters" for two releases while the listing said 14 - both
    describing one enum. The site is not translated, so this is only the count
    check and not the named-control one, but the count is the half that is a
    false claim rather than an awkward sentence.

    A number is looked for as `<n> <word>` rather than anywhere in the file:
    the page is full of unrelated integers (image widths, "2 to 5 photos", the
    26 MB model), and a bare `"14" in page` passes on any of them.
    """
    path = os.path.join(ROOT, "website", "index.html")
    if not os.path.exists(path):
        problems.append("website/index.html missing")
        return
    page = read(path)
    print()
    print("website/index.html")
    # what the page calls each thing -> the count it must agree with
    for what, words in (("looks", ("looks", "filters")),
                        ("blend modes", ("blend modes",)),
                        ("grid layouts", ("layouts",))):
        n = claim[what]
        found = {w: len(re.findall(r"\b%d\s+%s\b" % (n, w), page)) for w in words}
        stale = [w for w in words
                 if re.search(r"\b(?!%d\b)\d+\s+%s\b" % (n, w), page)]
        total = sum(found.values())
        print("  %-12s %d  (%s)" % (what, n,
              ", ".join("%s x%d" % (w, c) for w, c in found.items())))
        if not total:
            problems.append("website: never says %d %s" % (n, "/".join(words)))
        for w in stale:
            hit = re.search(r"\b(?!%d\b)(\d+)\s+%s\b" % (n, w), page).group(1)
            problems.append("website: says %s %s, the source has %d"
                            % (hit, w, n))


def main():
    arb = {code: json.loads(read(os.path.join(ROOT, "lib/l10n/app_%s.arb" % code)))
           for code in LOCALES.values()}
    claim = counts()
    problems = []

    print("counted from the source: " +
          ", ".join("%s=%d" % kv for kv in sorted(claim.items())))
    print()

    for play, code in LOCALES.items():
        path = os.path.join(STORE, play, "details.md")
        if not os.path.exists(path):
            problems.append("%s: no details.md" % play)
            continue
        s = sections(read(path))
        lens = {k: len(s.get(k, "")) for k in LIMITS}
        flags = ["%s %d/%d%s" % (k, lens[k], LIMITS[k],
                                 "!" if lens[k] > LIMITS[k] else "")
                 for k in ("title", "short", "long")]
        print("%-6s %s" % (play, "  ".join(flags)))
        for k, limit in LIMITS.items():
            if lens[k] > limit:
                problems.append("%s: %s is %d chars, Play allows %d"
                                % (play, k, lens[k], limit))

        long = s.get("long", "")
        for group, keys in QUOTED.items():
            missing = [arb[code][k] for k in keys if not names(arb[code][k], long)]
            if missing:
                problems.append("%s: %s not named in the copy: %s"
                                % (play, group, ", ".join(missing)))
        for what, n in claim.items():
            if str(n) not in long:
                problems.append("%s: the copy never says %d (%s)" % (play, n, what))
        for ratio in ASPECTS:
            if ratio not in long:
                problems.append("%s: crop ratio %s missing" % (play, ratio))
        for token in ("8.0", "80 px", "60 px", "U2-Net", ".ttf", ".otf",
                      "PNG", "JPG", "WebP", "100", "75", "50", "25", "200"):
            if token not in long:
                problems.append("%s: %r missing from the copy" % (play, token))

    check_whatsnew(problems)
    check_website(claim, problems)

    print()
    if not problems:
        print("every listing fits Play's limits and names the right controls")
        return 0
    print("PROBLEMS: %d" % len(problems))
    for p in problems:
        print("  " + p)
    return 1


if __name__ == "__main__":
    sys.exit(main())
