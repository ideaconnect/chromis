import 'dart:typed_data';

import 'package:chromis/core/models/frame.dart';
import 'package:chromis/core/models/grid.dart';
import 'package:chromis/core/models/layer.dart';
import 'package:chromis/core/models/layer_transform.dart';
import 'package:chromis/features/export/project_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// The exported file is the one artefact a user keeps, and until now nothing
/// looked at it. The renderer had parity tests (preview vs export) and geometry
/// tests, and the E2E export scenario asserted only "no unhandled error
/// occurred" - so an export that produced a blank image, the wrong size, or a
/// file no decoder would open would have passed every test in the repo.
///
/// These decode the real output bytes with an INDEPENDENT decoder
/// (package:image, not the engine that produced them) and assert what a user
/// would notice: it is the format we claimed, it is the size we promised, the
/// composition is actually in it, and transparency behaves the way each format
/// requires.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const amber = Color(0xFFE8B84A);

  /// A frame whose single caption box sits dead centre, so probing the middle
  /// hits paint and probing a corner hits background.
  Frame centred({Color fill = amber, double scale = 1, double opacity = 1}) =>
      Frame(
        id: 'f',
        layers: [
          BubbleLayer(
            id: 'b',
            name: 'b',
            shape: BubbleShape.caption,
            fillColor: fill,
            strokeColor: fill,
            opacity: opacity,
            transform: LayerTransform(
              position: const Offset(100, 100),
              scale: scale,
            ),
          ),
        ],
      );

  img.Image decode(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    expect(decoded, isNotNull, reason: 'no decoder recognised the output');
    return decoded!;
  }

  ({int r, int g, int b, int a}) at(img.Image image, int x, int y) {
    final p = image.getPixel(x, y);
    return (r: p.r.round(), g: p.g.round(), b: p.b.round(), a: p.a.round());
  }

  group('PNG', () {
    test(
      'is a real PNG at the requested size, and keeps transparency',
      () async {
        final bytes = await ProjectRenderer.renderPngSized(
          centred(),
          canvasWidth: 200,
          canvasHeight: 200,
          outputWidth: 200,
        );

        // The 8-byte PNG signature. A truncated or misencoded file fails here
        // with a clearer message than a decoder exception would give.
        expect(bytes.sublist(0, 8), [
          0x89,
          0x50,
          0x4E,
          0x47,
          0x0D,
          0x0A,
          0x1A,
          0x0A,
        ], reason: 'output should carry the PNG signature');

        final image = decode(bytes);
        expect(image.width, 200);
        expect(image.height, 200);
        expect(
          image.numChannels,
          4,
          reason: 'PNG export must keep an alpha channel',
        );

        // Photo exports are transparent where nothing was drawn - that is the
        // whole reason PNG is offered alongside JPG.
        expect(
          at(image, 2, 2).a,
          0,
          reason: 'the corner should stay transparent',
        );
        final middle = at(image, 100, 100);
        expect(middle.a, 255, reason: 'the caption box should be opaque');
        expect(middle.r, closeTo(0xE8, 4));
        expect(middle.g, closeTo(0xB8, 4));
        expect(middle.b, closeTo(0x4A, 4));
      },
    );

    test('is not a blank image', () async {
      // The cheapest possible guard against the whole composition silently
      // failing to paint: a blank export decodes, is the right size, and has
      // the right format - it just has nothing in it.
      final bytes = await ProjectRenderer.renderPngSized(
        centred(),
        canvasWidth: 120,
        canvasHeight: 120,
      );
      final image = decode(bytes);
      var painted = 0;
      for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < image.width; x++) {
          if (at(image, x, y).a > 0) painted++;
        }
      }
      final fraction = painted / (image.width * image.height);
      expect(
        fraction,
        greaterThan(0.05),
        reason: 'the exported frame is effectively empty ($painted px painted)',
      );
    });
  });

  group('JPG', () {
    test('is a real JPEG at the requested size', () async {
      final bytes = await ProjectRenderer.renderJpgSized(
        centred(),
        canvasWidth: 200,
        canvasHeight: 200,
        outputWidth: 200,
      );
      expect(bytes.sublist(0, 3), [
        0xFF,
        0xD8,
        0xFF,
      ], reason: 'output should carry the JPEG SOI marker');
      final image = decode(bytes);
      expect(image.width, 200);
      expect(image.height, 200);
    });

    test('flattens transparency onto white rather than black', () async {
      // JPEG has no alpha. Compositing onto white is a deliberate choice in
      // renderJpgSized; getting it wrong (or dropping the composite) turns
      // every transparent margin into a black frame, which is the kind of thing
      // a user only discovers after sharing the image.
      final bytes = await ProjectRenderer.renderJpgSized(
        centred(),
        canvasWidth: 200,
        canvasHeight: 200,
      );
      final image = decode(bytes);
      final corner = at(image, 3, 3);
      expect(corner.r, greaterThan(245));
      expect(corner.g, greaterThan(245));
      expect(corner.b, greaterThan(245));
      // ...and the drawn content still survives the flatten.
      final middle = at(image, 100, 100);
      expect(middle.r, closeTo(0xE8, 8));
      expect(middle.g, closeTo(0xB8, 8));
      expect(middle.b, closeTo(0x4A, 8));
    });
  });

  group('WebP', () {
    test('is a real WebP at the requested size', () async {
      final bytes = await ProjectRenderer.renderWebpSized(
        centred(),
        canvasWidth: 160,
        canvasHeight: 160,
        outputWidth: 160,
      );
      // RIFF container: "RIFF" .... "WEBP".
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WEBP');
      final image = decode(bytes);
      expect(image.width, 160);
      expect(image.height, 160);
    });
  });

  group('output sizing', () {
    test(
      'honours outputWidth and derives height from the canvas aspect',
      () async {
        // A 3:2 canvas exported at 300 wide must be 200 tall - the promise the
        // export screen's size summary makes to the user.
        final bytes = await ProjectRenderer.renderPngSized(
          centred(),
          canvasWidth: 600,
          canvasHeight: 400,
          outputWidth: 300,
        );
        final image = decode(bytes);
        expect(image.width, 300);
        expect(image.height, 200);
      },
    );

    test('a half-resolution export is half the size in both axes', () async {
      final full = decode(
        await ProjectRenderer.renderPngSized(
          centred(),
          canvasWidth: 400,
          canvasHeight: 400,
          outputWidth: 400,
        ),
      );
      final half = decode(
        await ProjectRenderer.renderPngSized(
          centred(),
          canvasWidth: 400,
          canvasHeight: 400,
          outputWidth: 200,
        ),
      );
      expect(half.width * 2, full.width);
      expect(half.height * 2, full.height);
    });

    test('scales the composition with the output, not just the frame', () async {
      // Downscaling must resample the CONTENT too. If layer transforms stopped
      // being multiplied by the output scale, the box would keep its pixel size
      // and cover a bigger share of a smaller export - which this catches.
      double coverage(img.Image image) {
        var painted = 0;
        for (var y = 0; y < image.height; y++) {
          for (var x = 0; x < image.width; x++) {
            if (at(image, x, y).a > 0) painted++;
          }
        }
        return painted / (image.width * image.height);
      }

      final full = decode(
        await ProjectRenderer.renderPngSized(
          centred(),
          canvasWidth: 240,
          canvasHeight: 240,
          outputWidth: 240,
        ),
      );
      final small = decode(
        await ProjectRenderer.renderPngSized(
          centred(),
          canvasWidth: 240,
          canvasHeight: 240,
          outputWidth: 120,
        ),
      );
      expect(coverage(small), closeTo(coverage(full), 0.02));
    });
  });

  group('grid export', () {
    test('paints the border colour behind the cells', () async {
      // The border is a background FILL that the cells are drawn over, so the
      // outer margin of a grid export must be the border colour - not
      // transparent, and not a stroke around each cell.
      final spec = GridSpec(
        root: GridSplit(
          GridAxis.columns,
          const [1, 1],
          const [GridLeaf('a'), GridLeaf('b')],
        ),
        borderColor: const Color(0xFF17B6D6),
        // Deliberately not the default, so this also proves the chosen width is
        // the one that gets rendered.
        borderWidth: 16,
      );
      final bytes = await ProjectRenderer.renderPngSized(
        const Frame(id: 'f'),
        canvasWidth: 200,
        canvasHeight: 200,
        outputWidth: 200,
        grid: spec,
      );
      final image = decode(bytes);
      final edge = at(image, 2, 100);
      expect(edge.a, 255, reason: 'the grid margin should be filled');
      expect(edge.r, closeTo(0x17, 4));
      expect(edge.g, closeTo(0xB6, 4));
      expect(edge.b, closeTo(0xD6, 4));
    });
  });

  group('cross-format agreement', () {
    test('PNG and WebP agree on a semi-transparent layer', () async {
      // PNG is encoded by the engine; WebP goes through _rasterize +
      // package:image, which needs STRAIGHT alpha. Handing it premultiplied
      // bytes darkens every soft edge - a bug that looks like nothing until you
      // compare the two formats, which is exactly what this does.
      const w = 120;
      Future<img.Image> as(Future<Uint8List> Function() encode) async =>
          decode(await encode());

      final png = await as(
        () => ProjectRenderer.renderPngSized(
          centred(opacity: 0.5),
          canvasWidth: w,
          canvasHeight: w,
          outputWidth: w,
        ),
      );
      final webp = await as(
        () => ProjectRenderer.renderWebpSized(
          centred(opacity: 0.5),
          canvasWidth: w,
          canvasHeight: w,
          outputWidth: w,
        ),
      );

      final a = at(png, w ~/ 2, w ~/ 2);
      final b = at(webp, w ~/ 2, w ~/ 2);
      expect(b.a, closeTo(a.a, 3), reason: 'alpha diverged between formats');
      expect(
        b.r,
        closeTo(a.r, 6),
        reason: 'red diverged - premultiplied bytes?',
      );
      expect(
        b.g,
        closeTo(a.g, 6),
        reason: 'green diverged - premultiplied bytes?',
      );
      expect(
        b.b,
        closeTo(a.b, 6),
        reason: 'blue diverged - premultiplied bytes?',
      );
    });
  });
}
