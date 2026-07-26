/// Renders the website's vignette / HDR / drop-shadow / contour demos through
/// the app's OWN painters, so they are the real output rather than a mirror.
///
/// The 15 one-tap looks are pure colour matrices, so the site can ship the
/// numbers and let the browser apply them - provably identical. These four are
/// Canvas routines, so they cannot be handed to a browser; they used to be
/// re-implemented in Python instead, and that mirror silently under-rendered
/// HDR by about a third on shadow-heavy photos. Calling `paintImageLayer` and
/// `paintLayerShadow` directly removes the whole question.
///
/// Reads the crops `tool/gen_filters.py --sources` writes, and puts the
/// rendered PNGs next to them for the same script to encode:
///
///     python tool/gen_filters.py --sources
///     flutter test tool/gen_effect_demos.dart
///     python tool/gen_filters.py
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:chromis/core/models/image_adjustments.dart';
import 'package:chromis/core/models/layer_effects.dart';
import 'package:chromis/core/rendering/layer_effects_painter.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const _dir = 'build/demo';

/// The settings the website advertises. Kept here, next to the render, so the
/// numbers on the page and the numbers in the picture cannot disagree.
const _hdr = 1.0; // the app's slider maximum
const _vignette = Vignette(amount: 1.0, size: 0.40, softness: 0.45);
const _stroke = LayerStroke(width: 16); // default colour is white
const _shadow = LayerShadow(
  enabled: true, // angle defaults to 90, straight down
  distance: 26,
  blur: 16,
  opacity: 0.5,
);

Future<ui.Image> _load(String name) async {
  final codec = await ui.instantiateImageCodec(
    await File('$_dir/$name').readAsBytes(),
  );
  return (await codec.getNextFrame()).image;
}

Future<void> _write(String name, ui.Image image) async {
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  await File('$_dir/$name').writeAsBytes(png!.buffer.asUint8List());
}

/// Records [paint] over a [w]x[h] canvas and rasterises it.
Future<ui.Image> _render(
  int w,
  int h,
  void Function(Canvas, Rect) paint,
) async {
  final rect = Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder, rect), rect);
  final picture = recorder.endRecording();
  final image = await picture.toImage(w, h);
  picture.dispose();
  return image;
}

void main() {
  test('render the website effect demos through the app painters', () async {
    // --- vignette and HDR: a photo, full frame -------------------------------
    for (final (src, out, adjustments, vignette) in [
      (
        'vignette_src.png',
        'vignette_out.png',
        ImageAdjustments.identity,
        _vignette,
      ),
      (
        'hdr_src.png',
        'hdr_out.png',
        const ImageAdjustments(hdr: _hdr),
        Vignette.none,
      ),
    ]) {
      final base = await _load(src);
      final image = await _render(base.width, base.height, (canvas, rect) {
        paintImageLayer(
          canvas,
          base: base,
          srcRect: rect,
          dest: rect,
          adjustments: adjustments,
          vignette: vignette,
          quality: FilterQuality.high,
        );
      });
      await _write(out, image);
      image.dispose();
      base.dispose();
    }

    // --- shadow and contour: a cut-out, with room around it ------------------
    // The mask is a separate image whose ALPHA is the matte, which is exactly
    // how the app holds a cut-out (base photo + maskPath), so the stroke hugs
    // the subject instead of framing its rectangle.
    final cut = await _load('cut_base.png');
    final mask = await _load('cut_mask.png');
    const pad = 150.0;
    final w = cut.width + pad.toInt() * 2;
    final h = cut.height + pad.toInt() * 2;
    final src = Rect.fromLTWH(
      0,
      0,
      cut.width.toDouble(),
      cut.height.toDouble(),
    );
    final dest = src.translate(pad, pad);

    void photo(Canvas canvas, LayerStroke stroke) => paintImageLayer(
      canvas,
      base: cut,
      mask: mask,
      srcRect: src,
      dest: dest,
      stroke: stroke,
      strokeWidthPx: stroke.isVisible ? stroke.width : 0,
      quality: FilterQuality.high,
    );

    final shadow = await _render(w, h, (canvas, _) {
      paintLayerShadow(
        canvas,
        _shadow,
        1.0,
        () => photo(canvas, LayerStroke.none),
      );
      photo(canvas, LayerStroke.none);
    });
    await _write('shadow_out.png', shadow);

    final contour = await _render(w, h, (canvas, _) => photo(canvas, _stroke));
    await _write('contour_out.png', contour);

    shadow.dispose();
    contour.dispose();
    cut.dispose();
    mask.dispose();
  });
}
