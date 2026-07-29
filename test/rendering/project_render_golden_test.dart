@Tags(['golden'])
library;

import 'dart:ui' as ui;

import 'package:chromis/core/models/frame.dart';
import 'package:chromis/core/models/grid.dart';
import 'package:chromis/core/models/layer.dart';
import 'package:chromis/core/models/layer_effects.dart';
import 'package:chromis/core/models/layer_transform.dart';
import 'package:chromis/features/export/project_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Visual regression cover for the pixels users actually keep.
///
/// Everything else about the renderer is asserted numerically - parity with the
/// preview, geometry, encode formats - but "does the frame still LOOK right"
/// had no test at all, so a change to a path, a colour matrix or the order of
/// two `saveLayer`s could land silently and only surface in an exported image.
///
/// These drive [ProjectRenderer] itself rather than a widget tree, so a golden
/// here is literally an export. They avoid photo layers on purpose: an
/// [ImageLayer] decodes from disk, which would make the golden depend on a
/// fixture file and an async decode. Bubbles and captions are vector, painted
/// by the same code the export uses for everything else.
///
/// Regenerate with `flutter test --update-goldens test/rendering`, then LOOK at
/// the PNGs before committing. See `test/flutter_test_config.dart` for the
/// anti-aliasing tolerance.
void main() {
  // The painters lay out real TextPainters (dart:ui) even without a widget.
  TestWidgetsFlutterBinding.ensureInitialized();

  const side = 320;

  Future<ui.Image> render(Frame frame, {GridSpec? grid}) =>
      ProjectRenderer.renderImageSized(
        frame,
        canvasWidth: side,
        canvasHeight: side,
        outputWidth: side,
        grid: grid,
      );

  BubbleLayer bubble(
    String id,
    BubbleShape shape,
    Offset position, {
    String text = '',
    double scale = 1,
    double rotation = 0,
    LayerEffects effects = LayerEffects.none,
    double opacity = 1,
    String? cellId,
    Color fill = const Color(0xFFFFFFFF),
  }) => BubbleLayer(
    id: id,
    name: id,
    shape: shape,
    text: text,
    opacity: opacity,
    effects: effects,
    cellId: cellId,
    fillColor: fill,
    transform: LayerTransform(
      position: position,
      scale: scale,
      rotation: rotation,
    ),
  );

  testWidgets('every bubble format, as exported', (tester) async {
    // One golden covering all five silhouettes: the tail, the cloud + dot
    // chain, the star's spiked outline and lightning tail, the tail-less box,
    // and the dashed outline. A regression in any path shows up here.
    final frame = Frame(
      id: 'f',
      layers: [
        bubble('a', BubbleShape.speech, const Offset(80, 60), scale: 0.55),
        bubble('b', BubbleShape.thought, const Offset(230, 60), scale: 0.55),
        bubble('c', BubbleShape.shout, const Offset(80, 175), scale: 0.55),
        bubble('d', BubbleShape.caption, const Offset(230, 175), scale: 0.55),
        bubble('e', BubbleShape.whisper, const Offset(155, 275), scale: 0.55),
      ],
    );
    await expectLater(
      render(frame),
      matchesGoldenFile('goldens/bubble_formats.png'),
    );
  });

  testWidgets('compositing effects, as exported', (tester) async {
    // Opacity, rotation, scale and the drop shadow all nest around the layer in
    // a specific order (see effects_render_parity_test). This golden is what
    // notices when that nesting changes shape rather than merely changing a
    // sampled pixel.
    final frame = Frame(
      id: 'f',
      layers: [
        bubble(
          'shadowed',
          BubbleShape.caption,
          const Offset(105, 90),
          scale: 0.6,
          effects: const LayerEffects(
            shadow: LayerShadow(
              enabled: true,
              angle: 60,
              distance: 12,
              blur: 8,
              opacity: 0.6,
            ),
          ),
        ),
        bubble(
          'rotated',
          BubbleShape.speech,
          const Offset(225, 100),
          scale: 0.5,
          rotation: -0.35,
        ),
        bubble(
          'faded',
          BubbleShape.thought,
          const Offset(105, 225),
          scale: 0.55,
          opacity: 0.35,
        ),
        // A blend needs something underneath or it is indistinguishable from
        // normal - the first cut of this golden had the multiply floating on
        // transparency and would have passed with blending removed entirely.
        bubble(
          'backdrop',
          BubbleShape.caption,
          const Offset(232, 232),
          scale: 0.75,
          fill: const Color(0xFFE8B84A),
        ),
        bubble(
          'multiplied',
          BubbleShape.shout,
          const Offset(215, 218),
          scale: 0.5,
          fill: const Color(0xFF17B6D6),
          effects: const LayerEffects(blend: LayerBlend.multiply),
        ),
      ],
    );
    await expectLater(
      render(frame),
      matchesGoldenFile('goldens/layer_effects.png'),
    );
  });

  testWidgets('a photo grid, as exported', (tester) async {
    // The border is a background FILL with the cells drawn over it, and a free
    // layer rides on top unclipped - the two claims in CLAUDE.md that a picture
    // checks better than a pixel probe. The clipped bubbles prove the cells
    // really do clip.
    final spec = GridSpec(
      root: GridSplit(
        GridAxis.columns,
        const [1, 1],
        [
          const GridLeaf('one'),
          GridSplit(
            GridAxis.rows,
            const [1, 1],
            const [GridLeaf('two'), GridLeaf('three')],
          ),
        ],
      ),
      borderColor: const Color(0xFF17B6D6),
      borderWidth: 10,
      cornerRadius: 12,
    );
    final frame = Frame(
      id: 'f',
      layers: [
        // Oversized and distinctly coloured, so each cell reads as its own
        // region and a broken clip - or a layer landing in the wrong cell - is
        // obvious rather than merely numerically different.
        bubble(
          'c1',
          BubbleShape.caption,
          const Offset(80, 160),
          scale: 1.9,
          cellId: 'one',
          fill: const Color(0xFFE8B84A),
        ),
        bubble(
          'c2',
          BubbleShape.caption,
          const Offset(240, 80),
          scale: 1.4,
          cellId: 'two',
          fill: const Color(0xFF8FA0F5),
        ),
        bubble(
          'c3',
          BubbleShape.caption,
          const Offset(240, 240),
          scale: 1.4,
          cellId: 'three',
          fill: const Color(0xFF35D0A0),
        ),
        // No cellId: drawn last, over the border and across every cell edge.
        bubble('free', BubbleShape.speech, const Offset(160, 165), scale: 0.5),
      ],
    );
    await expectLater(
      render(frame, grid: spec),
      matchesGoldenFile('goldens/photo_grid.png'),
    );
  });

  testWidgets('a caption inside a bubble, as exported', (tester) async {
    // Text is the one part that renders in the bundled test font (boxes, not
    // glyphs) - which is exactly what makes it a stable golden: it pins the
    // auto-fit's chosen size, the line count and the centring, not the shape of
    // anyone's font.
    final frame = Frame(
      id: 'f',
      layers: [
        bubble(
          'short',
          BubbleShape.speech,
          const Offset(90, 85),
          text: 'POW',
          scale: 0.6,
        ),
        // Long enough to force the #79 shrink-and-clamp path.
        bubble(
          'long',
          BubbleShape.caption,
          const Offset(225, 85),
          text: 'the quick brown fox jumps over the lazy dog',
          scale: 0.6,
        ),
        bubble(
          'wrapped',
          BubbleShape.thought,
          const Offset(155, 230),
          text: 'thinking about it',
          scale: 0.7,
        ),
      ],
    );
    await expectLater(
      render(frame),
      matchesGoldenFile('goldens/bubble_captions.png'),
    );
  });
}
