import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/models/frame.dart';
import '../../core/models/layer.dart';
import '../../core/models/project.dart';
import '../../core/persistence/atomic_file.dart';

/// Persists [Project]s as JSON manifests under the app documents
/// directory (`.../projects/<id>.json`). Image bytes are referenced by absolute
/// path in the manifest (written by the import service), so they survive
/// relaunches. Pass [baseDir] in tests to use a temp directory.
class ProjectRepository {
  ProjectRepository({Directory? baseDir}) : _baseOverride = baseDir;

  final Directory? _baseOverride;

  Future<Directory> _dir() async {
    final base = _baseOverride ?? await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/projects');
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  File _file(Directory dir, String id) => File('${dir.path}/$id.json');

  /// Atomically replaces `<id>.json` (see [writeFileAtomically]). The editor
  /// autosaves on a debounce, so a mid-write kill must never leave a truncated
  /// manifest where the last good one was.
  Future<void> save(Project project) async {
    final dir = await _dir();
    await writeFileAtomically(
      _file(dir, project.id),
      jsonEncode(project.toJson()),
    );
  }

  /// All saved projects, most-recently-updated first. A manifest that fails to
  /// parse is quarantined (best-effort) to `<id>.json.corrupt` so it stops
  /// shadowing its id - a later [save] of the same project recovers the slot -
  /// and stays on disk for inspection. `*.tmp` / `*.corrupt` files are never
  /// listed.
  Future<List<Project>> list() async {
    final dir = await _dir();
    final result = <Project>[];
    for (final entity in dir.listSync()) {
      // `.json.tmp` / `.json.corrupt` don't match the `.json` suffix check.
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      final Project? project;
      try {
        project = await _tryParse(entity);
      } on FileSystemException {
        continue; // transient read failure - retry next launch, do not rename
      }
      if (project != null) {
        result.add(project);
        continue;
      }
      // Move it aside so it stops shadowing its id, and keep going.
      try {
        await entity.rename('${entity.path}.corrupt');
      } catch (_) {
        // Best-effort - if the rename fails we still skip the file.
      }
    }
    // A manifest quarantined by an older build (or by a version whose schema
    // could not read it) may parse now. Un-quarantining is what makes a
    // downgrade-then-upgrade recoverable instead of a permanent loss - the
    // rename is one-way, so without this the project never comes back.
    for (final entity in dir.listSync()) {
      if (entity is! File || !entity.path.endsWith('.json.corrupt')) continue;
      final Project? project;
      try {
        project = await _tryParse(entity);
      } on FileSystemException {
        continue;
      }
      if (project == null) continue;
      try {
        await entity.rename(_file(dir, project.id).path);
      } catch (_) {
        // Could not restore the name; it is still readable, so list it anyway.
      }
      result.add(project);
    }
    DateTime key(Project p) => p.updatedAt ?? p.createdAt ?? DateTime.utc(1970);
    result.sort((a, b) => key(b).compareTo(key(a)));
    return result;
  }

  /// Reads and parses a manifest, returning null when the CONTENT is bad.
  ///
  /// An I/O failure rethrows instead: quarantining renames the file, and doing
  /// that because a read momentarily failed (low memory, a locked handle) would
  /// turn a transient error into a project the user has to recover by hand.
  /// Only a genuine parse failure is the manifest's own fault.
  static Future<Project?> _tryParse(File file) async {
    final String text;
    try {
      text = await file.readAsString();
    } on FileSystemException {
      rethrow;
    }
    try {
      final map = (jsonDecode(text) as Map).cast<String, dynamic>();
      return Project.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<Project?> load(String id) async {
    final dir = await _dir();
    final file = _file(dir, id);
    if (!file.existsSync()) return null;
    final map = (jsonDecode(await file.readAsString()) as Map)
        .cast<String, dynamic>();
    return Project.fromJson(map);
  }

  /// Saves a deep copy of project [id] under fresh ids - a new project id and
  /// new ids for every frame and layer - named `<old> copy`.
  ///
  /// Large `img_*` files are SHARED with the source, never re-copied:
  /// [sweepOrphanAssets] refcounts paths across all manifests, so a shared
  /// photo survives until the last project referencing it is gone.
  ///
  /// `mask_*` files are COPIED, because that refcount is not the only thing
  /// that deletes them. The editor runs its own in-session mask GC
  /// ([EditorController.isMaskReferenced] + [MaskStore.collect]), and that GC
  /// can only see the open document and its undo stacks - it has no
  /// cross-manifest view. With a shared mask, one erase stroke in either copy
  /// superseded the PNG and unlinked it out from under the other project, which
  /// then rendered and exported with its background back, silently and
  /// unrecoverably. Masks are small (one alpha channel, PNG-compressed) next to
  /// the photos they belong to, so copying them is the cheap half of the fix.
  ///
  /// Returns the copy, or null when the source manifest is missing/corrupt.
  ///
  /// [copyLabel] is the word appended to the name; UI callers pass the
  /// localized one. It defaults to English so the repository stays usable (and
  /// testable) without a BuildContext to resolve strings from.
  Future<Project?> duplicate(
    String id, {
    DateTime? now,
    String copyLabel = 'copy',
  }) async {
    final Project? source;
    try {
      source = await load(id);
    } catch (_) {
      return null; // unreadable manifest - nothing to duplicate
    }
    if (source == null) return null;
    final dir = await _dir();
    final at = now ?? DateTime.now();
    final newId = 'sm_${at.microsecondsSinceEpoch}';
    var layerSeq = 0;

    Future<Layer> freshLayer(Layer layer) async {
      final layerId = '${newId}_l${layerSeq++}';
      return switch (layer) {
        ImageLayer() => layer.copyWith(
          id: layerId,
          maskPath: await _copyMask(dir, layer.maskPath, layerId),
        ),
        TextLayer() => layer.copyWith(id: layerId),
        BubbleLayer() => layer.copyWith(id: layerId),
      };
    }

    final frames = <Frame>[];
    for (final (i, frame) in source.frames.indexed) {
      final layers = <Layer>[];
      for (final layer in frame.layers) {
        layers.add(await freshLayer(layer));
      }
      frames.add(Frame(id: '${newId}_f$i', layers: layers));
    }

    // copyWith, not a fresh Project(...): re-listing fields silently dropped
    // canvasWidth/canvasHeight/fps (a duplicated 1080x1920 project came back
    // 512x512 at 8fps) and would drop `grid` the same way.
    final copy = source.copyWith(
      id: newId,
      name: '${source.name} $copyLabel',
      createdAt: at,
      updatedAt: at,
      frames: frames,
    );
    await save(copy);
    return copy;
  }

  /// Copies a layer's mask PNG so the duplicate owns its own file, returning
  /// the new path.
  ///
  /// Falls back to sharing [maskPath] when there is nothing to copy (a mask the
  /// user already lost) or the copy fails: a duplicate that shares a mask is
  /// the old, occasionally-lossy behaviour, whereas one pointing at a file that
  /// was never written would show no cut-out at all.
  static Future<String?> _copyMask(
    Directory dir,
    String? maskPath,
    String layerId,
  ) async {
    if (maskPath == null) return null;
    try {
      final source = File(maskPath);
      if (!source.existsSync()) return maskPath;
      final assets = Directory('${dir.path}/assets');
      if (!assets.existsSync()) await assets.create(recursive: true);
      // Same shape as MaskStore.save's names, so the sweep's `mask_` prefix
      // check and anyone grepping the assets dir still recognise it.
      final stamp = DateTime.now().microsecondsSinceEpoch;
      final dest = '${assets.path}/mask_${layerId}_$stamp.png';
      await source.copy(dest);
      return dest;
    } catch (_) {
      return maskPath;
    }
  }

  Future<void> delete(String id) async {
    final dir = await _dir();
    final file = _file(dir, id);
    if (file.existsSync()) await file.delete();
    // A deleted project's unshared images/masks are now orphans - sweep them.
    await sweepOrphanAssets();
  }

  /// Deletes `img_*` / `mask_*` files in the shared `assets/` dir that no
  /// frame of any saved project references (#76). Reference counting is
  /// implicit: a file referenced by ANY manifest (frames legitimately share
  /// paths after duplication) is kept.
  ///
  /// Safety rules:
  /// - Call only when no editor session is active (project delete, cold
  ///   launch): in-memory undo stacks may point at mask files a saved
  ///   manifest no longer does.
  /// - Files younger than [minAge] are always kept - an import may not have
  ///   reached a (debounce-saved) manifest yet.
  /// - Quarantined `.json.corrupt` manifests are READ, not skipped - their
  ///   references count. The sweep aborts only for bytes that will not decode
  ///   as JSON at all, whose references genuinely cannot be recovered.
  ///
  /// The directory iteration + manifest parsing run inside [Isolate.run], so
  /// the cold-launch call in `main()` never blocks the UI isolate however
  /// large the asset dir has grown.
  ///
  /// Returns the number of files deleted.
  Future<int> sweepOrphanAssets({
    Duration minAge = const Duration(minutes: 10),
  }) async {
    final dirPath = (await _dir()).path;
    return Isolate.run(() => _sweepOrphanAssetsSync(dirPath, minAge));
  }

  /// Synchronous sweep body - safe to run on a worker isolate (`dart:io`
  /// only, no platform channels; the resolved base dir path is passed in).
  static int _sweepOrphanAssetsSync(String dirPath, Duration minAge) {
    final dir = Directory(dirPath);
    final assets = Directory('$dirPath/assets');
    if (!assets.existsSync()) return 0;

    final referenced = <String>{};
    for (final entity in dir.listSync()) {
      if (entity is! File) continue;
      // Quarantined manifests are read too, not treated as a wall. Most are
      // quarantined because `Project.fromJson` rejected the SCHEMA, not because
      // the bytes are unreadable - and [_collectAssetRefs] walks raw decoded
      // JSON, so it recovers their paths regardless of schema. Skipping them
      // outright is what turned one bad manifest into a permanent GC outage:
      // both callers (cold launch and project delete) became no-ops for the
      // life of the install, so "delete projects to free space" reclaimed
      // nothing.
      final relevant =
          entity.path.endsWith('.json') ||
          entity.path.endsWith('.json.corrupt');
      if (!relevant) continue;
      try {
        _collectAssetRefs(jsonDecode(entity.readAsStringSync()), referenced);
      } catch (_) {
        // Bytes that will not even decode as JSON: their references really are
        // invisible, and deleting an asset some recoverable project still needs
        // is worse than keeping an orphan. This one still aborts.
        return 0;
      }
    }

    var deleted = 0;
    final now = DateTime.now();
    for (final entity in assets.listSync()) {
      if (entity is! File) continue;
      final name = _basename(entity.path);
      final sweepable = name.startsWith('img_') || name.startsWith('mask_');
      if (!sweepable || referenced.contains(name)) continue;
      try {
        if (now.difference(entity.statSync().modified) < minAge) continue;
        entity.deleteSync();
        deleted++;
      } catch (_) {
        // Locked or already-gone file - skip, next sweep retries.
      }
    }
    return deleted;
  }

  /// Recursively collects the basenames of every `assetPath` / `maskPath`
  /// string in a decoded manifest - schema-agnostic on purpose, so future
  /// layer types with image references stay covered as long as they use the
  /// same key names.
  static void _collectAssetRefs(Object? node, Set<String> out) {
    if (node is Map) {
      node.forEach((key, value) {
        if ((key == 'assetPath' || key == 'maskPath') && value is String) {
          out.add(_basename(value));
        } else {
          _collectAssetRefs(value, out);
        }
      });
    } else if (node is List) {
      for (final item in node) {
        _collectAssetRefs(item, out);
      }
    }
  }

  /// Last path segment, tolerant of both `/` and `\` separators.
  static String _basename(String path) => path.split('/').last.split('\\').last;
}

final projectRepositoryProvider = Provider<ProjectRepository>(
  (ref) => ProjectRepository(),
);

/// The saved projects shown on Home. Invalidate after a save/delete to refresh.
final savedProjectsProvider = FutureProvider<List<Project>>(
  (ref) => ref.watch(projectRepositoryProvider).list(),
);
