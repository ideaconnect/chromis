import 'dart:ui' show Color, Offset, Size;

import 'package:chromis/core/models/frame.dart';
import 'package:chromis/core/models/grid.dart';
import 'package:chromis/core/models/layer.dart';
import 'package:chromis/core/models/layer_effects.dart';
import 'package:chromis/core/models/layer_transform.dart';
import 'package:chromis/core/models/photo_filter.dart';
import 'package:chromis/core/models/project.dart';
import 'package:chromis/core/rendering/canvas_geometry.dart';
import 'package:chromis/features/editor/state/editor_controller.dart';
import 'package:chromis/features/editor/state/editor_state.dart';
import 'package:chromis/features/grid/grid_templates.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// [EditorController]'s effect and merge commands: the filter / HDR / vignette
/// / shadow / stroke / blend mutations, and the layer-merging surgery behind
/// Merge down and Flatten.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Project projectWith(
    List<Layer> layers, {
    int w = 1080,
    int h = 1080,
    GridSpec? grid,
  }) => Project(
    id: 'p',
    name: 'Untitled',
    canvasWidth: w,
    canvasHeight: h,
    frames: [Frame(id: 'p_f0', layers: layers)],
    createdAt: DateTime(2024),
    grid: grid,
  );

  ImageLayer img(String id, {String? cellId}) => ImageLayer(
    id: id,
    name: 'Photo',
    assetPath: '/fake/$id.png',
    cellId: cellId,
    transform: const LayerTransform(position: Offset(540, 540)),
  );

  TextLayer txt(String id) => TextLayer(
    id: id,
    name: 'Cap',
    text: 'Cap',
    fontFamily: 'Bangers',
    transform: const LayerTransform(position: Offset(540, 540)),
  );

  BubbleLayer bubble(String id) => BubbleLayer(id: id, name: 'Hi', text: 'Hi');

  ({ProviderContainer container, EditorController controller}) open(
    Project seed,
  ) {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(editorControllerProvider.notifier);
    controller.loadProject(seed);
    return (container: container, controller: controller);
  }

  EditorState read(ProviderContainer c) => c.read(editorControllerProvider);
  Layer byId(ProviderContainer c, String id) =>
      read(c).layers.firstWhere((l) => l.id == id);
  ImageLayer imageById(ProviderContainer c, String id) =>
      byId(c, id) as ImageLayer;

  group('photo looks', () {
    test('setPhotoFilter applies at full strength and clears', () {
      final (:container, :controller) = open(projectWith([img('l_0')]));
      controller.setPhotoFilter('l_0', PhotoFilter.noir);
      expect(imageById(container, 'l_0').adjustments.filter, PhotoFilter.noir);
      expect(imageById(container, 'l_0').adjustments.filterStrength, 1.0);

      // A weakened look, then a fresh pick: the new filter arrives at full
      // strength instead of inheriting the previous one's fade.
      controller.setFilterStrength('l_0', 0.25);
      expect(imageById(container, 'l_0').adjustments.filterStrength, 0.25);
      controller.setPhotoFilter('l_0', PhotoFilter.warm);
      expect(imageById(container, 'l_0').adjustments.filterStrength, 1.0);

      controller.setPhotoFilter('l_0', PhotoFilter.none);
      expect(imageById(container, 'l_0').adjustments.hasFilter, isFalse);
    });

    test('the two Reset buttons stay out of one another\'s way', () {
      final (:container, :controller) = open(projectWith([img('l_0')]));
      controller.setPhotoFilter('l_0', PhotoFilter.retro);
      controller.setHdr('l_0', 0.6);
      controller.updateImageAdjustments(
        'l_0',
        imageById(container, 'l_0').adjustments.copyWith(brightness: 1.4),
      );

      // Adjust's Reset clears only its own sliders.
      controller.updateImageAdjustments(
        'l_0',
        imageById(container, 'l_0').adjustments.resetSliders(),
      );
      var adj = imageById(container, 'l_0').adjustments;
      expect(adj.brightness, 1.0);
      expect(adj.filter, PhotoFilter.retro);
      expect(adj.hdr, 0.6);

      // Effects' Reset clears the look and leaves the sliders alone.
      controller.updateImageAdjustments('l_0', adj.copyWith(brightness: 1.4));
      controller.resetLayerEffects('l_0');
      adj = imageById(container, 'l_0').adjustments;
      expect(adj.filter, PhotoFilter.none);
      expect(adj.hdr, 0);
      expect(adj.brightness, 1.4);
    });

    test('updateVignette sets each field independently', () {
      final (:container, :controller) = open(projectWith([img('l_0')]));
      controller.updateVignette('l_0', amount: 0.7);
      controller.updateVignette('l_0', color: const Color(0xFF00FF00));
      controller.updateVignette('l_0', size: 0.2, softness: 0.9);
      final v = imageById(container, 'l_0').vignette;
      expect(v.amount, 0.7);
      expect(v.color, const Color(0xFF00FF00));
      expect(v.size, 0.2);
      expect(v.softness, 0.9);
      expect(v.isVisible, isTrue);
    });
  });

  group('shared effects', () {
    test('a shadow control arms the shadow, so a drag is never a no-op', () {
      final (:container, :controller) = open(projectWith([img('l_0')]));
      expect(imageById(container, 'l_0').effects.shadow.enabled, isFalse);
      controller.updateLayerShadow('l_0', distance: 40); // no explicit enable
      final shadow = imageById(container, 'l_0').effects.shadow;
      expect(shadow.enabled, isTrue);
      expect(shadow.distance, 40);
      expect(shadow.isVisible, isTrue);

      controller.updateLayerShadow('l_0', enabled: false);
      expect(imageById(container, 'l_0').effects.shadow.isVisible, isFalse);
    });

    test('blend, shadow and stroke work on text and bubbles too', () {
      final (:container, :controller) = open(
        projectWith([txt('l_0'), bubble('l_1')]),
      );
      controller.setLayerBlend('l_0', LayerBlend.screen);
      controller.updateLayerStroke('l_0', width: 5);
      controller.updateLayerShadow('l_1', opacity: 0.8);
      expect(byId(container, 'l_0').effects.blend, LayerBlend.screen);
      expect(byId(container, 'l_0').effects.stroke.width, 5);
      expect(byId(container, 'l_1').effects.shadow.opacity, 0.8);
    });

    test('updateTextStroke sets width/color/opacity and restores auto', () {
      final (:container, :controller) = open(projectWith([txt('l_0')]));
      TextLayer text() => byId(container, 'l_0') as TextLayer;
      expect(text().strokeColor, isNull, reason: 'automatic by default');

      controller.updateTextStroke(
        'l_0',
        width: 8,
        color: const Color(0xFF123456),
        opacity: 0.4,
      );
      expect(text().strokeWidth, 8);
      expect(text().strokeColor, const Color(0xFF123456));
      expect(text().strokeOpacity, 0.4);

      controller.updateTextStroke('l_0', autoColor: true);
      expect(text().strokeColor, isNull);
      expect(text().strokeWidth, 8, reason: 'auto colour keeps the thickness');

      controller.updateTextStroke('l_0', width: 0);
      expect(text().hasStroke, isFalse);
    });

    test('resetLayerEffects clears every look in one undo step', () {
      final (:container, :controller) = open(projectWith([img('l_0')]));
      controller.setLayerBlend('l_0', LayerBlend.multiply);
      controller.updateLayerShadow('l_0', opacity: 0.9);
      controller.updateLayerStroke('l_0', width: 6);
      controller.updateVignette('l_0', amount: 0.5);
      controller.setPhotoFilter('l_0', PhotoFilter.fade);

      controller.resetLayerEffects('l_0');
      final l = imageById(container, 'l_0');
      expect(l.effects, LayerEffects.none);
      expect(l.vignette, Vignette.none);
      expect(l.adjustments.hasFilter, isFalse);

      controller.undo();
      final back = imageById(container, 'l_0');
      expect(back.effects.blend, LayerBlend.multiply);
      expect(back.vignette.amount, 0.5);
    });
  });

  group('applyMerges', () {
    test('replaces a group with one image at the lowest slot', () {
      final (:container, :controller) = open(
        projectWith([img('l_0'), txt('l_1'), img('l_2')]),
      );
      controller.applyMerges(const [
        MergedLayerSpec(
          ids: ['l_0', 'l_1'],
          assetPath: '/merged.png',
          name: 'Photo (merged)',
        ),
      ]);
      final layers = read(container).layers;
      expect(layers.length, 2);
      final merged = layers.first as ImageLayer;
      expect(merged.assetPath, '/merged.png');
      expect(merged.name, 'Photo (merged)');
      expect(
        merged.id,
        isNot(anyOf('l_0', 'l_1')),
        reason: 'the merge is a new layer, not a mutated one',
      );
      expect(layers[1].id, 'l_2', reason: 'the untouched layer keeps its slot');
      expect(read(container).selectedLayerId, merged.id);
    });

    test('the merged layer covers the canvas exactly', () {
      final (:container, :controller) = open(
        projectWith([img('l_0'), img('l_1')], h: 1920), // 1080x1920
      );
      controller.applyMerges(const [
        MergedLayerSpec(ids: ['l_0', 'l_1'], assetPath: '/m.png', name: 'M'),
      ]);
      final merged = read(container).layers.single as ImageLayer;
      expect(merged.transform.position, const Offset(540, 960));
      expect(
        merged.transform.scale,
        photoFitScale(const Size(1080, 1920), 1080, 1920),
      );
    });

    test('a merge inside a grid cell stays in that cell', () {
      final (:container, :controller) = open(
        projectWith([
          img('l_0', cellId: 'c0'),
          img('l_1', cellId: 'c0'),
          img('l_2', cellId: 'c1'),
        ], grid: GridSpec(root: gridTemplatesFor(2).first.root)),
      );
      controller.applyMerges(const [
        MergedLayerSpec(ids: ['l_0', 'l_1'], assetPath: '/m.png', name: 'M'),
      ]);
      final layers = read(container).layers;
      expect(layers.length, 2);
      expect(layers.first.cellId, 'c0');
      expect(
        read(container).project.grid,
        isNotNull,
        reason: 'flattening a collage keeps it a collage',
      );
    });

    test('several groups merge in a single undo step', () {
      final (:container, :controller) = open(
        projectWith([img('l_0'), img('l_1'), img('l_2'), img('l_3')]),
      );
      controller.applyMerges(const [
        MergedLayerSpec(ids: ['l_0', 'l_1'], assetPath: '/a.png', name: 'A'),
        MergedLayerSpec(ids: ['l_2', 'l_3'], assetPath: '/b.png', name: 'B'),
      ]);
      expect(read(container).layers.length, 2);
      controller.undo();
      expect(read(container).layers.length, 4);
    });

    test('an empty list does nothing at all', () {
      final (:container, :controller) = open(projectWith([img('l_0')]));
      final before = read(container).project;
      controller.applyMerges(const []);
      expect(read(container).project, same(before));
      expect(controller.canUndo, isFalse);
    });
  });
}
