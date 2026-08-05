/// The erase brush's size range, in 512-logical canvas units.
///
/// One home, for the same reason `layer_scale_curve.dart` holds the scale
/// range: the slider that sets the value, the state that stores it and the
/// overlay that draws the stroke at that width all have to agree, and three
/// literals with a comment saying to change all three is a rule no compiler
/// enforces. A trail drawn at a width the brush does not use is worse than no
/// trail, because it teaches the wrong thing about where the pixels will go.
library;

const double kMinBrushSize = 8;
const double kMaxBrushSize = 120;
const double kDefaultBrushSize = 40;
