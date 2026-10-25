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
Rotation, Horizontal, Vertical, Opacity - reads `Layer.transform` through
`updateTransform`, so it works on a caption or a bubble; the crop button and the
four colour sliders
reach pixels and stay an `ImageLayer`'s alone (`_photoAdjustments`). It answered
anything else with an empty hint before, which left one state with **no way
out**: the canvas hit box IS the layer, so a caption or bubble created small -
or pinched down by accident - is smaller than a finger and cannot be grabbed to
be made big again. A slider does not depend on the layer's size.

`layer_scale_curve.dart` holds the scale range and the slider's mapping.
`LayerScaleRange.forCanvas` is read by the slider, the pinch gesture's clamp
(`EditorCanvas._onScaleUpdate`) AND the snap engine's size match - the bounds
used to be duplicated with a comment saying to change both, which is a rule a
compiler cannot enforce; a gesture that reached a size the slider refuses to
represent would be a state with no way back.

**The range is per canvas, because a layer's scale is not.** Scale is relative
to the fixed `kLayerFitBoxSide` box, so a fixed 0.2…6x meant 2.4 canvas widths
at 1080 and less than a full bleed at 4096 - where a photo-sized canvas puts
its photo at 9.3x, and the first pinch clamped it to two thirds of its size.
`kMinLayerScale`/`kMaxLayerScale` are now the range on a 1080 canvas, stretched
by the canvas's longer side, and **it only ever widens**: the top grows on a
bigger canvas, the bottom shrinks on a smaller one, and neither moves inward,
so nothing that was in range before can leave it. That is deliberately not
proportional at both ends - proportional would keep a resized composition
exactly in range, but would pull a 512 canvas's top down to 2.8x and strand
every layer above it. What the asymmetry leaves (a layer shrunk past the bottom
by a Resize image, an old project) `clampGesture` absorbs: a pinch is clamped to
the range widened to where it STARTED, so an out-of-range layer never jumps and
can only be brought back toward the range.

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

**A pinch that reaches either end of the range says so** - a
`scale-limit-badge` pinned to the canvas's top edge and one light haptic tick on
arrival. The clamp is silent, so a layer at its limit just stops following the
fingers, which looks like the gesture was dropped. The badge is pinned to the
canvas rather than to the layer because a layer at its maximum is usually
bigger than the canvas, and it is asked with `kSnapPinchSlop` for the same
reason `snapScale` is: two fingers never hold a span exactly, so a two-finger
*move* of a layer already at the limit would flash it on every wobble. The size
sheet does the same for a typed canvas size past `Project.maxCanvasDimension`,
which used to grey Apply out with no reason given, and the Bubble panel says
when the auto-fit is drawing the caption smaller than Size asks for - past that
point the slider moves and nothing on the canvas does.

Rotation is shown wrapped into (-180°, 180°] because
the canvas ACCUMULATES it across pinches and a layer really can sit at 400°, and
it snaps to straight over the last couple of degrees, which a slider cannot hit
on purpose.

**Half a turn is the one angle the layer cannot describe, so the panel
remembers it.** -180° and 180° are the same rotation and both ends of the
slider, so wrapping alone had to pick one - and picking 180 meant a drag to the
LEFT end wrote -π and then watched the thumb teleport to the right end under
the finger, reading "180°" for a layer just turned the other way. Which of the
two equal readings to show is a fact about the drag rather than about the
layer, so `_setRotation` records the exact radians it wrote alongside the
degrees it was showing, and `_rotationDegreesOf` shows that reading back for as
long as the layer still holds exactly those radians. The match is **bit-exact**
on purpose: `updateTransform` stores the double untouched, whereas comparing
the two as *angles* would be at its least reliable at exactly ±180, where a
1e-13 rounding step crosses the wrap and reads as a 360° disagreement. Anything
else that moves the layer - a pinch, an undo, another layer selected - fails
the match and falls back to the wrapped angle, which is what keeps a sticky
reading from outliving the value it described.

**Horizontal and Vertical exist because the canvas hands a drag to the TOPMOST
layer under the finger.** A layer beneath a bigger one therefore cannot be
dragged out from under it - the hit test never reaches it - and that is a second
version of the same trap Scale was added for: every gesture on the canvas is
routed by the layer's own hit box, so any layer the hit box cannot deliver is
stranded. The panel addresses the *selected* layer, so neither the layer's size
nor what covers it has any say.

**100% is the offset at which the layer has just left the canvas: half the
canvas plus half the layer** (`placementTravel`). Two things follow from
choosing that over a plain fraction of the canvas. The bar covers everywhere the
layer can be *seen* and stops where it cannot, rather than spending its ends on
offsets that are all equally invisible; and the travel has to be measured per
layer, because a caption needs a few percent past the edge to be gone and a
full-bleed photo needs nearly a whole canvas more. Both ends snap to dead centre
over the last couple of percent, for the same reason Rotation snaps to straight.

**A layer parked off-canvas reads past ±100 and only the thumb pins to the
end.** Dragging a layer clean off the canvas is ordinary, not a corner case, so
the readout stays the true percentage (`LabeledSlider` clamps the `Slider`'s own
value) - the same trade the Scale slider makes. A clamped readout would say
"100%" for a layer three canvases away and then look broken when it moved.

**How big a layer is has ONE answer: `layerLogicalSize` in
`features/editor/layer_bounds.dart`.** The canvas hit-tests and draws the
selection frame with it and the placement sliders derive their travel from it,
and a hit box and a slider that measured the layer differently would be two
answers with nothing to reconcile them. The photo's pixel size that feeds it is
cached twice - once in `EditorCanvas`, once in `_EditorScreenState` - and that
is fine where a second copy of the formula would not be: a file's dimensions
cannot disagree between two readers. Until the header lands (or for a file that
will not decode) a photo measures as the full `kLayerFitBoxSide` square, which
rounds the answer UP, and up is the safe direction for both callers - a hit box
too big is still grabbable, and travel too long still reaches off-canvas.

**A photo that fills a grid cell gets none of the four.** `_clampToCell` keeps a
cell photo covering its cell, because one shrunk aside leaves a hole in the
collage that reads as a bug; a slider would be a second path to that state with
none of the clamp - and Horizontal/Vertical would be the *most* direct one.
Nothing is lost - a cell photo fills its cell, so it is never the layer you
cannot touch or the one hiding under another. Captions and bubbles in a cell
keep the sliders: they are never clamped there, only clipped.

#### Snapping

`layer_snap.dart` is pure and takes a proposed `LayerTransform` back to the
nearest alignment: three anchors per axis - leading edge, centre, trailing edge -
matched against the same three on every other visible layer **and on the
canvas**, closest pair wins, axes independent.

**All of it happens in a FRAME, and that is the whole design.** Alignment is
measured along a pair of axes at some angle, not along the canvas's x and y.
Two layers at the same angle are not turned at all *relative to each other*, so
in their shared frame their edges are parallel and can be made flush; two layers
at different angles have no parallel edges, and the most either can say about
the other is where its corners reach. An axis-aligned engine can only ever
compare bounding boxes, and **two turned layers can never be brought flush by
comparing bounding boxes** - the boxes touch at a corner while the edges are
still degrees apart.

`SnapFrame` is therefore a parameter, because the two callers cannot share one:

- **`layer`** - the moving layer's own rotation. What a gesture uses. In its own
  frame the layer is not turned, so its extent is its true width and height and
  its edges are the ones it draws.
- **`canvas`** - the canvas's x and y, with a turned layer measured by its
  bounding box. What the placement sliders MUST use: each of them moves the
  layer along one canvas axis, and an alignment found on a turned layer's own
  edge runs diagonally, so taking it would move the layer on the axis the slider
  does not own. A one-axis control that moves two axes is a bug whatever it
  snapped to.

At angle 0 the frame is the canvas - `cos 0` is exactly 1.0 and `sin 0` exactly
0.0, so the projection is an identity and the unrotated path is bit-for-bit what
it was before the frame existed.

**A layer may TAKE a neighbour's angle** (`kSnapRotationTolerance`, 4°), which is
the only way two turned layers ever become flush: 26° carried up against 28°
comes out at 28° with the edges touching. But a move is not a request to rotate,
so a borrowed angle has to be **paid for - it is kept only if the alignment it
produces is with the very layer it was borrowed from**. That gate, not the 4°,
is what stops a deliberately tilted caption being straightened by being carried
past an upright photo; without it every near-angle neighbour on the canvas would
fuse. `snapRotation` lifts the gate and only a gesture that is ITSELF turning the
layer passes it (`d.rotation != 0`, and the Rotation slider via
`nearestLayerRotation`) - there, matching a neighbour's angle is the thing being
asked for rather than a side effect of asking for something else.

Two more things a borrow has to clear, both found by adversarial review rather
than by use:

- **It must not cost an alignment the layer already has with somebody else.**
  Otherwise a borrow wins on merely existing: a layer sitting exactly flush with
  one neighbour would tilt itself off that alignment to take a seven-unit one
  with another. The own frame is therefore evaluated up front as *evidence*, not
  as a fallback.
- **A layer SQUARE to the canvas does not borrow on a move at all.** Arriving at
  level is a small surprise and leaving it is a large one, so the asymmetry is
  deliberate - without it one tilted sticker knocks every layer it is aligned to
  askew. A deliberate twist may still take any angle; by then the layer is not
  square anyway.

Borrowed angles are expressed as an offset from the layer's own rotation, not as
the neighbour's absolute angle, because the canvas ACCUMULATES rotation: a layer
wound to 386° taking a 28° neighbour's angle must come out at 388°, not unwind
three-quarters of a turn for the same picture.

**`d.scale != 1` and `d.rotation != 0` are the wrong question, and the tests
cannot tell you so.** Flutter derives both from the line between two pointers - a
span ratio and an `atan2` difference - so with two fingers down they are exactly
1 and 0 only when the fingers move perfectly parallel and perfectly together,
which no hand does. Read as *intent* they answer "yes, a deliberate resize" and
"yes, a deliberate twist" for the whole of every two-finger gesture, so a plain
two-finger move came out resized to a neighbour's width and turned to its angle.
A synthetic pointer moves exactly, so every widget test passed. They are asked
with a slop now - `kSnapPinchSlop`, `kSnapTwistSlop` - and the two tests that
pin it have to stage the wobble by hand.

The Rotation slider snaps to **straight first and a neighbour's angle only if
straight did not fire**. Level is the stronger of the two - a layer resting a
hair off level reads as a mistake - and a neighbour at 3° must not be able to
pull a layer off 0.

**The Snap toggle governs the canvas gesture AND the placement sliders**, because
those are the same two edits - the sliders exist for the layer a finger cannot
reach, and a toggle sitting directly above them that only reached the canvas
would be a promise about the controls under it that it does not keep. It is
session state on `EditorController` (like `addToAllFrames`), not a field on the
document: it changes how an edit is made, not what the edit is. Default **on**.

Three things it would be easy to get wrong:

- **`snapScale` is off by default, and a one-finger drag leaves it off.** On a
  plain move the proposed scale IS the layer's own, so a layer that happened to
  sit near a neighbour's width would be silently resized by being moved. Only a
  pinch (`d.scale != 1`) and the Scale slider ask for it. Size is matched on the
  resulting extent rather than on the scale factor - a scale ratio means nothing
  between two layers whose own sizes differ - and a match that would need a
  scale outside `kMinLayerScale…kMaxLayerScale` is **dropped, not clamped**.
- **The tolerance is the caller's, and the two callers are right to disagree.**
  A finger on the canvas is a screen-space thing, so `EditorCanvas` converts an
  8-px radius through the zoom; a slider thumb is somewhere else entirely, so
  the panel uses 2% of the canvas. A radius fixed in canvas units would grab
  from a centimetre away on a 4000-px canvas.
- **A snap with no feedback reads as the drag stuttering.** The canvas draws a
  magenta hairline on each alignment it landed on - magenta, not the selection's
  cyan, because the two are on screen together. **The line runs along the frame,
  not along the canvas**: the point of two layers sharing an angle is that they
  share a set of edge directions, and a guide drawn square to the canvas would
  cross those edges instead of lying on them. A size or angle match has no line
  to draw (the other layer is nowhere near), so the canvas **outlines that
  layer** instead. Both are gesture-scoped and cleared in `_onScaleEnd`.
- **The canvas's own edges are only a target while the frame is square to
  them.** Turned, "the canvas's left edge" is a diagonal in frame coordinates -
  the supporting line of the canvas's corner, which sits OUTSIDE the canvas and
  would draw a guide nobody can see. Its CENTRE stays a target at every angle,
  because a point is a point whichever way the axes run.
- **Only what is on SCREEN may be lined up with.** A collage cell clips its
  layer and a cell photo is cover-scaled, so on a 2×2 grid a 3:2 photo reaches
  135 units into the cell next door; aligning to that edge sticks the layer to a
  line with nothing on it. `clipOf` hands the engine each target's cell and it
  aligns to the intersection - which for a cover photo IS the cell, so the cell's
  edges and centre become the targets, which is what a collage is lined up to
  anyway. `_hitTest` has always applied this rule to taps; the snap path did not.

`_setPlacement` keeps its own snap-to-dead-centre: that one is not optional, a
slider that cannot hit its own middle is broken with snapping off too. Running
the engine afterwards is safe because it finds the position already exactly on
the canvas-centre target.

**The toggle cost the placement stack one slider's worth of fold.** The portrait
panel is capped at 300dp and scrolls, and a 48dp switch row pushed Vertical
below it - which is why the explainer is a `Semantics` hint rather than a second
line of muted text, and why `layer_transform_sliders_test.dart` now scrolls the
panel before driving that slider. A widget outside a `SingleChildScrollView`'s
viewport is clipped and cannot be hit-tested at all, so a drag aimed at it does
nothing at all rather than failing.

**Both overflow sweeps now SELECT a layer.** `text_scale_overflow_test` loaded a
project and left it unselected and `locale_overflow_test` used `Project.empty`,
so the Adjust panel's chips, crop buttons, toggle and sliders - every translated
string in the tool panel - were outside both. That is the same blind spot that
let the panel header's 50/50 split ship past five review rounds.

### Resize image

The top bar's size button opens one sheet with two tabs, because people look
for both behind it. **Canvas** changes the canvas around the layers, as it
always did. **Image** scales the whole picture: `resizeProjectGeometry`
(`features/editor/image_resize.dart`) moves and scales every layer in every
frame plus a collage's borders, `PhotoResampler` gives every photo new pixels,
and `EditorController.resizeImage` commits it all as one undo step. Width and
height are linked - a caption cannot be stretched, so neither can the picture.

**The pixels are computed on the CPU (`core/rendering/resample.dart`), because
a method the user picks by name has to be the method that runs.** A GPU draw
resamples with whatever `FilterQuality` maps to on its backend and there is no
Lanczos to ask for. Nearest / bilinear / bicubic (Catmull-Rom) / Lanczos-3,
separable, with the kernel widened by the shrink factor so a downscale averages
rather than aliases. RGBA is filtered **premultiplied**: straight, a cut-out's
hidden pixels bleed their colour into its edge. The vertical pass streams
through a ring of filtered rows instead of a whole intermediate image, which
for a 2048 -> 4096 upscale would be 100 MB of floats. Lanczos is the sharpest
at shrinking, not at enlarging - on an enlarged hard edge it is no steeper than
bicubic and its second lobe leaves a faint halo, which is what its description
in the sheet says and what `resample_test.dart` pins.

**Each photo is resampled to its FOOTPRINT, not by the resize factor**
(`photoResampleTarget`): the pixels it covers on the resized canvas, measured
with `layerLogicalSize` and divided back out of its crop, capped at
`kMaxPhotoSide`. The export then draws it 1:1, so the user's method is the only
resampling it ever gets. By factor, a 2048 photo on a 1080 canvas would stay
twice the size it is drawn at and the GPU's bilinear would finish the job -
which undoes nearest neighbour entirely. Text and bubbles get only the new
transform: they are drawn from their description, so they stay sharp.

Three things that are easy to break:

- **A mask is resampled with its photo, and they are swapped together or not
  at all.** `MaskMapper` and every AI tool address photo and mask with one pixel
  coordinate. The dock stays live during the seconds a resample takes, so
  `resizeImage` re-derives the geometry from the LIVE document and swaps only a
  layer that still shows what was resampled (`ResampledPhoto.fromAsset` /
  `fromMask`); anything else keeps its old pixels, which still draw correctly.
  The other direction is ordering, not a check: a cut-out, stroke or fill that
  landed AFTER the resize would set an old-size mask on the new photo, so the
  resize waits for a background removal in flight (`_bgRemovalSettled`), queues
  on `_strokeLock` with strokes and object removal, and Remove background shows
  busy while it runs.
- **The editor's working-mask cache is keyed by the photo too.** A layer with
  no mask yet caches a *filled* one at the photo's size, and Resize image swaps
  the photo for another size without giving it a mask - keyed by (layer, mask)
  alone, the next erase stroke painted into a mask the photo no longer matched.
- **New files, never rewritten ones.** The undo step before the resize still
  points at the originals; the orphan sweep reclaims them, and a superseded
  mask goes through the same `SupersededMaskCollector` as a brush stroke's. An
  opaque result goes back as JPEG at q95 - a 4096 px PNG of a photo is ~30 MB -
  and anything with alpha in it stays PNG.

**`kMaxPhotoSide` (4096, `canvas_geometry.dart`) is the import downscale AND
the resize cap** - one number, because a resize that could write a photo the
import would refuse is a second route to the memory this bounds. It was 2048.
A 4096 x 3072 photo is 50 MB decoded, four times what 2048 was, and the AI tools
decode their input in full; every memory and timing figure elsewhere in this
file was measured on 2048 px photos, so re-measure before trusting them at the
new cap.

### Caption fonts

Three sources, one picker: the bundled set (`AppFonts.bundledFonts`, 17), the
user's imported .ttf/.otf files (`features/fonts/custom_fonts.dart`), and the
device's own fonts (`features/fonts/device_fonts.dart`). The panels show one
`FontField` that opens `showFontPicker` - a searchable, sectioned list - where
there used to be a horizontal strip of chips, which stopped working once the
list stopped being five long.

**Every bundled caption face maps the full alphabet of all six app languages.**
A missing ą or ř falls back to the system font mid-word, which is worse than
not offering the face. Permanent Marker, Chewy, Creepster, Lilita One and
Bubblegum Sans were left out for exactly that. Captions and bubbles always draw
at w700, so a family that ships a real Bold bundles that file declared
`weight: 700` - undeclared it counts as 400 and is emboldened on top. A family
key is identity (projects persist it), so the picker shows `AppFonts.nameOf`.

**Device fonts are read straight out of `/system/fonts`, `/product/fonts` and
`/system_ext/fonts`** - world-readable, so no permission and no channel.
`font_file_info.dart` reads only the `name`, `OS/2` and `cmap` tables of each
file, because a scan that loaded whole files would read the CJK collections.
Kept: Latin-capable (all of A-Z/a-z - most of the directory is Noto script
fallbacks the engine reaches anyway), upright, under `kMaxDeviceFontBytes`,
and **offered by a NAMED family in `/system/etc/fonts.xml`** (or a vendor's
`/product/etc/fonts_customization.xml`). The Latin check alone is not enough:
on the API 37 emulator it kept Noto Sans Hebrew, Khmer, Tamil UI and Serif
Hentaigana - script fallbacks that carry a plain Latin - and a duplicate
`RobotoStatic`, 14 families of which 9 were real choices. Since Android 15 the
fallbacks live in a `font_fallback.xml` apps cannot read, so "listed only as a
fallback" cannot be asked; "listed by name" can. No readable config means no
filter, which over-offers rather than hiding the phone's fonts.

**And only a face whose own file declares the OFL or Apache 2.0** (name ids 13
and 14, `isOpenFontLicence`). The app never copies a device font, but a phone
maker's own faces - Google Sans on a Pixel, Samsung's - are licensed for the
maker's software rather than for other apps' pictures, and the app's licensing
policy is OFL / Apache / MIT / BSD for anything it uses. A font that does not
state its licence is not offered at all. Every AOSP font passes, and so does
every bundled one - `device_fonts_test.dart` asserts both.
`integration_test/device_fonts_device_test.dart` is the only check that runs
any of this against a real font directory - run it after touching the scan.
**One face per family is registered, the one nearest w700**, because a font
registered with the engine stays for the life of the process and on a 2 GB
phone a picker that pinned a family's six weights - or a 30 MB CJK font - by
being scrolled past is how the editor gets killed in the background. The list
is lazy for the same reason: building a row is what loads its font.

**A device font must be registered before anything draws it, and three paths
see to that:** the picker awaits it before writing the layer; `ProjectCanvas`
prefetches every family its frame names (a reopened project, Home's tiles);
`ProjectRenderer._render` awaits them, because an export has no second frame to
correct a fallback face. Text re-lays itself out when a font lands -
`loadFontFromList` broadcasts a fonts change - but **anything measured in
`build` does not**: `BubbleView`'s auto-fit and the canvas's hit boxes listen to
`PaintingBinding.instance.systemFonts` and rebuild. A family that is bundled or
imported is `reserve`d and never looked up as a device font - registered under
the same name, a device file would join that family as a second face. An import
is named unique against all three sources for the same reason.

Three things the second review found, each a way two files end up in one
family or a font silently goes missing:

- **Imported names are reserved before anything loads.** Home's first frame
  asks for the families its tiles draw, before the import catalogue is read;
  `CustomFontsController.build` hands its load to
  `DeviceFonts.holdUntilImportsKnown`, and every device load waits for it.
- **An import named like a family the app draws itself is renumbered on
  load** - "Lobster" imported before Lobster was bundled becomes "Lobster 2",
  written back to `fonts.json`. The set it is checked against includes
  Manrope, the UI face, which `bundledFonts` does not: an import called
  Manrope would otherwise become a second face of every label in the app.
- **A failed scan or load is not an answer.** Only "no such family on this
  phone" is cached; a read or registration that threw is forgotten so the
  next explicit `ensure` (the picker, an export) retries, and `prefetch`
  skips it so a failing file is not re-read on every frame of a drag.

The picker's de-duplication is by written name, case-insensitive - NOT
space-insensitive like its search: the engine tells "RobotoMono" from
"Roboto Mono", and folding the space hid one of two fonts that never collided.

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
it.

**Which tiers run is the user's choice, and it is named by what it costs, not
by model (#68).** Under Fill in sits **Best quality** (MI-GAN, falling through
to content fill) and **Low memory** (content fill alone) - `FillQuality` in
`features/segmentation/fill_quality.dart`, and `runFill` is the one place the
routing lives. It is a real trade, measured on the emulator with a 2048 px
photo: MI-GAN peaks 454-460 MB above the app and takes 7.6-24.6 s, content
fill 39-46 MB and 1.6-3.0 s - and on a 2 GB phone those 460 MB are #66's ANR.
The old label "Fill (AI)" named a model and promised one the app could not
always run; these two name an outcome both always deliver.

The first fill **asks** (`FillQualitySheet`), with a guess preselected:
`recommendFillQuality` says Low memory for a low-RAM device, under 3 GiB total,
or under 1 GiB free at the time - twice MI-GAN's peak - and Best quality
otherwise, including when the phone cannot say (SAM's "only a positive signal"
rule). It is asked after the "did the tap hit the photo" checks and **before**
the ad gate, so backing out costs nothing; dismissing saves nothing and the
next fill asks again. The answer is `settings.json`'s `fillQuality` key, with
the same remove-not-null rule as `themeMode`, and a tap on the panel row is a
choice too, so it is never asked after that.

**There is no availability gate on the generative tier, and that is
deliberate.** Deciding "should we even try MI-GAN?" got this tier silently
skipped THREE times - the dead chooser branch, then a synchronous
`ref.read(futureProvider).asData` that reads as AsyncLoading (i.e. "no model")
for the first fill of every session. `inpaint` already returns null for a
missing or unloadable asset, and null is the signal to fall through, so the
gate bought nothing and hid everything. Do not reintroduce one. **The quality
choice is not one**: Best quality still tries MI-GAN unconditionally and treats
null as "fall through"; only the user's own Low memory skips it. Read the
choice with `await ...future`, never `asData` - the same trap, one provider
over. And type the result where a `??` joins two provider reads: the left
side's nullable type becomes the right side's inference context, and
`ref.read` then hands back a nullable.

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

**Android Auto Backup is refused in the manifest, and that is load-bearing.**
Backup is ON by default and its default include-set covers
`getApplicationDocumentsDirectory()` - which is exactly where `projects/assets/`
keeps every photo the user imported and every AI cut-out mask. Left at the
default, installing this app would have copied the user's photo library into
their Google Drive with no code of ours involved, which is the one claim the
whole listing is built on. It takes **two** attributes, not one, and neither
implies the other: `android:allowBackup="false"` covers Android 11 and below,
and `android:dataExtractionRules` covers Android 12+, where the platform split
cloud backup from phone-to-phone transfer and a refusal has to name both.
`res/xml/data_extraction_rules.xml` is a blanket refusal rather than an exclude
list on purpose - an exclude list is a statement about the directories that
exist today, and the failure mode of one nobody remembered to add is a silent
upload.

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

**The Home banner exists only while Home can be seen (#67).** Routes are pushed,
so Home stays mounted under the editor and export screen, and a platform view in
a covered route stays attached and VISIBLE - the banner's WebView went on
rendering behind the editor, where the AI tools keep every core busy. That is
not free on our side: each WebView frame is a synchronous round trip from our
main thread to the ad's renderer process. On the emulator an animated banner
cost Home's main thread 2.4 s of view traversals and 0.5 s of VSync callbacks in
6.6 s, with nobody touching the phone. `OnScreenOnly`
(`core/widgets/on_screen_only.dart`) takes the `AdWidget` out of the tree when
`TickerMode` turns off, which `Overlay` does for everything under an opaque
route; the `BannerAd` stays loaded, so coming back re-attaches the same
`AdView` with no new request, and AdMob stops refreshing an ad nobody can see.
**Any new ad slot, or any other platform view on a screen that gets covered,
goes in one too.**

**`J.N.<letters>` in a Play ANR is WebView native code, and the letters are a
signature, not a name.** Chromium's multiplexed JNI names each native by its
types - `VJJJ` is "void, three longs" - so the mapping changes with the WebView
version and only the APK can answer it: `dexdump -d` its `classes.dex` and find
the `invoke-static ... LJ/N;.VJJJ` call sites. In WebView 151 there is one,
`ExternalBeginFrameSourceAndroid.doFrame` - the per-frame VSync callback - and
behind it `SynchronousCompositorSyncCallBridge` waits for the renderer on a
condition variable **with no timeout**. That is the frame the Android docs'
list of common Unity ANRs shows blocked in `pthread_cond_wait`; older builds
called it `J.N.Mhc_M_H$`.

### Leaving the app, and the Flutter pin

**Back on the last screen moves the task to the background; it never finishes
the activity** (`MainActivity`, #65). Flutter's default is `finish()`, which
tears the engine down while the process lives on and the AdMob banner's WebView
is still drawing into its platform-view texture - and both crashes of that
teardown are real: on Mali, Impeller frees fences the driver's backend thread
is still signalling (`FORTIFY: pthread_mutex_lock called on a destroyed mutex`,
no Flutter frame on the stack - flutter#187703, #191168), and on the emulator
the WebView trips a CHECK two back-outs in three. Android 12+ already treats
any other app's root activity this way.

It takes two hooks, because Android delivers back two ways. Where back is still
`onBackPressed` (below 16, or predictive back off) the last back lands in
`popSystemNavigator`. On Android 16+ an app targeting 36 gets only
`OnBackInvokedCallback`s, and Flutter unregisters its own on the last route, so
`MainActivity` registers one of its own **before `super.onCreate`**, underneath
Flutter's - equal priority runs most-recent-first. **Do not simplify this by
keeping Flutter's callback registered on the last route**: it was tried, and
the back swipe on Home was swallowed after any trip to the editor, because the
predictive-back page transition, not `canPop`, decides who claims a swipe.

Check it with the events log rather than by eye: `wm_finish_activity ...
app-request` is the finish. After the fix there is none and the pid survives.

**Flutter is pinned to the 3.44 line** (`ci.yml`). 3.47 drops MediaTek phones
below vendor SDK 32 to OpenGLES, where `toByteData` racing `toImage` - mask
decode and export both do it - deadlocks the Mali driver (flutter#193428,
open). 3.44.7 fixed a `sync_file` leak in platform-view textures on Android 13+
that the banner hit on every refresh: about 125 descriptors a refresh on the
emulator, released only by GC, and flat on 3.44.9. Re-check both before moving
off 3.44. `play.yml` reads its Flutter version out of `ci.yml`, so the pin
stays in one place and what ships is what CI tested.

### The Android main thread

**Input ANRs are the main thread, and on a 2 GB phone anything over a few
hundred ms on an emulator is a candidate.** Two rules on our side:

- **Platform-channel work that touches storage goes to a background thread.**
  `saveImageToGallery` wrote through MediaStore on the main thread, and the
  final `IS_PENDING=0` update makes the media provider scan the file before it
  returns - 150 ms for a 1.9 MB PNG on the emulator, right after the export's
  rewarded ad closes, which is when the user taps. It runs on `galleryWriter`
  now; only the pre-Q permission check stays on the main thread. A channel
  reply may come from any thread.
- **AI sessions must not keep their working memory** - see the arena under
  On-device AI. Memory pressure is how a main thread that looks idle in the
  trace still causes the ANR.

What is left there is not ours, measured on the API 37 emulator: Impeller's
surface setup at cold start (`FlutterJNI.nativeSurfaceCreated` waits on the
raster thread: 0.85 s warm, 3.9 s on the first launch after install), AdMob
creating its JavaScript WebView after `MobileAds.initialize` (~0.5 s), and
Play Billing's `startConnection` (~0.15 s).

**How to measure it.** The emulator is a user build, so `log.looper.*.slow`
cannot be set. A temporary `Looper.setMessageLogging` printer plus a watchdog
thread sampling `mainLooper.thread.stackTrace` finds slow messages, and
comparing the main thread's CPU time (`/proc/self/task/<pid>/stat`) with wall
time finds the other case - native work inside `nativePollOnce` (Flutter
engine tasks, Chromium's UI-thread tasks), which is exactly what the ANR trace
shows as "idle". Do not read Java costs from `simpleperf` on a Flutter
**profile** build: that build is debuggable, so ART interprets it. For memory,
`ProcessInfo.currentRss` from an integration test isolates one session at a
time; driving the UI cannot. For frame work, `adb shell atrace -t 8
-a tech.idct.chromis view gfx` does run on the user build and needs no code:
main-thread `traversal` and `animation` slices are where an ad WebView's frames
land.

## Milestones

Planned as GitHub milestones **M0-M9** with issues. Work one milestone at a time;
**after each milestone, stop and ask the user to test-deploy on their physical
device** before starting the next (device deploys need their acknowledgement).

## On-device AI (reused from Sticker Maker)

`lib/features/segmentation/**` - engine abstraction + registry, ML Kit engine,
bundled U²-Netp (ONNX) engine, MobileSAM object engine, mask brush/processing.
Models in `assets/models/*.onnx` (Apache-2.0). Runs via `flutter_onnxruntime`.

**Every ORT session is created with `ortSessionOptions()`
(`engines/ort_session_options.dart`), and that turns KleidiAI off.** ORT 1.23
switched its KleidiAI kernels on for any CPU reporting SME, but they are SME2
code, so Snapdragon 8 Gen 5 / 8 Elite Gen 5 (SME without SME2 - Galaxy S26,
razr fold) died with SIGILL on the first MobileSAM pass (#64). It was a process
kill, so no Dart `try` and no failure flag ever ran. And because opening Remove
object warms the encoder at once while background removal defaults to ML Kit,
it read as "object removal crashes" on phones where every ORT feature did. ORT
1.28 (`flutter_onnxruntime` 1.9) picks SME vs SME2 at runtime; the opt-out is
there so the fix does not rest on that detection on chips nobody here can test.
It costs nothing elsewhere, because MLAS only installs KleidiAI on SME CPUs.
`test/segmentation/ort_session_options_test.dart` fails on any session created
without it. **Do not settle on ORT 1.27**: it silently miscomputes on SM8850
(sherpa-onnx #3845), which is worse than a crash.

An ORT failure is otherwise invisible from outside - SAM reads as
"unavailable", U²-Net falls back to ML Kit, MI-GAN to content fill - so "the app
did not crash" proves nothing. `integration_test/ort_engines_device_test.dart`
(SAM, U²-Net) and `inpaint_device_test.dart` (MI-GAN) assert the models RAN;
run them after any ORT bump.

**`ortSessionOptions()` also turns ORT's CPU memory arena off (#66), and on a
2 GB phone that is the difference between working and not.** The arena grows
to fit a run and returns nothing while its session lives, and every session but
the SAM encoder lives for the process (MI-GAN's provider, U²-Net's engine, the
SAM decoder). Measured on the emulator: one U²-Net cut kept 200 MB, two MI-GAN
fills kept 1.1 GB, so the app sat at 1.4 GB resident after a couple of taps.
On an Infinix Smart 7 HD that is zram thrash in which the main thread is not
scheduled for seconds - an "Input dispatching timed out" whose trace shows an
idle `nativePollOnce`, because by the time it is sampled the thread has nothing
left to do. Arena off, the same two fills keep 44 MB, take the same time, and
the process peak drops from 1.6 GB to 1.0 GB. Nothing else shows the cost: the
fill still works, just as fast, so `inpaint_device_test.dart` asserts on the
resident size directly and fails with the arena on (+1,171 MB).

**`ortSessionOptions()` also turns ORT's Gelu fusions off, and 1.4.2 shipped
without that: Remove object's AI did not work on most phones.** MobileSAM is
fp16 with its GELUs written out as `Erf` arithmetic. ORT 1.28 fuses that into
one fp16 `com.microsoft.Gelu` on any ARM CPU with fp16 arithmetic - nearly every
phone since 2018 - then has no fp16 kernel for it, so the encoder session will
not create (`ORT_NOT_IMPLEMENTED`), and the editor says the AI "isn't available
on this device". Found on a Xiaomi 15 Ultra; every device test had passed,
because **an x86 emulator has no fp16 path and never takes the fusion**. So the
device tests must run on an ARM phone after any ORT bump - side by side with
the Play install, never over it: a temporary `applicationIdSuffix` on the
debug build type keeps the user's projects safe, and HyperOS needs "Install via
USB" plus a confirmation per install. The setting is
`optimization.disable_specified_optimizers`, and **its list is split on `;`** -
written with a comma it disables nothing, silently, which is what the first
attempt at this fix did; `ort_session_options_test.dart` now pins both.

## Monetization

`google_mobile_ads` (banner + **rewarded interstitial** + UMP; there is no
plain interstitial) and `in_app_purchase`. The one-time product id is
**`chromis_pro_mode`** - it is `kProProductId` in `lib/features/go_pro/iap.dart`,
and a product created under any other name simply returns nothing from
`queryProductDetails`, which only reproduces on a Play track. Ad unit IDs live in
one config file. See `docs/monetization-setup.md`.

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

**The photographs in those captures are CC0 and live in the repo.** A Play
listing is commercial use of every pixel inside the device frame, so which
photograph is in one is a decision that belongs in version control rather than
in whatever happened to be in an emulator's gallery - the first six listings
shipped a personal photo. `assets/store/samples/` holds them,
`tool/fetch_stock_photos.py` fetches them from Wikimedia Commons filtered to
CC0 as a **structured claim** (`haswbstatement:P275=Q6938433`, not a licence
string somebody has to read), and `SOURCES.json` keeps each one's title, size,
licence and source URL beside the pixels. Each is centre-cropped to its slot's
exact size, because the manifests carry transforms tuned to those dimensions -
1536x2048 at scale 4.6545 is full-bleed, and a photo of another aspect
letterboxes itself inside the frame. The cut-out is a **real AI Cut output**
(`capture_store_shots.py mask phone`), not a hand-drawn alpha: the sticker and
bubble shots are showing what the app produces.

**`capture_store_shots.py prepare` is not optional, and skipping it does not
look like an error.** Seeding `proEntitled: true` keeps ads out only until the
app checks it - `reconcileEntitlement` re-verifies the flag against Play on
every launch and revokes it on a confirmed "not owned", which is exactly what a
Play-store emulator with no purchase answers. The damage is not an ad in a
corner: **without Pro the editor's rail grows a Go Pro entry at the top, which
pushes every tool down one slot**, so the tap tables hit Bubble where they mean
AI Cut and the run yields eight plausible screenshots of the wrong panels, on
every device, in every language. `prepare` disables the Play Store so the
billing query throws instead (every uncertain case keeps Pro), drops the radios
so UMP cannot fetch a consent form over the first frame, and sets the dark
theme the listing art is composed from.

**A stopped capture run leaves the previous run's PNGs under the same names.**
Nothing downstream can tell a fresh set from a half-replaced one - the files
are all present and all the right size - which is how a tablet set captured
before a device fix survived into a composed listing. `tool/verify_shots.py
--since tab10=HH:MM` is the check, and its cutoff is **per profile** because
the devices are re-run independently.

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
  lowercases "cuadrado" mid-sentence. **It counts the website too**, because
  the landing page describes the same enums and drifted the same way - it
  advertised "15 filters" for two releases while the listing said 14, both
  describing one `PhotoFilter`. The site match is `<n> <word>`, not `str(n) in
  page`: the page is full of unrelated integers (image widths, "2 to 5 photos",
  the model's size in MB) and a bare substring test passes on any of them.
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

## Releasing to Google Play

**Publishing a full GitHub release ships it.** `.github/workflows/play.yml`
builds the tag, tests it, and uploads the signed bundle to the production
track at 100%. A pre-release uploads nothing. Setup and recovery are in
`docs/release-and-data-safety.md`, section 6.

**`docs/release/whatsnew-<version>.txt` goes straight to every user's update
screen, unreviewed.** It is the only source of the Play notes - the GitHub
release body is written for developers and is never sent. So the notes say what
changed for the person using the app, and nothing about how: no issue numbers,
file names, links, tooling, or the release process itself.
`tool/play_release_notes.py` refuses a file that reads like a changelog, that
is missing one of the six languages, or that runs past Play's 500 characters,
and the workflow runs it before building. The list it checks is a net, not a
review - "no longer blocks the main thread" passes it and still does not belong
there.

The tag must be `v` + `pubspec.yaml`'s version name, or the workflow stops.

## Website (`website/`)

Plain HTML/CSS - no Jekyll, no build. `.github/workflows/pages.yml` uploads the
folder as-is on any push touching `website/**` to a Cloudflare Worker that is
nothing but static assets (`wrangler.jsonc`), bound by route to
**idct.tech/chromis/**; every other path on `idct.tech` is still the org's apex
site on GitHub Pages. Pages there are flat files: `index.html`, `privacy.html`,
`terms.html`. **The folder is uploaded as-is**, so anything left in it ships -
a scratch probe copy of a page is a live URL and a duplicate of the listing.

**The `.html` URLs are the addresses, and Cloudflare's default would move
them.** Its HTML handling 307s `/chromis/privacy.html` to `/chromis/privacy` -
and `privacy.html` is what the app's About screen, Play Console and the page's
own canonical all hold. `wrangler.jsonc` sets `html_handling: "none"`, which
also stops `/chromis/` finding `index.html`, so `website/_redirects` rewrites
the home page back and redirects the extensionless spellings GitHub Pages used
to answer. The deploy moves `_redirects` to the root of the upload - the only
place Cloudflare reads it - and ends by asking the live site whether the home
page, policy and terms each answer 200 from Cloudflare.

**The site has both themes, because the app does**, and the palette is the app's
neutral one rather than the mockup's navy - a landing page whose job is to look
like the product cannot be a shade the product refuses. It follows
`prefers-color-scheme` and a header toggle pins either, which is the app's
System / Light / Dark. Four things in there that a redesign would break:

- **"System" is the ABSENCE of `data-theme` on `<html>`**, not a third value, so
  the media query stays in charge and a visitor who never touched the toggle has
  nothing stored about them. Same rule as the app's `themeMode` key, which is
  removed rather than written as null.
- **The light block is written twice** - once under the media query, once as
  `:root[data-theme="light"]`. `light-dark()` folds them into one and is the
  obvious cleanup, but in a browser that does not know that function *every*
  custom property resolves to nothing: an unstyled page, not a stale-looking one.
- **`data-theme` is applied by an inline script in the `<head>`**, before the
  stylesheet. The script at the end of the body is a frame too late and a pinned
  theme flashes the other one first.
- **A label pill drawn ON a photograph is OPAQUE (`--pill`), not glass.** A
  photo has no theme - the same reason `AppScrim` exists in the app - and a
  *translucent* pill's effective background is whatever the photo is behind it,
  so its contrast is unknowable: measured, accent text on the old 66%/72% glass
  ran from 9.7:1 down to 2.4:1 and failed in BOTH themes. `--glass-strong`
  survives for the sticky header alone, which sits on the page's own colour.
- **`--border` and `--border-ui` are two tokens because WCAG 1.4.11 governs only
  the second.** A card hairline at 1.3:1 is fine; the edge that tells you where a
  text field is must reach 3:1.

**The site contacts nobody until consent.** The two typefaces were being pulled
from `fonts.googleapis.com` on every page load - before the cookie banner and
whatever the visitor answered it - which on a privacy-branded page was the one
request a Decline could not stop. `tool/gen_web_fonts.py` subsets them out of
`assets/fonts/` (already in the repo, OFL, redistribution permitted) to 57 KB of
self-hosted woff2. Keep it that way: anything new that reaches another host is
either gated behind consent or self-hosted, and `privacy.html` states the
guarantee.

The screenshots and the AI example images are **generated from the same capture
session and the same CC0 photographs as the Play listing** (`tool/gen_screens.py`
reads `build/shots-i18n/`, `tool/gen_effects.py` reads `assets/store/samples/`).
A landing page is commercial use of every pixel on it exactly as a listing is;
these used to be personal photos out of a gitignored directory, which also meant
a fresh clone could not regenerate them.

**`website/sitemap.xml` is hand-maintained and must always be correct.** Unlike
the other IDCT sites - helena and gentastic generate theirs from a Liquid loop,
nuts uses `jekyll-sitemap` - this one is a literal list, so it is the only one
that goes stale on its own. Adding, renaming or deleting a page in `website/`
means editing `sitemap.xml` **in the same change**. The site workflow checks
that every page's canonical is its own URL and that the sitemap lists exactly
those, and refuses to deploy otherwise - which on `main` means the site stays at
its previous version until the sitemap is fixed.

It is not just this site's sitemap. `idct.tech/sitemap.xml` is a sitemap *index*
(repo `ideaconnect/ideaconnect.github.io`) that references this file directly and
is submitted to Google Search Console - so if this file 404s or goes malformed,
it is a hard error against the whole domain, not just `/chromis/`.

Two rules that go with it:

- **Every page needs a `<link rel="canonical">`, and it must match its `<loc>`
  here exactly.** `/chromis/` and `/chromis/index.html` both answer 200, so
  without a canonical the home page can be indexed twice. The canonical for the
  home page is the bare directory, `https://idct.tech/chromis/`, not
  `index.html`.
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
