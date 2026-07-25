import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'image_adjustments.dart';
import 'layer_effects.dart';
import 'layer_transform.dart';

/// A single element on a canvas: an image or a text caption. (Comic bubbles
/// arrive as a third variant in M3.) Layers are immutable; edits produce a new
/// instance via `copyWith`.
@immutable
sealed class Layer {
  const Layer({
    required this.id,
    required this.name,
    required this.transform,
    this.visible = true,
    this.opacity = 1.0,
    this.cellId,
    this.effects = LayerEffects.none,
  });

  final String id;
  final String name;
  final LayerTransform transform;
  final bool visible;

  /// 0.0 … 1.0
  final double opacity;

  /// Which Photo Grid cell this layer lives in (see `GridSpec`), or null for a
  /// **free** layer - drawn above the whole grid, unclipped, so a caption can
  /// span the collage. Always null in an ordinary (non-collage) project.
  final String? cellId;

  /// Blend mode, drop shadow and contour - the effects every layer type shares.
  final LayerEffects effects;

  /// Discriminator written into JSON.
  String get type;

  Map<String, dynamic> toJson();

  /// Base fields shared by every layer variant. `cellId` and `effects` are
  /// written only when set, so manifests of projects that use neither are
  /// unchanged.
  Map<String, dynamic> baseJson() => {
    'type': type,
    'id': id,
    'name': name,
    'transform': transform.toJson(),
    'visible': visible,
    'opacity': opacity,
    if (cellId != null) 'cellId': cellId,
    if (!effects.isNone) 'effects': effects.toJson(),
  };

  /// Reads the shared [effects] block, absent in pre-effects manifests.
  static LayerEffects effectsFromJson(Object? json) => json == null
      ? LayerEffects.none
      : LayerEffects.fromJson((json as Map).cast<String, dynamic>());

  factory Layer.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    return switch (type) {
      'image' => ImageLayer.fromJson(json),
      'text' => TextLayer.fromJson(json),
      'bubble' => BubbleLayer.fromJson(json),
      _ => throw FormatException('Unknown layer type: $type'),
    };
  }
}

/// Comic speech-bubble shapes. `caption` is a tail-less rounded box for
/// narration; `whisper` is a speech bubble with a dashed outline (#80).
enum BubbleShape { speech, thought, shout, caption, whisper }

/// A photo layer, optionally with an alpha mask (from AI cut-out / manual
/// erase) and per-image color adjustments.
final class ImageLayer extends Layer {
  const ImageLayer({
    required super.id,
    required super.name,
    required this.assetPath,
    super.transform = LayerTransform.identity,
    super.visible = true,
    super.opacity = 1.0,
    super.cellId,
    super.effects,
    this.maskPath,
    this.adjustments = ImageAdjustments.identity,
    this.vignette = Vignette.none,
    this.cropRect = const Rect.fromLTRB(0, 0, 1, 1),
  });

  /// Absolute path to the source image, copied into the app's assets dir by
  /// ImageImportService.
  final String assetPath;

  /// Absolute path to the 8-bit alpha mask (written by MaskStore), if the
  /// background has been removed or manually erased.
  final String? maskPath;

  final ImageAdjustments adjustments;

  /// Edge falloff painted inside the photo's own alpha.
  final Vignette vignette;

  /// The visible sub-rectangle of the source image, in normalized (0..1) image
  /// coordinates. Defaults to the whole image; a per-layer crop shrinks it.
  final Rect cropRect;

  /// Whether a non-trivial per-layer crop is applied.
  bool get isCropped => cropRect != const Rect.fromLTRB(0, 0, 1, 1);

  /// Whether this photo needs the painter path rather than a plain cached
  /// `Image.file`: a mask, a source crop, or any effect that has to reach the
  /// pixels (vignette, HDR's local-contrast pass, a contour stroke).
  bool get needsPainter =>
      maskPath != null ||
      isCropped ||
      vignette.isVisible ||
      !adjustments.isMatrixOnly ||
      effects.stroke.isVisible;

  @override
  String get type => 'image';

  ImageLayer copyWith({
    String? id,
    String? name,
    LayerTransform? transform,
    bool? visible,
    double? opacity,
    String? cellId,
    bool clearCell = false,
    LayerEffects? effects,
    String? assetPath,
    String? maskPath,
    bool clearMask = false,
    ImageAdjustments? adjustments,
    Vignette? vignette,
    Rect? cropRect,
  }) {
    return ImageLayer(
      id: id ?? this.id,
      name: name ?? this.name,
      transform: transform ?? this.transform,
      visible: visible ?? this.visible,
      opacity: opacity ?? this.opacity,
      cellId: clearCell ? null : (cellId ?? this.cellId),
      effects: effects ?? this.effects,
      assetPath: assetPath ?? this.assetPath,
      maskPath: clearMask ? null : (maskPath ?? this.maskPath),
      adjustments: adjustments ?? this.adjustments,
      vignette: vignette ?? this.vignette,
      cropRect: cropRect ?? this.cropRect,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...baseJson(),
    'assetPath': assetPath,
    'maskPath': maskPath,
    'adjustments': adjustments.toJson(),
    if (vignette.isVisible) 'vignette': vignette.toJson(),
    'crop': [cropRect.left, cropRect.top, cropRect.right, cropRect.bottom],
  };

  factory ImageLayer.fromJson(Map<String, dynamic> json) {
    return ImageLayer(
      id: json['id'] as String,
      name: json['name'] as String,
      transform: LayerTransform.fromJson(
        (json['transform'] as Map).cast<String, dynamic>(),
      ),
      visible: json['visible'] as bool? ?? true,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      cellId: json['cellId'] as String?,
      effects: _effectsWithLegacyOutline(json),
      assetPath: json['assetPath'] as String,
      maskPath: json['maskPath'] as String?,
      adjustments: ImageAdjustments.fromJson(
        (json['adjustments'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      vignette: json['vignette'] == null
          ? Vignette.none
          : Vignette.fromJson(
              (json['vignette'] as Map).cast<String, dynamic>(),
            ),
      cropRect: _cropFromJson(json['crop']),
    );
  }

  /// The die-cut outline used to be two fields of its own; it is now the
  /// general-purpose [LayerEffects.stroke], which also works on photos with no
  /// cut-out mask. Projects saved before the move are migrated on read.
  static LayerEffects _effectsWithLegacyOutline(Map<String, dynamic> json) {
    final effects = Layer.effectsFromJson(json['effects']);
    if (json['effects'] != null) return effects;
    final width = (json['outlineWidth'] as num?)?.toDouble() ?? 0;
    if (width <= 0) return effects;
    return effects.copyWith(
      stroke: LayerStroke(
        width: width,
        color: Color(json['outlineColor'] as int? ?? 0xFFFFFFFF),
      ),
    );
  }

  static Rect _cropFromJson(Object? v) {
    if (v is List && v.length == 4) {
      return Rect.fromLTRB(
        (v[0] as num).toDouble(),
        (v[1] as num).toDouble(),
        (v[2] as num).toDouble(),
        (v[3] as num).toDouble(),
      );
    }
    return const Rect.fromLTRB(0, 0, 1, 1);
  }

  @override
  bool operator ==(Object other) =>
      other is ImageLayer &&
      other.id == id &&
      other.name == name &&
      other.transform == transform &&
      other.visible == visible &&
      other.opacity == opacity &&
      other.cellId == cellId &&
      other.effects == effects &&
      other.assetPath == assetPath &&
      other.maskPath == maskPath &&
      other.adjustments == adjustments &&
      other.vignette == vignette &&
      other.cropRect == cropRect;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    transform,
    visible,
    opacity,
    cellId,
    effects,
    assetPath,
    maskPath,
    adjustments,
    vignette,
    cropRect,
  );
}

/// A text caption layer.
final class TextLayer extends Layer {
  const TextLayer({
    required super.id,
    required super.name,
    required this.text,
    required this.fontFamily,
    super.transform = LayerTransform.identity,
    super.visible = true,
    super.opacity = 1.0,
    super.cellId,
    super.effects,
    this.fontSize = 40,
    this.color = const Color(0xFFFFFFFF),
    this.strokeWidth = defaultStrokeWidth,
    this.strokeColor,
    this.strokeOpacity = 1.0,
    this.decorative = false,
  });

  /// The caption outline the design ships with, in 512-canvas units.
  static const double defaultStrokeWidth = 3.5;

  final String text;
  final String fontFamily;
  final double fontSize;
  final Color color;

  /// Outline thickness in 512-canvas units; 0 removes the outline (and with it
  /// the caption's baked-in drop shadow - a layer shadow does that job now).
  final double strokeWidth;

  /// Outline color, or null to keep the automatic contrast pick: a dark
  /// outline under light fills, white under everything else.
  final Color? strokeColor;

  /// 0.0 … 1.0
  final double strokeOpacity;

  bool get hasStroke =>
      !decorative && strokeWidth > 0.01 && strokeOpacity > 0.001;

  /// When true this layer is a plain glyph (emoji / prop from the glyph
  /// library, #61) - rendered without the caption stroke + drop shadow so an
  /// emoji keeps its own colors.
  final bool decorative;

  @override
  String get type => 'text';

  TextLayer copyWith({
    String? id,
    String? name,
    LayerTransform? transform,
    bool? visible,
    double? opacity,
    String? cellId,
    bool clearCell = false,
    LayerEffects? effects,
    String? text,
    String? fontFamily,
    double? fontSize,
    Color? color,
    double? strokeWidth,
    Color? strokeColor,
    bool autoStrokeColor = false,
    double? strokeOpacity,
    bool? decorative,
  }) {
    return TextLayer(
      id: id ?? this.id,
      name: name ?? this.name,
      transform: transform ?? this.transform,
      visible: visible ?? this.visible,
      opacity: opacity ?? this.opacity,
      cellId: clearCell ? null : (cellId ?? this.cellId),
      effects: effects ?? this.effects,
      text: text ?? this.text,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      strokeColor: autoStrokeColor ? null : (strokeColor ?? this.strokeColor),
      strokeOpacity: strokeOpacity ?? this.strokeOpacity,
      decorative: decorative ?? this.decorative,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...baseJson(),
    'text': text,
    'fontFamily': fontFamily,
    'fontSize': fontSize,
    'color': color.toARGB32(),
    if (strokeWidth != defaultStrokeWidth) 'strokeWidth': strokeWidth,
    if (strokeColor != null) 'strokeColor': strokeColor!.toARGB32(),
    if (strokeOpacity != 1.0) 'strokeOpacity': strokeOpacity,
    'decorative': decorative,
  };

  factory TextLayer.fromJson(Map<String, dynamic> json) {
    return TextLayer(
      id: json['id'] as String,
      name: json['name'] as String,
      transform: LayerTransform.fromJson(
        (json['transform'] as Map).cast<String, dynamic>(),
      ),
      visible: json['visible'] as bool? ?? true,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      cellId: json['cellId'] as String?,
      effects: Layer.effectsFromJson(json['effects']),
      text: json['text'] as String,
      fontFamily: json['fontFamily'] as String,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 40,
      color: Color(json['color'] as int),
      strokeWidth:
          (json['strokeWidth'] as num?)?.toDouble() ?? defaultStrokeWidth,
      strokeColor: json['strokeColor'] == null
          ? null
          : Color(json['strokeColor'] as int),
      strokeOpacity: (json['strokeOpacity'] as num?)?.toDouble() ?? 1.0,
      decorative: json['decorative'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TextLayer &&
      other.id == id &&
      other.name == name &&
      other.transform == transform &&
      other.visible == visible &&
      other.opacity == opacity &&
      other.cellId == cellId &&
      other.effects == effects &&
      other.text == text &&
      other.fontFamily == fontFamily &&
      other.fontSize == fontSize &&
      other.color == color &&
      other.strokeWidth == strokeWidth &&
      other.strokeColor == strokeColor &&
      other.strokeOpacity == strokeOpacity &&
      other.decorative == decorative;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    transform,
    visible,
    opacity,
    cellId,
    effects,
    text,
    fontFamily,
    fontSize,
    color,
    strokeWidth,
    strokeColor,
    strokeOpacity,
    decorative,
  );
}

/// A comic speech bubble: a vector shape (so it stays crisp at export) with an
/// optional embedded caption that reflows, a fill/stroke from the palette, and a
/// [tail] whose tip is positioned in bubble-local coordinates.
final class BubbleLayer extends Layer {
  const BubbleLayer({
    required super.id,
    required super.name,
    this.text = '',
    this.shape = BubbleShape.speech,
    this.fontFamily = 'Bangers',
    this.fontSize = 26,
    this.fillColor = const Color(0xFFFFFFFF),
    this.strokeColor = const Color(0xFF14101A),
    this.textColor = const Color(0xFF14101A),
    this.tail = const Offset(-0.28, 0.86),
    super.transform = LayerTransform.identity,
    super.visible = true,
    super.opacity = 1.0,
    super.cellId,
    super.effects,
  });

  final String text;
  final BubbleShape shape;
  final String fontFamily;
  final double fontSize;
  final Color fillColor;
  final Color strokeColor;
  final Color textColor;

  /// Tail tip in bubble-local normalized coordinates: the body spans roughly
  /// [-0.5, 0.5] on each axis, so a `dy > 0.5` tip points below the bubble.
  final Offset tail;

  @override
  String get type => 'bubble';

  BubbleLayer copyWith({
    String? id,
    String? name,
    LayerTransform? transform,
    bool? visible,
    double? opacity,
    String? cellId,
    bool clearCell = false,
    LayerEffects? effects,
    String? text,
    BubbleShape? shape,
    String? fontFamily,
    double? fontSize,
    Color? fillColor,
    Color? strokeColor,
    Color? textColor,
    Offset? tail,
  }) {
    return BubbleLayer(
      id: id ?? this.id,
      name: name ?? this.name,
      transform: transform ?? this.transform,
      visible: visible ?? this.visible,
      opacity: opacity ?? this.opacity,
      cellId: clearCell ? null : (cellId ?? this.cellId),
      effects: effects ?? this.effects,
      text: text ?? this.text,
      shape: shape ?? this.shape,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      fillColor: fillColor ?? this.fillColor,
      strokeColor: strokeColor ?? this.strokeColor,
      textColor: textColor ?? this.textColor,
      tail: tail ?? this.tail,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...baseJson(),
    'text': text,
    'shape': shape.name,
    'fontFamily': fontFamily,
    'fontSize': fontSize,
    'fillColor': fillColor.toARGB32(),
    'strokeColor': strokeColor.toARGB32(),
    'textColor': textColor.toARGB32(),
    'tailDx': tail.dx,
    'tailDy': tail.dy,
  };

  factory BubbleLayer.fromJson(Map<String, dynamic> json) {
    return BubbleLayer(
      id: json['id'] as String,
      name: json['name'] as String,
      transform: LayerTransform.fromJson(
        (json['transform'] as Map).cast<String, dynamic>(),
      ),
      visible: json['visible'] as bool? ?? true,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      cellId: json['cellId'] as String?,
      effects: Layer.effectsFromJson(json['effects']),
      text: json['text'] as String? ?? '',
      shape: BubbleShape.values.firstWhere(
        (s) => s.name == json['shape'],
        orElse: () => BubbleShape.speech,
      ),
      fontFamily: json['fontFamily'] as String? ?? 'Bangers',
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 26,
      fillColor: Color(json['fillColor'] as int? ?? 0xFFFFFFFF),
      strokeColor: Color(json['strokeColor'] as int? ?? 0xFF14101A),
      textColor: Color(json['textColor'] as int? ?? 0xFF14101A),
      tail: Offset(
        (json['tailDx'] as num?)?.toDouble() ?? -0.28,
        (json['tailDy'] as num?)?.toDouble() ?? 0.86,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BubbleLayer &&
      other.id == id &&
      other.name == name &&
      other.transform == transform &&
      other.visible == visible &&
      other.opacity == opacity &&
      other.cellId == cellId &&
      other.effects == effects &&
      other.text == text &&
      other.shape == shape &&
      other.fontFamily == fontFamily &&
      other.fontSize == fontSize &&
      other.fillColor == fillColor &&
      other.strokeColor == strokeColor &&
      other.textColor == textColor &&
      other.tail == tail;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    transform,
    visible,
    opacity,
    cellId,
    effects,
    text,
    shape,
    fontFamily,
    fontSize,
    fillColor,
    strokeColor,
    textColor,
    tail,
  );
}
