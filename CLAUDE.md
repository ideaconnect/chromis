# CLAUDE.md - Chromis

Guidance for AI coding sessions on this repo.

## What this is

Free, ad-supported Flutter **Android** photo editor with on-device AI (BG removal,
object removal, layers, text, comic bubbles, export). Built from the approved
Claude Design mockup, reusing IDCT Sticker Maker's engine code.

## Architecture

Feature-first: `lib/app` (root + `go_router`), `lib/core` (theme, models,
rendering, widgets), `lib/features/*`. State via `flutter_riverpod`. Light and
dark themes - read **every** colour from `context.colors` (`AppPalette`) and the
radii from `context.tokens` (`AppTokens`); fonts are **Manrope** (body) +
**Space Grotesk** (`AppFonts`).

### Theming

**Any colour written as a constant in a widget is a bug in one of the two
themes**, because a constant cannot vary. `context.colors` is the whole
interface: `AppTokens` is a `ThemeExtension` carrying one `AppPalette`, Flutter
picks between `AppTokens.dark` and `AppTokens.light`, and no widget ever asks
which theme it is in. `buildAppTheme(Brightness)` builds both from one function
so they cannot drift into being two designs.

The surfaces are **neutral**, not the mockup's navy. That navy was a bad fit at
both ends: on AMOLED it lights every pixel for a colour that was pure
decoration, and on IPS it greys out in daylight.

**Every surface that covers the screen is pure `#000000` or pure `#FFFFFF`** -
`pageBackground`, `background` and `chrome`, asserted by `appearance_test.dart`.
This is a hardware requirement, not a preference, and it is the one thing no
contrast check can catch: a near-black is perfectly legible and still keeps an
AMOLED pixel lit, and a 94% white is legible and still turns muddy on IPS in
daylight, which is what the light theme's grey page used to do. The trade is
that structure now comes from hairlines and recessed controls rather than from a
step in surface brightness - so **`inputField` is no longer white in light**
(a white field on a white page is not a field), and the border tokens are a step
stronger in both themes.

**`chrome` and `panel` are two tokens because one of them cannot be the page's
colour.** `chrome` is the editor's tool panel and landscape rail: the largest
persistent surfaces in the app, sitting directly on the page with a hairline
along the edge, so they take the page's colour and are exactly the pixels worth
switching off. `panel` is sheets, dialogs and the drawer, and it must stay one
step off - a sheet floats over a scrim, and **a scrim over black is still
black**, so a pure-black sheet would have no edge at all. Verified on device,
not reasoned about: the screenshots are the reason `panel` did not follow.

The **accents vary too** - the brand hues read on black
and wash out on white, so the light palette carries darkened variants. That is
what lets `onAccent` be one token: a filled accent button is bright-on-dark-ink
in dark and deep-on-white-ink in light, and callers need not know which.

Three things are deliberately NOT theme-aware, and each would be wrong if it
were:

- **`AppColors`** is the fixed brand palette, for a colour that is *data*: the
  Text/Bubble swatch rows and the fills they write into a layer. A saved project
  must export the same image whichever theme it is opened in.
- **`AppScrim`** is chrome drawn ON the user's photo - the "removing
  background" overlay, the frame badges, the crop dim, the knob outlines. A
  photo has no theme, so there is nothing to follow; reading `context.colors`
  here puts the light theme's near-black ink on a 70% dark scrim.
- **`_Splash`** matches the native splash colour, which `flutter_native_splash`
  bakes into the Android manifest and which is on screen before any Dart runs.
  Following the theme there would replace a seamless hand-off with a visible cut
  on every launch.

The mode is `ThemeMode.system` by default and overridable in Settings, persisted
as `settings.json`'s `themeMode` key with exactly the same rules as `locale`:
the key is REMOVED rather than written as null, so "never chose" and "chose
System" stay one state, and an unrecognised value reads as System rather than
throwing. The app shell holds the splash until it has loaded - a phone on its
night theme must not get a white flash first.

**The system bars are an `AnnotatedRegion` under the theme**, not a
`SystemChrome` call in `main`. The app draws behind both bars, so the light
theme needs dark icons; set once at startup they would also never re-apply when
the device flips to night. `main` keeps one call, and only because it runs
before the saved appearance is known - it matches the native splash.

`test/settings/appearance_test.dart` asserts the contrast ratios directly
against the palette. It is the only thing that can: a colour two steps too pale
does not overflow and does not throw, it just cannot be read outside, and
pumping widgets will never notice. It caught three of these on the first run.

### Photo Grid (collage)

A grid is a **partition of the canvas**, not a document type and not a layer
type: `Project.grid` holds a `GridSpec` (null = ordinary project) and each
`Layer.cellId` says which cell it lives in (null = free layer, drawn above the
grid unclipped). Layer transforms stay in canvas-logical units - cells only
clip - which is what lets every existing tool keep working inside a cell.

Cells are a tree of n-ary splits (`lib/core/models/grid.dart`), so dragging one
divider exchanges weight between exactly two siblings and every other cell keeps
its rect by construction. `layoutGrid` is the single source of cell rects, read
by both painters, the hit-tester and the template previews. The border renders
as a background FILL with the cells drawn on top, so gaps and the outer margin
ARE the border. Every reshape goes through `applyGridSpec`, which maps content
from the rects before/after (never incrementally, so drags cannot drift).

See `docs/photo-grid-plan.md`.

### Layer effects

`LayerEffects` (blend / shadow / stroke) is ONE field on the sealed `Layer`
base, so a new shared effect touches one class instead of three; photo-only
effects (filter, HDR, vignette) hang off `ImageLayer`/`ImageAdjustments`
because they describe pixels rather than compositing. Filters and the HDR tone
curve fold into the SAME colour matrix as the Adjust sliders, so a layer costs
one `ColorFilter` however many looks are stacked on it.

The photo chain is one function - `paintImageLayer` in
`core/rendering/layer_effects_painter.dart` - called by both the preview and
the export, so those cannot drift. Compositing (blend / opacity / shadow)
cannot be shared that way and is written twice, guarded by
`test/rendering/effects_render_parity_test.dart`.

The widget half (`core/widgets/layer_effects_box.dart`) MUST use raw
`saveLayer` render objects: a blend mode has no engine-layer representation, so
it has to live inside one recorded picture, and `Opacity`/`ColorFiltered`/
`ImageFiltered` each push a compositing layer that would split it.

### Layer placement

**Adjust is a panel for any layer, not only a photo.** Its top half - Scale,
Rotation, Opacity - reads `Layer.transform` through `updateTransform`, so it
works on a caption or a bubble; the crop button and the four colour sliders
reach pixels and stay an `ImageLayer`'s alone (`_photoAdjustments`). It answered
anything else with an empty hint before, which left one state with **no way
out**: the canvas hit box IS the layer, so a caption or bubble created small -
or pinched down by accident - is smaller than a finger and cannot be grabbed to
be made big again. A slider does not depend on the layer's size.

`layer_scale_curve.dart` holds the scale range and the slider's mapping.
`kMinLayerScale`/`kMaxLayerScale` are read by BOTH the slider and the pinch
gesture's clamp (`EditorCanvas._onScaleUpdate`) - they used to be duplicated
with a comment saying to change both, which is a rule a compiler cannot enforce;
a gesture that reached a size the slider refuses to represent would be a state
with no way back.

**The Scale slider is a curve, not a linear range, and it is driven in
bar-position space (0…1) rather than in percent.** Linear over 20…600% put 100%
at 14% of the bar: the entire shrink range was narrower than the thumb, so
making a layer *smaller* by a controlled amount was guesswork, while four fifths
of the bar went to enlarging - the direction a finger can already do comfortably
by pinching. `kScaleUnityAt` puts unity at a quarter and the exponent is
*derived* from it, so the range and the unity point cannot drift apart. The
readout stays the true percentage; `LabeledSlider` now also feeds `valueLabel`
to `semanticFormatterCallback`, because otherwise a screen reader announces the
thumb's position - "25%" for a layer at 100%.

Rotation is shown wrapped into (-180°, 180°] because
the canvas ACCUMULATES it across pinches and a layer really can sit at 400°, and
it snaps to straight over the last couple of degrees, which a slider cannot hit
on purpose.

**A photo that fills a grid cell gets neither slider.** `_clampToCell` keeps a
cell photo covering its cell, because one shrunk aside leaves a hole in the
collage that reads as a bug; a slider would be a second path to that state with
none of the clamp. Nothing is lost - a cell photo fills its cell, so it is never
the layer you cannot touch. Captions and bubbles in a cell keep the sliders:
they are never clamped there, only clipped.

### Object removal: which pixels, and what goes there

Removing an object is two questions, and only the first one was ever really
answered. *Which pixels* is the segmentation tier ladder - connected component,
then MobileSAM on a tap the free tier can't carve out. *What goes there* is
**Fill in** (rebuild the background) or **Erase** (cut to transparency), and
that choice now leads the Remove-object panel with a one-line explainer under
it. **Fill is the default**: "remove object" means a closed background to nearly
everyone who taps it, and a transparent hole read as a broken fill often enough
to be the bug report that changed this.

**A user-visible choice must not be gated on an optional asset.** The chooser
existed from the start, built only when `inpaintAvailableProvider` found
`assets/models/migan.onnx` in the asset manifest - an OPTIONAL model no shipped
build has ever bundled. So the branch was dead: every tap erased, nothing on
screen said so, and there was no way to ask for anything else. The panel renders
fine either way and the gate is a runtime provider rather than a compile-time
flag, so nothing could catch it but a test that entered the mode, which is what
`test/editor/object_fill_mode_test.dart` now is.

Fill has **two tiers, tried in order by `_tryInpaint`**: MI-GAN (bundled,
26.7 MB, MIT) then `ContentFillEngine`, which is pure Dart and always runs. The
floor is what lets Fill be offered unconditionally - it degrades rather than
disappears - but the generative tier is what makes it good: on a person-shaped
hole PatchMatch pastes a slab of background through the subject, MI-GAN rebuilds
it. **The tier is invisible to the user on purpose** - it is not a mode anyone
picks, and the old label "Fill (AI)" was a promise the shipped app could not
keep.

**A permissive licence with no carve-out covers the weights its authors
distribute under it, and the training set is a disclosed risk rather than a
veto.** That rule is forced: reading Places2's research-only terms as
encumbering MI-GAN's weights would also disqualify MobileSAM, which this app
already ships. What it does NOT license is the `ffhq` checkpoint sitting in the
same download folder - FFHQ is CC BY-NC-SA, and it is what a search for "person
removal" surfaces first. `model_conversion/convert_migan.py` exports the raw
generator ourselves rather than taking upstream's published ONNX, which is a
*pipeline* export with a different signature that would fail silently.

`content_fill_engine.dart` fills a **window** around the object (its bbox plus
75% of its longer side, downscaled only past 512 px), not the whole photo. That
is the difference between a patch and a smudge: MI-GAN squeezes the entire image
into 512², so a 100 px object in a 2000 px photo is synthesized ~25 px wide and
blown back up, where the window keeps a small object at native resolution - and
matching locally finds better patches anyway. The composite is weighted, and the
region SYNTHESIZED runs one blur radius wider than the region weighted at full
strength, or the seam fades back into the object's own colour fringe instead of
into clean photo.

`patch_match.dart` is the algorithm (PatchMatch + Wexler voting), byte arrays in
and out so it runs in `Isolate.run` and tests without decoding an image. Two
invariants it must keep: **known pixels are never written** - the result
composites over the full-resolution photo, so writing outside the hole would
resample the whole window as a soft rectangle around every removed object - and
a fill it cannot do returns **null** rather than a smear, which is what makes
the editor fall back to erasing and say so.

**`clamp()` is declared on `num`, so it boxes even when every argument is an
`int`** - and it was in the innermost loop of the patch search. Removing it
halved the fill (5.3 s → 2.4 s of work on a debug emulator);
`integration_test/content_fill_device_test.dart` is what found that, by printing
a decode/encode/search breakdown a host test cannot measure. Watch for the same
shape anywhere else per-pixel. See `docs/inpaint-setup.md`.

### Landscape

`EditorScreen` branches on `maxWidth > maxHeight`: the dock becomes a rail down
the left, the tool panel a folding column beside it, the rest is canvas.
Portrait is unchanged. Rotation is allowed by `supportedOrientations` in
`main.dart` - it was locked to portrait, which made the whole layout dead code.

A short viewport is now a real path, so **bottom sheets use `SheetBody`**
(caps the height, scrolls, clears the keyboard and gesture bar) rather than a
bare `Column`. `test/landscape_overflow_test.dart` pumps every screen and sheet
at landscape sizes; add new ones to it.

### Branding

Every brand asset - launcher icon and its adaptive layers, splash, Play listing
icon, in-app logo, website mark, favicon - is produced by `tool/gen_branding.py`
from the icon design in `assets/branding/modern.png`. **Never retouch an
output**; change the generator and re-run it, then
`dart run flutter_launcher_icons` + `flutter_native_splash:create`.

The composition is never re-arranged - assets differ only in size, in whether the
tile keeps its corners, and in how the tile is split for Android. Three things
worth knowing:

- The source is a **mock-up**: the tile on a white presentation card. The tile is
  found by chroma (the only saturated region); the card and backdrop are dropped.
- The tile's background is a **gradient**, so nothing can key off a single flat
  colour. `gradient_surface` recovers it as a degree-3 polynomial fitted
  iteratively with the artwork rejected as outliers; the artwork is then keyed
  and unmatted against that surface per pixel.
- The **adaptive icon** splits the design: the recovered gradient is a square
  full-bleed background, the artwork alone is the foreground, placed so the
  visible 72 of 108dp is the design at its own proportions - which lands it
  inside Android's guaranteed 66dp circle. A launcher's mask cuts gradient.

**No plate.** This tile is mid-tone teal and reads on both our surfaces
unaided - which is what lets one in-app mark serve the light theme as well as
the dark; the assets carry their own corners, so nothing should clip or chip
them. The icon before it was `#0A2127`, a couple of steps from the old dark
panel colour, and did need a light ground - if the artwork ever goes dark again,
that is the fix, and it would now have to clear the light theme too.

### Localization

English, Polish, German, Spanish, French and Czech, generated by `flutter gen-l10n` from `lib/l10n/app_*.arb`
into real (non-synthetic) sources that are **committed** - `flutter gen-l10n`
after any ARB edit. **No user-visible string may be a literal in a widget**;
read it from `AppLocalizations.of(context)`.

**`resolveAppLocale` is the "defaults to English" rule**, wired into every
`MaterialApp` as `localeListResolutionCallback`. Do not delete it and rely on
Flutter's default: that falls back to the FIRST entry of `supportedLocales`, and
gen-l10n emits that list **alphabetically** - so adding German put `de` at the
front and silently made German the language every untranslated device would have
got. The rule is a product decision, not a property of where a new ARB file
sorts. A user override lives in `LocaleController` (`core/settings/locale_controller.dart`)
and is persisted as `settings.json`'s `locale` key. **Null means "follow the
device", not English** - the two differ, and the key is REMOVED rather than
written as null so "never chose" and "chose System" stay one state. The app
shell holds the splash until it has loaded, so the first frame is never in the
wrong language.

**A suffix glued onto a name cannot be an inflected word.** `mergedName` builds
`'${layers.first.name} ($mergedSuffix)'` and `duplicate` builds
`'${source.name} $copyLabel'` - and the head is the *layer's* or *project's*
name, which can be "Zdjęcie", "Tekst", "Dymek" or anything the user typed. A
participle agrees with exactly one gender: Polish "scalone" gave "Tekst
(scalone)", Spanish "combinada" gave "Texto (combinada)". Both keys now use a
noun or a prepositional phrase - "(kopia)", "po scaleniu", "combinación",
"fusion", "po sloučení" - which needs no agreement. German is the exception
that misleads: its participles do not inflect in this position, so
"zusammengeführt" was always fine.

**Polish "Dotknij" takes the accusative, not the genitive it governs in prose.**
Textbook Polish is *dotknąć czegoś*, so "Dotknij obiektów do usunięcia" parses -
but the genitive plural then reads as a noun phrase, "a touch *of* the objects
marked for removal", rather than as a command with an object. UI Polish (and
Microsoft's and Google's Android style) writes *Dotknij pozycję / ikonę*, and
that is what the four tap hints use: "Dotknij **obiekty** do usunięcia",
"Dotknij **obiekt** na zdjęciu…", "Dotykaj **obiekty**…", "Dotknij **niechciany
obiekt**…". Czech is the same shape but already correct - *klepnout **na** +
accusative* - so its hints only needed the stacked prepositions unpicked ("Klepni
na fotce na objekt" → "Na fotce klepni na objekt").

**A verbal noun cannot carry the pronoun.** Polish "cofnięcie go przywróci"
was meant as "undo will bring it back", but "cofnięcie go" binds first as
"undoing *it*", leaving the sentence without an object. Toasts state the action
and then instruct: "Obiekt usunięty - cofnij, aby go przywrócić".

**A `Semantics` label is user-visible text.** The colour swatches took their
names from a `const` list of English words interpolated into
`label: '$label, ${_colorNames[i]}'` under `excludeSemantics: true`, so that
string was everything a screen reader had - and a Polish user heard
"Wypełnienie, white". Nothing could catch it: it never renders as a `Text`, and
`arb_parity_test` compares ARB against ARB, so a string that was never keyed is
invisible to it. The names are localized now (`swatchWhite` …). The label is
comma-separated on purpose, so the row name and the colour stay two facts and
neither has to agree with the other.

Three things that are not literals-in-widgets and have their own home:

- **Enum labels** (tools, filters, blend modes, grid templates, canvas presets,
  seg models) keep their English `label` field - it is identity as much as
  presentation: templates are matched and keyed by it, projects persist enum
  names, and tests read it. The translation is a separate lookup in
  `lib/l10n/localized_labels.dart`, all tables in one file so a new enum value
  is one compile error in one place.
- **Document data** - project and layer names ("Untitled", "Photo 2", "copy",
  "(merged)") - is localized at the UI call site and passed IN to the
  controller/repository, which keep English defaults so they stay usable from a
  test with no `BuildContext`. A name is written into the saved project, like a
  filename; it does not re-translate later.
- **Licence notices** stay English data (`name`/`by`/`license` are attribution);
  only `category` and `use` are mapped, falling through to the English original
  for anything unmapped.

`gen-l10n` does not fail on a missing translation - it silently emits the
English string - so **`test/settings/arb_parity_test.dart` is the only thing
that catches an untranslated key**. It also compares placeholders, since a
dropped `{count}` throws at runtime rather than at build. A new language is one
`app_<code>.arb` plus an entry in `kAppLanguages` (labelled in its own
language, so someone stranded in a language they cannot read can get out) - both
`arb_parity_test` and `locale_overflow_test` then cover it automatically.

**Plurals are the part gen-l10n will not check for you.** It accepts a message
that is missing the category the language needs and simply shows the wrong noun
form. The English template uses `=1{} other{}`; that is NOT enough elsewhere:

- **French** must use `one{} other{}`, never `=1`. In French the CLDR `one`
  category covers 0 as well as 1 - "0 projet", not "0 projets" - and `=1` would
  send 0 to the plural arm.
- **Czech** needs `one/few/other`: 1, then 2-4, then 0 and 5+. Without a `few{}`
  arm it reads "5 projekty" instead of "5 projektů", and each arm needs its own
  noun case (genitive plural in `other`).
- **Polish** needs `one/few/many`.

When adding a language, look up its CLDR categories before writing the first
plural, and add them to `PLURAL_CATEGORIES` in the ARB build script.

`test/settings/locale_overflow_test.dart` pumps every screen in **every**
language at 360, 412 and landscape: German runs 10-35% longer than English, and
the rest of the suite pumps in the default locale, so a translated string that
does not fit is otherwise invisible to CI.

### Fitting: text scale, translation, small screens

One rule, applied in one place each: **a control that carries text ellipsizes
when it is bounded, and a container bounds it.** `GradientButton`, `PillChip`,
`LabeledSlider` and `_PanelHint` all put their label in a `Flexible` with
`maxLines: 1`, so bounding any of them shortens the label instead of producing
an overflow stripe. They are `mainAxisSize.min`, so an *unbounded* one is still
exactly as wide as its label - nothing moves where it already fitted.

The half that is easy to get wrong: **a `Row` lays a non-flex child out at its
intrinsic width no matter how little room it was given.** Bounding a `Row` of
chips therefore does not shrink them, it just moves the overflow inside; the
chips have to be `Flexible` too. That is why `_panelHeader`'s trailing Row wraps
each chip, and it is the thing to remember when adding a new one.

`test/settings/text_scale_overflow_test.dart` pumps every screen at 1.5x and 2x
(Android's largest) in English and German, plus the editor at 3x. The editor is
the only screen that can overflow vertically - everything else is a ListView and
just scrolls - because a canvas app cannot scroll its canvas away. Two rules
keep its Column honest: the top bar's secondary line is capped to **two** lines,
so the chrome cannot grow without bound; and the tool panel's cap is **half of
what is left** after the top bar and dock, not half of the viewport. Taking it
from the whole viewport is what broke it - the panel kept claiming 50% while the
chrome grew underneath it.

Two, not one and not unbounded. Uncapped it wrapped to eight lines at 2x and
made the top bar taller than the screen; capped at one it fitted the English and
truncated every translation at *normal* size - "0 Ebenen · auto-gespeic…" -
because that column is only as wide as the title reserve. Capping a line count
to what English needs is the standard way to ship a bug the English build
cannot show you.

The editor top bar is the tightest row in the app and has its own file,
`test/editor/top_bar_fit_test.dart`. It reserves `_minTitleWidth` for the
project title and caps the Export button, which ellipsizes into what is left;
the rename pencil is dropped when the title area is narrower than
`_renameHintFrom`, because it is the only thing in that row that cannot shrink
and so the only thing that can make it overflow. Undo / redo / canvas-size are
40dp wide and 48dp tall on purpose - four 48dp buttons is over half of a 360dp
screen, the same trade the colour swatches already make. **Do not give the top
bar another fixed-width child** without taking width back somewhere: at 360dp it
had 6.5dp of slack, which is how it came to overflow by 12px in English.

Ellipsizing keeps a layout intact but still loses words, and a few slots have no
give at all - the editor dock's labels sit in a hard `SizedBox(width: 64)`, the
three export format chips are `Expanded` so each gets a third of the row, the
Layers panel's merge/flatten chips are `Expanded` halves of one row **and** carry
an icon, and a `_PanelHint` used as a `_panelHeader` trailing shares its row with
the title. There the fix is the string, not the layout. `test/settings/arb_parity_test.dart`
carries a per-locale budget for each of those keys; the numbers are character
counts measured on the device, because a widget test reports roughly **double** -
flutter_test substitutes a monospaced font in which every glyph is a full em
wide. Device screenshots are the authority on fit; the budgets just stop the
same string coming back.

**Loading the real fonts in the test does not rescue this** - it has been tried.
A `FontLoader` over `assets/fonts/Manrope-Variable.ttf` does make text render in
Manrope, but it pins the variable font at its default instance rather than the
weight each widget asks for, so the measurement is still wrong in the same
direction: a probe built that way called English "Untitled" truncated in the
editor top bar, which `test/editor/top_bar_fit_test.dart` and any screenshot
both show fitting. Do not ship a fit gate built on `didExceedMaxLines`; it fails
on correct UI.

**Measure offline instead: `python3 tool/measure_labels.py`.** Reading the TTF
directly - instancing the variable font at the weight the widget asks for and
summing advance widths - gives the engine's own numbers, and they have matched
the device every time they have been checked. Each slot in that file carries the
geometry it came from, so a wrong assumption is visible: it first ran with the
dock at 11sp/w600 and flagged two German labels that a screenshot showed
fitting; the dock is 9.5sp/w700, and at the real size they fit. **Check the
widget's actual `TextStyle` before believing an over-budget result.** It is what
found the grid template strip - `SizedBox(width: _tileWidth + 12)`, 74dp on the
square canvas the setup sheet opens on - where Polish "Jedno nad drugim" (81.9dp)
and "2 z lewej, 3 z prawej" (89.4dp) were being cut, in the one fixed-width slot
`arb_parity_test.dart` had no budget for.

**`_panelHeader` is a `Wrap`, not a `Row` of two `Flexible`s.** Two flex
children split a row 50/50 regardless of what they need, so the Adjust header
gave its chips half - about 77dp each - while its title used a fifth of its own
half and the space between went to waste; German rendered "+ Hinzu…" beside
"Zurücks…". A fixed ratio cannot fix it either, because the panels disagree
about who needs the room: Adjust is a short title with two chips, Erase is
"Manuelles Radieren" with a hint. `Wrap` asks each for its intrinsic width and
moves the trailing to a second line only when the two genuinely do not fit.
**This only reproduces with a photo layer selected** - the Reset chip is not
built otherwise - which is why five review rounds on an empty canvas missed it.

**Two buttons sharing a row is the shape that breaks first.** Reset crop had a
third of the Adjust panel, and an M3 `OutlinedButton` spends 24dp a side on
padding before the label starts - about 72dp of text on a 360dp phone. English
"Reset crop" is 68dp, so it fitted and nothing looked wrong; every translation
is longer, and German rendered "Zuschnitt …" beside a full "Zuschnitt
bearbeiten" - two buttons whose visible labels were the same word, one of them
cut. No wording fixes that and no flex ratio does either, because the two German
labels want 200dp each out of 324. **They are stacked now**, full width. When a
row's labels come from translation, ask what the shortest-language case is
hiding: `crop_button_test.dart` asserted only that they did not overlap, which
was true throughout.

**Shortening a label to fit can collide it with a neighbour.** The dock's
`addLayer` was cut to Polish "Dodaj" to stop it ellipsizing - which made it
identical to `add`, the panel-header chip sitting directly above it in the same
Column, and the two do different things (the chip opens the five-way add menu,
the dock jumps to the gallery). `layersEmptyHint` quotes that label by name, so
the hint became ambiguous too. The dock now takes a noun for the content it
adds - "Zdjęcie / Foto / Photo / Fotka" beside "Tekst" and "Dymek" - which is
short, distinct, and matches the `add_photo_alternate` icon. English never had
the problem because it distinguishes "Add" from "Add layer".

### Persistence

Anything the user cannot re-enter is written through `writeFileAtomically`
(`core/persistence/atomic_file.dart`): tmp + flush + rename, so a kill or a full
disk leaves the previous file rather than a truncated one. Both the project
manifests and `settings.json` use it - `settings.json` reads back as `{}` on any
error, and `{}` means "Pro was never bought".

Two GC rules that are easy to break:

- **A duplicated project owns its masks.** Photos (`img_*`) are shared and
  refcounted across manifests by `sweepOrphanAssets`; masks are NOT, because the
  editor also runs an in-session mask GC that can only see the open document.
  `ProjectRepository.duplicate` copies each `mask_*` for that reason.
- **A quarantined `.json.corrupt` is read, not skipped.** Most quarantines are
  schema rejections whose raw JSON still names its assets, and skipping them
  aborted the sweep - which disabled orphan cleanup for the life of the install.
  Only bytes that will not decode as JSON abort it. `list()` also un-quarantines
  a manifest that parses again, so a downgrade is recoverable.

### Ads and consent

Nothing may request an ad before UMP has answered. `AdsService.consentSettled`
is the gate; the Home banner and `showRewarded` both await it, and
`canRequestAds` decides whether a load happens at all. Consent is NOT awaited
inside `init()` - that would stall ads for the whole network timeout on every
offline launch. `PrivacyScreen` carries the permanent "Ad privacy choices" entry
point, rendered only where UMP reports it is required.

Consent is not a launch-time constant. **Every route to the consent UI goes
through `AdsService.requestConsent`** - "Ad privacy choices" called `ConsentForm`
directly and told nobody, so withdrawing consent there left `canRequestAds`
stale for the session: banner still up, export gate still offering an ad.
`canRequestAds` is a `ValueNotifier`; the Home banner listens and takes itself
down the moment consent is withdrawn (and loads when it is granted).

An empty ad slot is ambiguous - Pro, no-fill and a broken request all render
nothing - so in **debug** builds the Home banner retries once on
`AdsConfig.testBanner` and captions the slot with the real unit's error. The
real unit is still requested first, deliberately: a dev build that only ever
asks the test unit is how a unit that serves nothing reaches production, where
it reads as zero revenue rather than as a bug. See `docs/monetization-setup.md`
("The Home banner shows nothing").

## Milestones

Planned as GitHub milestones **M0-M9** with issues. Work one milestone at a time;
**after each milestone, stop and ask the user to test-deploy on their physical
device** before starting the next (device deploys need their acknowledgement).

## On-device AI (reused from Sticker Maker)

`lib/features/segmentation/**` - engine abstraction + registry, ML Kit engine,
bundled U²-Netp (ONNX) engine, MobileSAM object engine, mask brush/processing.
Models in `assets/models/*.onnx` (Apache-2.0). Runs via `flutter_onnxruntime`.

## Monetization

`google_mobile_ads` (banner/interstitial/rewarded + UMP) and `in_app_purchase`
(one-time `pro_remove_ads`). Ad unit IDs live in one config file; Google **test**
IDs are placeholders until the real ones are set. See `docs/monetization-setup.md`.

## Licensing policy (closed-source app)

Bundle **only** MIT / BSD / Apache-2.0 / SIL-OFL. No GPL/LGPL (ffmpeg dropped),
no CC-BY-NC (no `u2net_portrait` / BRIA RMBG). Register bundled font + model
license texts in `lib/features/about/bundled_licenses.dart`.

## Store listing (`assets/store/`)

Six listings, not one with translations bolted on: `assets/store/<play-locale>/`
holds `details.md` (title / short / long), `feature-graphic.png` and a
`screenshots/` tree, for each of `en-US pl-PL de-DE es-ES fr-FR cs-CZ` - the
same set as `kAppLanguages`. Everything but `details.md` is generated; see
`docs/ship-checklist.md` for the commands.

**A store screenshot is a picture of the app, so every word inside the device
frame is UI text.** Translating only the caption painted beside the phone
produces a Polish listing containing an English screenshot, which reads worse
than shipping no Polish listing at all. `tool/capture_store_shots.py` therefore
sets the app's per-app locale and drives all eight states again on all three
emulators. Its tap tables are locale-independent - layout does not move when
the glyphs change - but they are per *device*, because portrait, the 10-inch
rail and the 7-inch rail (which scrolls, and the 10-inch does not) are three
different screens.

**The project and layer names in those captures are document data, so they are
localized on disk.** The app localizes a name at the call site that creates it
and writes the result into the manifest, never re-translating it - so a Polish
Home screen shows Polish project names only if the manifest says so. The
capture script writes the manifests, and `DOCS` in it is where "Park day",
"Photo 2", the sticker's "PARK DAY" and the bubble's "WALKIES" get their
translations.

**Two offline checks, because both failure modes are silent:**

- `tool/check_store_listings.py` - Play truncates the title at 30 characters and
  the short description at 80 without saying so, and German, Spanish and French
  all ran past the 4000-character long-description cap on the first draft. It
  also counts the looks, blend modes, grid layouts and bundled fonts out of the
  Dart source (a listing that still promises 14 filters after a fifteenth lands
  is a false claim, not a typo), and checks that the copy names the *localized*
  control - a description telling a Polish reader about "Vivid" is naming a
  button that says "Żywy". The label match is stem-based and case-folded on
  purpose: the copy is prose, so Polish writes "od Mnożenia" and Spanish
  lowercases "cuadrado" mid-sentence.
- `tool/store_copy.py` - the captions are **painted into** the images, so a line
  that is too long does not wrap or ellipsize, it runs off the edge or into the
  phone beside it. Same offline TTF measurement as `tool/measure_labels.py`, for
  the same reason. Phone portrait is by far the tightest slot at 936 px.

**Demo mode does not hide notification icons.** `sysui_demo` pins the clock at
9:41 and the signal bars, and its `notifications visible false` command looks
like it covers the rest, but it does not - whatever the emulator happened to be
nagging about that week lands in all 24 captures for that device. They are
snoozed individually instead, all but the Safety-Center shield, which the first
capture session also had and which the six sets therefore keep.

## Website (`website/`)

Plain HTML/CSS - no Jekyll, no build. `.github/workflows/pages.yml` uploads the
folder as-is on any push touching `website/**`, publishing it at
**idct.tech/chromis/**. Pages there are flat files: `index.html`, `privacy.html`,
`terms.html`.

**`website/sitemap.xml` is hand-maintained and must always be correct.** Unlike
the other IDCT sites - helena and gentastic generate theirs from a Liquid loop,
nuts uses `jekyll-sitemap` - this one is a literal list, so it is the only one
that goes stale on its own. Adding, renaming or deleting a page in `website/`
means editing `sitemap.xml` **in the same change**. Nothing catches it if you
forget: no build fails, no test goes red, the page simply never gets indexed.

It is not just this site's sitemap. `idct.tech/sitemap.xml` is a sitemap *index*
(repo `ideaconnect/ideaconnect.github.io`) that references this file directly and
is submitted to Google Search Console - so if this file 404s or goes malformed,
it is a hard error against the whole domain, not just `/chromis/`.

Two rules that go with it:

- **Every page needs a `<link rel="canonical">`, and it must match its `<loc>`
  here exactly.** GitHub Pages answers both `/chromis/privacy` and
  `/chromis/privacy.html` with a 200, so without a canonical the same page can
  be indexed twice. The canonical for the home page is the bare directory,
  `https://idct.tech/chromis/`, not `index.html`.
- **`changefreq` / `priority` are omitted on purpose.** Google ignores both;
  don't reintroduce them.

Check after any page change:

```bash
python3 -c "import xml.etree.ElementTree as ET; \
print([e[0].text for e in ET.parse('website/sitemap.xml').getroot()])"
grep -l 'rel="canonical"' website/*.html   # every page must be listed
```

## Commands

```bash
flutter analyze        # keep clean
flutter test           # keep green
dart format .          # CI enforces formatting
flutter gen-l10n       # after ANY lib/l10n/*.arb edit (output is committed)
flutter build apk --debug
```

Identity: applicationId `tech.idct.chromis`, namespace `tech.idct.chromis`, minSdk 26.
