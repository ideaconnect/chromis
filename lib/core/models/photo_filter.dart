/// One-tap photo looks, in the vein of the filter strips every social photo app
/// ships. Each is a pure color transform - see `ColorMatrix.filter` for the
/// matrices - so applying one costs nothing at render time and stays fully
/// reversible: the source pixels are never touched.
///
/// Names are deliberately our own. They describe the look rather than borrowing
/// another app's filter names, which are trademarks.
enum PhotoFilter {
  none('Original'),
  vivid('Vivid'),
  punch('Punch'),
  chrome('Chrome'),
  warm('Warm'),
  cool('Cool'),
  sunset('Sunset'),
  dawn('Dawn'),
  dusk('Dusk'),
  fade('Fade'),
  matte('Matte'),
  retro('Retro'),
  sepia('Sepia'),
  mono('Mono'),
  noir('Noir');

  const PhotoFilter(this.label);

  /// Shown under the filter's thumbnail in the Effects panel.
  final String label;

  static PhotoFilter fromName(String? name) =>
      values.firstWhere((f) => f.name == name, orElse: () => PhotoFilter.none);
}
