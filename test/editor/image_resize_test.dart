import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect, Size;
import 'dart:ui' as ui;

import 'package:chromis/core/models/frame.dart';
import 'package:chromis/core/models/grid.dart';
import 'package:chromis/core/models/layer.dart';
import 'package:chromis/core/models/layer_transform.dart';
import 'package:chromis/core/models/project.dart';
import 'package:chromis/core/rendering/canvas_geometry.dart';
import 'package:chromis/core/rendering/resample.dart';
import 'package:chromis/features/editor/image_resize.dart';
import 'package:chromis/features/editor/layer_scale_curve.dart';
import 'package:chromis/features/editor/services/image_import.dart';
import 'package:chromis/features/editor/services/photo_resampler.dart';
import 'package:chromis/features/editor/state/editor_controller.dart';
import 'package:chromis/features/grid/grid_templates.dart';
import 'package:chromis/features/segmentation/alpha_mask.dart';
import 'package:chromis/features/segmentation/mask_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Resize image: the geometry (pure), what each photo is resampled to, the
/// one-step commit, and the resampler writing real files.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Project projectWith(List<Layer> layers, {int w = 1080, int h = 1080}) =>
      Project(
        id: 'p',
        name: 'Untitled',
        canvasWidth: w,
        canvasHeight: h,
        frames: [Frame(id: 'p_f0', layers: layers)],
      );

  ImageLayer photo({
    String id = 'l_0',
    String asset = '/fake/a.jpg',
    String? mask,
    Offset position = const Offset(540, 540),
    double scale = 1,
    Rect crop = const Rect.fromLTRB(0, 0, 1, 1),
    String? cellId,
  }) => ImageLayer(
    id: id,
    name: 'Photo',
    assetPath: asset,
    maskPath: mask,
    cropRect: crop,
    cellId: cellId,
    transform: LayerTransform(position: position, scale: scale),
  );

  group('resizeProjectGeometry', () {
    test('every layer keeps its place and grows with the canvas', () {
      final project = projectWith([
        photo(position: const Offset(100, 200), scale: 2),
        const TextLayer(
          id: 'l_1',
          name: 'Cap',
          text: 'Cap',
          fontFamily: 'Bangers',
          fontSize: 48,
          transform: LayerTransform(position: Offset(540, 900), rotation: 0.3),
        ),
      ]);
      final resized = resizeProjectGeometry(project, 2160, 2160);
      expect(resized.canvasWidth, 2160);
      expect(resized.canvasHeight, 2160);
      final layers = resized.currentFrame.layers;
      expect(layers[0].transform.position, const Offset(200, 400));
      expect(layers[0].transform.scale, 4);
      // Text is redrawn at its new size rather than resampled: only its
      // transform changes, and its font size stays what the user set.
      final text = layers[1] as TextLayer;
      expect(text.transform.position, const Offset(1080, 1800));
      expect(text.transform.scale, 2);
      expect(text.transform.rotation, 0.3);
      expect(text.fontSize, 48);
    });

    test('a non-square canvas keeps each layer at the same relative spot', () {
      final project = projectWith([
        photo(position: const Offset(270, 1012.5)),
      ], h: 1350);
      final resized = resizeProjectGeometry(project, 540, 675);
      expect(resized.currentFrame.layers.single.transform.position.dx, 135);
      expect(
        resized.currentFrame.layers.single.transform.position.dy,
        closeTo(506.25, 1e-9),
      );
    });

    test('every frame is resized, not just the one on screen', () {
      final project = Project(
        id: 'p',
        name: 'Anim',
        canvasWidth: 1000,
        canvasHeight: 1000,
        frames: [
          Frame(
            id: 'f0',
            layers: [photo(id: 'a')],
          ),
          Frame(
            id: 'f1',
            layers: [photo(id: 'b', scale: 2)],
          ),
        ],
      );
      final resized = resizeProjectGeometry(project, 500, 500);
      expect(resized.frames[0].layers.single.transform.scale, 0.5);
      expect(resized.frames[1].layers.single.transform.scale, 1);
    });

    test("a collage's borders scale with it, up to their caps", () {
      final grid = GridSpec(
        root: defaultGridTemplate(2).root,
      ).copyWith(borderWidth: 30, outerMargin: 30, cornerRadius: 20);
      final project = projectWith([]).copyWith(grid: grid);
      final half = resizeProjectGeometry(project, 540, 540).grid!;
      expect(half.borderWidth, 15);
      expect(half.outerMargin, 15);
      expect(half.cornerRadius, 10);
      final quadruple = resizeProjectGeometry(project, 4320, 4320).grid!;
      expect(quadruple.borderWidth, GridSpec.maxBorderWidth);
      expect(quadruple.outerMargin, GridSpec.maxOuterMargin);
      expect(quadruple.cornerRadius, GridSpec.maxCornerRadius);
    });

    test('a cell photo still covers its cell when a border hit its cap', () {
      // At 4x the 30 px gap wants 120 and gets 80, so each cell comes out
      // bigger than 4x its old self. Scaled by 4 alone, the photo would leave
      // a sliver of the cell uncovered.
      final grid = GridSpec(
        root: defaultGridTemplate(2).root,
      ).copyWith(borderWidth: 30, outerMargin: 30);
      const canvas = Size(1080, 1080);
      final cells = layoutGrid(grid, canvas).cells;
      final cellId = grid.cellIds.first;
      final cell = cells[cellId]!;
      const pixels = Size(1600, 1200);
      final cover = photoCoverScale(pixels, cell.width, cell.height);
      final project = projectWith([
        photo(position: cell.center, scale: cover, cellId: cellId),
      ]).copyWith(grid: grid);

      final resized = resizeProjectGeometry(project, 4320, 4320);
      final after = layoutGrid(
        resized.grid!,
        const Size(4320, 4320),
      ).cells[cellId]!;
      final layer = resized.currentFrame.layers.single as ImageLayer;
      final drawn = Rect.fromCenter(
        center: layer.transform.position,
        width: 440 * layer.transform.scale,
        height: 440 * 1200 / 1600 * layer.transform.scale,
      );
      expect(drawn.left, lessThanOrEqualTo(after.left + 1e-6));
      expect(drawn.top, lessThanOrEqualTo(after.top + 1e-6));
      expect(drawn.right, greaterThanOrEqualTo(after.right - 1e-6));
      expect(drawn.bottom, greaterThanOrEqualTo(after.bottom - 1e-6));
    });

    test('a resized full-bleed photo stays inside the scale range', () {
      // 1080 -> 4096: a photo filling the canvas ends at 9.3x, past the old
      // fixed 6x cap; the range on the NEW canvas has to take it, or the
      // first pinch afterwards would shrink it.
      const pixels = Size(2048, 2048);
      final project = projectWith([
        photo(scale: photoFitScale(pixels, 1080, 1080)),
      ]);
      final resized = resizeProjectGeometry(project, 4096, 4096);
      final scale = resized.currentFrame.layers.single.transform.scale;
      expect(scale, greaterThan(kMaxLayerScale));
      expect(
        LayerScaleRange.forCanvas(const Size(4096, 4096)).contains(scale),
        isTrue,
      );
    });
  });

  group('photoResampleTarget', () {
    test('a photo is resampled to exactly the pixels it covers', () {
      // A 2048 x 1536 photo fitted to a 1080 canvas covers 1080 x 810 of it.
      const source = Size(2048, 1536);
      final fit = photoFitScale(source, 1080, 1080);
      expect(photoResampleTarget(photo(scale: fit), source), (
        width: 1080,
        height: 810,
      ));
      // The same photo after a 2x Resize image covers 2160 x 1620 - more
      // than it has, so it is enlarged with the chosen method rather than
      // left for the GPU to stretch.
      expect(photoResampleTarget(photo(scale: fit * 2), source), (
        width: 2160,
        height: 1620,
      ));
    });

    test('a cropped photo is resampled whole, at the crop\'s density', () {
      // Half of a 2000 px photo, shown 1000 units wide: the visible half is
      // 1:1 at 1000 px, so the whole source becomes 2000 px - and the crop,
      // being normalised, still picks out the same half.
      const source = Size(2000, 1000);
      final layer = photo(
        crop: const Rect.fromLTRB(0, 0, 0.5, 1),
        scale: 1000 / 440,
      );
      expect(photoResampleTarget(layer, source), null); // already 1:1
      final shrunk = photo(
        crop: const Rect.fromLTRB(0, 0, 0.5, 1),
        scale: 500 / 440,
      );
      expect(photoResampleTarget(shrunk, source), (width: 1000, height: 500));
    });

    test('nothing past the photo cap, however far it is zoomed', () {
      const source = Size(1000, 500);
      final target = photoResampleTarget(photo(scale: 40), source)!;
      expect(target.width, kMaxPhotoSide);
      expect(target.height, kMaxPhotoSide ~/ 2);
    });

    test('a photo already drawn 1:1 is left alone', () {
      const source = Size(1080, 1080);
      expect(
        photoResampleTarget(
          photo(scale: photoFitScale(source, 1080, 1080)),
          source,
        ),
        isNull,
      );
    });
  });

  group('EditorController.resizeImage', () {
    ({ProviderContainer container, EditorController controller}) open(
      Project seed,
    ) {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(editorControllerProvider.notifier);
      controller.loadProject(seed);
      return (container: container, controller: controller);
    }

    test('canvas, layers and photos change in ONE undo step', () {
      final seed = projectWith([photo(mask: '/fake/m.png', scale: 2)]);
      final (:container, :controller) = open(seed);
      controller.resizeImage(
        540,
        540,
        photos: const {
          'l_0': ResampledPhoto(
            fromAsset: '/fake/a.jpg',
            fromMask: '/fake/m.png',
            assetPath: '/fake/a_small.jpg',
            maskPath: '/fake/m_small.png',
          ),
        },
      );
      final project = container.read(editorControllerProvider).project;
      expect(project.canvasWidth, 540);
      final layer = project.currentFrame.layers.single as ImageLayer;
      expect(layer.assetPath, '/fake/a_small.jpg');
      expect(layer.maskPath, '/fake/m_small.png');
      expect(layer.transform.scale, 1);

      controller.undo();
      expect(container.read(editorControllerProvider).project, seed);
      expect(controller.canUndo, isFalse);
    });

    test('a layer that changed while resampling keeps its own photo', () {
      // The dock stays live during the seconds a resample takes. A photo
      // swapped under it (a fill, say) must not be replaced by a bitmap of
      // the photo it no longer shows - it is resized on its own pixels.
      final (:container, :controller) = open(
        projectWith([photo(asset: '/fake/filled.png')]),
      );
      controller.resizeImage(
        2160,
        2160,
        photos: const {
          'l_0': ResampledPhoto(
            fromAsset: '/fake/a.jpg',
            fromMask: null,
            assetPath: '/fake/a_big.jpg',
            maskPath: null,
          ),
        },
      );
      final layer =
          container
                  .read(editorControllerProvider)
                  .project
                  .currentFrame
                  .layers
                  .single
              as ImageLayer;
      expect(layer.assetPath, '/fake/filled.png');
      expect(layer.transform.scale, 2); // the geometry still applied
    });

    test('a mask that changed while resampling blocks the swap too', () {
      // Photo and mask are swapped together or not at all: a mask has to
      // match its photo pixel for pixel.
      final (:container, :controller) = open(
        projectWith([photo(mask: '/fake/m_newer.png')]),
      );
      controller.resizeImage(
        540,
        540,
        photos: const {
          'l_0': ResampledPhoto(
            fromAsset: '/fake/a.jpg',
            fromMask: '/fake/m.png',
            assetPath: '/fake/a_small.jpg',
            maskPath: '/fake/m_small.png',
          ),
        },
      );
      final layer =
          container
                  .read(editorControllerProvider)
                  .project
                  .currentFrame
                  .layers
                  .single
              as ImageLayer;
      expect(layer.assetPath, '/fake/a.jpg');
      expect(layer.maskPath, '/fake/m_newer.png');
    });
  });

  group('PhotoResampler', () {
    late Directory tmp;

    setUp(() => tmp = Directory.systemTemp.createTempSync('resample_test'));
    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    Future<String> writePng(String name, int w, int h, List<int> rgba) async {
      final pixels = Uint8List(w * h * 4);
      for (var i = 0; i < pixels.length; i += 4) {
        pixels.setRange(i, i + 4, rgba);
      }
      final buffer = await ui.ImmutableBuffer.fromUint8List(pixels);
      final descriptor = ui.ImageDescriptor.raw(
        buffer,
        width: w,
        height: h,
        pixelFormat: ui.PixelFormat.rgba8888,
      );
      final codec = await descriptor.instantiateCodec();
      final frame = await codec.getNextFrame();
      final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      codec.dispose();
      descriptor.dispose();
      buffer.dispose();
      final file = File('${tmp.path}/$name');
      await file.writeAsBytes(png!.buffer.asUint8List());
      return file.path;
    }

    PhotoResampler resampler() => PhotoResampler(
      imports: _TempImports(tmp),
      masks: MaskStore(baseDir: tmp),
    );

    test('writes each photo and its mask at the footprint size', () async {
      final asset = await writePng('img_a.png', 400, 300, [10, 200, 30, 255]);
      final mask = await MaskStore(
        baseDir: tmp,
      ).save(AlphaMask.filled(400, 300, 200), id: 'l_0');
      // 400 x 300 fitted to a 400 canvas, then the picture halved: it covers
      // 200 x 150 of the result.
      final project = projectWith(
        [
          photo(
            asset: asset,
            mask: mask,
            position: const Offset(200, 200),
            scale: photoFitScale(const Size(400, 300), 400, 400),
          ),
        ],
        w: 400,
        h: 400,
      );

      final photos = await resampler().resample(
        project,
        width: 200,
        height: 200,
        method: ResampleMethod.lanczos,
      );

      final result = photos['l_0']!;
      expect(result.fromAsset, asset);
      expect(result.fromMask, mask);
      // Opaque, so it went back as a JPEG.
      expect(result.assetPath, endsWith('.jpg'));
      expect(
        await MaskStore.decodeImageSize(result.assetPath),
        const Size(200, 150),
      );
      final resampledMask = await MaskStore(
        baseDir: tmp,
      ).load(result.maskPath!);
      expect(resampledMask.width, 200);
      expect(resampledMask.height, 150);
      expect(resampledMask.alpha.every((a) => a == 200), isTrue);
      // The originals are untouched - the undo step still points at them.
      expect(File(asset).existsSync(), isTrue);
      expect(File(mask).existsSync(), isTrue);
    });

    test('a photo with transparency stays a PNG', () async {
      final asset = await writePng('img_b.png', 100, 100, [255, 0, 0, 128]);
      final project = projectWith(
        [photo(asset: asset, position: const Offset(50, 50), scale: 100 / 440)],
        w: 100,
        h: 100,
      );
      final photos = await resampler().resample(
        project,
        width: 300,
        height: 300,
        method: ResampleMethod.nearest,
      );
      expect(photos['l_0']!.assetPath, endsWith('.png'));
      expect(
        await MaskStore.decodeImageSize(photos['l_0']!.assetPath),
        const Size(300, 300),
      );
    });

    test('one resample for a layer copied across frames', () async {
      final asset = await writePng('img_c.png', 64, 64, [1, 2, 3, 255]);
      final project = Project(
        id: 'p',
        name: 'Anim',
        canvasWidth: 64,
        canvasHeight: 64,
        frames: [
          for (var i = 0; i < 4; i++)
            Frame(
              id: 'f$i',
              layers: [
                photo(
                  id: 'l_$i',
                  asset: asset,
                  position: const Offset(32, 32),
                  scale: 64 / 440,
                ),
              ],
            ),
        ],
      );
      final photos = await resampler().resample(
        project,
        width: 128,
        height: 128,
        method: ResampleMethod.bilinear,
      );
      expect(photos, hasLength(4));
      expect(photos.values.map((p) => p.assetPath).toSet(), hasLength(1));
    });

    test('a missing file is skipped, not fatal', () async {
      final project = projectWith([photo(asset: '${tmp.path}/gone.jpg')]);
      final photos = await resampler().resample(
        project,
        width: 540,
        height: 540,
        method: ResampleMethod.bicubic,
      );
      expect(photos, isEmpty);
    });
  });
}

/// Stores into a temp directory instead of the app documents directory.
class _TempImports extends ImageImportService {
  _TempImports(this.dir);

  final Directory dir;
  var _n = 0;

  @override
  Future<String> storeBytes(Uint8List bytes, {String ext = 'png'}) async {
    final file = File('${dir.path}/img_resampled_${_n++}.$ext');
    await file.writeAsBytes(bytes);
    return file.path;
  }
}
