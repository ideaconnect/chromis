import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/frame.dart';
import '../../../core/models/grid.dart';
import '../../../core/models/layer.dart';
import '../../../core/models/layer_transform.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/checkerboard.dart';
import '../../../l10n/app_localizations.dart';
import '../layer_scale_curve.dart';
import '../state/editor_controller.dart';
import '../state/editor_state.dart';
import '../state/editor_tool.dart';
import 'bubble_view.dart';
import 'project_canvas.dart';

/// The interactive editing surface: renders the current frame and lets the user
/// tap to select a layer and drag / pinch / rotate the selected layer directly
/// on the canvas (#19). Transform edits are undo-coalesced by the controller.
class EditorCanvas extends ConsumerStatefulWidget {
  const EditorCanvas({
    super.key,
    required this.onEmptyTap,
    required this.dropPlaceholder,
    this.onEmptyCellTap,
    this.onEraseStroke,
    this.onObjectTap,
    this.onionFrame,
  });

  /// Tapped when the canvas has no layers (kick off image import).
  final VoidCallback onEmptyTap;

  /// Tapped with the id of an EMPTY Photo Grid cell - the cell is the
  /// invitation to add a photo, so a tap imports straight into it.
  final void Function(String cellId)? onEmptyCellTap;

  /// Placeholder shown on an empty canvas.
  final Widget dropPlaceholder;

  /// When set, this frame is drawn ghosted behind the current one (onion skin).
  final Frame? onionFrame;

  /// Called with a brush stroke (points in 512-logical canvas units) when the
  /// Erase tool is active over the selected image layer.
  final void Function(List<Offset> pointsLogical)? onEraseStroke;

  /// When non-null and the Cut-out tool is active over the selected image
  /// layer, a tap becomes "remove the object under the finger" (#83) instead
  /// of layer selection. Point in 512-logical canvas units.
  final void Function(Offset pointLogical)? onObjectTap;

  @override
  ConsumerState<EditorCanvas> createState() => _EditorCanvasState();
}

class _EditorCanvasState extends ConsumerState<EditorCanvas> {
  /// Decoded pixel size per photo assetPath, so hit boxes and the selection
  /// frame match the BoxFit.contain content rect instead of the full 440
  /// square (#74). Read from the encoded header only - pixels are never
  /// decoded here.
  final Map<String, Size> _imageDims = {};
  final Set<String> _dimsLoading = {};

  LayerTransform? _startTransform;
  Offset? _startFocal;
  String? _gestureLayerId;

  /// Assigns [_gestureLayerId] and rebuilds, because [ProjectCanvas] freezes
  /// that layer's decode target for the duration of the gesture. Without the
  /// rebuild on release the photo would stay at its gesture-time resolution
  /// until something else happened to repaint.
  void _setGestureLayer(String? id) {
    if (_gestureLayerId == id) return;
    setState(() => _gestureLayerId = id);
  }

  /// Non-null while a Photo Grid divider is being dragged. The gesture grabs
  /// the divider instead of a layer, and the delta is measured from
  /// [_dividerStart] so the controller can map from its drag-start snapshot.
  GridDivider? _dragDivider;
  Offset? _dividerStart;

  /// Where the finger actually landed, in logical units.
  ///
  /// A scale gesture is only recognized AFTER the pointer has travelled past
  /// the pan slop (~36 logical px), so `onScaleStart`'s focal point is already
  /// displaced - by more than a divider's touch band is wide. Hit-testing that
  /// point would make a divider almost impossible to grab, so the grab is
  /// resolved against the pointer-down position instead.
  Offset? _pointerDownLogical;

  /// Touch radius around a divider, in SCREEN px. Converted to logical units
  /// per canvas: a fixed logical slop would be a few pixels wide on a 1080-px
  /// canvas shown at ~400.
  static const double _dividerTouchPx = 16;

  /// Tools where a canvas gesture already means "manipulate" rather than
  /// "paint". Only there are divider handles live, so a brush stroke or an
  /// object pick can never be stolen by a divider (same gating idea as the
  /// on-canvas delete handle below).
  static const Set<EditorTool> _dividerTools = {
    EditorTool.grid,
    EditorTool.layers,
    EditorTool.adjust,
    EditorTool.text,
  };

  /// Non-null while a brush stroke is being drawn (Erase tool). Points are in
  /// 512-logical canvas units.
  List<Offset>? _strokePoints;

  EditorController get _controller =>
      ref.read(editorControllerProvider.notifier);

  bool _isErasing(EditorState editor) =>
      editor.tool == EditorTool.erase && editor.selectedLayer is ImageLayer;

  /// The grid layout for the current document, or null when it is not a
  /// collage. Cheap (O(cells)) and pure, so it is recomputed per use rather
  /// than cached into state that could go stale.
  GridLayout? _layoutOf(EditorState editor) {
    final grid = editor.project.grid;
    if (grid == null) return null;
    return layoutGrid(
      grid,
      Size(
        editor.project.canvasWidth.toDouble(),
        editor.project.canvasHeight.toDouble(),
      ),
    );
  }

  /// The divider under [point] (logical units), or null. Among dividers within
  /// the touch slop, the nearest one wins, so overlapping slop near a corner
  /// cannot grab the wrong axis.
  GridDivider? _dividerAt(Offset point, double scale, EditorState editor) {
    if (!_dividerTools.contains(editor.tool)) return null;
    final layout = _layoutOf(editor);
    if (layout == null) return null;
    final slop = _dividerTouchPx / scale;
    GridDivider? best;
    var bestDistance = slop;
    for (final divider in layout.dividers) {
      if (!divider.band.inflate(slop).contains(point)) continue;
      final centre = divider.band.center;
      final distance = divider.axis == GridAxis.columns
          ? (point.dx - centre.dx).abs()
          : (point.dy - centre.dy).abs();
      if (distance <= bestDistance) {
        best = divider;
        bestDistance = distance;
      }
    }
    return best;
  }

  /// Loads (and caches) the pixel dimensions of [path] from the encoded image
  /// header. Fire-and-forget: until it lands, hit-testing falls back to the
  /// full square, which is the pre-#74 behavior. Deliberately NOT timer-based
  /// (a pending zero-duration timer trips widget tests).
  void _ensureDims(String path) {
    if (_imageDims.containsKey(path) || !_dimsLoading.add(path)) return;
    unawaited(_loadDims(path));
  }

  Future<void> _loadDims(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      buffer.dispose();
      final size = Size(
        descriptor.width.toDouble(),
        descriptor.height.toDouble(),
      );
      descriptor.dispose();
      if (mounted) setState(() => _imageDims[path] = size);
    } catch (_) {
      // Unreadable file - keep the square fallback (and don't retry).
      if (mounted) _imageDims[path] = Size.zero;
    } finally {
      _dimsLoading.remove(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editor = ref.watch(editorControllerProvider);
    for (final layer in editor.layers.whereType<ImageLayer>()) {
      _ensureDims(layer.assetPath);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        // The parent sizes this box to the canvas aspect exactly, so a uniform
        // scale maps logical (W×H) units to pixels with no letterbox offset.
        final scale = constraints.maxWidth / editor.project.canvasWidth;
        final selected = editor.selectedLayer;
        return Listener(
          onPointerDown: (e) => _pointerDownLogical = e.localPosition / scale,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => _onTap(d.localPosition / scale, editor, scale),
            onScaleStart: (d) => _onScaleStart(d, editor, scale),
            onScaleUpdate: (d) => _onScaleUpdate(d, scale),
            onScaleEnd: (_) => _onScaleEnd(),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const Checkerboard(cell: 12),
                if (widget.onionFrame != null)
                  Opacity(
                    opacity: 0.25,
                    child: ProjectCanvas(
                      frame: widget.onionFrame!,
                      width: editor.project.canvasWidth,
                      height: editor.project.canvasHeight,
                      grid: editor.project.grid,
                    ),
                  ),
                // A collage always renders - its empty cells are the invitation
                // to add photos, so the whole-canvas drop placeholder would only
                // cover them up.
                if (editor.layers.isEmpty && !editor.project.isGrid)
                  Center(child: widget.dropPlaceholder)
                else
                  ProjectCanvas(
                    frame: editor.currentFrame,
                    width: editor.project.canvasWidth,
                    height: editor.project.canvasHeight,
                    grid: editor.project.grid,
                    showCellPlaceholders: true,
                    gesturingLayerId: _gestureLayerId,
                  ),
                // Divider handles sit above the composition but below the layer
                // selection chrome.
                if (_dividerTools.contains(editor.tool))
                  for (final divider
                      in _layoutOf(editor)?.dividers ?? const <GridDivider>[])
                    _dividerHandle(divider, scale),
                if (selected != null && editor.tool != EditorTool.frames) ...[
                  _selectionOverlay(selected, scale),
                  // Bubbles get a draggable knob at the tail tip (#78) - except
                  // caption boxes, which have no tail (#80).
                  if (selected is BubbleLayer &&
                      selected.shape != BubbleShape.caption)
                    _tailHandle(selected, scale),
                  // Delete the selected layer right on the canvas - previously
                  // removal only existed on the Layers-panel rows, so anything
                  // added while on Adjust/Text felt undeletable. Hidden for
                  // Erase/Cut-out, where canvas taps mean brush dabs / object
                  // picks and a stray × would be destructive.
                  if (const {
                    EditorTool.layers,
                    EditorTool.adjust,
                    EditorTool.text,
                  }.contains(editor.tool))
                    _deleteHandle(selected, scale),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // --------------------------------------------------------- divider handle
  /// A grab pill centred on a divider. Purely an affordance - the drag itself
  /// is handled by the canvas-wide recognizer, which checks dividers before
  /// layers, so the pill never has to win a gesture arena.
  Widget _dividerHandle(GridDivider divider, double scale) {
    final centre = divider.band.center * scale;
    final columns = divider.axis == GridAxis.columns;
    final width = columns ? 5.0 : 30.0;
    final height = columns ? 30.0 : 5.0;
    return Positioned(
      key: ValueKey('grid-${divider.key}'),
      left: centre.dx - width / 2,
      top: centre.dy - height / 2,
      width: width,
      height: height,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.colors.cyan,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: AppScrim.outline.withValues(alpha: 0.4)),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ tail handle
  /// The bubble's tail tip in this widget's pixel space.
  Offset _tailTipPx(BubbleLayer layer, double scale) {
    final t = layer.transform;
    final local =
        bubbleTailTip(layer, kBubbleBaseSize) -
        Offset(kBubbleBaseSize.width / 2, kBubbleBaseSize.height / 2);
    final scaled = local * t.scale;
    final cosA = math.cos(t.rotation);
    final sinA = math.sin(t.rotation);
    final rotated = Offset(
      scaled.dx * cosA - scaled.dy * sinA,
      scaled.dx * sinA + scaled.dy * cosA,
    );
    return (t.position + rotated) * scale;
  }

  Widget _tailHandle(BubbleLayer layer, double scale) {
    const touch = 15.0; // touch radius in screen px
    final px = _tailTipPx(layer, scale);
    return Positioned(
      left: px.dx - touch,
      top: px.dy - touch,
      width: touch * 2,
      height: touch * 2,
      child: RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: <Type, GestureRecognizerFactory>{
          _ImmediatePanRecognizer:
              GestureRecognizerFactoryWithHandlers<_ImmediatePanRecognizer>(
                _ImmediatePanRecognizer.new,
                (r) {
                  r.onUpdate = (d) =>
                      _dragTail(layer.id, d.globalPosition, scale);
                  r.onEnd = (_) => _controller.endEdit();
                },
              ),
        },
        child: Center(
          child: Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.colors.cyan,
              border: Border.all(color: AppScrim.outline, width: 2),
            ),
          ),
        ),
      ),
    );
  }

  /// A tappable × on the selection frame's top-right corner (rotating with
  /// the layer) that removes the selected layer - one undo step.
  Widget _deleteHandle(Layer layer, double scale) {
    const pad = 10.0; // matches _selectionOverlay's frame padding
    final size = _sizeOf(layer);
    final t = layer.transform;
    // Top-right corner of the padded frame, rotated around the layer center.
    final cx = size.width * scale / 2 + pad;
    final cy = -(size.height * scale / 2 + pad);
    final cosA = math.cos(t.rotation);
    final sinA = math.sin(t.rotation);
    final corner =
        t.position * scale +
        Offset(cx * cosA - cy * sinA, cx * sinA + cy * cosA);
    // 24 rather than 16: a 48dp touch target, which is both Android's minimum
    // and what Flutter's androidTapTargetGuideline checks. The drawn dot stays
    // 22px - only the area that accepts the tap grew.
    const touch = 24.0;
    return Positioned(
      key: const ValueKey('layer-delete-handle'),
      left: corner.dx - touch,
      top: corner.dy - touch,
      width: touch * 2,
      height: touch * 2,
      child: Semantics(
        button: true,
        // This is the app's most destructive control and it is not an
        // IconButton, so `tooltip:` cannot reach it - TalkBack announced it as
        // a bare "button" sitting on the corner of the selected layer.
        label: AppLocalizations.of(context).deleteLayerNamed(layer.name),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _controller.removeLayer(layer.id),
          child: Center(
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.colors.rose,
                border: Border.all(color: AppScrim.outline, width: 2),
              ),
              child: Icon(
                Icons.close,
                size: 13,
                color: context.colors.onAccent,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Maps a drag position back through the layer transform into the bubble's
  /// normalized tail space and applies it (coalesced into one undo step).
  void _dragTail(String layerId, Offset globalPos, double scale) {
    final canvasBox = context.findRenderObject() as RenderBox?;
    final layer = ref
        .read(editorControllerProvider)
        .layers
        .whereType<BubbleLayer>()
        .where((l) => l.id == layerId)
        .firstOrNull;
    if (canvasBox == null || layer == null) return;
    final t = layer.transform;
    final logical = canvasBox.globalToLocal(globalPos) / scale;
    final rel = logical - t.position;
    final cosA = math.cos(-t.rotation);
    final sinA = math.sin(-t.rotation);
    final unrotated =
        Offset(rel.dx * cosA - rel.dy * sinA, rel.dx * sinA + rel.dy * cosA) /
        t.scale;
    final local =
        unrotated +
        Offset(kBubbleBaseSize.width / 2, kBubbleBaseSize.height / 2);
    _controller.updateBubbleLayer(
      layerId,
      tail: bubbleTailFromLocal(local, kBubbleBaseSize),
    );
  }

  // ------------------------------------------------------------ gestures
  void _onTap(Offset pointLogical, EditorState editor, double scale) {
    // Erase tool: a tap lays down a single dab on the selected photo.
    if (_isErasing(editor)) {
      widget.onEraseStroke?.call([pointLogical]);
      return;
    }
    // A tap that lands on a divider is a mis-aimed drag, not a deselect.
    if (_dividerAt(pointLogical, scale, editor) != null) return;
    // Cut-out tool in Remove-object mode: the tap picks an object (#83).
    if (widget.onObjectTap != null &&
        editor.tool == EditorTool.cutout &&
        editor.selectedLayer is ImageLayer) {
      widget.onObjectTap!(pointLogical);
      return;
    }
    final hit = _hitTest(editor.layers, pointLogical, editor);
    if (hit == null) {
      // An empty collage cell is the invitation to add a photo.
      final cell = _layoutOf(editor)?.cellAt(pointLogical);
      if (cell != null && !editor.layers.any((l) => l.cellId == cell)) {
        widget.onEmptyCellTap?.call(cell);
        return;
      }
      if (editor.layers.isEmpty && !editor.project.isGrid) {
        widget.onEmptyTap();
        return;
      }
    }
    _controller.selectLayer(hit?.id);
    // Tapping a bubble opens its editor right away - previously the bubble
    // panel appeared only if the Text tool happened to be active (#82).
    if (hit is BubbleLayer && editor.tool != EditorTool.text) {
      _controller.setTool(EditorTool.text);
    }
  }

  void _onScaleStart(ScaleStartDetails d, EditorState editor, double scale) {
    final focalLogical = d.localFocalPoint / scale;
    // Erase tool: start collecting a brush stroke on the selected photo,
    // instead of moving/scaling a layer.
    if (_isErasing(editor)) {
      _strokePoints = [focalLogical];
      return;
    }
    // A grab near a Photo Grid divider resizes the columns/rows instead of
    // moving a layer - checked BEFORE the layer hit test, since cell photos
    // overflow their cell and would otherwise swallow every divider.
    //
    // Resolved against the pointer-down position, not the focal point: by the
    // time a scale gesture is recognized the finger has already travelled past
    // the pan slop, which is wider than the divider's touch band. Single-finger
    // only - during a pinch the recorded point may belong to the second finger.
    final grab =
        (d.pointerCount <= 1 ? _pointerDownLogical : null) ?? focalLogical;
    final divider = _dividerAt(grab, scale, editor);
    if (divider != null) {
      _dragDivider = divider;
      // The divider tracks the finger from where it landed, so the handle ends
      // up under the fingertip instead of trailing it by the slop.
      _dividerStart = grab;
      _controller.beginDividerDrag();
      return;
    }
    final target =
        _hitTest(editor.layers, focalLogical, editor) ?? editor.selectedLayer;
    if (target == null) {
      _setGestureLayer(null);
      return;
    }
    _controller.selectLayer(target.id);
    _setGestureLayer(target.id);
    _startTransform = target.transform;
    _startFocal = focalLogical;
  }

  void _onScaleUpdate(ScaleUpdateDetails d, double scale) {
    if (_strokePoints != null) {
      _strokePoints!.add(d.localFocalPoint / scale);
      return;
    }
    final divider = _dragDivider;
    final dividerStart = _dividerStart;
    if (divider != null && dividerStart != null) {
      final point = d.localFocalPoint / scale;
      // Delta from the drag START, not the previous frame: the controller maps
      // from its snapshot, so an absolute delta is what keeps it drift-free.
      _controller.dragDivider(
        divider,
        divider.axis == GridAxis.columns
            ? point.dx - dividerStart.dx
            : point.dy - dividerStart.dy,
      );
      return;
    }
    final id = _gestureLayerId;
    final start = _startTransform;
    final startFocal = _startFocal;
    if (id == null || start == null || startFocal == null) return;
    final focalLogical = d.localFocalPoint / scale;
    final delta = focalLogical - startFocal;
    final editor = ref.read(editorControllerProvider);
    final layer = editor.layers.where((l) => l.id == id).firstOrNull;
    var next = LayerTransform(
      position: start.position + delta,
      // Shared with the Adjust panel's Scale slider rather than repeated, so
      // the two ways of resizing a layer cannot disagree about how small or
      // large one may get - a gesture that reached a size the slider refuses
      // to represent would be a state with no way back.
      scale: (start.scale * d.scale).clamp(kMinLayerScale, kMaxLayerScale),
      rotation: start.rotation + d.rotation,
    );
    if (layer != null) {
      final cell = _layoutOf(editor)?.cells[layer.cellId];
      if (cell != null) next = _clampToCell(layer, next, cell);
    }
    _controller.updateTransform(id, next);
  }

  /// Keeps a cell PHOTO covering its cell: it may be panned and zoomed inside
  /// the cell, but not out of it. Without this a photo can be dragged aside
  /// leaving a hole in the collage, which reads as a bug rather than an edit.
  ///
  /// Applies to image layers only - a caption or bubble placed in a cell is
  /// meant to be small, and is simply clipped.
  LayerTransform _clampToCell(Layer layer, LayerTransform next, Rect cell) {
    if (layer is! ImageLayer) return next;
    final unit = _sizeOfAt(layer, 1);
    if (unit.width <= 0 || unit.height <= 0) return next;
    final minScale = math.max(
      cell.width / unit.width,
      cell.height / unit.height,
    );
    final scale = math.max(next.scale, minScale);
    final half = Offset(unit.width * scale / 2, unit.height * scale / 2);
    // Valid centres are those keeping both edges outside the cell; the bounds
    // cross over when the layer is smaller than the cell, so centre it there.
    double axis(double value, double lo, double hi, double halfExtent) {
      final min = hi - halfExtent;
      final max = lo + halfExtent;
      return min > max ? (lo + hi) / 2 : value.clamp(min, max);
    }

    return next.copyWith(
      scale: scale,
      position: Offset(
        axis(next.position.dx, cell.left, cell.right, half.dx),
        axis(next.position.dy, cell.top, cell.bottom, half.dy),
      ),
    );
  }

  void _onScaleEnd() {
    final stroke = _strokePoints;
    if (stroke != null) {
      _strokePoints = null;
      if (stroke.isNotEmpty) widget.onEraseStroke?.call(stroke);
      return;
    }
    if (_dragDivider != null) {
      _dragDivider = null;
      _dividerStart = null;
      _controller.endDividerDrag();
      return;
    }
    final id = _gestureLayerId;
    _setGestureLayer(null);
    _controller.endEdit();
    if (id != null) _dropIntoCell(id);
  }

  /// A layer dropped with its centre over a DIFFERENT cell moves there,
  /// swapping with whatever was in it - the direct way to rearrange a collage.
  void _dropIntoCell(String layerId) {
    final editor = ref.read(editorControllerProvider);
    final layer = editor.layers.where((l) => l.id == layerId).firstOrNull;
    if (layer == null || layer.cellId == null) return;
    final target = _layoutOf(editor)?.cellAt(layer.transform.position);
    if (target != null && target != layer.cellId) {
      _controller.moveLayerToCell(layerId, target);
    }
  }

  // ------------------------------------------------------------ hit-testing
  Layer? _hitTest(List<Layer> layers, Offset p, EditorState editor) {
    // A cell photo is cover-scaled, so it overflows its cell; only the visible
    // (clipped) part may answer a tap, or a photo would swallow taps meant for
    // the neighbouring cell.
    final cells = _layoutOf(editor)?.cells;
    for (final layer in layers.reversed) {
      if (!layer.visible) continue;
      final cell = cells?[layer.cellId];
      if (cell != null && !cell.contains(p)) continue;
      final size = _sizeOf(layer);
      final c = layer.transform.position;
      // Rotate the point into the layer's local (un-rotated) frame.
      final rel = p - c;
      final a = -layer.transform.rotation;
      final cosA = math.cos(a);
      final sinA = math.sin(a);
      final local = Offset(
        rel.dx * cosA - rel.dy * sinA,
        rel.dx * sinA + rel.dy * cosA,
      );
      if (local.dx.abs() <= size.width / 2 &&
          local.dy.abs() <= size.height / 2) {
        return layer;
      }
    }
    return null;
  }

  /// [_sizeOf] at an explicit [scale] rather than the layer's own - used by the
  /// cell cover clamp, which needs the size the layer WOULD have.
  Size _sizeOfAt(Layer layer, double scale) {
    final own = layer.transform.scale;
    final size = _sizeOf(layer);
    if (own == 0) return size;
    return Size(size.width / own * scale, size.height / own * scale);
  }

  /// The layer's bounding size in 512-logical units, including its own scale.
  /// Image layers shrink to their BoxFit.contain content rect (once the header
  /// dims are cached) so a letterboxed photo doesn't blanket the canvas and
  /// block taps on the layer underneath (#74).
  Size _sizeOf(Layer layer) {
    final s = layer.transform.scale;
    return switch (layer) {
      ImageLayer(:final assetPath, :final cropRect) => () {
        const box = 440.0;
        final dims = _imageDims[assetPath];
        if (dims == null || dims.width <= 0 || dims.height <= 0) {
          return Size(box * s, box * s);
        }
        // Aspect of the visible (cropped) content, so hit-box + selection frame
        // track a per-layer crop (full crop → the source aspect, unchanged).
        final ar =
            (cropRect.width * dims.width) / (cropRect.height * dims.height);
        return ar >= 1
            ? Size(box * s, box / ar * s)
            : Size(box * ar * s, box * s);
      }(),
      BubbleLayer() => kBubbleBaseSize * s,
      TextLayer() => () {
        final tp = TextPainter(
          text: TextSpan(
            text: layer.text.isEmpty ? ' ' : layer.text,
            style: TextStyle(
              fontFamily: layer.fontFamily,
              fontSize: layer.fontSize,
              height: 1,
              letterSpacing: 1,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final size = Size(tp.width * s, tp.height * s);
        tp.dispose();
        return size;
      }(),
    };
  }

  // ------------------------------------------------------------ selection UI
  Widget _selectionOverlay(Layer layer, double scale) {
    const pad = 10.0;
    final size = _sizeOf(layer);
    final wPx = size.width * scale + pad * 2;
    final hPx = size.height * scale + pad * 2;
    final center = layer.transform.position * scale;
    return Positioned(
      left: center.dx - wPx / 2,
      top: center.dy - hPx / 2,
      width: wPx,
      height: hPx,
      child: IgnorePointer(
        child: Transform.rotate(
          angle: layer.transform.rotation,
          child: CustomPaint(painter: _SelectionPainter(context.colors.cyan)),
        ),
      ),
    );
  }
}

/// Wins the gesture arena on pointer-down, so a drag that starts on the tail
/// knob can never lose to the canvas-wide scale recognizer (#78).
class _ImmediatePanRecognizer extends PanGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

/// Draws the selection frame: a rounded accent border around the selected
/// layer. Scale/rotate is a two-finger pinch, so no drag-handles are drawn -
/// they would imply an interaction the canvas doesn't offer.
class _SelectionPainter extends CustomPainter {
  _SelectionPainter(this.accent);

  /// Passed in rather than read from a constant: a painter has no context, and
  /// the accent is a different colour in the light theme.
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(1), const Radius.circular(10)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = accent,
    );
  }

  @override
  bool shouldRepaint(_SelectionPainter oldDelegate) =>
      oldDelegate.accent != accent;
}

/// The dashed "drop a photo here" placeholder shown on an empty canvas.
class DropPlaceholder extends StatelessWidget {
  const DropPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: 0.62,
      heightFactor: 0.62,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.colors.borderStrong, width: 2),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 34,
                    color: context.colors.textMuted,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context).tapToAddPhoto,
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: 12,
                      color: context.colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
