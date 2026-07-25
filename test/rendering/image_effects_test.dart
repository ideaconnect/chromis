import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:chromis/core/models/frame.dart';
import 'package:chromis/core/models/image_adjustments.dart';
import 'package:chromis/core/models/layer.dart';
import 'package:chromis/core/models/layer_effects.dart';
import 'package:chromis/core/models/layer_transform.dart';
import 'package:chromis/core/models/photo_filter.dart';
import 'package:chromis/core/rendering/canvas_geometry.dart';
import 'package:chromis/features/export/project_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// What the photo effect chain actually DOES to pixels: the filter, the HDR
/// tone map, the vignette and the contour stroke.
///
/// These are behaviour tests rather than parity tests on purpose. Preview and
/// export share one function (`paintImageLayer`), so comparing the two surfaces
/// would only prove that a single implementation equals itself; what needs
/// pinning down is that a vignette darkens the corners and not the middle, that
/// a stroke lands outside the photo, and so on.
void main() {
  const side = 240;
  late Directory dir;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('chromis_effects');
  });

  tearDownAll(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  /// Writes a [w]×[h] PNG filled with [color] and returns its path.
  Future<String> solidPng(
    String name,
    Color color, {
    int w = 200,
    int h = 200,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()..color = color,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(w, h);
    picture.dispose();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final file = File('${dir.path}${Platform.pathSeparator}$name.png');
    await file.writeAsBytes(data!.buffer.asUint8List());
    return file.path;
  }

  /// A photo layer scaled so its square source exactly covers the canvas.
  ImageLayer photo(
    String path, {
    ImageAdjustments adjustments = ImageAdjustments.identity,
    Vignette vignette = Vignette.none,
    LayerEffects effects = LayerEffects.none,
    double coverage = 1,
  }) => ImageLayer(
    id: 'l0',
    name: 'p',
    assetPath: path,
    adjustments: adjustments,
    vignette: vignette,
    effects: effects,
    transform: LayerTransform(
      position: const Offset(side / 2, side / 2),
      scale: photoFitScale(const Size(200, 200), side, side) * coverage,
    ),
  );

  Future<ByteData> render(ImageLayer layer) async {
    final image = await ProjectRenderer.renderImageSized(
      Frame(id: 'f', layers: [layer]),
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

  Color pixelAt(ByteData data, int x, int y) {
    final i = (y * side + x) * 4;
    return Color.fromARGB(
      data.getUint8(i + 3),
      data.getUint8(i),
      data.getUint8(i + 1),
      data.getUint8(i + 2),
    );
  }

  test('a filter recolours the photo and its strength fades in', () async {
    final path = await solidPng('red', const Color(0xFFCC2020));
    final plain = pixelAt(await render(photo(path)), 120, 120);
    expect(plain.r, greaterThan(plain.g + 0.2), reason: 'the source is red');

    final mono = pixelAt(
      await render(
        photo(
          path,
          adjustments: const ImageAdjustments(filter: PhotoFilter.mono),
        ),
      ),
      120,
      120,
    );
    expect(
      [mono.g - mono.r, mono.b - mono.g],
      [closeTo(0, 0.02), closeTo(0, 0.02)],
      reason: 'Mono leaves no colour behind',
    );

    // Half strength sits between the original and the full effect.
    final half = pixelAt(
      await render(
        photo(
          path,
          adjustments: const ImageAdjustments(
            filter: PhotoFilter.mono,
            filterStrength: 0.5,
          ),
        ),
      ),
      120,
      120,
    );
    expect(half.r, greaterThan(mono.r));
    expect(half.r, lessThan(plain.r));
  });

  test('no filter at any strength leaves the photo untouched', () async {
    final path = await solidPng('plain', const Color(0xFF3070C0));
    final a = pixelAt(await render(photo(path)), 120, 120);
    final b = pixelAt(
      await render(
        photo(path, adjustments: const ImageAdjustments(filterStrength: 0.3)),
      ),
      120,
      120,
    );
    expect(
      [b.r, b.g, b.b],
      [closeTo(a.r, 0.01), closeTo(a.g, 0.01), closeTo(a.b, 0.01)],
    );
  });

  test('a vignette darkens the corners and leaves the centre alone', () async {
    final path = await solidPng('white', const Color(0xFFFFFFFF));
    final data = await render(
      photo(path, vignette: const Vignette(amount: 0.9, size: 0.5)),
    );
    final centre = pixelAt(data, 120, 120);
    final corner = pixelAt(data, 4, 4);
    expect(centre.r, closeTo(1, 0.02), reason: 'the clear centre is untouched');
    expect(
      corner.r,
      lessThan(0.4),
      reason: 'the corner takes the full vignette',
    );
    // The falloff is gradual, not a hard ring. x=15 is 105px from the centre,
    // i.e. 0.62 of the half-diagonal - inside the ramp that starts at 0.5.
    final mid = pixelAt(data, 15, 120);
    expect(mid.r, greaterThan(corner.r));
    expect(mid.r, lessThan(centre.r));
  });

  test('the vignette colour is selectable', () async {
    final path = await solidPng('grey', const Color(0xFF808080));
    final data = await render(
      photo(
        path,
        vignette: const Vignette(
          amount: 1,
          size: 0.3,
          color: Color(0xFFFF0000),
        ),
      ),
    );
    final corner = pixelAt(data, 3, 3);
    expect(
      corner.r,
      greaterThan(corner.g + 0.3),
      reason: 'a red vignette tints the corners red rather than darkening them',
    );
  });

  test('a vignette never spills outside the photo', () async {
    final path = await solidPng('half', const Color(0xFFFFFFFF));
    // Half-size photo: the canvas corners are bare.
    final data = await render(
      photo(
        path,
        coverage: 0.5,
        vignette: const Vignette(amount: 1, size: 0.1),
      ),
    );
    expect(
      pixelAt(data, 4, 4).a,
      0,
      reason: 'srcATop keeps the falloff inside the photo alpha',
    );
  });

  test('a stroke frames an uncut photo', () async {
    final path = await solidPng('sq', const Color(0xFF202020));
    final data = await render(
      photo(
        path,
        // The photo spans 60..180; the stroke, scaled by the layer's own zoom
        // like the rest of its content, reaches ~16px past that.
        coverage: 0.5,
        effects: const LayerEffects(
          stroke: LayerStroke(width: 60, color: Color(0xFF00FF00)),
        ),
      ),
    );
    final outside = pixelAt(data, 120, 188);
    expect(
      [outside.a, outside.g],
      [closeTo(1, 0.02), closeTo(1, 0.02)],
      reason: 'the contour paints just outside the photo edge',
    );
    expect(outside.r, closeTo(0, 0.02));
    final inside = pixelAt(data, 120, 120);
    expect(
      inside.g,
      lessThan(0.3),
      reason: 'the contour is behind the photo, not over it',
    );
    // Beyond the stroke width there is nothing.
    expect(pixelAt(data, 120, 220).a, 0);
  });

  test('stroke opacity is honoured', () async {
    final path = await solidPng('sq2', const Color(0xFF202020));
    final data = await render(
      photo(
        path,
        coverage: 0.5,
        effects: const LayerEffects(
          stroke: LayerStroke(width: 60, opacity: 0.5),
        ),
      ),
    );
    expect(pixelAt(data, 120, 188).a, closeTo(0.5, 0.05));
  });

  test(
    'HDR lifts the tone without disturbing a flat photo otherwise',
    () async {
      final path = await solidPng('mid', const Color(0xFF606060));
      final plain = pixelAt(await render(photo(path)), 120, 120);
      final hdr = pixelAt(
        await render(photo(path, adjustments: const ImageAdjustments(hdr: 1))),
        120,
        120,
      );
      expect(
        hdr.r,
        greaterThan(plain.r + 0.03),
        reason: 'HDR lifts the shadows',
      );
      // A flat region has no local contrast to recover, so the pass leaves the
      // colour neutral rather than tinting it.
      expect(hdr.g, closeTo(hdr.r, 0.02));
      expect(hdr.b, closeTo(hdr.r, 0.02));
    },
  );
}
