import 'dart:io';
import 'dart:ui' as ui;

import 'package:chromis/core/models/frame.dart';
import 'package:chromis/core/models/image_adjustments.dart';
import 'package:chromis/core/models/layer.dart';
import 'package:chromis/core/models/layer_effects.dart';
import 'package:chromis/core/models/layer_transform.dart';
import 'package:chromis/core/models/photo_filter.dart';
import 'package:chromis/features/editor/widgets/project_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Layer opacity and blend modes are applied by a raw `saveLayer` around the
/// layer's content, which only works while that content paints inline. A
/// content widget that pushes an engine layer (`ColorFiltered`, `Opacity`,
/// `ImageFiltered`, `RepaintBoundary`) breaks the group.
///
/// This is not a theoretical hazard: adjusted photos used to reach the canvas
/// through `ColorFiltered`, so dragging the Opacity slider on a photo that had
/// any adjustment tripped the assertion in debug - and in release would have
/// dropped the opacity silently. The fix routes colour transforms through the
/// painter instead; these tests make sure it stays that way.
void main() {
  late Directory dir;
  late String photoPath;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('chromis_group');
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      const Rect.fromLTWH(0, 0, 64, 64),
      Paint()..color = const Color(0xFF4080C0),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(64, 64);
    picture.dispose();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final file = File('${dir.path}${Platform.pathSeparator}p.png');
    await file.writeAsBytes(data!.buffer.asUint8List());
    photoPath = file.path;
  });

  tearDownAll(() async {
    // Best-effort: Windows keeps the decoded file handle open for a moment
    // after the last frame, and a failed cleanup must not fail the suite.
    try {
      if (dir.existsSync()) await dir.delete(recursive: true);
    } on FileSystemException {
      // ignored
    }
  });

  ImageLayer photo({
    ImageAdjustments adjustments = ImageAdjustments.identity,
    double opacity = 1,
    LayerEffects effects = LayerEffects.none,
  }) => ImageLayer(
    id: 'l0',
    name: 'p',
    assetPath: photoPath,
    adjustments: adjustments,
    opacity: opacity,
    effects: effects,
    transform: const LayerTransform(position: Offset(120, 120)),
  );

  Future<void> pump(WidgetTester tester, Layer layer) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 240,
            height: 240,
            child: ProjectCanvas(
              frame: Frame(id: 'f', layers: [layer]),
              width: 240,
              height: 240,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  final cases = <String, Layer Function()>{
    'an adjusted photo at reduced opacity': () => photo(
      adjustments: const ImageAdjustments(brightness: 1.4),
      opacity: 0.5,
    ),
    'a filtered photo that blends down': () => photo(
      adjustments: const ImageAdjustments(filter: PhotoFilter.noir),
      effects: const LayerEffects(blend: LayerBlend.multiply),
    ),
    'an HDR photo with a shadow': () => photo(
      adjustments: const ImageAdjustments(hdr: 0.5),
      effects: const LayerEffects(shadow: LayerShadow(enabled: true)),
    ),
    'a vignetted photo at reduced opacity': () => ImageLayer(
      id: 'l0',
      name: 'p',
      assetPath: photoPath,
      opacity: 0.4,
      vignette: const Vignette(amount: 0.6),
      transform: const LayerTransform(position: Offset(120, 120)),
    ),
    'a caption that blends down': () => const TextLayer(
      id: 'l0',
      name: 't',
      text: 'hi',
      fontFamily: 'Bangers',
      opacity: 0.6,
      effects: LayerEffects(blend: LayerBlend.screen),
      transform: LayerTransform(position: Offset(120, 120)),
    ),
    'a bubble with a shadow at reduced opacity': () => const BubbleLayer(
      id: 'l0',
      name: 'b',
      text: 'hi',
      opacity: 0.7,
      effects: LayerEffects(
        shadow: LayerShadow(enabled: true),
        stroke: LayerStroke(width: 3),
      ),
      transform: LayerTransform(position: Offset(120, 120)),
    ),
  };

  for (final entry in cases.entries) {
    testWidgets('${entry.key} paints inline', (tester) async {
      await pump(tester, entry.value());
      expect(
        tester.takeException(),
        isNull,
        reason:
            'the effect group could not be applied - see the assertion message',
      );
    });
  }

  testWidgets('an adjusted photo goes through the painter, not ColorFiltered', (
    tester,
  ) async {
    await pump(tester, photo(adjustments: const ImageAdjustments(hue: 40)));
    expect(
      find.byType(ColorFiltered),
      findsNothing,
      reason: 'a colour transform must not push an engine layer',
    );
    expect(
      find.byType(Image),
      findsNothing,
      reason: 'the cached Image.file path cannot carry a colour matrix',
    );
  });

  testWidgets('an untouched photo keeps the cached Image.file path', (
    tester,
  ) async {
    await pump(tester, photo());
    expect(
      find.byType(Image),
      findsOneWidget,
      reason: 'no reason to give up the image cache when nothing is applied',
    );
  });
}
