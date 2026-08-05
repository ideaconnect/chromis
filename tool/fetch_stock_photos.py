#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Find and fetch the public-domain photos the store screenshots are built on.

    python tool/fetch_stock_photos.py search        # candidates, with licences
    python tool/fetch_stock_photos.py fetch         # download + crop the picks

A Play listing is commercial use of every pixel inside the device frame, so the
sample photos in it cannot be personal snaps or anything with an attribution or
non-commercial string attached. Everything here is filtered to **CC0 / public
domain** through the Openverse API, which returns the licence as data rather
than as a page a human has to read - and each pick is recorded in `PICKS` with
its licence and source URL, so the provenance survives the download.

The output sizes are not a preference. `tool/capture_store_shots.py` writes
project manifests with transforms tuned to the photos they point at: the
subject is 1536x2048 at scale 4.6545 and the landscape 1600x1067 at 3.6364,
both of which come out exactly full-bleed on their canvas. A replacement of a
different aspect would letterbox or crop itself inside the frame, so each photo
is centre-cropped to its slot's aspect and resized to its exact pixels.
"""
from __future__ import annotations

import io
import json
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "store" / "samples"
UA = {"User-Agent": "chromis-store-shots/1.0 (bartosz@idct.tech)"}

# slot -> (width, height) the app's manifests expect. See the module docstring.
SLOTS = {
    "subject": (1536, 2048),    # full-bleed on the 1536x2048 cut-out canvas
    "landscape": (1600, 1067),  # full-bleed on the 1600x1067 photo canvas
    "cell1": (2048, 1536),
    "cell2": (1600, 1067),
    "cell3": (1600, 1067),
    "cell4": (1600, 1067),
}

# slot -> the Commons file the slot is filled from, by exact title. Pinned
# rather than re-searched, so a rebuild produces the same seven photos and not
# whatever the API ranks first that day. `resolve` turns these into SOURCES.json
# with each file's real URL, size and licence, and that file is what `fetch`
# reads - so the provenance travels with the pixels instead of living in a
# commit message.
PICKS = {
    # Centred, full-bodied, and lit clear of a soft background: the cut-out, the
    # sticker outline and the drop shadow are all drawn from this silhouette, so
    # a subject that merges into its background has nothing to show.
    "subject": "File:Farm Dog in the Rain (Unsplash).jpg",
    # This one carries TWO shots - the filter panel and object removal - and the
    # coin-operated viewer in the middle of it is why. "Tap an object to remove
    # it" over a bare landscape is a caption with nothing under it.
    "landscape": "File:Tower viewer on a mountain lake (Unsplash).jpg",
    "cell1": "File:Snow covered mountain peaks in Moraine Lake (Unsplash).jpg",
    "cell2": "File:Horse ride on the beach at dusk (Unsplash).jpg",
    "cell3": "File:Tranquil autumn lake (Unsplash).jpg",
    "cell4": "File:Arctic Fox, Iceland 2 (Unsplash).jpg",
}
PICKS_FILE = ROOT / "assets" / "store" / "samples" / "SOURCES.json"


# Wikimedia Commons, searched through its own API rather than through an
# aggregator, for two reasons that both bit first:
#
# - Openverse reports each result's ORIGINAL dimensions but hands back a fixed
#   derivative for some providers - a row reading 5472x3648 downloads at 1024,
#   and the subject slot needs 2048. Commons' `url` is the file itself.
# - `haswbstatement:P275=Q6938433` is a licence filter Commons evaluates as a
#   structured claim, so "CC0" here is the uploader's machine-readable licence
#   statement rather than a string in a page that has to be read and trusted.
#
# Commons also hosts Unsplash's CC0 collection, which is where the photographs
# (as against the Rijksmuseum engravings a plain search surfaces) come from.
CC0 = "haswbstatement:P275=Q6938433"
API = "https://commons.wikimedia.org/w/api.php"


def commons(query: str, *, limit: int = 30) -> list[dict]:
    """CC0 bitmap files matching `query`, newest API shape, with sizes + licence."""
    url = API + "?" + urllib.parse.urlencode({
        "action": "query", "format": "json", "formatversion": "2",
        "generator": "search", "gsrsearch": "%s filetype:bitmap %s" % (query, CC0),
        "gsrnamespace": "6", "gsrlimit": str(limit),
        "prop": "imageinfo", "iiprop": "url|size|extmetadata",
        "iiextmetadatafilter": "LicenseShortName|Artist|Credit",
    })
    req = urllib.request.Request(url, headers=UA)
    for attempt in range(3):
        try:
            body = urllib.request.urlopen(req, timeout=45).read()
            break
        except urllib.error.HTTPError as exc:
            if attempt == 2:
                raise
            time.sleep(4 * (attempt + 1))
    pages = json.loads(body).get("query", {}).get("pages", [])
    out = []
    for p in pages:
        info = (p.get("imageinfo") or [{}])[0]
        if not info.get("url"):
            continue
        meta = info.get("extmetadata", {})
        out.append({
            "title": p["title"],
            "url": info["url"],
            "width": info.get("width", 0),
            "height": info.get("height", 0),
            "license": (meta.get("LicenseShortName") or {}).get("value", "?"),
            "page": "https://commons.wikimedia.org/wiki/" + p["title"].replace(" ", "_"),
        })
    return out


def fetch_bytes(url: str) -> bytes:
    return urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60).read()


def cover(img: Image.Image, size: tuple[int, int]) -> Image.Image:
    """Centre-crop to `size`'s aspect, then resize to exactly `size`.

    Cover rather than fit: the photo is full-bleed on its canvas, so a fit
    would put bars inside the picture the screenshot is meant to show.
    """
    tw, th = size
    want = tw / th
    have = img.width / img.height
    if have > want:                       # too wide - trim the sides
        w = round(img.height * want)
        box = ((img.width - w) // 2, 0, (img.width - w) // 2 + w, img.height)
    else:                                 # too tall - trim top and bottom
        h = round(img.width / want)
        box = (0, (img.height - h) // 2, img.width, (img.height - h) // 2 + h)
    return img.crop(box).resize(size, Image.LANCZOS).convert("RGB")


def cmd_search(terms: list[str]) -> int:
    """Print CC0 candidates big enough to fill the biggest slot, per term."""
    for i, term in enumerate(terms):
        if i:
            time.sleep(2)
        print("=== %s" % term)
        for r in commons(term):
            if r["width"] < 1600 or r["height"] < 1000:
                continue
            print("  %5dx%-5d %.2f %-4s %s"
                  % (r["width"], r["height"], r["width"] / r["height"],
                     r["license"], r["url"]))
    return 0


def cmd_grab(query: str, aspect: str, count: int = 12) -> int:
    """Search, then lay the hits out as ONE contact sheet with index numbers.

    A picture has to be looked at, and looking at twelve files one at a time is
    twelve round trips. The sheet is cropped to the slot's aspect so what is on
    it is what the slot would actually show - a photo whose subject survives a
    3:4 crop is not the same set as a photo that is good.
    """
    tw, th = SLOTS[aspect]
    hits = [r for r in commons(query, limit=40)
            if r["width"] >= 1600 and r["height"] >= 1000][:count]
    dest = ROOT / "build" / "stock-candidates"
    dest.mkdir(parents=True, exist_ok=True)

    cell = (360, round(360 * th / tw))
    cols = 4
    rows = (len(hits) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * (cell[0] + 12) + 12,
                              rows * (cell[1] + 34) + 12), (18, 18, 22))
    draw = ImageDraw.Draw(sheet)
    manifest = []
    for i, r in enumerate(hits):
        try:
            img = Image.open(io.BytesIO(fetch_bytes(r["url"])))
        except Exception as exc:                      # noqa: BLE001 - report and skip
            print("  !! %s: %s" % (r["title"][:40], exc))
            continue
        x = 12 + (i % cols) * (cell[0] + 12)
        y = 12 + (i // cols) * (cell[1] + 34)
        sheet.paste(cover(img, cell), (x, y))
        draw.text((x + 2, y + cell[1] + 6),
                  "%2d  %s" % (i, urllib.parse.unquote(r["title"])[5:44]), fill=(210, 214, 220))
        manifest.append(r)
        print("  %2d  %-52s %dx%d" % (i, urllib.parse.unquote(r["title"])[5:52],
                                      r["width"], r["height"]))
    out = dest / ("sheet-%s.jpg" % aspect)
    sheet.save(out, "JPEG", quality=88)
    (dest / ("sheet-%s.json" % aspect)).write_text(
        json.dumps(manifest, indent=1, ensure_ascii=False), encoding="utf-8")
    print("  -> %s" % out)
    return 0


def cmd_resolve() -> int:
    """Look each pinned title up on Commons and write SOURCES.json.

    The licence is re-read here rather than trusted from the search that found
    the file: this is the record a licence question gets answered from, and a
    file's licence tag can be corrected after upload.
    """
    url = API + "?" + urllib.parse.urlencode({
        "action": "query", "format": "json", "formatversion": "2",
        "titles": "|".join(PICKS.values()),
        "prop": "imageinfo", "iiprop": "url|size|extmetadata",
        "iiextmetadatafilter": "LicenseShortName|Artist|Credit|LicenseUrl",
    })
    body = urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=45).read()
    found = {}
    for p in json.loads(body).get("query", {}).get("pages", []):
        info = (p.get("imageinfo") or [{}])[0]
        if not info.get("url"):
            print("  !! not found: %s" % p.get("title"))
            continue
        meta = info.get("extmetadata", {})
        artist = re.sub(r"<[^>]+>", "", (meta.get("Artist") or {}).get("value", "")).strip()
        found[p["title"]] = {
            "title": p["title"],
            "url": info["url"].split("?")[0],
            "width": info["width"], "height": info["height"],
            "license": (meta.get("LicenseShortName") or {}).get("value", "?"),
            "artist": artist,
            "page": "https://commons.wikimedia.org/wiki/"
                    + urllib.parse.quote(p["title"].replace(" ", "_")),
        }
    out = {}
    for slot, title in PICKS.items():
        rec = found.get(title)
        if rec is None:
            sys.exit("unresolved pick for %s: %s" % (slot, title))
        if rec["license"] not in ("CC0", "No restrictions", "Public domain"):
            sys.exit("%s is %s, not public domain: %s" % (slot, rec["license"], title))
        out[slot] = rec
        print("  %-10s %-4s %5dx%-5d %s"
              % (slot, rec["license"], rec["width"], rec["height"], rec["title"][5:]))
    PICKS_FILE.parent.mkdir(parents=True, exist_ok=True)
    PICKS_FILE.write_text(json.dumps(out, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print("  -> %s" % PICKS_FILE)
    return 0


def cmd_fetch() -> int:
    picks = json.loads(PICKS_FILE.read_text(encoding="utf-8"))
    OUT.mkdir(parents=True, exist_ok=True)
    for slot, meta in picks.items():
        size = SLOTS[slot]
        raw = fetch_bytes(meta["url"])
        img = Image.open(io.BytesIO(raw))
        if img.mode != "RGB":
            img = img.convert("RGB")
        out = cover(img, size)
        dest = OUT / ("%s.jpg" % slot)
        out.save(dest, "JPEG", quality=92, optimize=True)
        print("  %-10s %s  <- %dx%d  %s  %s"
              % (slot, out.size, img.width, img.height, meta["license"], dest.name))
    return 0


def main() -> int:
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    if sys.argv[1] == "search":
        return cmd_search(sys.argv[2:] or ["golden retriever", "mountain lake sunrise"])
    if sys.argv[1] == "grab":
        return cmd_grab(sys.argv[2], sys.argv[3], int(sys.argv[4]) if len(sys.argv) > 4 else 12)
    if sys.argv[1] == "resolve":
        return cmd_resolve()
    if sys.argv[1] == "fetch":
        return cmd_fetch()
    sys.exit("unknown command: %s" % sys.argv[1])


if __name__ == "__main__":
    sys.exit(main())
