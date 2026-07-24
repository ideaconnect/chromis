import 'package:flutter_test/flutter_test.dart';
import 'package:photo_editor_ai/features/segmentation/seg_model.dart';

/// Guards the [SegModel] enum data + its id/engineId resolvers: the picker and
/// the registry read straight from these, so the stable ids, engine ids and the
/// null/unknown fallbacks must stay exactly as the design and settings expect.
void main() {
  test('fromId maps known ids and falls back to builtin otherwise', () {
    expect(SegModel.fromId('builtin'), SegModel.builtin);
    expect(SegModel.fromId('u2net'), SegModel.u2net);
    // Null and unknown persisted values default to the design's built-in model.
    expect(SegModel.fromId(null), SegModel.builtin);
    expect(SegModel.fromId('nope'), SegModel.builtin);
  });

  test('fromEngineId maps engine ids and returns null for unknown', () {
    expect(SegModel.fromEngineId('mlkit'), SegModel.builtin);
    expect(SegModel.fromEngineId('bundled'), SegModel.u2net);
    expect(SegModel.fromEngineId('unknown'), isNull);
  });

  test('builtin carries its exact id / engineId / label / tagline', () {
    expect(SegModel.builtin.id, 'builtin');
    expect(SegModel.builtin.engineId, 'mlkit');
    expect(SegModel.builtin.label, 'Built-in AI');
    expect(SegModel.builtin.tagline, 'On-device · fast & private');
    expect(SegModel.builtin.blurb, isNotEmpty);
  });

  test('u2net carries its exact id / engineId / label / tagline', () {
    expect(SegModel.u2net.id, 'u2net');
    expect(SegModel.u2net.engineId, 'bundled');
    expect(SegModel.u2net.label, 'U²-Net');
    expect(SegModel.u2net.tagline, 'Open-source · sharper detail');
    expect(SegModel.u2net.blurb, isNotEmpty);
  });

  test('every value round-trips through fromId and fromEngineId', () {
    for (final m in SegModel.values) {
      expect(SegModel.fromId(m.id), m, reason: 'fromId(${m.id})');
      expect(
        SegModel.fromEngineId(m.engineId),
        m,
        reason: 'engine ${m.engineId}',
      );
    }
  });

  test('ids and engineIds are unique across the enum', () {
    final ids = SegModel.values.map((m) => m.id).toList();
    final engineIds = SegModel.values.map((m) => m.engineId).toList();
    expect(ids.toSet(), hasLength(ids.length), reason: 'ids must be unique');
    expect(
      engineIds.toSet(),
      hasLength(engineIds.length),
      reason: 'engineIds must be unique',
    );
  });
}
