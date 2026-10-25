#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Split a release's "What's new" into the files Play's upload API takes.

    python tool/play_release_notes.py docs/release/whatsnew-1.4.2.txt build/whatsnew

`docs/release/whatsnew-<version>.txt` holds all six languages in the
`<en-US>…</en-US>` block format the Play Console accepts as a paste. The
upload API takes one file per language instead, and
`.github/workflows/play.yml` hands it the directory this writes:
`whatsnew-en-US`, `whatsnew-pl-PL`, ...

What this writes goes straight to the update screen of every user, and
nothing reviews it on the way, so it is checked first:

1. **Every listing language, once.** A language with no block shows its users
   the English notes; two blocks for one language means one of them is lost.

2. **Play's 500-character cap**, measured exactly as
   `check_store_listings.py` measures it - the same function.

3. **Nothing that only a developer knows.** The notes describe what changed
   for the person using the app. Issue numbers, links, source files and the
   names of the tools the app is built and shipped with are developer
   knowledge - and a GitHub release body is made of them, which is why the
   workflow never falls back to one. This is a net for the obvious leaks, not
   a review: it cannot tell that "the export is faster" is fine and "the
   export no longer blocks the main thread" is not.

Exits non-zero and writes nothing if any check fails.
"""
from __future__ import annotations

import io
import os
import re
import sys

from check_store_listings import (LOCALES, WHATSNEW_LIMIT, whatsnew_blocks,
                                  whatsnew_length)

# (pattern, what it is). Word boundaries are Unicode-aware here, so "CI" does
# not match inside Polish "pamięci"; it is case-sensitive for the same reason.
INTERNAL = [
    (r"#\d+", "an issue or pull request number"),
    (r"https?://|www\.", "a link"),
    (r"\b[\w./-]+\.(?:dart|py|ya?ml|kts|gradle|json|md|txt)\b", "a file name"),
    (r"\b(?:lib|test|tool|docs|android|assets)/", "a source path"),
    (r"(?i)\bgithub\b", "GitHub"),
    (r"\bCI\b", "CI"),
    (r"(?i)\bflutter\b", "the app's framework"),
    (r"(?i)\bversion ?code\b", "the version code"),
    (r"(?i)\bplay console\b", "the Play Console"),
    (r"(?i)\bclaude\b", "the coding assistant"),
    (r"(?i)\b(?:commit|pull request|deploy\w*)\b", "a development step"),
]


def problems_in(text):
    """Every reason these notes must not reach Play, as strings."""
    blocks = whatsnew_blocks(text)
    found = []
    tags = [tag for tag, _ in blocks]
    for tag in LOCALES:
        if tag not in tags:
            found.append("%s: no <%s> block" % (tag, tag))
    for tag in sorted(set(tags)):
        if tags.count(tag) > 1:
            found.append("%s: %d blocks" % (tag, tags.count(tag)))
        if tag not in LOCALES:
            found.append("%s: not a listing language" % tag)
    for tag, body in blocks:
        if not body.strip():
            found.append("%s: empty" % tag)
        n = whatsnew_length(body)
        if n > WHATSNEW_LIMIT:
            found.append("%s: %d characters, Play allows %d"
                         % (tag, n, WHATSNEW_LIMIT))
        for pattern, what in INTERNAL:
            hit = re.search(pattern, body)
            if hit:
                found.append("%s: %s (%r) - the notes are for users"
                             % (tag, what, hit.group(0)))
    return found


def main(argv):
    if len(argv) != 3:
        print(__doc__.strip().splitlines()[2].strip())
        return 2
    source, out = argv[1], argv[2]
    if not os.path.isfile(source):
        print("%s: missing. Write the user-facing notes for this version "
              "first - the GitHub release text is never used." % source)
        return 1
    with io.open(source, encoding="utf-8") as fh:
        text = fh.read()
    found = problems_in(text)
    if found:
        print("%s:" % source)
        for p in found:
            print("  " + p)
        return 1
    os.makedirs(out, exist_ok=True)
    for tag, body in whatsnew_blocks(text):
        # LF and no trailing newline: the API stores the file as it is sent.
        with io.open(os.path.join(out, "whatsnew-" + tag), "w",
                     encoding="utf-8", newline="\n") as fh:
            fh.write(body.strip())
        print("  %-6s %d/%d" % (tag, whatsnew_length(body), WHATSNEW_LIMIT))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
