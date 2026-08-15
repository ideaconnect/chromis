# Facebook promo (Polish)

**Graphics** (generated - do not hand-edit, change `tool/gen_facebook_promo_pl.py`
and re-run):

| File | Use |
|---|---|
| `assets/store/social/facebook-pl-feed.png` (1080x1350) | native feed post - **use this one** |
| `assets/store/social/facebook-pl-link.png` (1200x630) | link share / OG card |

```bash
python tool/gen_facebook_promo_pl.py
```

4:5 is the tallest an uploaded image gets in the Facebook feed, which is why
the feed version is portrait rather than square. The captures are the Polish
ones from `build/shots-i18n/pl/phone` - the same directory the pl-PL Play
listing is built from, because a Polish post carrying an English screenshot is
the tell that the app is not really translated.

## The composition is a feature list you can see

**One device per named feature, captioned, left to right.** Five across is
exactly what the width allows: 936px of usable width, five slots of 187, and a
phone 340 tall tilted 6 degrees has a bounding box 187 wide. The fan is a
shallow sweep rather than five uprights, and each caption sits under its own
device's CENTRE so the tilt never makes it ambiguous which label belongs to
which screen.

The in-device text is illegible at this size and that is expected - the devices
say "these are five different screens of a real app" and the captions say
which. What has to survive the downsample is the SHAPE of each: a filter strip,
a cut-out on a checkerboard, a layer stack, a 2x2 collage, a speech bubble.

An earlier cut led on privacy and carried the tools as a chip list. This one
puts the tools in the headline and on the devices, and keeps privacy to one
line at the foot.

## The copy, and where each line comes from

| Slot | Polish | Provenance |
|---|---|---|
| Eyebrow | EDYTOR ZDJĘĆ Z AI | states the category only; the sub carries completeness |
| Headline | Wytnij tło, zrób kolaż, / **dodaj dymek.** | three imperatives, each naming a tool; "Dodaj dymek" is `app_pl.arb` verbatim, and `zrób kolaż` is the listing's collocation (`details.md:9`) - `ułożyć` it pairs with layers, not collages |
| Sub | Komplet narzędzi w jednej aplikacji. Wszystko działa na urządzeniu. | `details.md:68` for the second half. **No numeral**: the graphic names nine capabilities and the dock has seven tools, none of them bubbles - a count here is a number the same image disproves |
| Caption | 14 filtrów | counted from `PhotoFilter`; `check_store_listings.py` enforces the 14 |
| Caption | Usuwanie tła | `app_pl.arb:150` / `:362` - the app's own noun. It is **not** "Wycinanie tła", which appears nowhere in the pl ARB and echoed the headline's "Wytnij tło" right above it |
| Caption | Warstwy | `app_pl.arb:355` verbatim (`toolLayers`) |
| Caption | Siatka zdjęć | `app_pl.arb` verbatim (`toolGridPanel`) |
| Caption | Dymki komiksowe | `app_pl.arb:194` ("Dymek komiksowy"), pluralised |
| Chip | Usuwanie obiektów | `app_pl.arb:240` ("Usuń obiekt") |
| Chip | Przyciąganie warstw | `app_pl.arb:166` ("Przyciąganie") |
| Chip | HDR i winieta | `app_pl.arb` section headers HDR / WINIETA |
| Chip | Eksport i udostępnianie | `app_pl.arb:416` verbatim (`exportTitle`) |
| Foot | Bez konta i logowania. Zdjęcia nie są nigdzie wysyłane do obróbki. | `details.md:66`, `:68`. Scoped to *processing* on purpose: "nie opuszczają telefonu" sits two lines under the chip "Eksport i udostępnianie", where sharing does send the image somewhere |
| Foot | Za darmo, z reklamami, które usuwa jeden opcjonalny zakup. | `details.md:62-63`. A relative clause, **not** "Usuwa je …": `je` is accusative plural non-masculine-personal, which fits *reklamy* and equally fits *Zdjęcia* on the line above - and that garden path reads "one optional purchase removes your photos" |
| CTA | Pobierz z Google Play | the official Polish badge wording |

## Claims that are NOT allowed here

Three independent Polish drafts were written and judged by native readers
against the source. These were the faults, and they stand whatever the
composition:

- **Privacy claims stay scoped to the PHOTOS.** No "bez chmury", no bare "nic
  się nigdzie nie wysyła". True of the photos, false of an app that initialises
  AdMob, fetches a UMP consent form and queries Play billing on launch - and
  the pl-PL listing is careful about exactly that (`details.md:67`, "Internet
  służy do reklam i zakupów").
- **The ads are stated.** Two of the features shown cost a rewarded ad per
  session for a free user (`_ensureAiAllowed`), so "za darmo" on its own
  composes into "ad-free", which is the one thing this is not.
- **No "liczone / liczy się na telefonie"** - a word-for-word calque of English
  "computed on your phone"; the app's own Polish says "działa".
- **Półpauza in a numeric range** - "2–5", the way `app_pl.arb:52` writes it.
- **Labels must name controls that exist.** There is no panel called "Usuwanie
  obiektów" - it is a tab, "Usuń obiekt", inside "Usuwanie tła przez AI". As a
  chip describing a capability it is fine; as a panel name it would not be.

## Two guards in the generator, both of which caught something

- **`fits()`** measures every painted string against the column it has to live
  in. Painted copy cannot wrap or ellipsize; it runs off the edge. It caught the
  chip row at 957px against 936.
- **`contrast()`** measures each string against the pixels ACTUALLY BEHIND IT -
  under the glyphs, not over their bounding band, because the band catches the
  bloom's peak well to the side of where the words end - and refuses to render
  below 4.5:1 (3:1 for large text). It caught two real defects that nothing else
  would have: the bloom at (540, 300) sat behind the headline and took the cyan
  accent line to **1.22:1**, and once moved to (540, 790) its original wide
  radii reached the caption row and took "Warstwy" to **4.15:1**. Neither
  overflows, neither throws, and on a dark thumbnail both read as a design
  choice. The bloom's centre AND its radii are now set by that measurement.

## Perspective and antialiasing

The phones are tilted, and the edges survive it because `place()` does the
work: premultiply, rotate bicubic, re-clamp `rgb <= a`, composite, and assert
the rotated bounding box is still on the canvas - with the whole composition
built at 3x and downsampled ONCE at the end. Never rotate by hand in this file
and never resize the finished canvas twice; `ImageDraw` antialiases nothing, so
every pill, rule and capsule depends on that single final pass. Checked at 6x:
no stair-stepping on the tilted bezels and no dark fringe, which is what
rotating straight alpha would give.
