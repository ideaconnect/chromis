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

4:5 is the tallest an uploaded image gets in the Facebook feed, which is why the
feed version is portrait rather than square. The captures are the Polish ones
from `build/shots-i18n/pl/phone` - the same directory the pl-PL Play listing is
built from, because a Polish post carrying an English screenshot is the tell
that the app is not really translated.

## The copy, and where each line comes from

Three independent Polish drafts were written from different angles and each was
judged by a native reader against the source. Nothing below is invented: it is
either lifted from `lib/l10n/app_pl.arb` / `assets/store/pl-PL/details.md`, or
it is a line all three passes agreed on.

| Slot | Polish | Provenance |
|---|---|---|
| Eyebrow | PRYWATNY EDYTOR ZDJĘĆ | — |
| Headline | Twoje zdjęcia / **zostają w telefonie.** | judged the strongest line of the three drafts, and natively Polish rather than translated |
| Sub | Każde narzędzie AI działa na urządzeniu. Bez konta. | `details.md:68`, `:66` |
| Chip | Usuwanie tła przez AI | `app_pl.arb:362` verbatim (`toolCutoutPanel`) |
| Chip | Usuń obiekt, tło zostaje | `app_pl.arb:240` + the 1.3.0 fill claim |
| Chip | Warstwy, tekst i dymki | `app_pl.arb:355`, `:358`, `:195` |
| Chip | 14 filtrów, HDR i winieta | counted from `PhotoFilter`; `check_store_listings.py` enforces the 14 |
| Chip | Kolaż z 2–5 zdjęć | `app_pl.arb:52` verbatim, półpauza included |
| Chip | Eksport i udostępnianie | `app_pl.arb:416` verbatim (`exportTitle`) |
| Panel | Zdjęcia nie opuszczają telefonu. Bez konta i logowania. | `app_pl.arb:80`, `details.md:66` |
| Panel | Za darmo. Reklamy usuwa jeden opcjonalny zakup. | `details.md:62-63` |
| CTA | Pobierz z Google Play | the official Polish badge wording |

## What the review changed, and why

- **No blanket "nic się nigdzie nie wysyła", and no "bez chmury".** Both were in
  the first cut. They are true of the PHOTOS and false of the app, which
  initialises AdMob, fetches a UMP consent form and queries Play billing on
  launch - and the pl-PL listing is careful about exactly this
  (`details.md:67`, "Internet służy do reklam i zakupów"). Every privacy claim
  on the graphic is now scoped to the photos, which is the claim the repo
  actually supports and loses no punch.
- **The ads are stated.** The graphic leads with two features that cost a
  rewarded ad per session for a free user (`_ensureAiAllowed`). "Za darmo" next
  to a privacy panel, with no mention of ads, composes into "ad-free and
  tracker-free" - three true statements making a false impression. The panel
  says "Za darmo. Reklamy usuwa jeden opcjonalny zakup." and the CTA is the
  neutral "Pobierz z Google Play".
- **No "liczone / liczy się na telefonie".** A word-for-word calque of English
  "computed on your phone"; the app's own Polish says "działa na urządzeniu".
- **Półpauza in a numeric range** - "2–5", the way `app_pl.arb:52` writes it.
- **The chips name controls that exist.** There is no panel called "Usuwanie
  obiektów" - it is a tab, "Usuń obiekt", inside "Usuwanie tła przez AI".

## Two guards in the generator, both of which caught something

- **`fits()`** measures every painted string against the column it has to live
  in. Painted copy cannot wrap or ellipsize; it runs off the edge.
- **`contrast()`** measures each string against the pixels ACTUALLY BEHIND IT,
  under the glyphs rather than over their bounding band, and refuses to render
  below 4.5:1 (3:1 for large text). This is not belt-and-braces - it found a
  real defect. `backdrop()` puts its teal bloom wherever it is told, the first
  version of this file put it at (540, 300), and that is dead behind the
  headline: the cyan accent line measured **1.22:1**, which is invisible.
  Nothing else would have found it. The copy did not overflow, no assert fired,
  and on a dark thumbnail it read as a design choice. The bloom now haloes the
  phones, which is where it belonged anyway.

## Perspective and antialiasing

The phones are tilted 9°, and the edges survive it because `place()` does the
work: premultiply, rotate bicubic, re-clamp `rgb <= a`, composite, and assert
the rotated bounding box is still on the canvas - with the whole composition
built at 3x and downsampled ONCE at the end. Never rotate by hand in this file
and never resize the finished canvas twice; `ImageDraw` does not antialias, so
every pill and rule depends on that single final pass.
