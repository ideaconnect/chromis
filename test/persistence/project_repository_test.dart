import 'dart:io';

import 'package:chromis/core/models/frame.dart';
import 'package:chromis/core/models/layer.dart';
import 'package:chromis/core/models/layer_transform.dart';
import 'package:chromis/core/models/project.dart';
import 'package:chromis/features/home/project_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Persistence contract for [ProjectRepository]: manifests round-trip through
/// disk, corrupt manifests are quarantined rather than crashing the list, a
/// duplicate re-ids the document while sharing its image/mask files, and the
/// orphan sweep only reclaims unreferenced assets (and never runs when a
/// manifest is unreadable). All paths use a per-test temp dir, dart:io only.
void main() {
  // Layers construct dart:ui values (Color/Offset/Rect) as defaults.
  TestWidgetsFlutterBinding.ensureInitialized();

  /// A temp dir that is torn down after the current test.
  Directory freshTemp() {
    final dir = Directory.systemTemp.createTempSync('project_repo_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    return dir;
  }

  /// `<base>/projects` — the dir the repo reads/writes; created up front so a
  /// test can drop hand-written (corrupt) manifests before any save().
  Directory projectsDirOf(Directory base) =>
      Directory('${base.path}/projects')..createSync(recursive: true);

  Project buildProject({
    required String id,
    String name = 'Sample',
    DateTime? createdAt,
    DateTime? updatedAt,
    int currentFrameIndex = 0,
    List<Frame>? frames,
  }) {
    return Project(
      id: id,
      name: name,
      canvasWidth: 800,
      canvasHeight: 600,
      currentFrameIndex: currentFrameIndex,
      fps: 12,
      createdAt: createdAt,
      updatedAt: updatedAt,
      frames:
          frames ??
          [
            Frame(
              id: '${id}_f0',
              layers: [
                ImageLayer(
                  id: '${id}_l0',
                  name: 'Photo',
                  assetPath: '/assets/img_$id.png',
                  maskPath: '/assets/mask_$id.png',
                  transform: const LayerTransform(
                    position: Offset(120, 90),
                    scale: 1.5,
                    rotation: 0.25,
                  ),
                ),
                TextLayer(
                  id: '${id}_l1',
                  name: 'Caption',
                  text: 'Hi',
                  fontFamily: 'Manrope',
                ),
              ],
            ),
          ],
    );
  }

  test('save then load round-trips an equal project', () async {
    final repo = ProjectRepository(baseDir: freshTemp());
    final project = buildProject(
      id: 'p1',
      name: 'Round trip',
      createdAt: DateTime.utc(2026, 1, 2, 3, 4, 5, 6, 7),
      updatedAt: DateTime.utc(2026, 2, 3, 4, 5, 6, 7, 8),
    );

    await repo.save(project);
    final loaded = await repo.load('p1');

    // Project.== compares every field incl. nested frames/layers.
    expect(loaded, equals(project));
  });

  test('load(missingId) returns null', () async {
    final repo = ProjectRepository(baseDir: freshTemp());
    expect(await repo.load('does-not-exist'), isNull);
  });

  test('list() returns projects most-recently-updated first', () async {
    final repo = ProjectRepository(baseDir: freshTemp());
    // pA has no updatedAt: its sort key falls back to createdAt.
    final pA = buildProject(id: 'a', createdAt: DateTime.utc(2026, 5, 15));
    final pB = buildProject(
      id: 'b',
      createdAt: DateTime.utc(2026, 1, 10),
      updatedAt: DateTime.utc(2026, 6, 20),
    );
    final pC = buildProject(id: 'c', updatedAt: DateTime.utc(2026, 2, 12));
    // Save out of order to prove list() sorts rather than echoing disk order.
    await repo.save(pB);
    await repo.save(pA);
    await repo.save(pC);

    final ids = (await repo.list()).map((p) => p.id).toList();

    // Keys: B=Jun, A=May(createdAt fallback), C=Feb → descending.
    expect(ids, ['b', 'a', 'c']);
  });

  test('list() sort key is monotonically non-increasing', () async {
    final repo = ProjectRepository(baseDir: freshTemp());
    for (var i = 0; i < 5; i++) {
      await repo.save(
        buildProject(id: 'p$i', updatedAt: DateTime.utc(2026, 1, 1 + i)),
      );
    }
    final listed = await repo.list();
    for (var i = 1; i < listed.length; i++) {
      final prev = listed[i - 1].updatedAt!;
      final cur = listed[i].updatedAt!;
      expect(prev.isAfter(cur) || prev.isAtSameMomentAs(cur), isTrue);
    }
  });

  test(
    'a corrupt manifest is quarantined to .json.corrupt and skipped',
    () async {
      final base = freshTemp();
      final repo = ProjectRepository(baseDir: base);
      await repo.save(
        buildProject(id: 'good', updatedAt: DateTime.utc(2026, 1, 9)),
      );

      final dir = projectsDirOf(base);
      final corrupt = File('${dir.path}/broken.json')
        ..writeAsStringSync('{ this is : not json');

      final listed = await repo.list();

      // The good project is returned; the corrupt one never crashes list().
      expect(listed.map((p) => p.id), ['good']);
      // Quarantined: original renamed aside so it stops shadowing its id.
      expect(corrupt.existsSync(), isFalse);
      expect(File('${dir.path}/broken.json.corrupt').existsSync(), isTrue);
    },
  );

  test('duplicate() re-ids the document and shares asset/mask paths', () async {
    final repo = ProjectRepository(baseDir: freshTemp());
    final source = buildProject(
      id: 'src',
      name: 'Doodle',
      frames: [
        const Frame(
          id: 'src_f0',
          layers: [
            ImageLayer(
              id: 'src_l0',
              name: 'Photo',
              assetPath: '/assets/img_shared.png',
              maskPath: '/assets/mask_shared.png',
            ),
          ],
        ),
        const Frame(
          id: 'src_f1',
          layers: [
            TextLayer(
              id: 'src_l1',
              name: 'Caption',
              text: 'Hi',
              fontFamily: 'Manrope',
            ),
          ],
        ),
      ],
    );
    await repo.save(source);

    final now = DateTime.utc(2026, 7, 22, 12);
    final copy = await repo.duplicate('src', now: now);

    expect(copy, isNotNull);
    final c = copy!;
    // Fresh project id derived from `now`; name gets the " copy" suffix.
    expect(c.id, 'sm_${now.microsecondsSinceEpoch}');
    expect(c.id, isNot('src'));
    expect(c.name, 'Doodle copy');

    // Fresh frame ids, positionally derived from the new project id.
    expect(c.frames.map((f) => f.id), ['${c.id}_f0', '${c.id}_f1']);
    // Fresh layer ids, sequential across all frames (shared counter).
    final img = c.frames[0].layers[0] as ImageLayer;
    final txt = c.frames[1].layers[0] as TextLayer;
    expect(img.id, '${c.id}_l0');
    expect(txt.id, '${c.id}_l1');
    expect({img.id, txt.id}.intersection({'src_l0', 'src_l1'}), isEmpty);

    // Asset/mask paths are shared verbatim — never renamed or re-copied.
    expect(img.assetPath, '/assets/img_shared.png');
    expect(img.maskPath, '/assets/mask_shared.png');

    // The copy is persisted, not just returned.
    expect(await repo.load(c.id), equals(c));
  });

  test('duplicate() of a missing source returns null', () async {
    final repo = ProjectRepository(baseDir: freshTemp());
    expect(await repo.duplicate('nope'), isNull);
  });

  test('duplicate() of a corrupt source returns null', () async {
    final base = freshTemp();
    final repo = ProjectRepository(baseDir: base);
    final dir = projectsDirOf(base);
    File('${dir.path}/rotten.json').writeAsStringSync('not json at all');

    expect(await repo.duplicate('rotten'), isNull);
  });

  test('delete() removes the manifest file', () async {
    final base = freshTemp();
    final repo = ProjectRepository(baseDir: base);
    await repo.save(buildProject(id: 'gone'));
    final file = File('${projectsDirOf(base).path}/gone.json');
    expect(file.existsSync(), isTrue);

    await repo.delete('gone');

    expect(file.existsSync(), isFalse);
    expect(await repo.load('gone'), isNull);
  });

  test(
    'sweepOrphanAssets deletes only unreferenced img_/mask_ files',
    () async {
      final base = freshTemp();
      final repo = ProjectRepository(baseDir: base);
      final assets = Directory('${base.path}/projects/assets')
        ..createSync(recursive: true);

      final imgRef = File('${assets.path}/img_ref.png')..writeAsBytesSync([1]);
      final maskRef = File('${assets.path}/mask_ref.png')
        ..writeAsBytesSync([1]);
      final imgOrphan = File('${assets.path}/img_orphan.png')
        ..writeAsBytesSync([1]);
      final maskOrphan = File('${assets.path}/mask_orphan.png')
        ..writeAsBytesSync([1]);
      // Neither img_ nor mask_ prefixed → not sweepable regardless of refs.
      final other = File('${assets.path}/thumb_orphan.png')
        ..writeAsBytesSync([1]);

      await repo.save(
        Project(
          id: 'owner',
          name: 'Owner',
          createdAt: DateTime.utc(2026, 1, 5),
          updatedAt: DateTime.utc(2026, 1, 5),
          frames: [
            Frame(
              id: 'owner_f0',
              layers: [
                ImageLayer(
                  id: 'owner_l0',
                  name: 'Photo',
                  assetPath: imgRef.path,
                  maskPath: maskRef.path,
                ),
              ],
            ),
          ],
        ),
      );

      final deleted = await repo.sweepOrphanAssets(minAge: Duration.zero);

      expect(deleted, 2);
      expect(imgRef.existsSync(), isTrue);
      expect(maskRef.existsSync(), isTrue);
      expect(other.existsSync(), isTrue);
      expect(imgOrphan.existsSync(), isFalse);
      expect(maskOrphan.existsSync(), isFalse);
    },
  );

  test('sweepOrphanAssets keeps files younger than minAge', () async {
    final base = freshTemp();
    final repo = ProjectRepository(baseDir: base);
    final assets = Directory('${base.path}/projects/assets')
      ..createSync(recursive: true);
    final young = File('${assets.path}/img_young.png')..writeAsBytesSync([1]);

    // Just-created orphan is inside the min-age window → kept.
    final deleted = await repo.sweepOrphanAssets(
      minAge: const Duration(hours: 1),
    );

    expect(deleted, 0);
    expect(young.existsSync(), isTrue);
  });

  test('sweepOrphanAssets aborts when a manifest is unparseable', () async {
    final base = freshTemp();
    final repo = ProjectRepository(baseDir: base);
    final dir = projectsDirOf(base);
    final assets = Directory('${dir.path}/assets')..createSync(recursive: true);
    final orphan = File('${assets.path}/img_orphan.png')..writeAsBytesSync([1]);
    File('${dir.path}/bad.json').writeAsStringSync('{ broken');

    final deleted = await repo.sweepOrphanAssets(minAge: Duration.zero);

    // A corrupt manifest's references are invisible — deleting would be unsafe.
    expect(deleted, 0);
    expect(orphan.existsSync(), isTrue);
  });

  test(
    'sweepOrphanAssets aborts when a .json.corrupt quarantine exists',
    () async {
      final base = freshTemp();
      final repo = ProjectRepository(baseDir: base);
      final dir = projectsDirOf(base);
      final assets = Directory('${dir.path}/assets')
        ..createSync(recursive: true);
      final orphan = File('${assets.path}/mask_orphan.png')
        ..writeAsBytesSync([1]);
      File('${dir.path}/old.json.corrupt').writeAsStringSync('irrelevant');

      final deleted = await repo.sweepOrphanAssets(minAge: Duration.zero);

      expect(deleted, 0);
      expect(orphan.existsSync(), isTrue);
    },
  );
}
