import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../../core/models/frame.dart';
import '../../core/models/grid.dart';
import '../../core/models/layer.dart';
import '../../core/rendering/canvas_geometry.dart';
import '../../core/rendering/layer_effects_painter.dart';
import '../../core/widgets/text_caption.dart';
import '../editor/widgets/bubble_view.dart';

/// Flattens a project [Frame] to a transparent raster image at an arbitrary
/// target size, matching the on-canvas rendering (ProjectCanvas). This is the
/// single source of truth for export pixels - the PNG/JPG/WebP encoders all
/// build on it. Painting happens against a [Canvas] (origin = layer centre) so
/// it renders headlessly without a widget pipeline.
abstract final class ProjectRenderer {
  ProjectRenderer._();

  /// Renders [frame] at the project's aspect. [outputWidth] defaults to
  /// [canvasWidth]; height follows the canvas aspect. Layer transforms are in
  /// canvasWidth×canvasHeight logical units, so scale = outputWidth/canvasWidth
  /// (uniform) - matching the on-canvas render (WYSIWYG).
  static Future<ui.Image> renderImageSized(
    Frame frame, {
    required int canvasWidth,
    required int canvasHeight,
    int? outputWidth,
    GridSpec? grid,
  }) {
    final outW = (outputWidth ?? canvasWidth).clamp(1, 100000);
    final outH = (outW * canvasHeight / canvasWidth).round().clamp(1, 100000);
    return _render(
      frame,
      outW,
      outH,
      outW / canvasWidth,
      Size(canvasWidth.toDouble(), canvasHeight.toDouble()),
      grid,
    );
  }

  static Future<ui.Image> _render(
    Frame frame,
    int outW,
    int outH,
    double scale,
    Size logicalCanvas,
    GridSpec? grid,
  ) async {
    final decoded = await _decodeImages(frame, scale);
    try {
      final recorder = ui.PictureRecorder();
      final bounds = Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble());
      final canvas = Canvas(recorder, bounds);

      void paintLayer(Layer layer) {
        final t = layer.transform;
        final effects = layer.effects;
        final opacity = layer.opacity.clamp(0.0, 1.0);
        if (opacity <= 0) return;
        canvas.save();
        canvas.translate(t.position.dx * scale, t.position.dy * scale);
        // Opacity and blend as one group around the whole layer, outside the
        // rotate/scale - the same nesting `ProjectCanvas` builds with
        // LayerBlendBox, so the two surfaces composite identically.
        final grouped = !effects.blend.isNormal || opacity < 1.0;
        if (grouped) {
          canvas.saveLayer(
            null,
            Paint()
              ..blendMode = effects.blend.mode
              ..color = Color.fromRGBO(0, 0, 0, opacity),
          );
        }
        canvas.rotate(t.rotation);
        canvas.scale(t.scale);
        void paintContent() {
          switch (layer) {
            case ImageLayer():
              _paintImage(canvas, layer, scale, decoded);
            case TextLayer():
              _paintText(canvas, layer, scale);
            case BubbleLayer():
              _paintBubble(canvas, layer, scale);
          }
        }

        // Inside the transforms, so the shadow rotates and scales with the
        // layer (LayerShadowBox sits in the same place on the widget side).
        paintLayerShadow(canvas, effects.shadow, scale, paintContent);
        paintContent();
        if (grouped) canvas.restore();
        canvas.restore();
      }

      final visible = frame.layers.where((l) => l.visible);
      if (grid == null) {
        visible.forEach(paintLayer);
      } else {
        // Mirrors ProjectCanvas exactly (see the parity test): the border is a
        // background fill, each cell clips its own layers, and free layers -
        // including any pointing at a cell the grid no longer has - ride on
        // top, unclipped.
        final cells = layoutGrid(grid, logicalCanvas).cells;
        if (grid.borderColor.a > 0) {
          canvas.drawRect(bounds, Paint()..color = grid.borderColor);
        }
        final radius = Radius.circular(grid.cornerRadius * scale);
        for (final id in grid.cellIds) {
          final cell = cells[id];
          if (cell == null) continue;
          final rect = scaleRect(cell, scale);
          canvas.save();
          canvas.clipRRect(RRect.fromRectAndRadius(rect, radius));
          for (final layer in visible) {
            if (layer.cellId == id) paintLayer(layer);
          }
          canvas.restore();
        }
        for (final layer in visible) {
          if (layer.cellId == null || !cells.containsKey(layer.cellId)) {
            paintLayer(layer);
          }
        }
      }

      final picture = recorder.endRecording();
      final image = await picture.toImage(outW, outH);
      picture.dispose();
      return image;
    } finally {
      for (final image in decoded.values) {
        image.dispose();
      }
    }
  }

  /// PNG bytes (transparent) at the project's aspect - photo export.
  static Future<Uint8List> renderPngSized(
    Frame frame, {
    required int canvasWidth,
    required int canvasHeight,
    int? outputWidth,
    GridSpec? grid,
  }) async => _pngBytes(
    await renderImageSized(
      frame,
      canvasWidth: canvasWidth,
      canvasHeight: canvasHeight,
      outputWidth: outputWidth,
      grid: grid,
    ),
  );

  static Future<Uint8List> _pngBytes(ui.Image image) async {
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('failed to encode PNG');
      return data.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  /// JPG bytes at the project's aspect - transparency flattened onto white
  /// (JPG has no alpha).
  static Future<Uint8List> renderJpgSized(
    Frame frame, {
    required int canvasWidth,
    required int canvasHeight,
    int? outputWidth,
    GridSpec? grid,
    int quality = 92,
  }) async {
    final (rgba, w, h) = await _rasterize(
      frame,
      canvasWidth: canvasWidth,
      canvasHeight: canvasHeight,
      outputWidth: outputWidth,
      grid: grid,
    );
    // package:image encode is pure-Dart + CPU-heavy - run it off the UI isolate
    // (heavy pure-Dart CPU work). JPG has no alpha, so flatten onto white.
    return Isolate.run(() {
      final src = img.Image.fromBytes(
        width: w,
        height: h,
        bytes: rgba.buffer,
        numChannels: 4,
      );
      final flat = img.Image(width: w, height: h)
        ..clear(img.ColorRgb8(255, 255, 255));
      img.compositeImage(flat, src);
      return img.encodeJpg(flat, quality: quality);
    });
  }

  /// WebP bytes at the project's aspect (keeps transparency).
  static Future<Uint8List> renderWebpSized(
    Frame frame, {
    required int canvasWidth,
    required int canvasHeight,
    int? outputWidth,
    GridSpec? grid,
  }) async {
    final (rgba, w, h) = await _rasterize(
      frame,
      canvasWidth: canvasWidth,
      canvasHeight: canvasHeight,
      outputWidth: outputWidth,
      grid: grid,
    );
    return Isolate.run(() {
      final src = img.Image.fromBytes(
        width: w,
        height: h,
        bytes: rgba.buffer,
        numChannels: 4,
      );
      return img.encodeWebP(src);
    });
  }

  /// Renders [frame] and returns its straight-alpha RGBA bytes + dimensions.
  /// The engine rasterizes off the UI isolate; callers then encode the bytes in
  /// a background isolate (package:image works in straight alpha - premultiplied
  /// would darken edges).
  static Future<(Uint8List, int, int)> _rasterize(
    Frame frame, {
    required int canvasWidth,
    required int canvasHeight,
    int? outputWidth,
    GridSpec? grid,
  }) async {
    final image = await renderImageSized(
      frame,
      canvasWidth: canvasWidth,
      canvasHeight: canvasHeight,
      outputWidth: outputWidth,
      grid: grid,
    );
    try {
      final data = await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      if (data == null) throw StateError('failed to rasterize for encoding');
      return (data.buffer.asUint8List(), image.width, image.height);
    } finally {
      image.dispose();
    }
  }

  // ------------------------------------------------- layer painters
  // The canvas has been translated to the layer's centre, so each painter draws
  // around the origin.

  static void _paintImage(
    Canvas canvas,
    ImageLayer layer,
    double scale,
    Map<String, ui.Image> decoded,
  ) {
    final base = decoded[layer.assetPath];
    if (base == null) return; // missing source file → nothing to export
    final boxSide = kLayerFitBoxSide * scale;
    final box = Rect.fromCenter(
      center: Offset.zero,
      width: boxSide,
      height: boxSide,
    );
    // The visible source sub-rectangle (per-layer crop; the whole image by
    // default, in which case srcRect == the full image and output is identical).
    final srcRect = _cropRect(layer.cropRect, base.width, base.height);
    final fitted = applyBoxFit(BoxFit.contain, srcRect.size, box.size);
    final dest = Alignment.center.inscribe(fitted.destination, box);
    final mask = layer.maskPath == null ? null : decoded[layer.maskPath];
    // The one shared effect chain - see layer_effects_painter.dart. The canvas
    // preview reaches the very same function through `_MaskedImagePainter`.
    paintImageLayer(
      canvas,
      base: base,
      mask: mask,
      srcRect: srcRect,
      maskSrc: mask == null
          ? null
          : _cropRect(layer.cropRect, mask.width, mask.height),
      dest: dest,
      adjustments: layer.adjustments,
      vignette: layer.vignette,
      stroke: layer.effects.stroke,
      strokeWidthPx: layer.effects.stroke.width * scale,
      quality: FilterQuality.high,
    );
  }

  /// The pixel source rect for a normalized [crop] over a [w]×[h] image.
  static Rect _cropRect(Rect crop, int w, int h) => Rect.fromLTWH(
    crop.left * w,
    crop.top * h,
    crop.width * w,
    crop.height * h,
  );

  static void _paintText(Canvas canvas, TextLayer layer, double scale) {
    final strokeColor = TextCaption.resolveStrokeColor(
      layer.color,
      layer.strokeColor,
      layer.strokeOpacity,
    );
    final style = TextStyle(
      fontFamily: layer.fontFamily,
      fontSize: layer.fontSize * scale,
      height: 1,
      // Tracking scales with the font so the outline/shadow/spacing stay in the
      // same proportion at every output size (512-px reference down the budget
      // ladder) and match the on-canvas TextCaption preview (WYSIWYG).
      letterSpacing: 1 * scale,
      fontWeight: FontWeight.w700,
    );
    // Emoji / props (#61), and captions with the outline turned off, render as
    // a plain glyph - no caption stroke, and no shadow either (the outline is
    // what carried it; a layer shadow does that job properly now).
    if (!layer.hasStroke) {
      final glyph = TextPainter(
        text: TextSpan(
          text: layer.text,
          style: style.copyWith(color: layer.color),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      glyph.paint(canvas, Offset(-glyph.width / 2, -glyph.height / 2));
      return;
    }
    // Outline (drawn behind) carries the drop shadow.
    final stroke = TextPainter(
      text: TextSpan(
        text: layer.text,
        style: style.copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = layer.strokeWidth * scale
            ..strokeJoin = StrokeJoin.round
            ..color = strokeColor,
          shadows: [
            Shadow(
              color: const Color(0x40000000),
              offset: Offset(0, 4 * scale),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    stroke.paint(canvas, Offset(-stroke.width / 2, -stroke.height / 2));
    final fill = TextPainter(
      text: TextSpan(
        text: layer.text,
        style: style.copyWith(color: layer.color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    fill.paint(canvas, Offset(-fill.width / 2, -fill.height / 2));
  }

  static void _paintBubble(Canvas canvas, BubbleLayer layer, double scale) {
    final size = kBubbleBaseSize * scale;
    canvas.save();
    canvas.translate(-size.width / 2, -size.height / 2);
    BubblePainter(layer).paint(canvas, size);
    // Caption centred in the body rect - the SAME auto-fit as BubbleView, so
    // a long caption that wraps in the editor wraps identically in the
    // exported image instead of spilling outside the bubble (#79).
    final captionRect = bubbleBodyRect(size).deflate(10 * scale);
    final fontSize = bubbleFitFontSize(
      text: layer.text,
      fontFamily: layer.fontFamily,
      maxSize: layer.fontSize * scale,
      bounds: captionRect.size,
    );
    // Match BubbleView exactly: cap the line count + ellipsize a caption too
    // long to fit even at the floor size, and clip to the body rect, so it can
    // never spill over the outline/tail in the exported image (#79 / WYSIWYG).
    final tp = TextPainter(
      text: TextSpan(
        text: layer.text,
        style: TextStyle(
          fontFamily: layer.fontFamily,
          fontSize: fontSize,
          height: 1.05,
          color: layer.textColor,
          fontWeight: FontWeight.w700,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: bubbleCaptionMaxLines(fontSize, captionRect.height),
      ellipsis: '…',
    )..layout(maxWidth: captionRect.width);
    canvas.save();
    canvas.clipRect(captionRect);
    tp.paint(
      canvas,
      Offset(
        captionRect.center.dx - tp.width / 2,
        captionRect.center.dy - tp.height / 2,
      ),
    );
    canvas.restore();
    canvas.restore();
  }

  static Future<Map<String, ui.Image>> _decodeImages(
    Frame frame,
    double scale,
  ) async {
    // Decode each source no larger than its on-output footprint, so a layer
    // drawn small - or a downscaled export / the 600-px preview - never decodes
    // a multi-MB full-res bitmap. The fitted contain width is <= this bound, so
    // there is no quality loss; _decode caps the target at the source size.
    final targets = <String, int>{};
    void bump(String? p, int w) {
      if (p == null) return;
      final prev = targets[p];
      if (prev == null || w > prev) targets[p] = w;
    }

    for (final layer in frame.layers) {
      if (layer is! ImageLayer) continue;
      var w = (kLayerFitBoxSide * scale * layer.transform.scale).ceil().clamp(
        1,
        1 << 20,
      );
      // A cropped layer shows only cropRect.width of the source stretched to
      // fill the same box, so decode 1/cropRect.width larger to keep the
      // visible region at full detail - matching the on-canvas preview
      // (project_canvas._imageContent). Without this, exported crops are
      // softer than the WYSIWYG preview. _decode still caps at the source size.
      if (layer.isCropped && layer.cropRect.width > 0) {
        w = (w / layer.cropRect.width).ceil().clamp(1, 1 << 20);
      }
      bump(layer.assetPath, w);
      bump(layer.maskPath, w);
    }

    final map = <String, ui.Image>{};
    for (final entry in targets.entries) {
      final image = await _decode(entry.key, maxWidth: entry.value);
      if (image != null) map[entry.key] = image;
    }
    return map;
  }

  static Future<ui.Image?> _decode(String path, {int? maxWidth}) async {
    try {
      final file = File(path);
      if (!file.existsSync()) return null;
      final buffer = await ui.ImmutableBuffer.fromUint8List(
        await file.readAsBytes(),
      );
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      // Only ever downscale - never decode larger than the source.
      final target = (maxWidth != null && descriptor.width > maxWidth)
          ? maxWidth
          : null;
      final codec = await descriptor.instantiateCodec(targetWidth: target);
      try {
        final frame = await codec.getNextFrame();
        return frame.image;
      } finally {
        codec.dispose();
        descriptor.dispose();
        buffer.dispose();
      }
    } catch (_) {
      return null;
    }
  }
}
