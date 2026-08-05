#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Assert every store capture is present, the right size, and from THIS run.

    python tool/verify_shots.py                       # completeness + sizes
    python tool/verify_shots.py --since 21:02         # nothing older, any device
    python tool/verify_shots.py --since tab10=21:02,tab7=21:02

The `--since` check is the one that is not obvious. A capture run that is
stopped part way leaves the previous run's PNGs on disk under the same names,
so the next thing to read them - `gen_store_screens.py` - cannot tell a fresh
set from a half-replaced one, and neither can a file listing. That is how a
tablet set captured before a device fix survived into the composed listing:
every file was there, every file was the right size, and half of them were an
hour old.

It takes a cutoff **per profile** rather than one for everything, because the
devices are fixed and re-run independently - a phone set that was right the
first time is not stale merely because the tablets were re-captured after it.
One bare time applies to every profile.
"""
from __future__ import annotations

import sys
import time
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "build" / "shots-i18n"
LOCALES = ["en", "pl", "de", "es", "fr", "cs"]
SHOTS = ["cutout_result", "sticker", "effects", "layers",
         "grid", "objremove_panel", "bubble", "home"]
# profile -> the device resolution its captures must be, portrait or landscape
SIZES = {"phone": (1280, 2856), "tab10": (2560, 1600), "tab7": (1920, 1200)}


def main() -> int:
    def stamp(hhmm):
        now = time.localtime()
        h, m = hhmm.split(":")
        return time.mktime((now.tm_year, now.tm_mon, now.tm_mday,
                            int(h), int(m), 0, 0, 0, -1))

    cutoff = {}
    if "--since" in sys.argv:
        arg = sys.argv[sys.argv.index("--since") + 1]
        if "=" in arg:
            for part in arg.split(","):
                prof, hhmm = part.split("=")
                cutoff[prof] = stamp(hhmm)
        else:
            cutoff = {p: stamp(arg) for p in SIZES}

    problems = []
    for locale in LOCALES:
        row = []
        for profile, size in SIZES.items():
            d = SRC / locale / profile
            missing, wrong, stale, oldest = [], [], [], None
            for shot in SHOTS:
                p = d / ("%s.png" % shot)
                if not p.exists():
                    missing.append(shot)
                    continue
                with Image.open(p) as img:
                    if img.size != size:
                        wrong.append("%s=%dx%d" % (shot, *img.size))
                mtime = p.stat().st_mtime
                oldest = mtime if oldest is None else min(oldest, mtime)
                if profile in cutoff and mtime < cutoff[profile]:
                    stale.append(shot)
            mark = "ok"
            if missing:
                problems.append("%s/%s missing: %s" % (locale, profile, ", ".join(missing)))
                mark = "MISSING %d" % len(missing)
            elif wrong:
                problems.append("%s/%s wrong size: %s" % (locale, profile, ", ".join(wrong)))
                mark = "SIZE"
            elif stale:
                problems.append("%s/%s from an earlier run: %s"
                                % (locale, profile, ", ".join(stale)))
                mark = "STALE %d" % len(stale)
            row.append("%s %-10s %s" % (
                profile, mark,
                time.strftime("%H:%M", time.localtime(oldest)) if oldest else "-"))
        print("  %-3s %s" % (locale, " | ".join(row)))

    if problems:
        print("\nPROBLEMS: %d" % len(problems))
        for p in problems:
            print("  " + p)
        return 1
    print("\nall %d captures present, right size%s"
          % (len(LOCALES) * len(SIZES) * len(SHOTS),
             ", and from this run" if cutoff else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
