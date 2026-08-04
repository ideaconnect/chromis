#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Drive three emulators through the eight store-screenshot states, per language.

    python tool/capture_store_shots.py phone            # every locale
    python tool/capture_store_shots.py tab10 pl de      # two of them
    python tool/capture_store_shots.py phone en sticker # one shot, to re-check

Writes `build/shots-i18n/<locale>/<profile>/<shot>.png`, which is what
`tool/gen_store_screens.py` and `tool/gen_store_graphic.py` read. Run the three
profiles concurrently - they are separate devices and do not contend.

Why the whole thing is re-captured per language
-----------------------------------------------
A store screenshot is a picture of the app, and every word inside the device
frame is UI text. Translating only the caption painted beside the phone gives a
Polish listing with an English screenshot in it, which is worse than no
localized listing at all. So the app's per-app locale is set with
`cmd locale set-app-locales` and all eight states are driven again.

The tap tables are locale-independent on purpose: layout does not move when the
glyphs change, so a sequence verified once in English holds for all six. What
does move is the device - portrait puts the tools in a scrolling dock along the
bottom, landscape puts them in a rail down the left, and the 7-inch rail scrolls
while the 10-inch one does not. Hence three tables, not one scaled.

Preconditions
-------------
- Three emulators: a phone at 1280x2856/480dpi, an sw800dp tablet at
  2560x1600/320dpi, an sw600dp tablet at 1920x1200/320dpi, all in their natural
  orientation (`user_rotation 0` is portrait on the phone, landscape on both
  tablets).
- A **debug** build installed. Everything that touches app-private data goes
  through `run-as`, and these are Play-store system images, so `adb root` is
  refused. The debug build is also how the Pro entitlement gets set, which is
  what keeps ads out of the captures.
- The sample photos already in the app's `projects/assets` (`img_*`, `mask_*`).
  This script writes the manifests that point at them; it does not import
  photos. Copy the directory from a device that has them with
  `run-as ... tar -cf -`.

Two things that were not obvious
--------------------------------
- **Notifications, not demo mode, decide the status bar.** `sysui_demo` pins
  the clock at 9:41 and the signal bars, but its `notifications visible false`
  does not hide notification ICONS, so whatever the emulator happened to be
  nagging about that week lands in every shot. They are snoozed instead, all
  but the Safety-Center shield that the first capture session also had.
- **Binary over `adb shell` stdin gets mangled**, `-T` included. Files travel
  as a tar pushed to /data/local/tmp - world-traversable, so the app uid can
  read it - and are unpacked by `run-as tar -xf`.
"""
from __future__ import annotations

import io
import json
import os
import subprocess
import sys
import tarfile
import time
import traceback
from pathlib import Path

PKG = "tech.idct.chromis"
APPDIR = "/data/data/%s/app_flutter" % PKG
ROOT = Path(__file__).resolve().parent.parent
OUTDIR = ROOT / "build" / "shots-i18n"
STAGING = ROOT / "build" / "shots-i18n" / ".staging"

LOCALES = ["en", "pl", "de", "es", "fr", "cs"]
LOCALE_TAGS = {"en": "en-US", "pl": "pl-PL", "de": "de-DE",
               "es": "es-ES", "fr": "fr-FR", "cs": "cs-CZ"}

# ----------------------------------------------------------------- documents
#
# Project names, layer names, the sticker's caption and the bubble's line are
# document data: the app localizes them at the call site that creates them and
# writes the result into the manifest, then never re-translates it (CLAUDE.md).
# A screenshot in Polish therefore needs Polish names ON DISK, not just a
# Polish build - which is why they are here rather than read from the ARB.
ASSETS = "/data/user/0/%s/app_flutter/projects/assets" % PKG
DOG = ASSETS + "/img_1785189869988262.jpg"
MASK = ASSETS + "/mask_l_1_1785189950064696.png"
YOS = ASSETS + "/img_1785190641018039.jpg"
CELLS = [ASSETS + "/img_" + n for n in ("1785190567587941.jpg",
                                        "1785190567591660.jpg",
                                        "1785190567592655.jpg",
                                        "1785190567594783.jpg")]

DOCS = {
    "en": dict(untitled="Untitled", photo="Photo", park="Park day",
               collage="Summer collage", valley="Yosemite valley",
               caption="PARK DAY", bubble="WALKIES"),
    "pl": dict(untitled="Bez tytułu", photo="Zdjęcie", park="Dzień w parku",
               collage="Letni kolaż", valley="Dolina Yosemite",
               caption="W PARKU", bubble="NA SPACER!"),
    "de": dict(untitled="Ohne Titel", photo="Foto", park="Parktag",
               collage="Sommercollage", valley="Yosemite Valley",
               caption="PARKTAG", bubble="GASSI!"),
    "es": dict(untitled="Sin título", photo="Foto", park="Día en el parque",
               collage="Collage de verano", valley="Valle de Yosemite",
               caption="AL PARQUE", bubble="¡A PASEAR!"),
    # "Vallée de Yosemite" was cut to "Vallée de Yosemi…" on the Home tile:
    # the name shares its row with the layer count, and French "1 calque" is
    # the longest of the six. A tile name is the one string here that has to
    # fit a slot, so check the Home shot before changing one.
    "fr": dict(untitled="Sans titre", photo="Photo", park="Journée au parc",
               collage="Collage d'été", valley="Vallée Yosemite",
               caption="AU PARC", bubble="ON SORT !"),
    "cs": dict(untitled="Bez názvu", photo="Fotka", park="Den v parku",
               collage="Letní koláž", valley="Údolí Yosemite",
               caption="V PARKU", bubble="NA PROCHÁZKU!"),
}

# Newest first: Home sorts on updatedAt descending, and the shots tap tiles by
# position, so the order has to be pinned rather than inherited.
STAMPS = ["2026-07-28T00:%d:35.000000" % m for m in (22, 21, 20, 19, 18)]

STICKER_FX = {
    "shadow": {"enabled": True, "angle": 90.0, "distance": 14.0, "blur": 10.0,
               "density": 0.0, "color": 4278190080, "opacity": 0.56},
    "stroke": {"width": 10.769230769230768, "color": 4294967295, "opacity": 1.0},
}
GRID_2X2 = {
    "root": {"type": "split", "axis": "rows", "weights": [0.5, 0.5], "children": [
        {"type": "split", "axis": "columns", "weights": [0.5, 0.5], "children": [
            {"type": "leaf", "id": "c0"}, {"type": "leaf", "id": "c1"}]},
        {"type": "split", "axis": "columns", "weights": [0.5, 0.5], "children": [
            {"type": "leaf", "id": "c2"}, {"type": "leaf", "id": "c3"}]}]},
    "borderColor": 4294967295, "borderWidth": 12.0,
    "outerMargin": 12.0, "cornerRadius": 0.0,
}


def _image(lid, name, path, x, y, scale, *, mask=None, adjust=None,
           effects=None, cell=None):
    layer = {
        "type": "image", "id": lid, "name": name,
        "transform": {"x": x, "y": y, "scale": scale, "rotation": 0.0},
        "visible": True, "opacity": 1.0, "assetPath": path, "maskPath": mask,
        "adjustments": adjust or {"brightness": 1.0, "contrast": 1.0,
                                  "saturation": 1.0, "hue": 0.0},
        "crop": [0.0, 0.0, 1.0, 1.0],
    }
    if effects:
        layer["effects"] = effects
    if cell:
        layer["cellId"] = cell
    return layer


def _project(pid, name, w, h, layers, stamp, grid=None):
    doc = {"version": 3, "id": pid, "name": name,
           "canvasWidth": w, "canvasHeight": h,
           "currentFrameIndex": 0, "fps": 8.0}
    if grid:
        doc["grid"] = grid
    doc["createdAt"] = stamp
    doc["updatedAt"] = stamp
    doc["frames"] = [{"id": pid + "_f0", "layers": layers}]
    return doc


def project_set(locale, which):
    """{filename: manifest} for the `editor` or the `home` set.

    Two sets, because the first capture session was taken that way and the six
    listings should differ only in language: every editor shot shows a project
    named the localized *Untitled*, and only the Home shot shows named ones.
    """
    t = DOCS[locale]

    def raw_dog(name, stamp):
        # The adjustments are display-only, and are the ones the first English
        # capture happened to have on its sliders; the Adjust panel sits behind
        # the result sheet in that shot, so they are matched deliberately.
        adj = {"brightness": 1.15, "contrast": 1.19, "saturation": 1.17, "hue": 0.0}
        return _project("pe_cutout", name, 1536, 2048,
                        [_image("l_1", t["photo"], DOG, 768.0, 1024.0,
                                4.654545454545454, adjust=adj)], stamp)

    def sticker(name, stamp):
        return _project("pe_sticker", name, 1536, 2048,
                        [_image("l_1", t["photo"], DOG, 768.0, 1024.0,
                                4.654545454545454, mask=MASK,
                                effects=STICKER_FX)], stamp)

    def valley(name, stamp):
        adj = {"brightness": 1.0, "contrast": 1.0, "saturation": 1.0, "hue": 0.0,
               "filter": "vivid", "filterStrength": 1.0,
               "hdr": 0.4846153846153846}
        return _project("pe_valley", name, 1600, 1067,
                        [_image("l_8", t["photo"], YOS, 800.0, 533.5,
                                3.6363636363636362, adjust=adj)], stamp)

    def collage(name, stamp):
        xs = [(483.0, 273.0, "c0"), (1437.0, 273.0, "c1"),
              (483.0, 807.0, "c2"), (1437.0, 807.0, "c3")]
        layers = [
            _image("l_%d" % (4 + i),
                   t["photo"] if i == 0 else "%s %d" % (t["photo"], i + 1),
                   CELLS[i], x, y, 2.140909090909091, cell=cell)
            for i, (x, y, cell) in enumerate(xs)
        ]
        return _project("pe_collage", name, 1920, 1080, layers, stamp,
                        grid=GRID_2X2)

    def park(name, stamp):
        layers = [
            _image("l_1", t["photo"], DOG, 768.0, 1024.0, 4.654545454545454,
                   mask=MASK, effects=STICKER_FX),
            {"type": "text", "id": "l_2", "name": t["caption"],
             "transform": {"x": 484.151376146789, "y": 1828.738532110092,
                           "scale": 1.0, "rotation": 0.0},
             "visible": True, "opacity": 1.0, "text": t["caption"],
             "fontFamily": "Bangers", "fontSize": 71.78461538461539,
             "color": 4293310538, "decorative": False},
            {"type": "bubble", "id": "l_3", "name": t["bubble"],
             "transform": {"x": 414.9418960244649, "y": 538.111620795107,
                           "scale": 1.0, "rotation": 0.0},
             "visible": True, "opacity": 1.0, "text": t["bubble"],
             "shape": "speech", "fontFamily": "Bangers",
             "fontSize": 38.46153846153846, "fillColor": 4294967295,
             "strokeColor": 4279504922, "textColor": 4279504922,
             "tailDx": -0.28, "tailDy": 0.86},
        ]
        return _project("pe_park", name, 1536, 2048, layers, stamp)

    if which == "editor":
        u = t["untitled"]
        docs = [raw_dog(u, STAMPS[0]), sticker(u, STAMPS[1]),
                valley(u, STAMPS[2]), collage(u, STAMPS[3]), park(u, STAMPS[4])]
    else:
        docs = [park(t["park"], STAMPS[0]), collage(t["collage"], STAMPS[1]),
                valley(t["valley"], STAMPS[2])]
    return {d["id"] + ".json": d for d in docs}


# ---------------------------------------------------------------------- adb
def sh(serial, *args, timeout=180):
    return subprocess.run(["adb", "-s", serial] + list(args),
                          capture_output=True, timeout=timeout)


def shell(serial, cmd, timeout=180):
    return sh(serial, "shell", cmd, timeout=timeout).stdout.decode(
        "utf-8", "replace").strip()


def runas(serial, cmd):
    return shell(serial, "run-as %s sh -c '%s'" % (PKG, cmd))


def push_tar(serial, members, dest):
    """`members` is {arcname: bytes}; unpack them under `dest` on the device."""
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w") as tar:
        for name, data in members.items():
            info = tarfile.TarInfo(name)
            info.size, info.mtime = len(data), 1785189870
            tar.addfile(info, io.BytesIO(data))
    # Named per device: the three profiles are meant to run concurrently, and a
    # shared staging file would have them overwrite each other's manifests.
    name = "_shots_%s.tar" % serial.replace("-", "_")
    STAGING.mkdir(parents=True, exist_ok=True)
    local = STAGING / name
    local.write_bytes(buf.getvalue())
    sh(serial, "push", "-q", str(local), "/data/local/tmp/" + name)
    shell(serial, "chmod 644 /data/local/tmp/" + name)
    return runas(serial, "cd %s && tar -xf /data/local/tmp/%s" % (dest, name))


def set_projects(serial, locale, which):
    """Replace the manifests. The photo assets are expected to be there already."""
    runas(serial, "rm -f %s/projects/*.json" % APPDIR)
    members = {"projects/" + n: json.dumps(d, ensure_ascii=False).encode("utf-8")
               for n, d in project_set(locale, which).items()}
    return push_tar(serial, members, APPDIR)


def set_pro(serial, on=True):
    body = '{"onboardingSeen":true,"proEntitled":%s}' % ("true" if on else "false")
    return runas(serial, 'printf %%s "%s" > %s/settings.json'
                 % (body.replace('"', '\\"'), APPDIR))


def set_locale(serial, tag):
    shell(serial, "cmd locale set-app-locales %s --locales %s" % (PKG, tag or ""))


def quiet_status_bar(serial):
    """9:41, full battery, full signal - and no notification icons.

    Demo mode does the clock and the bars. It does NOT hide notification icons,
    whatever its `notifications visible false` command suggests, so those are
    snoozed one by one. The Safety-Center shield is left alone: the first
    capture session had it, and the six listings should match.
    """
    shell(serial, "settings put global sysui_demo_allowed 1")
    for cmd in ("command enter",
                "command clock -e hhmm 0941",
                "command battery -e level 100 -e plugged false",
                "command network -e wifi show -e level 4",
                "command network -e mobile show -e datatype 3g -e level 4",
                "command notifications -e visible false"):
        shell(serial, "am broadcast -a com.android.systemui.demo -e " + cmd)
    for key in shell(serial, "cmd notification list").splitlines():
        key = key.strip()
        if key and "|android|2345|" not in key:
            shell(serial, "cmd notification snooze --for 28800000 '%s'" % key)


def restart(serial, wait=11.0):
    shell(serial, "am force-stop %s" % PKG)
    time.sleep(0.6)
    shell(serial, "am start -n %s/.MainActivity" % PKG)
    time.sleep(wait)


def tap(serial, x, y, after=0.9):
    shell(serial, "input tap %d %d" % (x, y))
    time.sleep(after)


def swipe(serial, x1, y1, x2, y2, ms=350, after=0.9):
    shell(serial, "input swipe %d %d %d %d %d" % (x1, y1, x2, y2, ms))
    time.sleep(after)


def cap(serial, path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    out = subprocess.run(["adb", "-s", serial, "exec-out", "screencap", "-p"],
                         capture_output=True, timeout=180)
    path.write_bytes(out.stdout)


# ------------------------------------------------------------------ profiles
RAIL_X = 67
RAIL = dict(addLayer=248, text=382, bubble=516, aicut=655, erase=792,
            crop=932, adjust=1071, effects=1208, layers=1345)
# A collage puts Grid first and pushes everything down one slot.
RAIL_GRID = dict(grid=248, addLayer=382, text=516, bubble=655, aicut=792,
                 erase=932, crop=1071, adjust=1208, effects=1345, layers=1482)
# The 7-inch rail does not fit its own contents. These are the positions once
# it has been dragged to its end, where Layers sits against the bottom; they
# hold for a collage too, because the extra Grid entry only changes where the
# rail starts, not where it stops.
RAIL_END = dict(layers=1029, effects=889, adjust=750, crop=613,
                erase=473, aicut=334)

PROFILES = {
    "phone": dict(
        serial="emulator-5554", nav="dock", size=(1280, 2856),
        tiles={1: (340, 1400), 2: (940, 1400), 3: (340, 2100),
               4: (940, 2100), 5: (340, 2750)},
        canvas=(640, 1160),            # the 1536x2048 dog projects
        canvas_valley=(640, 900),      # the 1600x1067 landscape photo
        cell_br=(937, 1106),           # bottom-right cell of the 2x2 collage
        bubble=(369, 787),             # the speech bubble in the park project
        dock_y=2560,
        dock={"addLayer": 120, "text": 309, "bubble": 501,
              "aicut": 694, "erase": 883, "crop": 1076},
        dock_scrolled={"aicut": 200, "erase": 390, "crop": 580,
                       "adjust": 775, "effects": 965, "layers": 1155},
        dock_scroll=(1150, 2570, 300, 2570),
        sheet_object_tab=(920, 1568),  # "Object" while the sheet is on Background
        sheet_button=(640, 2620),      # the sheet's primary action, either tab
        # Starts on the panel's own header, the one row that is not a
        # full-width slider - a drag begun on a slider moves the slider, and
        # one begun in the left padding is not inside the list at all. It ends
        # above the panel: the pointer may leave, the scroll follows it. Slow,
        # because a flick coasts past the shadow group this shot is about.
        panel_scroll=(400, 1640, 400, 1116),
    ),
    "tab10": dict(
        serial="emulator-5556", nav="rail", size=(2560, 1600),
        tiles={1: (735, 774), 2: (1277, 774), 3: (1819, 774),
               4: (735, 1394), 5: (1277, 1394)},
        canvas=(1665, 850), canvas_valley=(1665, 850),
        cell_br=(2096, 1089), bubble=(1440, 529),
        sheet_object_tab=(1574, 725), sheet_button=(1280, 1445),
        panel_scroll=None,             # the panel is tall enough here
    ),
    "tab7": dict(
        serial="emulator-5558", nav="rail", size=(1920, 1200),
        tiles={1: (416, 780), 2: (960, 780), 3: (1500, 780),
               4: (420, 857), 5: (975, 857)},
        # Only three project tiles fit above the fold here.
        home_scroll=(960, 950, 960, 500), scroll_from_tile=4,
        rail_scroll=(68, 1050, 68, 250), rail_needs_scroll=("effects", "layers"),
        canvas=(1346, 664), canvas_valley=(1361, 643),
        cell_br=(1616, 806), bubble=(1185, 433),
        sheet_object_tab=(1253, 326), sheet_button=(958, 1043),
        panel_scroll=None,
    ),
}


def go(s, p, name, collage=False):
    """Tap a tool. Portrait scrolls its dock; landscape may scroll its rail."""
    if p["nav"] == "rail":
        if name in p.get("rail_needs_scroll", ()):
            swipe(s, *p["rail_scroll"], 900, 1.2)
            tap(s, RAIL_X, RAIL_END[name], 1.8)
        else:
            tap(s, RAIL_X, (RAIL_GRID if collage else RAIL)[name], 1.8)
        return
    if name in p["dock"]:
        tap(s, p["dock"][name], p["dock_y"], 1.8)
    else:
        swipe(s, *p["dock_scroll"], 400, 1.2)
        tap(s, p["dock_scrolled"][name], p["dock_y"], 1.8)


def open_tile(s, p, n, wait=3.2):
    if p.get("home_scroll") and n >= p.get("scroll_from_tile", 99):
        swipe(s, *p["home_scroll"], 600, 1.5)
    tap(s, *p["tiles"][n], wait)


# --------------------------------------------------------------------- shots
def shot_cutout_result(s, p, out):
    """AI Cut has just run: the result sheet over the Adjust panel."""
    open_tile(s, p, 1)
    tap(s, *p["canvas"], 1.4)
    go(s, p, "aicut")
    tap(s, *p["sheet_button"], 1.0)
    time.sleep(30)                       # the model runs on the device
    cap(s, out)


def shot_sticker(s, p, out):
    """Contour and drop shadow, on the Effects panel at its SHADOW group."""
    open_tile(s, p, 2)
    tap(s, *p["canvas"], 1.4)
    go(s, p, "effects")
    if p["panel_scroll"]:
        swipe(s, *p["panel_scroll"], 1200, 2.0)
    cap(s, out)


def shot_effects(s, p, out):
    open_tile(s, p, 3)
    tap(s, *p["canvas_valley"], 1.4)
    go(s, p, "effects")
    cap(s, out)


def shot_layers(s, p, out):
    open_tile(s, p, 4)
    tap(s, *p["cell_br"], 1.4)
    go(s, p, "layers", collage=True)
    cap(s, out)


def shot_grid(s, p, out):
    """A collage opens on its Grid tool, so this one is just the selection."""
    open_tile(s, p, 4)
    tap(s, *p["cell_br"], 1.8)
    cap(s, out)


def shot_objremove_panel(s, p, out):
    """The dock's AI Cut opens a sheet; the panel behind it is what this shows."""
    open_tile(s, p, 3)
    tap(s, *p["canvas_valley"], 1.4)
    go(s, p, "aicut")
    tap(s, *p["sheet_object_tab"], 1.6)
    tap(s, *p["sheet_button"], 1.0)
    time.sleep(7)                        # let the "tap an object" toast fade
    cap(s, out)


def shot_bubble(s, p, out):
    """Selecting a bubble opens the bubble editor by itself.

    Do NOT then tap Text as well. In landscape a tap on the tool you are
    already in folds the panel away, so the extra tap captured a rail beside a
    bare canvas - the one thing this shot is not about.
    """
    open_tile(s, p, 5)
    tap(s, *p["bubble"], 2.2)
    cap(s, out)


def shot_home(s, p, out):
    cap(s, out)


SHOTS = [
    ("cutout_result", shot_cutout_result, "editor"),
    ("sticker", shot_sticker, "editor"),
    ("effects", shot_effects, "editor"),
    ("layers", shot_layers, "editor"),
    ("grid", shot_grid, "editor"),
    ("objremove_panel", shot_objremove_panel, "editor"),
    ("bubble", shot_bubble, "editor"),
    ("home", shot_home, "home"),
]


def run(profile, locale, only=None):
    p = PROFILES[profile]
    s = p["serial"]
    outdir = OUTDIR / locale / profile
    set_locale(s, LOCALE_TAGS[locale])
    set_pro(s, True)
    quiet_status_bar(s)
    loaded = None
    for name, fn, which in SHOTS:
        if only and name not in only:
            continue
        if loaded != which:
            set_projects(s, locale, which)
            loaded = which
        restart(s)
        fn(s, p, outdir / ("%s.png" % name))
        print("  %-6s %-3s %s" % (profile, locale, name), flush=True)


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in PROFILES:
        sys.exit("usage: %s <%s> [locale ...] [shot ...]"
                 % (os.path.basename(sys.argv[0]), "|".join(PROFILES)))
    profile = sys.argv[1]
    rest = sys.argv[2:]
    locales = [a for a in rest if a in LOCALES] or LOCALES
    only = {a for a in rest if a not in LOCALES} or None
    bad = [a for a in (only or ()) if a not in {n for n, _, _ in SHOTS}]
    if bad:
        sys.exit("unknown shot(s): %s" % ", ".join(bad))
    for loc in locales:
        try:
            run(profile, loc, only)
        except Exception:
            traceback.print_exc()
            print("!! %s %s failed" % (profile, loc), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
