import 'package:flutter/material.dart';

/// The editor tools, each with its own accent color.
enum ToolAccent { layers, adjust, text, erase, cutout, frames, grid, effects }

/// Every semantic colour in the app, in one object per theme.
///
/// Read it from the widget tree - `context.colors.textMuted` - never as a
/// constant. Two instances exist, [dark] and [light], and which one a widget
/// gets is a runtime decision (the device's setting, or the user's override in
/// Settings). See `AppTokens`, which carries this through the [Theme].
///
/// ## Why two, and why neutral
///
/// The original palette was a deep navy (`#0A1826` and friends) taken from the
/// mockup. It was a bad fit at both ends of the market this ships to: on an
/// AMOLED panel a navy surface lights every pixel, so it costs battery and
/// shows none of the perfect black the panel can do; on an IPS panel the same
/// navy greys out under any daylight, and IPS users mostly run their phone
/// light anyway. Neither audience was served by a colour that was really just
/// decoration. The surfaces are neutral now: [dark] bottoms out at true black,
/// [light] tops out at white.
///
/// ## What varies and what does not
///
/// Surfaces, text and hairlines flip. The **accents do too**, but only in
/// value: the brand hues are mid-tone, which reads on black and washes out on
/// white, so [light] carries darkened variants that clear 4.5:1 against its own
/// surfaces. That is what makes [onAccent] work as one token - a filled accent
/// button is bright-on-dark-ink in [dark] and deep-on-white-ink in [light], and
/// callers need not know which.
///
/// **Document colours are NOT in here.** The text and bubble swatch rows, and
/// the fills they write into a saved project, stay fixed constants in
/// `AppColors`: a saved project must render the same whichever theme the user
/// is in, or exporting the same file twice would produce two different images.
/// Chrome that sits ON the user's photo rather than on one of our surfaces:
/// the "removing background" overlay, the frame badges, the crop dim, the
/// selection knobs' outlines.
///
/// Fixed in both themes, and that is the point - a photo has no theme, so
/// there is nothing for these to follow. Reading them from [AppPalette] is the
/// mistake this class exists to prevent: the light theme's ink is near-black,
/// and near-black on a 70% dark scrim is a label nobody can read. Judge these
/// against the scrim, not against the app.
abstract final class AppScrim {
  AppScrim._();

  /// The dim laid over a photo while something is happening to it.
  static const Color fill = Color(0xB2101013);

  /// The same, for a small badge that has to stay legible over a busy
  /// thumbnail.
  static const Color fillStrong = Color(0xCC101013);

  /// A hard outline that separates a knob or handle from the photo under it.
  static const Color outline = Color(0xFF101013);

  static const Color ink = Color(0xFFF1F2F4);
  static const Color inkMuted = Color(0xFFB6BAC2);

  /// The Frames accent at its dark-theme value, because the badge it labels is
  /// always dark.
  static const Color accent = Color(0xFFF0885A);

  /// The live erase stroke, drawn under the finger while it moves.
  ///
  /// An `AppScrim` colour for the usual reason - it is painted on the user's
  /// photo, which has no theme - and blue for a second one: the selection frame
  /// is `context.colors.cyan` and the snap guides are magenta, both on screen
  /// during a stroke, so the trail needs a hue that is neither. Semi-transparent
  /// because it is a promise about pixels that are still there, not a claim that
  /// they are already gone - but only just. Checked on the device rather than
  /// picked: at 44% over a mid-tone photo it desaturated into slate grey and
  /// stopped reading as a colour at all. 60% still shows the photo through it
  /// and is unmistakably blue.
  static const Color brush = Color(0x994D9BFF);
}

@immutable
class AppPalette {
  const AppPalette({
    required this.brightness,
    required this.pageBackground,
    required this.background,
    required this.chrome,
    required this.panel,
    required this.card,
    required this.cardAlt,
    required this.inputField,
    required this.chipSurface,
    required this.elevated,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textFaint,
    required this.border,
    required this.borderFaint,
    required this.borderStrong,
    required this.onAccent,
    required this.neutralButton,
    required this.checkerBase,
    required this.checkerTile,
    required this.shadow,
    required this.violet,
    required this.cyan,
    required this.pink,
    required this.amber,
    required this.green,
    required this.orange,
    required this.gold,
    required this.violetBright,
    required this.violetLight,
    required this.magenta,
    required this.greenLight,
    required this.teal,
    required this.rose,
  });

  final Brightness brightness;

  bool get isLight => brightness == Brightness.light;

  // Surfaces, darkest to lightest in [dark] and the reverse in [light].
  final Color pageBackground;
  final Color background;

  /// The editor's own chrome - the tool panel and the landscape rail. It is the
  /// PAGE's colour, which is the whole point: those are the largest persistent
  /// surfaces in the app, so on an AMOLED panel they are the pixels worth
  /// switching off, and on an IPS panel they are the ones that must not read as
  /// grey. It can be, because it sits directly on the page with a hairline
  /// along its edge.
  ///
  /// [panel] cannot, and that is why these are two tokens rather than one. A
  /// sheet or a dialog floats over a scrim, and a scrim over black is still
  /// black - a pure-black sheet would have no edge at all. It stays one step
  /// off the page so it reads as something laid on top.
  final Color chrome;

  final Color panel;
  final Color card;
  final Color cardAlt;
  final Color inputField;
  final Color chipSurface;

  /// Lifted off the surface behind it: a grab handle, the inactive page dot, a
  /// disabled button's fill, the plate behind a layer badge. In [light] this is
  /// a step DOWN from white rather than up - a raised thing on a white card can
  /// only be seen by being darker.
  final Color elevated;

  // Text.
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textFaint;

  // Hairline borders. Translucent, so they sit on any surface: white in [dark],
  // black in [light].
  final Color border;
  final Color borderFaint;

  /// The heavier ring - an unselected swatch, the drop placeholder, a frame
  /// thumbnail. These are drawn over content rather than over a surface, so
  /// they need more than a hairline to stay visible.
  final Color borderStrong;

  /// Ink on top of a filled accent (a `GradientButton`, a primary
  /// `ElevatedButton`, the cut-out gradient). Near-black on [dark]'s bright
  /// accents, white on [light]'s deep ones.
  final Color onAccent;

  /// The un-accented fill for a secondary/"already done" button.
  final Color neutralButton;

  /// The transparency checkerboard behind a canvas or thumbnail. Two steps
  /// apart and low-contrast on purpose - it has to read as "nothing here"
  /// without competing with the photo on top of it.
  final Color checkerBase;
  final Color checkerTile;

  /// The drop shadow under the canvas and the toast. A dark theme can afford a
  /// heavy one because it reads as depth against black; the same 50% black on a
  /// white page reads as dirt, so [light] uses a tenth of it.
  final Color shadow;

  // Accents - each editor tool owns one.
  final Color violet; // Layers
  final Color cyan; // Adjust / selection / primary
  final Color pink; // Text / object
  final Color amber; // Erase
  final Color green; // AI Cut / background removed
  final Color orange; // Frames

  /// Go Pro. Deliberately not [amber], which is the Erase tool's accent - the
  /// crown has to read as a badge rather than as another tool.
  final Color gold;

  // Accent support tints.
  final Color violetBright; // primary glow
  final Color violetLight; // light cyan
  final Color magenta; // hero-gradient midpoint
  final Color greenLight;
  final Color teal;
  final Color rose; // destructive

  List<Color> get heroGradient => [violetBright, magenta, pink];
  List<Color> get cutoutGradient => [green, teal];
  List<Color> get logoGradient => [cyan, pink];

  Map<ToolAccent, Color> get accents => {
    ToolAccent.layers: violet,
    ToolAccent.adjust: cyan,
    ToolAccent.text: pink,
    ToolAccent.erase: amber,
    ToolAccent.cutout: green,
    ToolAccent.frames: orange,
    ToolAccent.grid: violet,
    ToolAccent.effects: teal,
  };

  Color accent(ToolAccent a) => accents[a]!;

  /// True black wherever the page is, so an AMOLED panel can switch those
  /// pixels off, with neutral greys above it only for things that float. That
  /// now includes the editor's tool panel ([chrome]), which is the largest
  /// persistent surface in the app and was the last big grey field left.
  /// Nothing is tinted: a photo editor's chrome should not push a colour cast
  /// onto the image it is framing.
  static const AppPalette dark = AppPalette(
    brightness: Brightness.dark,
    pageBackground: Color(0xFF000000),
    background: Color(0xFF000000),
    chrome: Color(0xFF000000),
    panel: Color(0xFF101013),
    card: Color(0xFF121215),
    cardAlt: Color(0xFF1A1A1F),
    inputField: Color(0xFF1A1A1F),
    chipSurface: Color(0xFF1A1A1F),
    elevated: Color(0xFF24242B),
    textPrimary: Color(0xFFF1F2F4),
    textSecondary: Color(0xFFB6BAC2),
    textMuted: Color(0xFF8C919B),
    textFaint: Color(0xFF6E7480),
    // A step up from where these were. With the page, the chrome and the dock
    // all at the same black, the hairline IS the edge - there is no longer a
    // fill difference behind it doing half the work.
    border: Color(0x1FFFFFFF), // ~12% white
    borderFaint: Color(0x17FFFFFF), // ~9% white
    borderStrong: Color(0x3DFFFFFF), // ~24% white
    onAccent: Color(0xFF08090C),
    neutralButton: Color(0xFF1A1A1F),
    checkerBase: Color(0xFF1B1B20),
    checkerTile: Color(0xFF24242B),
    shadow: Color(0x80000000),
    violet: Color(0xFF8FA0F5),
    cyan: Color(0xFF17B6D6),
    pink: Color(0xFFE87896),
    amber: Color(0xFFE6B84A),
    green: Color(0xFF35D0A0),
    orange: Color(0xFFF0885A),
    gold: Color(0xFFF3C33C),
    violetBright: Color(0xFF17B6D6),
    violetLight: Color(0xFF7FD6EA),
    magenta: Color(0xFF6C7FE0),
    greenLight: Color(0xFF6EE7C4),
    teal: Color(0xFF22D3EE),
    rose: Color(0xFFF08AA0),
  );

  /// Pure white pages, not the light grey every other Android app uses.
  ///
  /// The grey was the safe choice and the wrong one here: IPS is the panel this
  /// theme exists for, and a 94%-white field is exactly what an IPS panel turns
  /// muddy the moment there is daylight on it - the greys wash together and the
  /// whole app reads dirty. White has nowhere to fall to. It also means a photo
  /// is no longer the brightest thing on screen, which is the trade: the app
  /// gets its structure from hairlines and recessed controls instead of from a
  /// step in surface brightness.
  ///
  /// That is why [inputField] is NOT white any more. On a grey page a white
  /// field read as a field by being brighter than everything around it; on a
  /// white page the same colour is invisible, so it has to recede instead.
  ///
  /// The accents are the same hues at roughly half the luminance. They were
  /// picked against white, not eyeballed: each clears 4.5:1 there, which is
  /// what lets the same token be an icon, a border and a button fill.
  static const AppPalette light = AppPalette(
    brightness: Brightness.light,
    pageBackground: Color(0xFFFFFFFF),
    background: Color(0xFFFFFFFF),
    chrome: Color(0xFFFFFFFF),
    panel: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    cardAlt: Color(0xFFEDEFF4),
    inputField: Color(0xFFF2F4F8),
    chipSurface: Color(0xFFECEEF3),
    elevated: Color(0xFFE4E7EC),
    textPrimary: Color(0xFF14161A),
    textSecondary: Color(0xFF4A515B),
    textMuted: Color(0xFF5F656E),
    textFaint: Color(0xFF7B828D),
    // Stronger than they were, for the same reason as [dark]'s: a white card on
    // a white page has only its hairline to say where it ends.
    border: Color(0x29000000), // ~16% black
    borderFaint: Color(0x1F000000), // ~12% black
    borderStrong: Color(0x4D000000), // ~30% black
    onAccent: Color(0xFFFFFFFF),
    neutralButton: Color(0xFFE3E6EC),
    checkerBase: Color(0xFFE2E5EA),
    checkerTile: Color(0xFFF1F3F6),
    shadow: Color(0x1F000000),
    violet: Color(0xFF4C5AC0),
    cyan: Color(0xFF0C7A90),
    pink: Color(0xFFB94765),
    amber: Color(0xFF8A6510),
    green: Color(0xFF0F7A5A),
    orange: Color(0xFFB94D1D),
    gold: Color(0xFF8F6704),
    violetBright: Color(0xFF0C7A90),
    violetLight: Color(0xFF27738A),
    magenta: Color(0xFF5060C6),
    greenLight: Color(0xFF0E7F5F),
    teal: Color(0xFF0D7490),
    rose: Color(0xFFBE3A57),
  );

  /// Crossfades two palettes. Only ever called with [dark] and [light] (a theme
  /// switch), so the halfway frame is a legitimate mid-grey rather than a
  /// nonsense colour.
  static AppPalette lerp(AppPalette a, AppPalette b, double t) {
    if (identical(a, b)) return a;
    Color c(Color x, Color y) => Color.lerp(x, y, t)!;
    return AppPalette(
      brightness: t < 0.5 ? a.brightness : b.brightness,
      pageBackground: c(a.pageBackground, b.pageBackground),
      background: c(a.background, b.background),
      chrome: c(a.chrome, b.chrome),
      panel: c(a.panel, b.panel),
      card: c(a.card, b.card),
      cardAlt: c(a.cardAlt, b.cardAlt),
      inputField: c(a.inputField, b.inputField),
      chipSurface: c(a.chipSurface, b.chipSurface),
      elevated: c(a.elevated, b.elevated),
      textPrimary: c(a.textPrimary, b.textPrimary),
      textSecondary: c(a.textSecondary, b.textSecondary),
      textMuted: c(a.textMuted, b.textMuted),
      textFaint: c(a.textFaint, b.textFaint),
      border: c(a.border, b.border),
      borderFaint: c(a.borderFaint, b.borderFaint),
      borderStrong: c(a.borderStrong, b.borderStrong),
      onAccent: c(a.onAccent, b.onAccent),
      neutralButton: c(a.neutralButton, b.neutralButton),
      checkerBase: c(a.checkerBase, b.checkerBase),
      checkerTile: c(a.checkerTile, b.checkerTile),
      shadow: c(a.shadow, b.shadow),
      violet: c(a.violet, b.violet),
      cyan: c(a.cyan, b.cyan),
      pink: c(a.pink, b.pink),
      amber: c(a.amber, b.amber),
      green: c(a.green, b.green),
      orange: c(a.orange, b.orange),
      gold: c(a.gold, b.gold),
      violetBright: c(a.violetBright, b.violetBright),
      violetLight: c(a.violetLight, b.violetLight),
      magenta: c(a.magenta, b.magenta),
      greenLight: c(a.greenLight, b.greenLight),
      teal: c(a.teal, b.teal),
      rose: c(a.rose, b.rose),
    );
  }
}
