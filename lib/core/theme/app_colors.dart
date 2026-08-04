import 'package:flutter/material.dart';

/// The fixed brand hues, for the places a colour is **data** rather than
/// chrome.
///
/// There is exactly one such place: the swatch rows in the Text and Bubble
/// panels, and the fills they write into a layer. Those must not follow the
/// theme - a project saved with an amber caption has to export amber next
/// year, in whichever theme the user happens to be in, or the same document
/// would render two different images. They are stored in the manifest as ARGB
/// ints, so a value here is effectively frozen once shipped.
///
/// **Everything else reads `context.colors`** ([AppPalette]). If you are about
/// to reference this class from a widget's decoration, text style or icon, that
/// is the bug this file exists to prevent: it will be right in dark and wrong
/// in light. The one legitimate consumer outside the swatch rows is
/// `TextCaption.resolveStrokeColor`, which compares a *stored* fill against
/// [amber] to pick a contrasting outline.
abstract final class AppColors {
  AppColors._();

  static const Color violet = Color(0xFF8FA0F5);
  static const Color cyan = Color(0xFF17B6D6);
  static const Color pink = Color(0xFFE87896);
  static const Color amber = Color(0xFFE6B84A);
  static const Color green = Color(0xFF35D0A0);
  static const Color orange = Color(0xFFF0885A);
  static const Color rose = Color(0xFFF08AA0);

  /// The swatch row offered for a caption fill or a bubble fill/outline, in
  /// display order. `_colorNames` in the editor names these positionally for a
  /// screen reader - the two lists have to stay in step.
  static const List<Color> swatches = [
    Colors.white,
    Color(0xFF111111),
    pink,
    amber,
    green,
    cyan,
    violet,
    rose,
    orange,
  ];
}
