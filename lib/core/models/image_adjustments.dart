import 'package:flutter/foundation.dart';

import 'photo_filter.dart';

/// Per-image color adjustments driven by the Adjust and Effects tools.
/// Multiplicative factors are expressed as `1.0 == 100%` (matching the design's
/// sliders); [hue] is a rotation in degrees (-180…180).
///
/// [filter] and [hdr] live here rather than in `LayerEffects` because they are
/// pixel transforms of the photo itself, and because folding them into the same
/// color matrix as the sliders means a filtered, HDR-boosted, hue-shifted photo
/// still costs exactly one [ColorFilter] at draw time.
@immutable
class ImageAdjustments {
  const ImageAdjustments({
    this.brightness = 1.0,
    this.contrast = 1.0,
    this.saturation = 1.0,
    this.hue = 0.0,
    this.filter = PhotoFilter.none,
    this.filterStrength = 1.0,
    this.hdr = 0.0,
  });

  final double brightness;
  final double contrast;
  final double saturation;
  final double hue;

  /// A one-tap look applied *before* the manual sliders, so tweaking Brightness
  /// still behaves the way it does on an unfiltered photo.
  final PhotoFilter filter;

  /// How much of [filter] to mix in (0 = off, 1 = full).
  final double filterStrength;

  /// Tone-maps the photo the way a phone's HDR mode does: lifted shadows,
  /// held-back highlights, and a local-contrast pass that makes texture pop.
  /// 0 disables it. The local-contrast half is not a matrix - see
  /// `paintImageLayer` - so this field is read by the painters too.
  final double hdr;

  static const ImageAdjustments identity = ImageAdjustments();

  bool get isIdentity => this == identity;

  /// Whether the color matrix alone describes this adjustment. False when the
  /// HDR local-contrast pass is needed on top.
  bool get isMatrixOnly => hdr <= 0.001;

  /// Whether [filter] contributes anything.
  bool get hasFilter => filter != PhotoFilter.none && filterStrength > 0.001;

  ImageAdjustments copyWith({
    double? brightness,
    double? contrast,
    double? saturation,
    double? hue,
    PhotoFilter? filter,
    double? filterStrength,
    double? hdr,
  }) {
    return ImageAdjustments(
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      saturation: saturation ?? this.saturation,
      hue: hue ?? this.hue,
      filter: filter ?? this.filter,
      filterStrength: filterStrength ?? this.filterStrength,
      hdr: hdr ?? this.hdr,
    );
  }

  /// Only the manual sliders, cleared - the filter and HDR survive. Used by the
  /// Adjust panel's Reset, which should not silently drop the chosen look.
  ImageAdjustments resetSliders() => ImageAdjustments(
    filter: filter,
    filterStrength: filterStrength,
    hdr: hdr,
  );

  Map<String, dynamic> toJson() => {
    'brightness': brightness,
    'contrast': contrast,
    'saturation': saturation,
    'hue': hue,
    // Written only when set, so manifests of photos with no look are unchanged.
    if (filter != PhotoFilter.none) 'filter': filter.name,
    if (filter != PhotoFilter.none) 'filterStrength': filterStrength,
    if (hdr != 0) 'hdr': hdr,
  };

  factory ImageAdjustments.fromJson(Map<String, dynamic> json) {
    return ImageAdjustments(
      brightness: (json['brightness'] as num?)?.toDouble() ?? 1.0,
      contrast: (json['contrast'] as num?)?.toDouble() ?? 1.0,
      saturation: (json['saturation'] as num?)?.toDouble() ?? 1.0,
      hue: (json['hue'] as num?)?.toDouble() ?? 0.0,
      filter: PhotoFilter.fromName(json['filter'] as String?),
      filterStrength: (json['filterStrength'] as num?)?.toDouble() ?? 1.0,
      hdr: (json['hdr'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ImageAdjustments &&
      other.brightness == brightness &&
      other.contrast == contrast &&
      other.saturation == saturation &&
      other.hue == hue &&
      other.filter == filter &&
      other.filterStrength == filterStrength &&
      other.hdr == hdr;

  @override
  int get hashCode => Object.hash(
    brightness,
    contrast,
    saturation,
    hue,
    filter,
    filterStrength,
    hdr,
  );
}
