import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:photo_editor_ai/core/models/frame.dart';
import 'package:photo_editor_ai/core/models/image_adjustments.dart';
import 'package:photo_editor_ai/core/models/layer.dart';
import 'package:photo_editor_ai/core/models/layer_transform.dart';
import 'package:photo_editor_ai/core/models/project.dart';

/// Guards the [Project] document model: canvas-size clamping, derived geometry,
/// per-field copyWith, the versioned JSON manifest round-trip (mixed layer
/// types + ISO8601 dates), and the v1->v2 migration / validation paths in
/// [Project.fromJson].

final _created = DateTime.utc(2026, 7, 22, 10, 30, 15, 500);
final _updated = DateTime.utc(2026, 7, 22, 11, 45, 0, 250);

/// A fully-populated two-frame project with one of every layer variant, using
/// non-default values everywhere so serialization/copy bugs surface.
Project _sampleProject() {
  const f0 = Frame(
    id: 'p_f0',
    layers: [
      ImageLayer(
        id: 'l0',
        name: 'Photo',
        assetPath: '/data/img0.png',
        maskPath: '/data/mask0.png',
        transform: LayerTransform(
          position: Offset(100, 200),
          scale: 1.5,
          rotation: 0.3,
        ),
        visible: false,
        opacity: 0.8,
        adjustments: ImageAdjustments(
          brightness: 1.2,
          contrast: 0.9,
          saturation: 1.1,
          hue: 30,
        ),
        outlineWidth: 4,
        outlineColor: Color(0xFF00FF00),
        cropRect: Rect.fromLTRB(0.1, 0.2, 0.9, 0.8),
      ),
      TextLayer(
        id: 'l1',
        name: 'Caption',
        text: 'Hello',
        fontFamily: 'Manrope',
        transform: LayerTransform(
          position: Offset(300, 400),
          scale: 2,
          rotation: 1,
        ),
        opacity: 0.5,
        fontSize: 48,
        color: Color(0xFFFF0000),
        decorative: true,
      ),
    ],
  );
  const f1 = Frame(
    id: 'p_f1',
    layers: [
      BubbleLayer(
        id: 'l2',
        name: 'Bubble',
        text: 'Pow!',
        shape: BubbleShape.shout,
        fontFamily: 'Comic',
        fontSize: 30,
        fillColor: Color(0xFFFFFF00),
        strokeColor: Color(0xFF000000),
        textColor: Color(0xFF111111),
        tail: Offset(0.3, 0.7),
      ),
      // A second image layer that leans on the defaults (null mask, identity
      // adjustments, whole-image crop) to exercise those serialization paths.
      ImageLayer(id: 'l3', name: 'Photo2', assetPath: '/data/img1.png'),
    ],
  );
  return Project(
    id: 'proj-1',
    name: 'My Project',
    frames: [f0, f1],
    canvasWidth: 1920,
    canvasHeight: 1080,
    currentFrameIndex: 1,
    fps: 12,
    createdAt: _created,
    updatedAt: _updated,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('constants have the documented values', () {
    expect(Project.minCanvasDimension, 16);
    expect(Project.maxCanvasDimension, 8192);
    expect(Project.defaultCanvasWidth, 1080);
    expect(Project.defaultCanvasHeight, 1080);
    expect(Project.legacyCanvasSize, 512);
    expect(Project.minFps, 0.25);
    expect(Project.maxFps, 30.0);
    expect(Project.defaultFps, 8.0);
    expect(Project.schemaVersion, 2);
  });

  test('Project.empty clamps canvas dimensions into range', () {
    final small = Project.empty(id: 'x', width: 8, height: 10000);
    expect(small.canvasWidth, Project.minCanvasDimension); // 8 -> 16
    expect(small.canvasHeight, Project.maxCanvasDimension); // 10000 -> 8192

    final big = Project.empty(id: 'y', width: 10000, height: 8);
    expect(big.canvasWidth, Project.maxCanvasDimension); // 10000 -> 8192
    expect(big.canvasHeight, Project.minCanvasDimension); // 8 -> 16

    // An in-range value passes through untouched.
    expect(Project.empty(id: 'z', width: 640, height: 480).canvasWidth, 640);
  });

  test(
    'Project.empty seeds one frame and mirrors createdAt into updatedAt',
    () {
      final p = Project.empty(id: 'abc', createdAt: _created);
      expect(p.frames, hasLength(1));
      expect(p.frames.single.id, 'abc_f0');
      expect(p.frames.single.layers, isEmpty);
      expect(p.frameCount, 1);
      expect(p.isAnimated, isFalse);
      expect(p.createdAt, _created);
      expect(p.updatedAt, _created); // both set to the passed createdAt

      // Defaults when nothing is supplied.
      final d = Project.empty(id: 'q');
      expect(d.name, 'Untitled');
      expect(d.canvasWidth, Project.defaultCanvasWidth);
      expect(d.canvasHeight, Project.defaultCanvasHeight);
      expect(d.createdAt, isNull);
      expect(d.updatedAt, isNull);
    },
  );

  test('canvasCenter and canvasAspect derive from the canvas size', () {
    final p = _sampleProject(); // 1920 x 1080
    expect(p.canvasCenter, Offset(p.canvasWidth / 2, p.canvasHeight / 2));
    expect(p.canvasCenter, const Offset(960, 540));
    expect(p.canvasAspect, p.canvasWidth / p.canvasHeight);
    // A square canvas has aspect 1.
    expect(Project.empty(id: 's', width: 500, height: 500).canvasAspect, 1.0);
  });

  test('safeFrameIndex clamps out-of-range currentFrameIndex', () {
    final base = _sampleProject(); // 2 frames -> valid range [0, 1]
    expect(base.copyWith(currentFrameIndex: 9).safeFrameIndex, 1);
    expect(base.copyWith(currentFrameIndex: -5).safeFrameIndex, 0);
    expect(base.copyWith(currentFrameIndex: 1).safeFrameIndex, 1);

    // currentFrame / layerCount follow the clamped index.
    final over = base.copyWith(currentFrameIndex: 99);
    expect(over.currentFrame, base.frames.last);
    expect(over.layerCount, base.frames.last.layers.length);
  });

  test('safeFrameIndex is 0 and counts are 0 for an empty frame list', () {
    const p = Project(id: 'e', name: 'empty', frames: []);
    expect(p.safeFrameIndex, 0);
    expect(p.frameCount, 0);
    expect(p.layerCount, 0);
    expect(p.isAnimated, isFalse);
  });

  test('frameCount / layerCount / isAnimated reflect structure', () {
    final p = _sampleProject();
    expect(p.frameCount, 2);
    expect(p.isAnimated, isTrue);
    // currentFrameIndex is 1 -> the bubble+image frame (2 layers).
    expect(p.layerCount, 2);

    final single = p.copyWith(frames: [p.frames.first], currentFrameIndex: 0);
    expect(single.isAnimated, isFalse);
    expect(single.frameCount, 1);
    expect(single.layerCount, p.frames.first.layers.length);
  });

  test('copyWith replaces one field and leaves the rest unchanged', () {
    final base = _sampleProject();

    // No-op copy equals the original.
    expect(base.copyWith(), equals(base));

    // For each field: the new value takes effect, and reverting it reproduces
    // the base exactly (proving nothing else moved).
    void checkString(
      Project changed,
      String Function(Project) get,
      String value,
    ) {
      expect(get(changed), value);
    }

    final byId = base.copyWith(id: 'other');
    checkString(byId, (p) => p.id, 'other');
    expect(byId.copyWith(id: base.id), equals(base));

    final byName = base.copyWith(name: 'Renamed');
    checkString(byName, (p) => p.name, 'Renamed');
    expect(byName.copyWith(name: base.name), equals(base));

    final byW = base.copyWith(canvasWidth: 640);
    expect(byW.canvasWidth, 640);
    expect(byW.copyWith(canvasWidth: base.canvasWidth), equals(base));

    final byH = base.copyWith(canvasHeight: 480);
    expect(byH.canvasHeight, 480);
    expect(byH.copyWith(canvasHeight: base.canvasHeight), equals(base));

    final byIdx = base.copyWith(currentFrameIndex: 0);
    expect(byIdx.currentFrameIndex, 0);
    expect(
      byIdx.copyWith(currentFrameIndex: base.currentFrameIndex),
      equals(base),
    );

    final byFps = base.copyWith(fps: 3);
    expect(byFps.fps, 3);
    expect(byFps.copyWith(fps: base.fps), equals(base));

    final newFrames = [const Frame(id: 'only')];
    final byFrames = base.copyWith(frames: newFrames);
    expect(byFrames.frames, newFrames);
    expect(byFrames.copyWith(frames: base.frames), equals(base));

    final d = DateTime.utc(2000);
    final byCreated = base.copyWith(createdAt: d);
    expect(byCreated.createdAt, d);
    expect(byCreated.copyWith(createdAt: base.createdAt), equals(base));

    final byUpdated = base.copyWith(updatedAt: d);
    expect(byUpdated.updatedAt, d);
    expect(byUpdated.copyWith(updatedAt: base.updatedAt), equals(base));
  });

  test('toJson/fromJson round-trips a mixed-layer project through JSON', () {
    final original = _sampleProject();
    final json = original.toJson();

    // Manifest carries the schema version and ISO8601 timestamps.
    expect(json['version'], Project.schemaVersion);
    expect(json['createdAt'], original.createdAt!.toIso8601String());
    expect(json['updatedAt'], original.updatedAt!.toIso8601String());

    // Force everything through real JSON primitives, then rebuild.
    final decoded = jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
    final restored = Project.fromJson(decoded);
    expect(restored, equals(original));
    expect(restored.frames, equals(original.frames));
  });

  test('fromJson migrates a v1 manifest to the legacy canvas size', () {
    // v1: no "version", no canvasWidth/Height.
    final v1 = <String, dynamic>{
      'id': 'p1',
      'name': 'Legacy',
      'frames': [
        {'id': 'p1_f0', 'layers': <dynamic>[]},
      ],
    };
    final p = Project.fromJson(v1);
    expect(p.canvasWidth, Project.legacyCanvasSize); // 512
    expect(p.canvasHeight, Project.legacyCanvasSize); // 512
    expect(p.fps, Project.defaultFps);
    expect(p.currentFrameIndex, 0);
    expect(p.frameCount, 1);
    expect(p.createdAt, isNull);
  });

  test('fromJson rejects a manifest newer than schemaVersion', () {
    final future = <String, dynamic>{
      'version': Project.schemaVersion + 1,
      'id': 'p',
      'name': 'Future',
      'frames': <dynamic>[],
    };
    expect(() => Project.fromJson(future), throwsFormatException);
  });

  test('fromJson clamps fps into [minFps, maxFps]', () {
    Map<String, dynamic> manifest(num fps) => {
      'version': Project.schemaVersion,
      'id': 'p',
      'name': 'n',
      'canvasWidth': 512,
      'canvasHeight': 512,
      'fps': fps,
      'frames': <dynamic>[],
    };
    expect(Project.fromJson(manifest(100)).fps, Project.maxFps); // 30
    expect(Project.fromJson(manifest(0.001)).fps, Project.minFps); // 0.25
    expect(Project.fromJson(manifest(8)).fps, 8.0); // in-range untouched
  });

  test('fromJson parses absent or malformed dates as null', () {
    Map<String, dynamic> withDates(Object? created, Object? updated) => {
      'version': Project.schemaVersion,
      'id': 'p',
      'name': 'n',
      'canvasWidth': 512,
      'canvasHeight': 512,
      'createdAt': ?created,
      'updatedAt': ?updated,
      'frames': <dynamic>[],
    };

    // Absent keys.
    final absent = Project.fromJson(withDates(null, null));
    expect(absent.createdAt, isNull);
    expect(absent.updatedAt, isNull);

    // Malformed string and a non-string value both fall back to null.
    final bad = Project.fromJson(withDates('not-a-date', 12345));
    expect(bad.createdAt, isNull);
    expect(bad.updatedAt, isNull);
  });
}
