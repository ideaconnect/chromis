# Store sample photos

The photographs that appear **inside the device frame** in every Play Store
screenshot and feature graphic. They are not shipped in the APK - `pubspec.yaml`
lists assets individually, and this directory is not among them.

Every file is **CC0 / public domain**, sourced from Wikimedia Commons and
recorded in [`SOURCES.json`](SOURCES.json) with its title, original size,
licence and source page. A Play listing is commercial use of every pixel inside
that frame, so which photograph is in one is a decision that belongs in version
control rather than in whatever happened to be on the capture device.

| File | Used by |
|---|---|
| `subject.jpg` | the cut-out, sticker and comic-bubble shots (1536x2048) |
| `subject-mask.png` | the cut-out itself - see below |
| `landscape.jpg` | the filter shot and the object-removal shot (1600x1067) |
| `cell1..4.jpg` | the 2x2 collage (cell1 is 2048x1536, the rest 1600x1067) |

## Regenerating

```bash
python tool/fetch_stock_photos.py resolve   # pinned titles -> SOURCES.json
python tool/fetch_stock_photos.py fetch     # download + centre-crop to size
```

`resolve` re-reads each file's licence from Commons and **exits** if one is not
public domain, because a file's licence tag can be corrected after upload.

The sizes are not a preference. `tool/capture_store_shots.py` writes project
manifests whose transforms are tuned to them - the subject is 1536x2048 at
scale 4.6545 and the landscape 1600x1067 at 3.6364, both exactly full-bleed on
their canvas - so a replacement of a different aspect letterboxes itself inside
the frame. `fetch` centre-crops to the slot's aspect rather than fitting.

## The mask

`subject-mask.png` is a **real output of the app's own AI Cut**, produced once
by running it on the device and keeping what it wrote:

```bash
python tool/capture_store_shots.py mask phone
```

It is copied to the other devices rather than re-derived per device, so all
three form factors show the same cut-out. Drawing an alpha by hand here would
put a result in the listing that the app did not produce.

## Picking a replacement

```bash
python tool/fetch_stock_photos.py search "mountain lake Unsplash"
python tool/fetch_stock_photos.py grab "dog Unsplash" subject 16
```

`grab` writes one contact sheet to `build/stock-candidates/`, already cropped to
the slot's aspect - a photo whose subject survives a 3:4 crop is not the same
set as a photo that is good. Then pin the winner's Commons title in `PICKS` and
re-run `resolve` + `fetch`.
