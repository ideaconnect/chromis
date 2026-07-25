import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// How a layer composites onto everything already drawn beneath it - the
/// Photoshop / GIMP layer-mode list, restricted to the modes Skia implements
/// identically on every backend.
///
/// The enum exists so the persisted name is ours (a saved project must not
/// depend on Flutter's [BlendMode] index order) and so the panel has a label to
/// show without a switch at the call site.
enum LayerBlend {
  normal('Normal', BlendMode.srcOver),
  multiply('Multiply', BlendMode.multiply),
  screen('Screen', BlendMode.screen),
  overlay('Overlay', BlendMode.overlay),
  darken('Darken', BlendMode.darken),
  lighten('Lighten', BlendMode.lighten),
  colorDodge('Dodge', BlendMode.colorDodge),
  colorBurn('Burn', BlendMode.colorBurn),
  hardLight('Hard light', BlendMode.hardLight),
  softLight('Soft light', BlendMode.softLight),
  difference('Difference', BlendMode.difference),
  exclusion('Exclusion', BlendMode.exclusion),
  hue('Hue', BlendMode.hue),
  saturation('Saturation', BlendMode.saturation),
  color('Color', BlendMode.color),
  luminosity('Luminosity', BlendMode.luminosity);

  const LayerBlend(this.label, this.mode);

  final String label;

  /// The Skia mode this maps to.
  final BlendMode mode;

  bool get isNormal => this == LayerBlend.normal;

  static LayerBlend fromName(String? name) =>
      values.firstWhere((b) => b.name == name, orElse: () => LayerBlend.normal);
}

/// A drop shadow cast by a layer's own silhouette - the alpha of the photo (or
/// its cut-out mask), the glyphs of a caption, the outline of a bubble.
///
/// [angle] is measured in degrees clockwise from "east", so 90° drops the
/// shadow straight down, matching how the panel's dial reads. The offset lives
/// in **layer space**: it rotates and scales with the layer, so a rotated
/// sticker keeps its shadow glued to it instead of sliding out from under it.
@immutable
class LayerShadow {
  const LayerShadow({
    this.enabled = false,
    this.angle = 90,
    this.distance = 14,
    this.blur = 10,
    this.density = 0,
    this.color = const Color(0xFF000000),
    this.opacity = 0.45,
  });

  final bool enabled;

  /// Degrees clockwise from east (90 = straight down).
  final double angle;

  /// Distance from the layer, in canvas-logical px.
  final double distance;

  /// Gaussian sigma, in canvas-logical px. 0 = a hard-edged shadow.
  final double blur;

  /// How far the silhouette is thickened before blurring, in canvas-logical px
  /// (Photoshop calls this "spread"). Turns a soft haze into a solid slab.
  final double density;

  final Color color;

  /// 0.0 … 1.0
  final double opacity;

  static const LayerShadow none = LayerShadow();

  /// Whether this shadow contributes any pixels.
  bool get isVisible => enabled && opacity > 0.001;

  /// The shadow's offset in canvas-logical px, from [angle] and [distance].
  Offset get offset {
    final rad = angle * math.pi / 180.0;
    return Offset(math.cos(rad) * distance, math.sin(rad) * distance);
  }

  LayerShadow copyWith({
    bool? enabled,
    double? angle,
    double? distance,
    double? blur,
    double? density,
    Color? color,
    double? opacity,
  }) {
    return LayerShadow(
      enabled: enabled ?? this.enabled,
      angle: angle ?? this.angle,
      distance: distance ?? this.distance,
      blur: blur ?? this.blur,
      density: density ?? this.density,
      color: color ?? this.color,
      opacity: opacity ?? this.opacity,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'angle': angle,
    'distance': distance,
    'blur': blur,
    'density': density,
    'color': color.toARGB32(),
    'opacity': opacity,
  };

  factory LayerShadow.fromJson(Map<String, dynamic> json) => LayerShadow(
    enabled: json['enabled'] as bool? ?? false,
    angle: (json['angle'] as num?)?.toDouble() ?? 90,
    distance: (json['distance'] as num?)?.toDouble() ?? 14,
    blur: (json['blur'] as num?)?.toDouble() ?? 10,
    density: (json['density'] as num?)?.toDouble() ?? 0,
    color: Color(json['color'] as int? ?? 0xFF000000),
    opacity: (json['opacity'] as num?)?.toDouble() ?? 0.45,
  );

  @override
  bool operator ==(Object other) =>
      other is LayerShadow &&
      other.enabled == enabled &&
      other.angle == angle &&
      other.distance == distance &&
      other.blur == blur &&
      other.density == density &&
      other.color == color &&
      other.opacity == opacity;

  @override
  int get hashCode =>
      Object.hash(enabled, angle, distance, blur, density, color, opacity);
}

/// A solid contour drawn behind a layer, grown out of its own silhouette - the
/// sticker "die-cut" border. For a plain photo the silhouette is the photo's
/// rectangle, so the stroke reads as a picture frame; for a cut-out it hugs the
/// subject.
@immutable
class LayerStroke {
  const LayerStroke({
    this.width = 0,
    this.color = const Color(0xFFFFFFFF),
    this.opacity = 1.0,
  });

  /// Thickness in canvas-logical px, before the layer's own zoom - the contour
  /// belongs to the layer, so it grows and shrinks with it.  0 disables it.
  final double width;

  final Color color;

  /// 0.0 … 1.0
  final double opacity;

  static const LayerStroke none = LayerStroke();

  bool get isVisible => width > 0.01 && opacity > 0.001;

  LayerStroke copyWith({double? width, Color? color, double? opacity}) =>
      LayerStroke(
        width: width ?? this.width,
        color: color ?? this.color,
        opacity: opacity ?? this.opacity,
      );

  Map<String, dynamic> toJson() => {
    'width': width,
    'color': color.toARGB32(),
    'opacity': opacity,
  };

  factory LayerStroke.fromJson(Map<String, dynamic> json) => LayerStroke(
    width: (json['width'] as num?)?.toDouble() ?? 0,
    color: Color(json['color'] as int? ?? 0xFFFFFFFF),
    opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
  );

  @override
  bool operator ==(Object other) =>
      other is LayerStroke &&
      other.width == width &&
      other.color == color &&
      other.opacity == opacity;

  @override
  int get hashCode => Object.hash(width, color, opacity);
}

/// A darkened (or tinted) falloff towards the edges of a photo. Painted inside
/// the layer's own alpha, so a cut-out subject gets a vignette shaped like the
/// subject rather than a rectangle floating behind it.
@immutable
class Vignette {
  const Vignette({
    this.amount = 0,
    this.color = const Color(0xFF000000),
    this.size = 0.55,
    this.softness = 0.5,
  });

  /// Peak opacity at the corners. 0 disables the vignette.
  final double amount;

  /// Any color - a black vignette is the classic, a white one blooms the edges.
  final Color color;

  /// Where the falloff starts, as a fraction of the half-diagonal. Bigger = a
  /// wider clear centre.
  final double size;

  /// 0 = an abrupt ring, 1 = a long gradual fade.
  final double softness;

  static const Vignette none = Vignette();

  bool get isVisible => amount > 0.001;

  Vignette copyWith({
    double? amount,
    Color? color,
    double? size,
    double? softness,
  }) => Vignette(
    amount: amount ?? this.amount,
    color: color ?? this.color,
    size: size ?? this.size,
    softness: softness ?? this.softness,
  );

  Map<String, dynamic> toJson() => {
    'amount': amount,
    'color': color.toARGB32(),
    'size': size,
    'softness': softness,
  };

  factory Vignette.fromJson(Map<String, dynamic> json) => Vignette(
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
    color: Color(json['color'] as int? ?? 0xFF000000),
    size: (json['size'] as num?)?.toDouble() ?? 0.55,
    softness: (json['softness'] as num?)?.toDouble() ?? 0.5,
  );

  @override
  bool operator ==(Object other) =>
      other is Vignette &&
      other.amount == amount &&
      other.color == color &&
      other.size == size &&
      other.softness == softness;

  @override
  int get hashCode => Object.hash(amount, color, size, softness);
}

/// The effects every layer type shares: how it blends down, the shadow it
/// casts, and the contour drawn around it. Photo-only effects (filters, HDR,
/// vignette) hang off [ImageLayer] instead, because they describe pixels rather
/// than compositing.
///
/// Carried as ONE field on the sealed [Layer] base so adding an effect touches
/// one class instead of three, and serialized only when non-default so existing
/// project manifests stay byte-identical.
@immutable
class LayerEffects {
  const LayerEffects({
    this.blend = LayerBlend.normal,
    this.shadow = LayerShadow.none,
    this.stroke = LayerStroke.none,
  });

  final LayerBlend blend;
  final LayerShadow shadow;
  final LayerStroke stroke;

  static const LayerEffects none = LayerEffects();

  bool get isNone => this == none;

  LayerEffects copyWith({
    LayerBlend? blend,
    LayerShadow? shadow,
    LayerStroke? stroke,
  }) => LayerEffects(
    blend: blend ?? this.blend,
    shadow: shadow ?? this.shadow,
    stroke: stroke ?? this.stroke,
  );

  Map<String, dynamic> toJson() => {
    if (!blend.isNormal) 'blend': blend.name,
    if (shadow != LayerShadow.none) 'shadow': shadow.toJson(),
    if (stroke != LayerStroke.none) 'stroke': stroke.toJson(),
  };

  factory LayerEffects.fromJson(Map<String, dynamic> json) => LayerEffects(
    blend: LayerBlend.fromName(json['blend'] as String?),
    shadow: json['shadow'] == null
        ? LayerShadow.none
        : LayerShadow.fromJson((json['shadow'] as Map).cast<String, dynamic>()),
    stroke: json['stroke'] == null
        ? LayerStroke.none
        : LayerStroke.fromJson((json['stroke'] as Map).cast<String, dynamic>()),
  );

  @override
  bool operator ==(Object other) =>
      other is LayerEffects &&
      other.blend == blend &&
      other.shadow == shadow &&
      other.stroke == stroke;

  @override
  int get hashCode => Object.hash(blend, shadow, stroke);
}
