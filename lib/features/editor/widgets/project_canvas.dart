import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/models/frame.dart';
import '../../../core/models/grid.dart';
import '../../../core/models/layer.dart';
import '../../../core/models/project.dart';
import '../../../core/rendering/canvas_geometry.dart';
import '../../../core/rendering/color_matrix.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
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
  });

  final Frame frame;

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
        return Center(
          child: SizedBox(
            width: fitW,
            height: fitH,
            child: Stack(children: _children(scale, dpr, logicalW, logicalH)),
          ),
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
    return Positioned(
      left: t.position.dx * scale - origin.dx,
      top: t.position.dy * scale - origin.dy,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: Opacity(
          opacity: layer.opacity.clamp(0.0, 1.0),
          child: Transform.rotate(
            angle: t.rotation,
            child: Transform.scale(
              scale: t.scale,
              child: _content(layer, scale, dpr),
            ),
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
      layerScale: layer.transform.scale,
    );
    // A crop shows only a fraction of the source across the box, so decode
    // proportionally more source pixels to keep the visible region sharp.
    if (layer.isCropped && layer.cropRect.width > 0) {
      target = (target / layer.cropRect.width).round().clamp(256, 4096);
    }
    final colorFilter = layer.adjustments.isIdentity
        ? null
        : ColorFilter.matrix(layer.adjustments.toColorMatrix());

    // A cut-out layer composites its alpha mask over the photo (background
    // removed). The mask file may be absent (e.g. a project opened without its
    // assets) - fall back to the plain photo in that case.
    final maskPath = layer.maskPath;
    final hasMask = maskPath != null && _exists(maskPath);
    // A mask OR a per-layer crop needs the painter path (Image.file can't
    // source-crop); a plain uncropped photo keeps the cached Image.file path.
    if (hasMask || layer.isCropped) {
      return _MaskedImage(
        imagePath: layer.assetPath,
        maskPath: hasMask ? maskPath : null,
        cropRect: layer.cropRect,
        side: base,
        decodeTarget: target,
        colorFilter: colorFilter,
        outlineWidthPx: hasMask ? layer.outlineWidth * scale : 0,
        outlineColor: layer.outlineColor,
      );
    }

    Widget image = Image.file(
      file,
      width: base,
      height: base,
      fit: BoxFit.contain,
      // Shared via Flutter's ImageCache; sized decode instead of full-res.
      cacheWidth: target,
      errorBuilder: (_, _, _) =>
          _ImagePlaceholder(name: layer.name, side: 180 * scale),
    );
    if (colorFilter != null) {
      image = ColorFiltered(colorFilter: colorFilter, child: image);
    }
    return image;
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
    this.colorFilter,
    this.outlineWidthPx = 0,
    this.outlineColor = const Color(0xFFFFFFFF),
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

  final ColorFilter? colorFilter;
  final double outlineWidthPx;
  final Color outlineColor;

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
  static Future<ui.Image?> _decode(String path, int targetWidth) async {
    try {
      final bytes = await File(path).readAsBytes();
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      buffer.dispose();
      try {
        final codec = descriptor.width > targetWidth
            ? await descriptor.instantiateCodec(targetWidth: targetWidth)
            : await descriptor.instantiateCodec();
        try {
          final frame = await codec.getNextFrame();
          return frame.image;
        } finally {
          codec.dispose();
        }
      } finally {
        descriptor.dispose();
      }
    } catch (_) {
      return null;
    }
  }

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
      return SizedBox.square(dimension: widget.side);
    }
    return CustomPaint(
      size: Size.square(widget.side),
      painter: _MaskedImagePainter(
        base: base,
        mask: _mask,
        cropRect: widget.cropRect,
        colorFilter: widget.colorFilter,
        outlineWidthPx: widget.outlineWidthPx,
        outlineColor: widget.outlineColor,
      ),
    );
  }
}

/// Paints [base] fitted (contain) into the box, then multiplies its alpha by
/// [mask] via `BlendMode.dstIn`. [mask] shares the photo's aspect ratio, so it
/// maps onto the same destination rect.
class _MaskedImagePainter extends CustomPainter {
  _MaskedImagePainter({
    required this.base,
    this.mask,
    this.cropRect = const Rect.fromLTRB(0, 0, 1, 1),
    this.colorFilter,
    this.outlineWidthPx = 0,
    this.outlineColor = const Color(0xFFFFFFFF),
  });

  final ui.Image base;
  final ui.Image? mask;
  final Rect cropRect;
  final ColorFilter? colorFilter;
  final double outlineWidthPx;
  final Color outlineColor;

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

    final basePaint = Paint()..filterQuality = FilterQuality.medium;
    if (colorFilter != null) basePaint.colorFilter = colorFilter;

    final maskImage = mask;
    if (maskImage == null) {
      canvas.drawImageRect(base, srcRect, dest, basePaint);
      return;
    }

    final maskSrc = _crop(cropRect, maskImage.width, maskImage.height);
    // Die-cut contour behind the subject.
    if (outlineWidthPx > 0) {
      _paintDieCut(canvas, srcRect, maskSrc, dest);
    }
    canvas.saveLayer(dest, Paint());
    canvas.drawImageRect(base, srcRect, dest, basePaint);
    canvas.drawImageRect(
      maskImage,
      maskSrc,
      dest,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..filterQuality = FilterQuality.medium,
    );
    canvas.restore();
  }

  /// Solid [outlineColor] silhouette of the subject, grown by [outlineWidthPx]
  /// via a morphological dilate, painted before the subject. Mirrors
  /// ProjectRenderer._paintDieCut so preview and export match.
  void _paintDieCut(Canvas canvas, Rect srcRect, Rect maskSrc, Rect dest) {
    final inflated = dest.inflate(outlineWidthPx + 2);
    canvas.saveLayer(
      inflated,
      Paint()
        ..imageFilter = ui.ImageFilter.dilate(
          radiusX: outlineWidthPx,
          radiusY: outlineWidthPx,
        ),
    );
    canvas.saveLayer(dest, Paint());
    canvas.drawImageRect(
      base,
      srcRect,
      dest,
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.drawImageRect(
      mask!,
      maskSrc,
      dest,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..filterQuality = FilterQuality.medium,
    );
    canvas.drawRect(
      dest,
      Paint()
        ..color = outlineColor
        ..blendMode = BlendMode.srcIn,
    );
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MaskedImagePainter old) =>
      old.base != base ||
      old.mask != mask ||
      old.cropRect != cropRect ||
      old.colorFilter != colorFilter ||
      old.outlineWidthPx != outlineWidthPx ||
      old.outlineColor != outlineColor;
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
        color: AppColors.cardAlt.withValues(alpha: 0.7),
      ),
      child: const Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: EdgeInsets.all(6),
            child: Icon(
              Icons.add_photo_alternate_outlined,
              size: 26,
              color: AppColors.textMuted,
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
        color: AppColors.cardAlt.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.image_outlined,
            color: AppColors.textMuted,
            size: 28,
          ),
          const SizedBox(height: 6),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppFonts.ui,
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
