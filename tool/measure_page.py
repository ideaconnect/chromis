"""Report the rendered box of chosen elements on the website, via headless Edge.

Screenshots show you that something looks wrong; this says what size it actually
is. Handy for the responsive checks a static page can otherwise only be
eyeballed for - and it catches the classic "the image ignored its max-width"
kind of bug that a scaled-down screenshot hides.

    python tool/measure_page.py [viewport-width] [selector ...]
"""

import json
import os
import re
import subprocess
import sys

ROOT = os.getcwd()
PAGE = os.path.join(ROOT, "website", "index.html")
PROBE = os.path.join(ROOT, "build", "webshot", "probe.html")
EDGE = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"

DEFAULT_SELECTORS = [
    "body",
    ".hero-visual .ba",
    ".fx-gallery",
    ".fx-stage",
    ".fx-stage-img",
    ".fx-strip",
    ".fx-chip img",
    ".fx-cards",
    ".fx-card .fx-ba",
    ".split .phone",
    ".split .phone img",
    ".shots",
    ".shot .phone img",
    ".shot-wide img",
    ".features",
]


def main():
    args = sys.argv[1:]
    width = int(args[0]) if args and args[0].isdigit() else 1280
    selectors = args[1:] if len(args) > 1 else DEFAULT_SELECTORS

    src = open(PAGE, encoding="utf-8").read()
    probe = src.replace(
        "</body>",
        "<script>window.addEventListener('load',function(){"
        "var sels=" + json.dumps(selectors) + ";"
        "var out=sels.map(function(s){var e=document.querySelector(s);"
        "if(!e)return {sel:s,missing:true};var r=e.getBoundingClientRect();"
        "return {sel:s,w:Math.round(r.width),h:Math.round(r.height),"
        "x:Math.round(r.left),y:Math.round(r.top+window.scrollY)};});"
        "var res={page:document.documentElement.scrollWidth,"
        "view:document.documentElement.clientWidth,boxes:out};"
        # Inside the sizing iframe the parent cannot read this document
        # (file:// is cross-origin to itself), so hand the result over by
        # postMessage, which is not subject to that.
        "if(window.parent!==window){parent.postMessage(JSON.stringify(res),'*');return;}"
        "var d=document.createElement('div');d.id='__probe';"
        "d.textContent='@@'+JSON.stringify(res)+'@@';"
        "document.body.appendChild(d);});</script></body>",
    )
    os.makedirs(os.path.dirname(PROBE), exist_ok=True)
    # Written next to the page's own directory would be cleaner, but the probe
    # must resolve ./assets and ./styles.css, so point it back at the source.
    base = "file:///" + os.path.join(ROOT, "website").replace(os.sep, "/") + "/"
    probe = probe.replace("<head>", f'<head><base href="{base}">', 1)
    open(PROBE, "w", encoding="utf-8").write(probe)

    # The page is measured inside an iframe of exactly `width` CSS px. Headless
    # Edge refuses to make its window narrower than ~490px, so --window-size
    # alone cannot reach a phone viewport - and phones are the whole audience.
    frame = os.path.join(os.path.dirname(PROBE), "frame.html")
    open(frame, "w", encoding="utf-8").write(
        "<!doctype html><meta charset=utf-8>"
        "<style>html,body{margin:0}iframe{border:0;display:block}</style>"
        f'<iframe src="probe.html" width="{width}" height="1400"></iframe>'
        "<div id=out></div>"
        "<script>addEventListener('message',function(e){"
        "document.getElementById('out').textContent='@@'+e.data+'@@';});</script>"
    )

    res = subprocess.run(
        # force-device-scale-factor is required: without it the host's display
        # scaling is applied and the CSS viewport does not match --window-size.
        [EDGE, "--headless=new", "--disable-gpu", "--dump-dom",
         "--force-device-scale-factor=1", "--hide-scrollbars",
         f"--window-size={max(width + 40, 900)},1400", "--virtual-time-budget=8000",
         "file:///" + frame.replace(os.sep, "/")],
        # Decode as UTF-8 explicitly: the page has non-ASCII in it, and the
        # Windows console default (cp1250 here) throws on the DOM dump.
        capture_output=True, timeout=180,
    )
    stdout = res.stdout.decode("utf-8", "replace")
    m = re.search(r"@@(\{.*?\})@@", stdout, re.S)
    if not m:
        sys.exit("probe produced no output; is the page valid?")
    data = json.loads(m.group(1))

    view = data["view"]
    print(f"viewport {view}px (asked {width})   document scrollWidth {data['page']}")
    if data["page"] > view + 1:
        print(f"  !! page scrolls horizontally by {data['page'] - view}px")
    print(f"  {'selector':<26} {'w':>6} {'h':>6}   x,y")
    for b in data["boxes"]:
        if b.get("missing"):
            print(f"  {b['sel']:<26} (not found)")
        else:
            print(f"  {b['sel']:<26} {b['w']:>6} {b['h']:>6}   {b['x']},{b['y']}")


if __name__ == "__main__":
    main()
