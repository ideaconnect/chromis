import 'dart:typed_data';

import 'package:chromis/core/models/frame.dart';
import 'package:chromis/core/models/layer.dart';
import 'package:chromis/core/models/layer_effects.dart';
import 'package:chromis/core/models/layer_transform.dart';
import 'package:chromis/features/editor/widgets/project_canvas.dart';
import 'package:chromis/features/export/project_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// WYSIWYG parity for the layer effects that composite a layer rather than
/// filter its pixels: the drop shadow and the blend mode.
///
/// Both are implemented twice - once as raw [Canvas] calls in
/// `layer_effects_painter.dart` for the export, once as [RenderProxyBox]es in
/// `layer_effects_box.dart` for the preview - so "they nest their saveLayers
/// the same way" is exactly the kind of claim that rots silently. These tests
/// rasterize both surfaces and compare sampled pixels.
///
/// The probes are caption bubbles: solid vector fills painted by the same
/// painter on both paths, with no async image decode to race.
void main() {
  const side = 240;

  BubbleLayer probe(
    String id,
    Color color,
    Offset position, {
    LayerEffects effects = LayerEffects.none,
    double opacity = 1,
    double scale = 1,
  }) => BubbleLayer(
    id: id,
    name: id,
    shape: BubbleShape.caption,
    fillColor: color,
    strokeColor: color,
    opacity: opacity,
    effects: effects,
    transform: LayerTransform(position: position, scale: scale),
  );

  const red = Color(0xFFFF0000);
  const cyan = Color(0xFF00FFFF);

  Color pixelAt(ByteData data, int x, int y) {
    final i = (y * side + x) * 4;
    return Color.fromARGB(
      data.getUint8(i + 3),
      data.getUint8(i),
      data.getUint8(i + 1),
      data.getUint8(i + 2),
    );
  }

  Future<ByteData> rasterizeExport(Frame frame) async {
    final image = await ProjectRenderer.renderImageSized(
      frame,
      canvasWidth: side,
      canvasHeight: side,
      outputWidth: side,
    );
    try {
      return (await image.toByteData())!;
    } finally {
      image.dispose();
    }
  }

  /// Rasterizes the preview. [backdrop] paints an opaque colour BEHIND the
  /// canvas: a blending layer that is not properly isolated blends into it, so
  /// passing one is what turns the blend tests from decorative into load-
  /// bearing. Left null, the canvas sits on transparency like the export does.
  Future<ByteData> rasterizeCanvas(
    WidgetTester tester,
    Frame frame, {
    Color? backdrop,
  }) async {
    final key = GlobalKey();
    Widget canvas = ProjectCanvas(frame: frame, width: side, height: side);
    if (backdrop != null) {
      canvas = Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: backdrop),
          canvas,
        ],
      );
    }
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            key: key,
            child: SizedBox(
              width: side.toDouble(),
              height: side.toDouble(),
              child: canvas,
            ),
          ),
        ),
      ),
    );
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    try {
      return (await image.toByteData())!;
    } finally {
      image.dispose();
    }
  }

  /// Asserts the two surfaces agree at every sampled point.
  void expectAgree(
    ByteData export,
    ByteData preview,
    Map<String, Offset> samples,
  ) {
    for (final entry in samples.entries) {
      final a = pixelAt(export, entry.value.dx.round(), entry.value.dy.round());
      final b = pixelAt(
        preview,
        entry.value.dx.round(),
        entry.value.dy.round(),
      );
      expect(
        [b.a, b.r, b.g, b.b],
        [
          closeTo(a.a, 0.02),
          closeTo(a.r, 0.02),
          closeTo(a.g, 0.02),
          closeTo(a.b, 0.02),
        ],
        reason: 'canvas and export disagree at ${entry.key} (export $a)',
      );
    }
  }

  testWidgets('a drop shadow lands in the same place in both paths', (
    tester,
  ) async {
    await tester.runAsync(() async {
      // Straight down, far enough that the shadow clears the layer entirely,
      // and hard-edged so the sample is unambiguous.
      final frame = Frame(
        id: 'f0',
        layers: [
          probe(
            'l0',
            red,
            const Offset(120, 90),
            effects: const LayerEffects(
              shadow: LayerShadow(
                enabled: true,
                distance: 60,
                blur: 0,
                opacity: 1,
              ),
            ),
          ),
        ],
      );
      final export = await rasterizeExport(frame);
      final preview = await rasterizeCanvas(tester, frame);

      expectAgree(export, preview, const {
        'layer centre': Offset(120, 90),
        'shadow centre': Offset(120, 150),
        'above the layer': Offset(120, 20),
      });

      for (final data in [export, preview]) {
        final layer = pixelAt(data, 120, 90);
        expect(layer.r, closeTo(1, 0.02), reason: 'the layer paints on top');
        final shadow = pixelAt(data, 120, 150);
        expect(shadow.a, closeTo(1, 0.02), reason: 'the shadow is opaque');
        expect(
          shadow.r + shadow.g + shadow.b,
          closeTo(0, 0.06),
          reason: 'the shadow is the shadow colour, not a copy of the layer',
        );
      }
    });
  });

  testWidgets('shadow opacity and blur agree between the paths', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final frame = Frame(
        id: 'f0',
        layers: [
          probe(
            'l0',
            red,
            const Offset(120, 80),
            // scale 2 also pins WHERE the shadow box sits in the widget tree:
            // the offset must scale with the layer, which it only does if the
            // shadow is applied inside the layer's own transform.
            scale: 2,
            effects: const LayerEffects(
              shadow: LayerShadow(
                enabled: true,
                distance: 30,
                blur: 6,
                density: 3,
                opacity: 0.5,
              ),
            ),
          ),
        ],
      );
      final export = await rasterizeExport(frame);
      final preview = await rasterizeCanvas(tester, frame);

      // distance 30 at layer scale 2 puts the shadow 60px below the layer.
      expectAgree(export, preview, const {
        'shadow core': Offset(120, 190),
        'shadow edge': Offset(60, 190),
        'layer centre': Offset(120, 80),
      });
      for (final data in [export, preview]) {
        expect(
          pixelAt(data, 120, 190).a,
          closeTo(0.5, 0.05),
          reason: 'a half-opacity shadow is half opaque',
        );
      }
    });
  });

  // Cyan multiplied over red: (0,1,1)*(1,0,0) = black. The cyan probe is the
  // BIGGER of the two, so "cyan only" is a point where the blending layer
  // covers bare canvas - the one place an un-isolated preview gives itself
  // away, because there it would multiply into the page instead.
  Frame multiplyFrame({double topOpacity = 1}) => Frame(
    id: 'f0',
    layers: [
      probe('l0', red, const Offset(120, 120), scale: 0.55),
      probe(
        'l1',
        cyan,
        const Offset(120, 120),
        scale: 1.5,
        opacity: topOpacity,
        effects: const LayerEffects(blend: LayerBlend.multiply),
      ),
    ],
  );

  // Yellow: multiplying cyan into it yields green, nothing like cyan.
  const backdrop = Color(0xFFFFFF00);
  const blendSamples = {
    'overlap': Offset(120, 120),
    'cyan over bare canvas': Offset(120, 155),
  };

  testWidgets('a Multiply layer blends against the layer below, not the page', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final frame = multiplyFrame();
      final export = await rasterizeExport(frame);
      final preview = await rasterizeCanvas(tester, frame, backdrop: backdrop);

      expectAgree(export, preview, blendSamples);

      for (final data in [export, preview]) {
        final mixed = pixelAt(data, 120, 120);
        expect(
          [mixed.r, mixed.g, mixed.b],
          [closeTo(0, 0.03), closeTo(0, 0.03), closeTo(0, 0.03)],
          reason: 'red multiplied by cyan is black',
        );
        final bare = pixelAt(data, 120, 155);
        expect(
          [bare.r, bare.g, bare.b],
          [closeTo(0, 0.03), closeTo(1, 0.03), closeTo(1, 0.03)],
          reason: 'over bare canvas the multiply layer keeps its own colour',
        );
      }
    });
  });

  testWidgets('blend composes with layer opacity the same way in both paths', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final frame = multiplyFrame(topOpacity: 0.5);
      final export = await rasterizeExport(frame);
      // No backdrop here: a half-opacity layer over bare canvas is
      // semi-transparent, so an opaque page behind the preview would show
      // through and the two surfaces could not be compared pixel for pixel.
      // Isolation is what the full-opacity test above pins down.
      final preview = await rasterizeCanvas(tester, frame);
      expectAgree(export, preview, blendSamples);
    });
  });
}
