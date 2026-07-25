import 'dart:ui' show Offset, Size;

import 'package:chromis/core/models/frame.dart';
import 'package:chromis/core/models/layer.dart';
import 'package:chromis/core/models/layer_transform.dart';
import 'package:chromis/core/models/project.dart';
import 'package:chromis/core/rendering/canvas_geometry.dart';
import 'package:chromis/features/editor/services/layer_flattener.dart';
import 'package:flutter_test/flutter_test.dart';

/// Which layers a merge folds together, and what the replacement has to be.
/// The pixel side of merging is [ProjectRenderer]'s job (already covered by the
/// parity tests); what lives here is the grouping policy, which is where the
/// surprises are: hidden layers, collage cells, and nothing-to-merge cases.
void main() {
  ImageLayer img(String id, {String? cellId, bool visible = true}) =>
      ImageLayer(
        id: id,
        name: id,
        assetPath: '/$id.png',
        cellId: cellId,
        visible: visible,
        transform: const LayerTransform(position: Offset(540, 540)),
      );

  Frame frameOf(List<Layer> layers) => Frame(id: 'f', layers: layers);

  List<List<String>> idsOf(List<List<Layer>> groups) => [
    for (final g in groups) [for (final l in g) l.id],
  ];

  group('flattenGroups', () {
    test('folds a plain stack into one group', () {
      final groups = LayerFlattener.flattenGroups(
        frameOf([img('a'), img('b'), img('c')]),
      );
      expect(idsOf(groups), [
        ['a', 'b', 'c'],
      ]);
    });

    test('a single layer is not a group - there is nothing to merge', () {
      expect(LayerFlattener.flattenGroups(frameOf([img('a')])), isEmpty);
      expect(LayerFlattener.flattenGroups(frameOf([])), isEmpty);
    });

    test('hidden layers are left out, and cannot form a group alone', () {
      final groups = LayerFlattener.flattenGroups(
        frameOf([img('a'), img('b', visible: false)]),
      );
      expect(
        groups,
        isEmpty,
        reason: 'a flatten must not resurrect a layer the user hid',
      );
    });

    test('a collage groups per cell, so the partition survives', () {
      final groups = LayerFlattener.flattenGroups(
        frameOf([
          img('a', cellId: 'c0'),
          img('b', cellId: 'c1'),
          img('c', cellId: 'c0'),
          img('d'), // free layer above the grid
          img('e'),
        ]),
      );
      expect(idsOf(groups), [
        ['a', 'c'],
        ['d', 'e'],
      ]);
      expect(
        idsOf(groups).expand((g) => g),
        isNot(contains('b')),
        reason: 'a lone photo in its cell has nothing to merge with',
      );
    });

    test('z-order within a group is preserved', () {
      final groups = LayerFlattener.flattenGroups(
        frameOf([img('bottom'), img('middle'), img('top')]),
      );
      expect(idsOf(groups).single, ['bottom', 'middle', 'top']);
    });
  });

  group('mergeDownTarget', () {
    test('is the visible layer directly below, in the same cell', () {
      final frame = frameOf([img('a'), img('b'), img('c')]);
      expect(LayerFlattener.mergeDownTarget(frame, 'c')?.id, 'b');
      expect(LayerFlattener.mergeDownTarget(frame, 'b')?.id, 'a');
    });

    test('the bottom layer has nothing to merge into', () {
      final frame = frameOf([img('a'), img('b')]);
      expect(LayerFlattener.mergeDownTarget(frame, 'a'), isNull);
    });

    test('skips hidden layers rather than merging into nothing', () {
      final frame = frameOf([img('a'), img('b', visible: false), img('c')]);
      expect(LayerFlattener.mergeDownTarget(frame, 'c')?.id, 'a');
    });

    test('never reaches across a cell boundary', () {
      final frame = frameOf([
        img('a', cellId: 'c0'),
        img('b', cellId: 'c1'),
        img('c', cellId: 'c1'),
      ]);
      expect(LayerFlattener.mergeDownTarget(frame, 'c')?.id, 'b');
      expect(
        LayerFlattener.mergeDownTarget(frame, 'b'),
        isNull,
        reason: 'the only layer below lives in another cell',
      );
    });

    test('an unknown id resolves to nothing', () {
      expect(LayerFlattener.mergeDownTarget(frameOf([img('a')]), 'zz'), isNull);
    });
  });

  test('canvasCoverScale maps a canvas-sized image back 1:1', () {
    // The merged PNG has the canvas aspect, so it must land at exactly the
    // scale that re-covers the canvas - otherwise merging would resize the
    // composition it just captured.
    for (final size in const [
      Size(1080, 1080),
      Size(1080, 1920),
      Size(2000, 800),
    ]) {
      final w = size.width.toInt();
      final h = size.height.toInt();
      expect(LayerFlattener.canvasCoverScale(w, h), photoFitScale(size, w, h));
    }
  });

  test('mergedName marks the bottom layer as merged', () {
    expect(
      LayerFlattener.mergedName([img('Photo'), img('b')]),
      'Photo (merged)',
    );
    expect(LayerFlattener.mergedName([]), 'Merged');
  });

  test('canFlatten answers for the whole project', () {
    Project withLayers(List<Layer> layers) => Project(
      id: 'p',
      name: 'p',
      frames: [frameOf(layers)],
      createdAt: DateTime(2024),
    );
    expect(LayerFlattener.canFlatten(withLayers([img('a')])), isFalse);
    expect(LayerFlattener.canFlatten(withLayers([img('a'), img('b')])), isTrue);
  });
}
