import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/models/frame.dart';
import '../../../core/models/grid.dart';
import '../../../core/models/image_adjustments.dart';
import '../../../core/models/layer.dart';
import '../../../core/models/layer_effects.dart';
import '../../../core/models/project.dart';
import '../../../core/rendering/canvas_geometry.dart';
import '../../../core/rendering/image_decode.dart';
import '../../../core/rendering/layer_effects_painter.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/layer_effects_box.dart';
import '../../../core/widgets/text_caption.dart';
import 'bubble_view.dart';

/// Renders a [Frame]'s layers in z-order (bottom → top), mapping the model's
/// 512-unit logical coordinates onto whatever square size the widget is given.
/// Image layers render as placeholders until image import (#21) provides pixels;
/// text layers render for real with the caption outline.
///
/// With a [grid], the same layers are drawn as a Photo Grid: the grid's border
/// color fills the canvas, each cell clips the layers assigned to it, and free
/// layers (no `cellId`) draw above the whole collage. Must stay in lockstep
/// with `ProjectRenderer` - see the parity test.
class ProjectCanvas extends StatelessWidget {
  const ProjectCanvas({
    super.key,
    required this.frame,
    this.width = Project.legacyCanvasSize,
    this.height = Project.legacyCanvasSize,
    this.grid,
    this.showCellPlaceholders = false,
    this.gesturingLayerId,
  });

  final Frame frame;

  /// The layer currently under a pinch/drag, if any.
  ///
  /// Its decode target is frozen for the duration: a pinch sweeps through
  /// several 256-px quantization steps, and each one used to start a fresh
  /// whole-file read + JPEG decode and leave another byte-identical entry in
  /// the [ImageCache] under a distinct `ResizeImageKey`. Sharpness catches up
  /// the moment the gesture ends, which is the only time anyone looks closely.
  final String? gesturingLayerId;

  /// The project's canvas size in logical (pixel) units - the layer-transform
  /// coordinate space. The W×H rect is BoxFit.contain-ed and centered within
  /// whatever box the widget is given (so square thumbnails letterbox cleanly).
  final int width;
  final int height;

  /// Photo Grid partition, or null for an ordinary composition.
  final GridSpec? grid;

  /// Draws the "tap to add a photo" hint in empty cells. Editor chrome only:
  /// off by default so Home thumbnails and the export renderer never show it.
  final bool showCellPlaceholders;

  /// Cached `File.existsSync` results keyed by absolute path. A path's on-disk
  /// presence is stable for a layer's lifetime - asset paths are written once at
  /// import, and mask paths are freshly timestamped on every cut-out / erase -
  /// so re-stat-ing per image layer AND per mask on every rebuild (i.e. per
  /// pointer-move frame during a drag) is pure syscall waste (#review perf,
  /// 2026-07-19). Shared statically so frame thumbnails reusing an asset stat it
  /// once between them.
  @visibleForTesting
  static final Map<String, bool> existsCache = <String, bool>{};

  /// The filesystem probe behind [existsCache]. Swappable in tests to count /
  /// stub stat calls; production always uses [defaultFileExists].
  @visibleForTesting
  static bool Function(String path) fileExists = defaultFileExists;

  static bool defaultFileExists(String path) => File(path).existsSync();

  /// Marks the stand-in shown while a photo layer's own decode is in flight, so
  /// a test can tell it apart from the cached `Image.file` fast path - the two
  /// are the same widget type but mean opposite things. See
  /// `_MaskedImageState.build`.
  static const Key decodePlaceholderKey = ValueKey('layer-decode-placeholder');

  /// Cached existence check - stats a given [path] at most once.
  static bool _exists(String path) =>
      existsCache.putIfAbsent(path, () => fileExists(path));

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final logicalW = width.toDouble();
        final logicalH = height.toDouble();
        final avail = constraints.biggest;
        // BoxFit.contain the W×H canvas into the available box (uniform scale).
        final aspect = logicalW / logicalH;
        var fitW = avail.width;
        var fitH = fitW / aspect;
        if (fitH > avail.height) {
          fitH = avail.height;
          fitW = fitH * aspect;
        }
        final scale = fitW / logicalW;
        final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
        Widget stack = Stack(
          children: _children(scale, dpr, logicalW, logicalH),
        );
        // A blending layer must see the composition beneath it and nothing
        // else. Without this group it would blend into whatever the editor
        // paints behind the canvas, and the export - which starts transparent -
        // would not match what the user is looking at.
        if (frame.layers.any((l) => l.visible && !l.effects.blend.isNormal)) {
          stack = CompositeGroup(child: stack);
        }
        return Center(
          child: SizedBox(width: fitW, height: fitH, child: stack),
        );
      },
    );
  }

  List<Widget> _children(
    double scale,
    double dpr,
    double logicalW,
    double logicalH,
  ) {
    final grid = this.grid;
    final visible = frame.layers.where((l) => l.visible);
    if (grid == null) {
      return [for (final layer in visible) _positioned(layer, scale, dpr)];
    }

    final layout = layoutGrid(grid, Size(logicalW, logicalH));
    final cells = layout.cells;
    final radius = Radius.circular(grid.cornerRadius * scale);
    return [
      // The frame is a background fill, not a stroke: cells are drawn on top of
      // it, so the gaps and the outer margin ARE the border and no photo pixel
      // is ever painted over. An empty cell simply shows this fill through.
      if (grid.borderColor.a > 0)
        Positioned.fill(child: ColoredBox(color: grid.borderColor)),
      for (final id in grid.cellIds)
        if (cells[id] case final cell?)
          Positioned.fromRect(
            rect: scaleRect(cell, scale),
            child: ClipRRect(
              borderRadius: BorderRadius.all(radius),
              child: _cellContent(id, cell, scale, dpr, visible),
            ),
          ),
      // Free layers ride above the whole collage, unclipped - a caption can
      // span cells. A layer pointing at a cell the grid no longer has is
      // treated as free rather than silently dropped, so content stays visible
      // (and fixable) instead of vanishing.
      for (final layer in visible)
        if (layer.cellId == null || !cells.containsKey(layer.cellId))
          _positioned(layer, scale, dpr),
    ];
  }

  /// One cell's layers, drawn relative to the cell's top-left. The layer maths
  /// is the whole-canvas one shifted by the cell origin, so nothing about the
  /// coordinate space changes inside a cell.
  Widget _cellContent(
    String id,
    Rect cell,
    double scale,
    double dpr,
    Iterable<Layer> visible,
  ) {
    final layers = [
      for (final l in visible)
        if (l.cellId == id) l,
    ];
    if (layers.isEmpty) {
      return showCellPlaceholders
          ? const _CellPlaceholder()
          : const SizedBox.expand();
    }
    final origin = cell.topLeft * scale;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final layer in layers) _positioned(layer, scale, dpr, origin),
      ],
    );
  }

  Widget _positioned(
    Layer layer,
    double scale,
    double dpr, [
    Offset origin = Offset.zero,
  ]) {
    final t = layer.transform;
    final shadow = layer.effects.shadow;
    Widget content = _content(layer, scale, dpr);
    // Inside the transforms, so the shadow rotates and scales with the layer -
    // exactly where `ProjectRenderer` paints it.
    if (shadow.isVisible) {
      content = LayerShadowBox(shadow: shadow, scale: scale, child: content);
    }
    return Positioned(
      left: t.position.dx * scale - origin.dx,
      top: t.position.dy * scale - origin.dy,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: LayerBlendBox(
          blend: layer.effects.blend,
          opacity: layer.opacity,
          child: Transform.rotate(
            angle: t.rotation,
            child: Transform.scale(scale: t.scale, child: content),
          ),
        ),
      ),
    );
  }

  Widget _content(Layer layer, double scale, double dpr) {
    return switch (layer) {
      TextLayer() => TextCaption(
        text: layer.text,
        fontFamily: layer.fontFamily,
        fontSize: layer.fontSize * scale,
        color: layer.color,
        rotation: 0, // rotation handled by the enclosing Transform
        strokeWidth: layer.strokeWidth,
        strokeColor: layer.strokeColor,
        strokeOpacity: layer.strokeOpacity,
        // Scale the outline/shadow/tracking with the canvas so the preview and
        // thumbnails match the 512-px export (ProjectRenderer._paintText).
        scale: scale,
        decorative: layer.decorative,
      ),
      BubbleLayer() => BubbleView(layer: layer, scale: scale),
      ImageLayer() => _imageContent(layer, scale, dpr),
    };
  }

  Widget _imageContent(ImageLayer layer, double scale, double dpr) {
    final file = File(layer.assetPath);
    // Show the placeholder synchronously for a missing asset (e.g. the demo /
    // gallery fixtures, or a deleted file) instead of flashing an error frame.
    // Existence is cached per path (see [existsCache]) - the path only changes
    // when the layer's asset changes, so a drag doesn't re-stat every frame.
    if (!_exists(layer.assetPath)) {
      return _ImagePlaceholder(name: layer.name, side: 180 * scale);
    }
    final base =
        kLayerFitBoxSide * scale; // ~0.86 of the canvas; user scale above
    // Decode only the pixels this box (and the layer's own zoom) can show -
    // full-res decodes of 2048² sources per widget instance were the top OOM
    // risk with several photos × frame thumbnails (#75).
    var target = layerDecodeTarget(
      side: base,
      dpr: dpr,
      // Frozen at 1.0 while this layer is being pinched - see
      // [gesturingLayerId]. The transform still applies visually; only the
      // number of source pixels decoded stops chasing it.
      layerScale: layer.id == gesturingLayerId ? 1.0 : layer.transform.scale,
    );
    // A crop shows only a fraction of the source across the box, so decode
    // proportionally more source pixels to keep the visible region sharp.
    if (layer.isCropped && layer.cropRect.width > 0) {
      target = (target / layer.cropRect.width).round().clamp(256, 4096);
    }
    // A cut-out layer composites its alpha mask over the photo (background
    // removed). The mask file may be absent (e.g. a project opened without its
    // assets) - fall back to the plain photo in that case.
    final maskPath = layer.maskPath;
    final hasMask = maskPath != null && _exists(maskPath);
    // A mask, a crop, or anything that reaches the pixels needs the painter -
    // see [ImageLayer.needsPainter]. An untouched photo keeps the cached
    // Image.file path.
    if (hasMask || layer.needsPainter) {
      return _MaskedImage(
        imagePath: layer.assetPath,
        maskPath: hasMask ? maskPath : null,
        cropRect: layer.cropRect,
        side: base,
        decodeTarget: target,
        adjustments: layer.adjustments,
        vignette: layer.vignette,
        stroke: layer.effects.stroke,
        strokeWidthPx: layer.effects.stroke.width * scale,
      );
    }

    return Image.file(
      file,
      width: base,
      height: base,
      fit: BoxFit.contain,
      // Shared via Flutter's ImageCache; sized decode instead of full-res.
      cacheWidth: target,
      // Hold the last frame while a new decode target is being read from disk.
      // Without it, every 256-px quantization step a pinch crosses nulls the
      // image and shows an empty box through the grid border until the fresh
      // JPEG decode lands - the photo visibly blinks several times per gesture.
      // The masked path already made this trade (commit ec41528); this plain
      // one was simply missed.
      gaplessPlayback: true,
      errorBuilder: (_, _, _) =>
          _ImagePlaceholder(name: layer.name, side: 180 * scale),
    );
  }
}

/// The decode width (physical px) for a photo shown in a [side]-logical-px
/// contain box at [dpr], keeping the layer's own pinch zoom sharp via
/// [layerScale]. Quantized up to 256-px steps so a pinch doesn't re-decode on
/// every frame, and clamped to sane bounds; the decoder additionally never
/// upscales past the source width (#75).
int layerDecodeTarget({
  required double side,
  required double dpr,
  double layerScale = 1.0,
}) {
  final raw = side * dpr * layerScale.clamp(1.0, 6.0);
  final quantized = ((raw + 255) ~/ 256) * 256;
  return quantized < 256 ? 256 : (quantized > 4096 ? 4096 : quantized);
}

/// Renders a photo with its alpha mask applied - the visible result of an AI
/// cut-out. Both files are decoded to [ui.Image] and composited with
/// `BlendMode.dstIn` so the photo survives only where the mask is opaque.
/// Non-destructive: the source photo and the mask stay separate on disk.
/// Decodes at [decodeTarget] physical px (never past the source resolution),
/// so a frame thumbnail holds kilobytes instead of a full 2048² bitmap (#75).
class _MaskedImage extends StatefulWidget {
  const _MaskedImage({
    required this.imagePath,
    required this.maskPath,
    required this.side,
    required this.decodeTarget,
    this.cropRect = const Rect.fromLTRB(0, 0, 1, 1),
    this.adjustments = ImageAdjustments.identity,
    this.vignette = Vignette.none,
    this.stroke = LayerStroke.none,
    this.strokeWidthPx = 0,
  });

  final String imagePath;

  /// Optional alpha mask (AI cut-out / erase). Null → the plain (possibly
  /// cropped) photo, drawn through this same painter so cropping is supported.
  final String? maskPath;
  final double side;

  /// Decode width in physical px (see [layerDecodeTarget]).
  final int decodeTarget;

  /// Visible source sub-rect (normalized 0..1); the whole image by default.
  final Rect cropRect;

  final ImageAdjustments adjustments;
  final Vignette vignette;
  final LayerStroke stroke;

  /// [stroke]'s width already scaled into this canvas's pixel space.
  final double strokeWidthPx;

  @override
  State<_MaskedImage> createState() => _MaskedImageState();
}

class _MaskedImageState extends State<_MaskedImage> {
  ui.Image? _base;
  ui.Image? _mask;

  /// The target the current `_base`/`_mask` were decoded at.
  int _decodedTarget = 0;

  /// Bumped on each (re)load so an out-of-order decode from a superseded load
  /// discards its result instead of clobbering the newer one.
  int _loadGen = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_MaskedImage old) {
    super.didUpdateWidget(old);
    if (old.imagePath != widget.imagePath || old.maskPath != widget.maskPath) {
      _load();
    } else if (widget.decodeTarget > _decodedTarget) {
      // More pixels needed (pinch zoom / bigger box) - smaller targets keep
      // the existing decode; downscaling again would only cost CPU.
      _load();
    }
  }

  Future<void> _load() async {
    final gen = ++_loadGen;
    final target = widget.decodeTarget;
    final base = await _decode(widget.imagePath, target);
    final mask = widget.maskPath == null
        ? null
        : await _decode(widget.maskPath!, target);
    // Superseded by a newer load (or unmounted): drop this stale result.
    if (!mounted || gen != _loadGen) {
      base?.dispose();
      mask?.dispose();
      return;
    }
    setState(() {
      _base?.dispose();
      _mask?.dispose();
      _base = base;
      _mask = mask;
      _decodedTarget = target;
    });
  }

  /// Decodes [path] at most [targetWidth] px wide - never upscaled past the
  /// encoded source size.
  static Future<ui.Image?> _decode(String path, int targetWidth) async =>
      (await decodeImageFile(path, maxWidth: targetWidth))?.image;

  @override
  void dispose() {
    _base?.dispose();
    _mask?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = _base;
    if (base == null) {
      // Hold the photo on screen while the first decode is in flight, instead
      // of a blank box.
      //
      // This is what the user sees as a flicker on the FIRST brightness or
      // contrast nudge: an untouched photo renders through the cached
      // `Image.file` fast path, and the moment `needsPainter` flips this widget
      // takes its place, mounts, and has nothing to paint until its async
      // decode returns. The photo vanished and came back.
      //
      // `Image.file` at the same `cacheWidth` is the entry the fast path just
      // populated in Flutter's ImageCache, so this resolves synchronously and
      // costs no second decode. It is the un-adjusted photo for a frame or two -
      // the effects arrive when the decode does - which is a far smaller lie
      // than an empty canvas. Re-decodes (pinch zoom raising the target) never
      // reach here: `_base` stays non-null and is swapped only on completion.
      return Image.file(
        File(widget.imagePath),
        key: ProjectCanvas.decodePlaceholderKey,
        width: widget.side,
        height: widget.side,
        fit: BoxFit.contain,
        cacheWidth: widget.decodeTarget,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => SizedBox.square(dimension: widget.side),
      );
    }
    return CustomPaint(
      size: Size.square(widget.side),
      painter: _MaskedImagePainter(
        base: base,
        mask: _mask,
        cropRect: widget.cropRect,
        adjustments: widget.adjustments,
        vignette: widget.vignette,
        stroke: widget.stroke,
        strokeWidthPx: widget.strokeWidthPx,
      ),
    );
  }
}

/// Draws one photo layer's pixels: [base] fitted (contain) into the box, with
/// the effect chain applied by [paintImageLayer] - the SAME function
/// `ProjectRenderer` calls, which is what makes the preview and the export
/// agree by construction rather than by two painters being kept in sync by
/// hand. [mask] shares the photo's aspect ratio, so it maps onto the same
/// destination rect.
class _MaskedImagePainter extends CustomPainter {
  _MaskedImagePainter({
    required this.base,
    this.mask,
    this.cropRect = const Rect.fromLTRB(0, 0, 1, 1),
    this.adjustments = ImageAdjustments.identity,
    this.vignette = Vignette.none,
    this.stroke = LayerStroke.none,
    this.strokeWidthPx = 0,
  });

  final ui.Image base;
  final ui.Image? mask;
  final Rect cropRect;
  final ImageAdjustments adjustments;
  final Vignette vignette;
  final LayerStroke stroke;
  final double strokeWidthPx;

  /// Pixel source rect for the normalized [cropRect] over a [w]×[h] image.
  static Rect _crop(Rect c, int w, int h) =>
      Rect.fromLTWH(c.left * w, c.top * h, c.width * w, c.height * h);

  @override
  void paint(Canvas canvas, Size size) {
    final srcRect = _crop(cropRect, base.width, base.height);
    final fitted = applyBoxFit(BoxFit.contain, srcRect.size, size);
    final dest = Alignment.center.inscribe(
      fitted.destination,
      Offset.zero & size,
    );
    final maskImage = mask;
    paintImageLayer(
      canvas,
      base: base,
      mask: maskImage,
      srcRect: srcRect,
      maskSrc: maskImage == null
          ? null
          : _crop(cropRect, maskImage.width, maskImage.height),
      dest: dest,
      adjustments: adjustments,
      vignette: vignette,
      stroke: stroke,
      strokeWidthPx: strokeWidthPx,
    );
  }

  @override
  bool shouldRepaint(_MaskedImagePainter old) =>
      old.base != base ||
      old.mask != mask ||
      old.cropRect != cropRect ||
      old.adjustments != adjustments ||
      old.vignette != vignette ||
      old.stroke != stroke ||
      old.strokeWidthPx != strokeWidthPx;
}

/// The "tap to add a photo" hint drawn inside an empty Photo Grid cell. Editor
/// chrome only - [ProjectCanvas.showCellPlaceholders] keeps it out of
/// thumbnails and exports.
class _CellPlaceholder extends StatelessWidget {
  const _CellPlaceholder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.cardAlt.withValues(alpha: 0.7),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              Icons.add_photo_alternate_outlined,
              size: 26,
              color: context.colors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// Stand-in for an image layer until real pixels arrive in #21.
class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.name, required this.side});

  final String name;
  final double side;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: side,
      height: side,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.colors.cardAlt.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      // Scaled down rather than clipped: `side` follows the canvas scale, so in
      // a Home thumbnail this box is a few dozen px while the icon and label
      // are fixed - which overflowed. Same treatment as [_CellPlaceholder].
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.image_outlined,
                color: context.colors.textMuted,
                size: 28,
              ),
              const SizedBox(height: 6),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppFonts.ui,
                  fontSize: 11,
                  color: context.colors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
