import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/frame.dart';
import '../../../core/models/grid.dart';
import '../../../core/models/image_adjustments.dart';
import '../../../core/models/layer.dart';
import '../../../core/models/layer_effects.dart';
import '../../../core/models/layer_transform.dart';
import '../../../core/models/photo_filter.dart';
import '../../../core/models/project.dart';
import '../../../core/rendering/canvas_geometry.dart';
import '../../grid/grid_refit.dart';
import '../../grid/grid_templates.dart';
import 'editor_state.dart';
import 'editor_tool.dart';

/// Owns the editor document and drives every mutation. All document edits go
/// through [_commit], which records an immutable snapshot for undo/redo (#20).
/// Continuous gestures (slider drags, typing) coalesce into a single history
/// step via a coalesce key, reset at interaction boundaries and by [endEdit].
class EditorController extends Notifier<EditorState> {
  /// Optional seed project (used by the route / tests). Defaults to a blank
  /// document when absent (see [_demoProject]).
  EditorController([this._seed]);

  final Project? _seed;
  int _seq = 0;

  static const int _maxHistory = 50;
  final List<Project> _undoStack = [];
  final List<Project> _redoStack = [];
  String? _coalesceKey;

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  String _newId(String prefix) => '${prefix}_${_seq++}';

  @override
  EditorState build() {
    final project = _seed ?? _demoProject();
    return EditorState(project: project);
  }

  /// Fallback document when the editor is opened without a loaded project
  /// (the normal Home/drawer flows always call [loadProject] first). A blank
  /// canvas - the user imports a photo to begin.
  Project _demoProject() {
    return Project(
      id: 'demo',
      name: 'Untitled',
      frames: [Frame(id: _newId('f'))],
    );
  }

  // ------------------------------------------------------------ history
  /// Commits a new document, recording history. When [coalesce] matches the
  /// previous commit's key, the two fold into one undo step (e.g. a drag).
  void _commit(Project next, {String? coalesce, bool clearSelection = false}) {
    final coalescing =
        coalesce != null && coalesce == _coalesceKey && _undoStack.isNotEmpty;
    if (!coalescing) {
      _undoStack.add(state.project);
      if (_undoStack.length > _maxHistory) _undoStack.removeAt(0);
    }
    _coalesceKey = coalesce;
    _redoStack.clear();
    state = state.copyWith(project: next, clearSelection: clearSelection);
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(state.project);
    final prev = _undoStack.removeLast();
    _coalesceKey = null;
    state = state.copyWith(project: prev, clearSelection: true);
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(state.project);
    final next = _redoStack.removeLast();
    _coalesceKey = null;
    state = state.copyWith(project: next, clearSelection: true);
  }

  /// Ends a continuous edit (e.g. a slider drag), so the next edit starts a
  /// fresh undo step.
  void endEdit() => _coalesceKey = null;

  /// Replaces the current document (e.g. opening a saved project), resetting
  /// history. Bumps the id counter past any loaded ids to avoid collisions.
  void loadProject(Project project) {
    _undoStack.clear();
    _redoStack.clear();
    _coalesceKey = null;
    for (final frame in project.frames) {
      _bumpSeqPast(frame.id);
      for (final layer in frame.layers) {
        _bumpSeqPast(layer.id);
      }
    }
    // A collage opens on its Grid tool: layout, count and border are the first
    // things you reach for, and the tool is invisible on ordinary projects.
    state = EditorState(
      project: project,
      tool: project.isGrid ? EditorTool.grid : EditorTool.adjust,
    );
  }

  void _bumpSeqPast(String id) {
    final i = id.lastIndexOf('_');
    if (i < 0) return;
    final n = int.tryParse(id.substring(i + 1));
    if (n != null && n >= _seq) _seq = n + 1;
  }

  // ------------------------------------------------------------ UI state
  void setTool(EditorTool tool) {
    _coalesceKey = null;
    state = state.copyWith(tool: tool);
  }

  void selectLayer(String? id) {
    _coalesceKey = null;
    state = state.copyWith(selectedLayerId: id, clearSelection: id == null);
  }

  // ------------------------------------------------------------ layer ops
  void _mutateLayers(
    List<Layer> Function(List<Layer>) transform, {
    String? coalesce,
  }) {
    final frames = [...state.project.frames];
    final index = state.project.safeFrameIndex;
    frames[index] = frames[index].copyWith(
      layers: transform(frames[index].layers),
    );
    _commit(state.project.copyWith(frames: frames), coalesce: coalesce);
  }

  /// When true, layers added via the Add menu are inserted onto **every** frame
  /// (a fresh id per frame) - the basis for animating one caption across frames.
  /// Toggled from the Frames panel; only takes effect on animated projects.
  bool addToAllFrames = false;

  /// Adds a layer to the current frame, or - when [addToAllFrames] is on and the
  /// project is animated - a fresh-id copy to every frame, selecting the copy on
  /// the current frame. [make] is called once per target frame.
  T _addLayer<T extends Layer>(T Function() make) {
    if (addToAllFrames && state.project.frameCount > 1) {
      final project = state.project;
      final currentIdx = project.safeFrameIndex;
      late T selected;
      final frames = <Frame>[];
      for (var i = 0; i < project.frames.length; i++) {
        final layer = make();
        if (i == currentIdx) selected = layer;
        frames.add(
          project.frames[i].copyWith(
            layers: [...project.frames[i].layers, layer],
          ),
        );
      }
      _commit(project.copyWith(frames: frames));
      selectLayer(selected.id);
      return selected;
    }
    final layer = make();
    _mutateLayers((layers) => [...layers, layer]);
    selectLayer(layer.id);
    return layer;
  }

  TextLayer addTextLayer({
    String text = 'Text',
    String fontFamily = 'Bangers',
    double fontSize = 40,
  }) => _addLayer(
    () => TextLayer(
      id: _newId('l'),
      name: text,
      text: text,
      fontFamily: fontFamily,
      fontSize: fontSize,
      transform: LayerTransform(position: state.project.canvasCenter),
    ),
  );

  /// With no explicit [name], photos are auto-numbered ("Photo", "Photo 2", …)
  /// against the current frame so multiple image layers stay tellable apart
  /// in the Layers panel (#73). Additional photos land cascade-offset from
  /// center (24 logical px per existing photo, cycling) so a new image never
  /// exactly buries the one below (#74).
  ImageLayer addImageLayer({required String assetPath, String? name}) {
    final resolved = name ?? _nextPhotoName();
    final existing = state.layers.whereType<ImageLayer>().length;
    final cascade = (existing % 5) * 24.0;
    final center = state.project.canvasCenter;
    return _addLayer(
      () => ImageLayer(
        id: _newId('l'),
        name: resolved,
        assetPath: assetPath,
        transform: LayerTransform(position: center + Offset(cascade, cascade)),
      ),
    );
  }

  /// Places a photo into Photo Grid cell [cellId]: centred on the cell and
  /// cover-scaled from [pixels] so it fills the cell edge to edge (the cell
  /// clip hides the spill). Returns null when the project has no grid or no
  /// such cell. Without [pixels] the photo lands at scale 1 - the caller could
  /// not read its size, so leave it as imported rather than guessing.
  ImageLayer? addPhotoToCell({
    required String assetPath,
    required String cellId,
    Size? pixels,
  }) {
    final project = state.project;
    final grid = project.grid;
    if (grid == null) return null;
    final rect = layoutGrid(
      grid,
      Size(project.canvasWidth.toDouble(), project.canvasHeight.toDouble()),
    ).cells[cellId];
    if (rect == null) return null;
    final scale = pixels == null
        ? 1.0
        : photoCoverScale(pixels, rect.width, rect.height);
    final name = _nextPhotoName();
    return _addLayer(
      () => ImageLayer(
        id: _newId('l'),
        name: name,
        assetPath: assetPath,
        cellId: cellId,
        transform: LayerTransform(position: rect.center, scale: scale),
      ),
    );
  }

  /// The smallest unused "Photo N" name on the current frame ("Photo" = N 1).
  String _nextPhotoName() {
    final names = state.layers
        .whereType<ImageLayer>()
        .map((l) => l.name)
        .toSet();
    if (!names.contains('Photo')) return 'Photo';
    var n = 2;
    while (names.contains('Photo $n')) {
      n++;
    }
    return 'Photo $n';
  }

  /// Drops an [emoji] onto the canvas as a decorative (no outline/shadow) text
  /// layer from the glyph library (#61). Centered, large, and selected.
  TextLayer addEmoji(String emoji, {double fontSize = 96}) => _addLayer(
    () => TextLayer(
      id: _newId('l'),
      name: emoji,
      text: emoji,
      fontFamily: 'Rubik',
      fontSize: fontSize,
      decorative: true,
      transform: LayerTransform(position: state.project.canvasCenter),
    ),
  );

  void removeLayer(String id) {
    _mutateLayers((layers) => layers.where((l) => l.id != id).toList());
    if (state.selectedLayerId == id) selectLayer(null);
  }

  /// How far a duplicated layer is nudged from its source, in logical px, so
  /// the copy never exactly buries the original.
  static const double duplicateNudge = 16;

  /// Inserts a fresh-id copy of layer [id] directly above the source (one
  /// z-slot later in the bottom-to-top list), nudged by [duplicateNudge], and
  /// selects it. A single undoable step.
  void duplicateLayer(String id) {
    final index = state.layers.indexWhere((l) => l.id == id);
    if (index < 0) return;
    final source = state.layers[index];
    final nudged = source.transform.copyWith(
      position: source.transform.position.translate(
        duplicateNudge,
        duplicateNudge,
      ),
    );
    final clone = _cloneWithNewId(source);
    final copy = switch (clone) {
      ImageLayer() => clone.copyWith(transform: nudged),
      TextLayer() => clone.copyWith(transform: nudged),
      BubbleLayer() => clone.copyWith(transform: nudged),
    };
    _mutateLayers((layers) => [...layers]..insert(index + 1, copy));
    selectLayer(copy.id);
  }

  void reorderLayer(int oldIndex, int newIndex) {
    _mutateLayers((layers) {
      final next = [...layers];
      final item = next.removeAt(oldIndex);
      next.insert(newIndex.clamp(0, next.length), item);
      return next;
    });
  }

  void toggleVisibility(String id) => _updateLayer(
    id,
    image: (l) => l.copyWith(visible: !l.visible),
    text: (l) => l.copyWith(visible: !l.visible),
    bubble: (l) => l.copyWith(visible: !l.visible),
  );

  void setOpacity(String id, double opacity) => _updateLayer(
    id,
    coalesce: 'opacity:$id',
    image: (l) => l.copyWith(opacity: opacity),
    text: (l) => l.copyWith(opacity: opacity),
    bubble: (l) => l.copyWith(opacity: opacity),
  );

  void updateTransform(String id, LayerTransform transform) => _updateLayer(
    id,
    coalesce: 'transform:$id',
    image: (l) => l.copyWith(transform: transform),
    text: (l) => l.copyWith(transform: transform),
    bubble: (l) => l.copyWith(transform: transform),
  );

  Layer _withTransform(Layer l, LayerTransform t) => switch (l) {
    ImageLayer() => l.copyWith(transform: t),
    TextLayer() => l.copyWith(transform: t),
    BubbleLayer() => l.copyWith(transform: t),
  };

  /// Changes the canvas size. With [scaleContent] the whole composition is
  /// resampled - layer positions and scales multiply by the size ratio so it
  /// keeps its relative layout (the "resize to N px" path). Without it the
  /// canvas simply grows/shrinks around the layers in place.
  void setCanvasSize(int width, int height, {bool scaleContent = false}) {
    final project = state.project;
    final w = width.clamp(
      Project.minCanvasDimension,
      Project.maxCanvasDimension,
    );
    final h = height.clamp(
      Project.minCanvasDimension,
      Project.maxCanvasDimension,
    );
    if (w == project.canvasWidth && h == project.canvasHeight) return;
    if (!scaleContent) {
      _commit(project.copyWith(canvasWidth: w, canvasHeight: h));
      return;
    }
    final sx = w / project.canvasWidth;
    final sy = h / project.canvasHeight;
    final layerScale = (sx + sy) / 2;
    final frames = project.frames
        .map(
          (f) => f.copyWith(
            layers: f.layers.map((l) {
              final t = l.transform;
              return _withTransform(
                l,
                t.copyWith(
                  position: Offset(t.position.dx * sx, t.position.dy * sy),
                  scale: t.scale * layerScale,
                ),
              );
            }).toList(),
          ),
        )
        .toList();
    _commit(project.copyWith(canvasWidth: w, canvasHeight: h, frames: frames));
  }

  /// Resizes the canvas to [newWidth]×[newHeight] keeping the composition
  /// centered - every layer shifts by half the size delta (a center crop or
  /// extend, unlike [setCanvasSize]'s top-left-anchored resize).
  void cropCanvas(int newWidth, int newHeight) {
    final project = state.project;
    final w = newWidth.clamp(
      Project.minCanvasDimension,
      Project.maxCanvasDimension,
    );
    final h = newHeight.clamp(
      Project.minCanvasDimension,
      Project.maxCanvasDimension,
    );
    if (w == project.canvasWidth && h == project.canvasHeight) return;
    final shift = Offset(
      (w - project.canvasWidth) / 2,
      (h - project.canvasHeight) / 2,
    );
    final frames = project.frames
        .map(
          (f) => f.copyWith(
            layers: f.layers
                .map(
                  (l) => _withTransform(
                    l,
                    l.transform.copyWith(
                      position: l.transform.position + shift,
                    ),
                  ),
                )
                .toList(),
          ),
        )
        .toList();
    _commit(project.copyWith(canvasWidth: w, canvasHeight: h, frames: frames));
  }

  /// Crops the canvas to an arbitrary [rect] in canvas-logical space (top-left
  /// origin). The new canvas is `rect.size` and every layer shifts by
  /// `-rect.topLeft`, so retained content keeps its position. Used by the
  /// freeform drag-crop; [cropCanvas] is the centered aspect-preset variant.
  void cropCanvasRect(Rect rect) {
    final project = state.project;
    final w = rect.width.round().clamp(
      Project.minCanvasDimension,
      Project.maxCanvasDimension,
    );
    final h = rect.height.round().clamp(
      Project.minCanvasDimension,
      Project.maxCanvasDimension,
    );
    final shift = -rect.topLeft;
    if (w == project.canvasWidth &&
        h == project.canvasHeight &&
        shift == Offset.zero) {
      return;
    }
    final frames = project.frames
        .map(
          (f) => f.copyWith(
            layers: f.layers
                .map(
                  (l) => _withTransform(
                    l,
                    l.transform.copyWith(
                      position: l.transform.position + shift,
                    ),
                  ),
                )
                .toList(),
          ),
        )
        .toList();
    _commit(project.copyWith(canvasWidth: w, canvasHeight: h, frames: frames));
  }

  void updateTextLayer(
    String id, {
    String? text,
    String? fontFamily,
    double? fontSize,
    Color? color,
  }) => _updateLayer(
    id,
    coalesce: 'text:$id',
    text: (l) => l.copyWith(
      text: text,
      name: text,
      fontFamily: fontFamily,
      fontSize: fontSize,
      color: color,
    ),
  );

  void renameLayer(String id, String name) => _updateLayer(
    id,
    image: (l) => l.copyWith(name: name),
    text: (l) => l.copyWith(name: name),
    bubble: (l) => l.copyWith(name: name),
  );

  /// Adds a comic speech bubble (centred a little above the canvas middle) and
  /// selects it.
  BubbleLayer addBubbleLayer({
    String text = '',
    BubbleShape shape = BubbleShape.speech,
  }) => _addLayer(
    () => BubbleLayer(
      id: _newId('l'),
      name: text.isEmpty ? 'Bubble' : text,
      text: text,
      shape: shape,
      transform: LayerTransform(
        position: state.project.canvasCenter - const Offset(0, 36),
      ),
    ),
  );

  void updateBubbleLayer(
    String id, {
    String? text,
    BubbleShape? shape,
    String? fontFamily,
    double? fontSize,
    Color? fillColor,
    Color? strokeColor,
    Color? textColor,
    Offset? tail,
  }) {
    // Coalesce per property group, not per bubble - otherwise shape → fill →
    // typing all collapsed into one giant undo step (#82).
    final group = text != null
        ? 'text'
        : shape != null
        ? 'shape'
        : tail != null
        ? 'tail'
        : fontSize != null
        ? 'size'
        : fontFamily != null
        ? 'font'
        : 'color';
    _updateLayer(
      id,
      coalesce: 'bubble:$id:$group',
      bubble: (l) => l.copyWith(
        text: text,
        // Mirror the layer name, but never rename to '' when the caption is
        // cleared (#82) - keep the last non-empty name instead.
        name: text == null || text.trim().isEmpty ? null : text,
        shape: shape,
        fontFamily: fontFamily,
        fontSize: fontSize,
        fillColor: fillColor,
        strokeColor: strokeColor,
        textColor: textColor,
        tail: tail,
      ),
    );
  }

  void updateImageAdjustments(String id, ImageAdjustments adjustments) =>
      _updateLayer(
        id,
        coalesce: 'adjust:$id',
        image: (l) => l.copyWith(adjustments: adjustments),
      );

  /// Sets the one-tap look on a photo layer. A fresh pick restores full
  /// strength, so tapping a filter always shows what it actually does; picking
  /// [PhotoFilter.none] clears it.
  void setPhotoFilter(String id, PhotoFilter filter, {double? strength}) =>
      _updateLayer(
        id,
        image: (l) => l.copyWith(
          adjustments: l.adjustments.copyWith(
            filter: filter,
            filterStrength: strength ?? 1.0,
          ),
        ),
      );

  void setFilterStrength(String id, double strength) => _updateLayer(
    id,
    coalesce: 'filterStrength:$id',
    image: (l) => l.copyWith(
      adjustments: l.adjustments.copyWith(filterStrength: strength),
    ),
  );

  void setHdr(String id, double amount) => _updateLayer(
    id,
    coalesce: 'hdr:$id',
    image: (l) => l.copyWith(adjustments: l.adjustments.copyWith(hdr: amount)),
  );

  void updateVignette(
    String id, {
    double? amount,
    Color? color,
    double? size,
    double? softness,
  }) => _updateLayer(
    id,
    coalesce: 'vignette:$id',
    image: (l) => l.copyWith(
      vignette: l.vignette.copyWith(
        amount: amount,
        color: color,
        size: size,
        softness: softness,
      ),
    ),
  );

  /// Sets the contour drawn around a layer (logical px; 0 disables). On a
  /// cut-out it hugs the subject, on a plain photo it frames the photo.
  /// Coalesces consecutive slider ticks into one undo step.
  void updateLayerStroke(
    String id, {
    double? width,
    Color? color,
    double? opacity,
  }) => _updateEffects(
    id,
    coalesce: 'stroke:$id',
    (e) => e.copyWith(
      stroke: e.stroke.copyWith(width: width, color: color, opacity: opacity),
    ),
  );

  void updateLayerShadow(
    String id, {
    bool? enabled,
    double? angle,
    double? distance,
    double? blur,
    double? density,
    Color? color,
    double? opacity,
  }) => _updateEffects(
    id,
    coalesce: 'shadow:$id',
    (e) => e.copyWith(
      shadow: e.shadow.copyWith(
        // Touching any control arms the shadow: a user dragging Distance with
        // the effect off would otherwise see nothing happen.
        enabled: enabled ?? true,
        angle: angle,
        distance: distance,
        blur: blur,
        density: density,
        color: color,
        opacity: opacity,
      ),
    ),
  );

  void setLayerBlend(String id, LayerBlend blend) =>
      _updateEffects(id, (e) => e.copyWith(blend: blend));

  /// Clears every look applied to a layer - filter, HDR, vignette, shadow,
  /// contour and blend - in one undoable step. The manual Adjust sliders are
  /// deliberately left alone: they belong to the other panel.
  void resetLayerEffects(String id) => _updateLayer(
    id,
    image: (l) => l.copyWith(
      effects: LayerEffects.none,
      vignette: Vignette.none,
      adjustments: l.adjustments.copyWith(
        filter: PhotoFilter.none,
        filterStrength: 1,
        hdr: 0,
      ),
    ),
    text: (l) => l.copyWith(effects: LayerEffects.none),
    bubble: (l) => l.copyWith(effects: LayerEffects.none),
  );

  /// Sets the caption outline. [autoColor] returns it to the automatic
  /// contrast pick (dark under light fills, white otherwise).
  void updateTextStroke(
    String id, {
    double? width,
    Color? color,
    bool autoColor = false,
    double? opacity,
  }) => _updateLayer(
    id,
    coalesce: 'textStroke:$id',
    text: (l) => l.copyWith(
      strokeWidth: width,
      strokeColor: color,
      autoStrokeColor: autoColor,
      strokeOpacity: opacity,
    ),
  );

  /// Applies [change] to any layer type's shared effects block.
  void _updateEffects(
    String id,
    LayerEffects Function(LayerEffects) change, {
    String? coalesce,
  }) => _updateLayer(
    id,
    coalesce: coalesce,
    image: (l) => l.copyWith(effects: change(l.effects)),
    text: (l) => l.copyWith(effects: change(l.effects)),
    bubble: (l) => l.copyWith(effects: change(l.effects)),
  );

  void setImageMask(String id, String? maskPath) => _updateLayer(
    id,
    image: (l) => maskPath == null
        ? l.copyWith(clearMask: true)
        : l.copyWith(maskPath: maskPath),
  );

  /// Sets the per-layer crop (normalized 0..1 image coords) for an image layer;
  /// pass the full rect to clear it.
  void setImageCrop(String id, Rect crop) =>
      _updateLayer(id, image: (l) => l.copyWith(cropRect: crop));

  /// Replaces the layer's source photo (e.g. after generative fill), keeping its
  /// transform, mask, crop and adjustments.
  void replaceImageAsset(String id, String assetPath) =>
      _updateLayer(id, image: (l) => l.copyWith(assetPath: assetPath));

  /// Swaps each group of [merges] for one image layer holding its rendered
  /// pixels, in a single undo step. The replacement takes the z-slot of the
  /// LOWEST layer it replaces, so a merge never reorders the stack around it,
  /// and inherits that layer's cell so a collage keeps its partition.
  ///
  /// The caller renders the bytes (see `LayerFlattener`); this method only does
  /// the document surgery, which keeps the controller free of async I/O.
  void applyMerges(List<MergedLayerSpec> merges) {
    if (merges.isEmpty) return;
    final project = state.project;
    final scale = layerCoverScale;
    final center = project.canvasCenter;
    // id → the merge that consumes it, so one pass over the layer list is
    // enough no matter how many groups a flatten produced.
    final owner = <String, MergedLayerSpec>{};
    for (final merge in merges) {
      for (final id in merge.ids) {
        owner[id] = merge;
      }
    }
    final built = <MergedLayerSpec, ImageLayer>{};
    String? lastId;
    _mutateLayers((layers) {
      final next = <Layer>[];
      for (final layer in layers) {
        final merge = owner[layer.id];
        if (merge == null) {
          next.add(layer);
          continue;
        }
        if (built.containsKey(merge)) continue; // already emitted, drop
        final merged = ImageLayer(
          id: _newId('l'),
          name: merge.name,
          assetPath: merge.assetPath,
          cellId: layer.cellId,
          transform: LayerTransform(position: center, scale: scale),
        );
        built[merge] = merged;
        lastId = merged.id;
        next.add(merged);
      }
      return next;
    });
    if (lastId != null) selectLayer(lastId);
  }

  /// The layer scale at which a canvas-sized image covers the canvas exactly.
  double get layerCoverScale => photoFitScale(
    Size(
      state.project.canvasWidth.toDouble(),
      state.project.canvasHeight.toDouble(),
    ),
    state.project.canvasWidth,
    state.project.canvasHeight,
  );

  /// Applies a type-specific transform to the matching layer. A callback left
  /// null means "leave that layer type unchanged".
  void _updateLayer(
    String id, {
    ImageLayer Function(ImageLayer)? image,
    TextLayer Function(TextLayer)? text,
    BubbleLayer Function(BubbleLayer)? bubble,
    String? coalesce,
  }) {
    _mutateLayers(
      (layers) => layers.map((layer) {
        if (layer.id != id) return layer;
        return switch (layer) {
          ImageLayer() => image?.call(layer) ?? layer,
          TextLayer() => text?.call(layer) ?? layer,
          BubbleLayer() => bubble?.call(layer) ?? layer,
        };
      }).toList(),
      coalesce: coalesce,
    );
  }

  // ------------------------------------------------------------ frame ops
  Layer _cloneWithNewId(Layer layer) => switch (layer) {
    ImageLayer() => layer.copyWith(id: _newId('l')),
    TextLayer() => layer.copyWith(id: _newId('l')),
    BubbleLayer() => layer.copyWith(id: _newId('l')),
  };

  /// Adds a new frame that duplicates the current one, and selects it.
  void addFrame() {
    final project = state.project;
    final source = project.currentFrame;
    final clone = Frame(
      id: _newId('f'),
      layers: source.layers.map(_cloneWithNewId).toList(),
    );
    final frames = [...project.frames, clone];
    _commit(
      project.copyWith(frames: frames, currentFrameIndex: frames.length - 1),
      clearSelection: true,
    );
  }

  /// Frame navigation - not an undoable document edit.
  void selectFrame(int index) {
    final project = state.project;
    if (index < 0 || index >= project.frames.length) return;
    _coalesceKey = null;
    state = state.copyWith(
      project: project.copyWith(currentFrameIndex: index),
      clearSelection: true,
    );
  }

  void deleteFrame(int index) {
    final project = state.project;
    if (project.frames.length <= 1) return; // keep at least one frame
    final frames = [...project.frames]..removeAt(index);
    // Keep viewing the same frame: deleting one before the current shifts it
    // left by one, so decrement to compensate.
    var current = project.currentFrameIndex;
    if (index < current) current -= 1;
    _commit(
      project.copyWith(
        frames: frames,
        currentFrameIndex: current.clamp(0, frames.length - 1),
      ),
      clearSelection: true,
    );
  }

  /// Inserts a copy of frame [index] right after it, and selects the copy.
  void duplicateFrame(int index) {
    final project = state.project;
    if (index < 0 || index >= project.frames.length) return;
    final source = project.frames[index];
    final clone = Frame(
      id: _newId('f'),
      layers: source.layers.map(_cloneWithNewId).toList(),
    );
    final frames = [...project.frames]..insert(index + 1, clone);
    _commit(
      project.copyWith(frames: frames, currentFrameIndex: index + 1),
      clearSelection: true,
    );
  }

  /// Moves the frame at [oldIndex] to [newIndex] as a single undoable step,
  /// mirroring [reorderLayer]'s list-move. The currently viewed frame stays
  /// selected: its index follows the move (tracked by frame id). Out-of-range
  /// or no-op indices are ignored.
  void reorderFrame(int oldIndex, int newIndex) {
    final project = state.project;
    final frames = project.frames;
    if (oldIndex < 0 || oldIndex >= frames.length) return;
    final target = newIndex.clamp(0, frames.length - 1);
    if (target == oldIndex) return;
    final selectedId = frames[project.safeFrameIndex].id;
    final next = [...frames];
    final moved = next.removeAt(oldIndex);
    next.insert(target, moved);
    final current = next.indexWhere((f) => f.id == selectedId);
    _commit(
      project.copyWith(
        frames: next,
        currentFrameIndex: current < 0 ? project.safeFrameIndex : current,
      ),
    );
  }

  // ------------------------------------------------------------- photo grid
  /// Replaces the grid, carrying every cell's content to its new rect (see
  /// [applyGridSpec]). One undoable step; [coalesce] folds a continuous change
  /// (a slider, a divider drag) into a single entry.
  void setGrid(GridSpec next, {String? coalesce}) {
    if (state.project.grid == next) return;
    _commit(applyGridSpec(state.project, next), coalesce: coalesce);
  }

  /// Switches to another layout of the same photo count. Cell ids are stable,
  /// so photo N stays in cell N and simply moves to that cell's new rect.
  void setGridTemplate(GridNode root) {
    final grid = state.project.grid;
    if (grid == null) return;
    setGrid(grid.copyWith(root: root.withCanonicalIds()));
  }

  /// Changes how many photos the collage holds, landing on that count's default
  /// layout. Growing adds empty cells; shrinking drops the trailing cells'
  /// layers as part of this same undo step.
  void setGridPhotoCount(int count) {
    final grid = state.project.grid;
    final clamped = count.clamp(kMinGridPhotos, kMaxGridPhotos);
    if (grid == null || grid.cellCount == clamped) return;
    setGrid(grid.copyWith(root: defaultGridTemplate(clamped).root));
  }

  /// Frame styling. Deliberately does not move cell content - see
  /// [applyGridSpec]. Coalesced per property so a slider drag is one step.
  void setGridBorder({Color? color, double? width, double? radius}) {
    final grid = state.project.grid;
    if (grid == null) return;
    final group = color != null
        ? 'color'
        : width != null
        ? 'width'
        : 'radius';
    setGrid(
      grid.copyWith(
        borderColor: color,
        borderWidth: width?.clamp(0, GridSpec.maxBorderWidth),
        // The outer frame tracks the gap, which is what "border width" reads
        // as; a separate control for it would be a setting nobody asks for.
        outerMargin: width?.clamp(0, GridSpec.maxOuterMargin),
        cornerRadius: radius?.clamp(0, GridSpec.maxCornerRadius),
      ),
      coalesce: 'grid:$group',
    );
  }

  /// The document as it was when the current divider drag started. Every update
  /// maps from THIS, not from the previous frame, so a long drag cannot
  /// accumulate float drift or slowly distort a pan the user made inside a cell.
  Project? _dividerDragStart;

  void beginDividerDrag() => _dividerDragStart = state.project;

  /// Moves [divider] by [deltaPx] **measured from the drag start**, in
  /// canvas-logical units. Weight moves between the two adjacent cells only;
  /// every other cell keeps its rect, and both cells' content follows.
  void dragDivider(GridDivider divider, double deltaPx) {
    final base = _dividerDragStart ?? state.project;
    final grid = base.grid;
    if (grid == null) return;
    final next = moveDivider(grid, divider, deltaPx);
    if (next == state.project.grid) return;
    _commit(applyGridSpec(base, next), coalesce: 'grid:${divider.key}');
  }

  void endDividerDrag() {
    _dividerDragStart = null;
    endEdit();
  }

  /// Moves layer [layerId] into cell [targetCell], swapping places with
  /// whatever already lives there. One undoable step.
  ///
  /// The moved layer is re-centred on its new cell (a drop reads as "put this
  /// photo here"), while the displaced content keeps its relative placement.
  void moveLayerToCell(String layerId, String targetCell) {
    final project = state.project;
    final grid = project.grid;
    if (grid == null) return;
    final layer = state.layers.where((l) => l.id == layerId).firstOrNull;
    final from = layer?.cellId;
    if (layer == null || from == null || from == targetCell) return;
    final cells = layoutGrid(
      grid,
      Size(project.canvasWidth.toDouble(), project.canvasHeight.toDouble()),
    ).cells;
    final source = cells[from];
    final target = cells[targetCell];
    if (source == null || target == null) return;

    _mutateLayers(
      (layers) => [
        for (final l in layers)
          if (l.id == layerId)
            assignCell(
              l,
              targetCell,
              l.transform.copyWith(
                position: target.center,
                scale: l.transform.scale * _coverFactor(source, target),
              ),
            )
          else if (l.cellId == targetCell)
            assignCell(l, from, refitToCell(l.transform, target, source))
          else if (l.cellId == from)
            assignCell(l, targetCell, refitToCell(l.transform, source, target))
          else
            l,
      ],
    );
  }

  static double _coverFactor(Rect from, Rect to) =>
      math.max(to.width / from.width, to.height / from.height);

  /// Rotates the photos one cell forward, so a collage can be rearranged
  /// without dragging anything.
  void shuffleGridPhotos() {
    if (state.project.grid == null) return;
    _commit(shuffleGridCells(state.project), clearSelection: true);
  }

  /// Renames the project. Blank input is rejected - the old name is kept -
  /// and renaming to the current name is a no-op (no empty undo step).
  void rename(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == state.project.name) return;
    _commit(state.project.copyWith(name: trimmed));
  }

  /// Sets the playback / export frame rate. One coalesced undo step so dragging
  /// or tapping through speeds collapses to a single entry; clamped to the
  /// project's supported range and a no-op when unchanged.
  void setFps(double fps) {
    final clamped = fps.clamp(Project.minFps, Project.maxFps).toDouble();
    if (clamped == state.project.fps) return;
    _commit(state.project.copyWith(fps: clamped), coalesce: 'fps');
  }

  /// True when [maskPath] is still reachable - referenced by the live document
  /// or by any undo/redo snapshot. A superseded mask PNG may be deleted only
  /// while this is false, so an undo/redo can never surface a missing mask
  /// (drives the delete-on-supersede GC in the editor, #review perf 2026-07-19).
  bool isMaskReferenced(String maskPath) {
    bool inProject(Project project) => project.frames.any(
      (frame) => frame.layers.any(
        (layer) => layer is ImageLayer && layer.maskPath == maskPath,
      ),
    );
    return inProject(state.project) ||
        _undoStack.any(inProject) ||
        _redoStack.any(inProject);
  }
}

/// One "merge these layers into that image" instruction for
/// [EditorController.applyMerges].
@immutable
class MergedLayerSpec {
  const MergedLayerSpec({
    required this.ids,
    required this.assetPath,
    required this.name,
  });

  /// The layers being replaced, in z-order (bottom → top).
  final List<String> ids;

  /// The rendered PNG holding their combined pixels.
  final String assetPath;

  final String name;
}

/// Editor state for the active document. Override in tests / the editor route
/// to seed a specific project.
final editorControllerProvider =
    NotifierProvider<EditorController, EditorState>(EditorController.new);
