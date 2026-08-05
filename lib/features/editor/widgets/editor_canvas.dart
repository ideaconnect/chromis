import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show listEquals, setEquals;
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
import '../brush_size.dart';
import '../layer_bounds.dart';
import '../layer_scale_curve.dart';
import '../layer_snap.dart';
import '../state/editor_controller.dart';
import '../state/editor_state.dart';
import '../state/editor_tool.dart';
import 'bubble_view.dart';
import 'erase_trail.dart';
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
    this.eraseTrail,
    this.brushSize = kDefaultBrushSize,
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
  /// Erase tool is active over the selected image layer. [trailTicket] is the
  /// stroke's entry in [eraseTrail] - hand it back to
  /// `EraseTrail.markCommitted` / `retireIfUncommitted` so the blue trail is
  /// held until the real pixels land, and dropped if they never do.
  final void Function(List<Offset> pointsLogical, int trailTicket)?
  onEraseStroke;

  /// The live erase stroke, drawn under the finger. Optional: every other
  /// caller of this widget (tests, and anything that does not erase) leaves it
  /// null and gets exactly the behaviour it had before.
  final EraseTrail? eraseTrail;

  /// The brush's diameter in 512-logical canvas units, so the trail is drawn at
  /// the width the stroke will actually erase.
  final double brushSize;

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

  /// How near an alignment has to be before the gesture is pulled onto it, in
  /// SCREEN px - same conversion, and for a stronger reason: "close enough"
  /// during a drag is a statement about the finger, so a snap radius fixed in
  /// canvas units would grab from a centimetre away on a 4000-px canvas and be
  /// unreachable on a small one.
  static const double _snapTouchPx = 8;

  /// The alignments the current gesture is resting on, for the guide lines -
  /// empty whenever nothing is being dragged.
  List<SnapGuide> _guides = const [];

  /// The layers the gesture has just matched the size or the ANGLE of, outlined
  /// rather than drawn a line through: they are somewhere else on the canvas
  /// entirely, and what happened is "you are now like that one".
  Set<String> _snapMatchIds = const {};

  void _setSnapFeedback(SnapResult? result) {
    final guides = result?.guides ?? const <SnapGuide>[];
    final matches = result?.matchIds ?? const <String>{};
    if (setEquals(matches, _snapMatchIds) && listEquals(guides, _guides)) {
      return;
    }
    setState(() {
      _guides = guides;
      _snapMatchIds = matches;
    });
  }

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
                    onLayerPainted: widget.eraseTrail?.paintedFor,
                  ),
                // The live erase stroke, above the photo it is erasing and
                // below every piece of selection chrome.
                if (_isErasing(editor) && widget.eraseTrail != null)
                  _brushTrailOverlay(editor, scale),
                // Divider handles sit above the composition but below the layer
                // selection chrome.
                if (_dividerTools.contains(editor.tool))
                  for (final divider
                      in _layoutOf(editor)?.dividers ?? const <GridDivider>[])
                    _dividerHandle(divider, scale),
                // Snap feedback sits above the composition and below the
                // selection frame: the cyan frame is where the finger is, and
                // must not be the thing that gets covered.
                for (final guide in _guides)
                  _guideLine(
                    guide,
                    scale,
                    Size(
                      editor.project.canvasWidth.toDouble(),
                      editor.project.canvasHeight.toDouble(),
                    ),
                  ),
                ..._matchOutlines(editor.layers, scale),
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

  /// The live erase stroke. `IgnorePointer` because it must not take the very
  /// gesture that is drawing it, and `RepaintBoundary` because it repaints on
  /// every pointer move and the composition beneath it must not.
  Widget _brushTrailOverlay(EditorState editor, double scale) {
    final layer = editor.selectedLayer;
    Rect? clip;
    if (layer != null) {
      // The layer's own content box, so a stroke that runs off the photo does
      // not promise an erase that cannot happen...
      final size = _sizeOf(layer);
      clip = Rect.fromCenter(
        center: layer.transform.position,
        width: size.width,
        height: size.height,
      );
      // ...intersected with its collage cell, which clips it as well.
      final cell = layer.cellId == null
          ? null
          : _layoutOf(editor)?.cells[layer.cellId];
      if (cell != null) clip = clip.intersect(cell);
    }
    return Positioned.fill(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(
            key: const ValueKey('erase-trail'),
            willChange: true,
            painter: BrushTrailPainter(
              trail: widget.eraseTrail!,
              scale: scale,
              clip: clip,
            ),
          ),
        ),
      ),
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

  // -------------------------------------------------------------- snap guides
  /// A hairline across the whole canvas at the alignment the layer landed on.
  ///
  /// It runs along the FRAME the alignment was found in, not along the canvas.
  /// The whole point of two layers sharing an angle is that they then share a
  /// set of edge directions, and a guide drawn square to the canvas would cross
  /// those edges instead of lying on them.
  ///
  /// Magenta rather than the selection's cyan on purpose: these two are on
  /// screen together during every snapped drag, and a guide in the selection
  /// colour reads as part of the frame rather than as something the canvas is
  /// telling you.
  Widget _guideLine(SnapGuide guide, double scale, Size canvasLogical) {
    final cos = math.cos(guide.angle);
    final sin = math.sin(guide.angle);
    // The axis the alignment was measured along, and the direction the line
    // itself runs - square to it.
    final axis = guide.axis == SnapAxis.x
        ? Offset(cos, sin)
        : Offset(-sin, cos);
    final along = Offset(-axis.dy, axis.dx);
    // Anchored at the point of the line nearest the canvas centre, so the drawn
    // segment covers the part anyone is looking at. Long enough to cross the
    // canvas from any angle; the editor's own ClipRect trims the rest.
    final centre = Offset(canvasLogical.width / 2, canvasLogical.height / 2);
    final point =
        centre +
        axis * (guide.position - (centre.dx * axis.dx + centre.dy * axis.dy));
    final px = point * scale;
    final length =
        1.2 *
        scale *
        math.sqrt(
          canvasLogical.width * canvasLogical.width +
              canvasLogical.height * canvasLogical.height,
        );
    return Positioned(
      key: ValueKey('snap-guide-${guide.axis.name}-${guide.position}'),
      left: px.dx - length / 2,
      top: px.dy - 0.5,
      width: length,
      height: 1,
      child: IgnorePointer(
        child: Transform.rotate(
          angle: math.atan2(along.dy, along.dx),
          child: ColoredBox(color: context.colors.magenta),
        ),
      ),
    );
  }

  /// Outlines a layer this gesture has just matched the size or the ANGLE of. A
  /// match like that has no line to draw - the two layers are nowhere near each
  /// other - so the only way to say WHICH layer is now alike is to point at it.
  List<Widget> _matchOutlines(List<Layer> layers, double scale) {
    return [
      for (final layer in layers)
        if (_snapMatchIds.contains(layer.id))
          _outline(layer, scale, ValueKey('snap-match-${layer.id}')),
    ];
  }

  Widget _outline(Layer layer, double scale, Key key) {
    final size = _sizeOf(layer);
    final wPx = size.width * scale;
    final hPx = size.height * scale;
    final centre = layer.transform.position * scale;
    return Positioned(
      key: key,
      left: centre.dx - wPx / 2,
      top: centre.dy - hPx / 2,
      width: wPx,
      height: hPx,
      child: IgnorePointer(
        child: Transform.rotate(
          angle: layer.transform.rotation,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: context.colors.magenta),
            ),
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
      _beginTrail(editor, pointLogical);
      _dispatchStroke([pointLogical]);
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

  /// Starts the visible half of a stroke. Kept beside the dispatch so the two
  /// halves of "draw it, then hand it over" cannot drift apart.
  void _beginTrail(EditorState editor, Offset pointLogical) {
    final layer = editor.selectedLayer;
    if (layer == null) return;
    widget.eraseTrail?.begin(layer.id, pointLogical, widget.brushSize / 2);
  }

  /// Hands a stroke to the screen along with its trail ticket.
  ///
  /// The ticket is what lets the screen say "these pixels have landed" or "this
  /// one failed, stop drawing it". With no trail attached there is nothing to
  /// settle and nothing to report, so the stroke is dispatched with a ticket of
  /// 0 and the screen's ledger calls are no-ops.
  void _dispatchStroke(List<Offset> pointsLogical) {
    final ticket = widget.eraseTrail?.settle() ?? 0;
    widget.onEraseStroke?.call(pointsLogical, ticket);
  }

  void _onScaleStart(ScaleStartDetails d, EditorState editor, double scale) {
    final focalLogical = d.localFocalPoint / scale;
    // Erase tool: start collecting a brush stroke on the selected photo,
    // instead of moving/scaling a layer.
    if (_isErasing(editor)) {
      // From the pointer-down, not the focal point: a scale gesture is not
      // recognised until the finger has travelled its slop, so seeding here
      // silently threw away the first ~36 logical px of every stroke. Nobody
      // noticed while nothing was drawn during the drag; with a trail under the
      // finger it would be plainly visible as a stroke that starts late. Same
      // guard and same reason as the divider grab below.
      final seed =
          (d.pointerCount <= 1 ? _pointerDownLogical : null) ?? focalLogical;
      _strokePoints = [seed];
      _beginTrail(editor, seed);
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
      final point = d.localFocalPoint / scale;
      _strokePoints!.add(point);
      // The whole of the "it only appears after a delay" complaint was here:
      // this method appended to a list and returned, with no setState and no
      // callback, so the tree did not even rebuild and nothing on screen COULD
      // change until the finger lifted. The trail is a ChangeNotifier driving
      // its painter's `repaint:`, so this dirties one render object rather than
      // rebuilding the canvas subtree.
      widget.eraseTrail?.extend(point);
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
      // A photo that fills a cell is placed by the clamp below, which has the
      // last word anyway - snapping it would only fight that. Everything else
      // in a cell (captions, bubbles) is a free layer and snaps normally.
      final clamped = cell != null && layer is ImageLayer;
      if (_controller.snapEnabled && !clamped) {
        final result = snapTransform(
          moving: layer,
          proposed: next,
          others: editor.layers,
          measure: (l, s) => layerLogicalSize(
            l,
            scale: s,
            imagePixels: l is ImageLayer ? _imageDims[l.assetPath] : null,
          ),
          canvas: Size(
            editor.project.canvasWidth.toDouble(),
            editor.project.canvasHeight.toDouble(),
          ),
          // A layer in a collage cell is CLIPPED to it, and a cell photo is
          // cover-scaled, so a good deal of its box is behind the neighbouring
          // cells. Only what is on screen may be lined up with - the same rule
          // `_hitTest` applies to taps, for the same reason.
          clipOf: (l) =>
              l.cellId == null ? null : _layoutOf(editor)?.cells[l.cellId],
          tolerance: _snapTouchPx / scale,
          // "Is this gesture resizing / turning the layer" - and asked with a
          // SLOP, never as `!= 1` or `!= 0`. Flutter derives both numbers from
          // the line between two pointers, so with two fingers down neither is
          // ever exactly its neutral value; read as intent, an exact comparison
          // answers yes to both for the whole of every two-finger gesture, and
          // a plain two-finger move would come out resized to a neighbour's
          // width and turned to its angle. A one-finger drag is unambiguous -
          // there is no second pointer, so both are exactly neutral.
          snapScale: (d.scale - 1).abs() > kSnapPinchSlop,
          // A move MAY still take a neighbour's angle - that is the only way
          // two turned layers ever go flush - but only by landing on that
          // neighbour's edge and not at the cost of an alignment it already
          // had; `snapTransform` enforces both. Past the twist slop the user is
          // plainly turning it, and then the angle is asked for outright,
          // exactly as the size is.
          rotationTolerance: kSnapRotationTolerance,
          snapRotation: d.rotation.abs() > kSnapTwistSlop,
        );
        next = result.transform;
        _setSnapFeedback(result);
      } else {
        _setSnapFeedback(null);
      }
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
      // A documented exception to "gesture-scoped canvas state is cleared in
      // _onScaleEnd": the trail is NOT cleared here. The pixels have not been
      // written yet, let alone decoded, so clearing it now is exactly the
      // flash of un-erased photo the feature exists to remove. It is retired
      // by the renderer instead - see EraseTrail.
      if (stroke.isNotEmpty) _dispatchStroke(stroke);
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
    _setSnapFeedback(null);
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
  Size _sizeOfAt(Layer layer, double scale) => layerLogicalSize(
    layer,
    scale: scale,
    imagePixels: layer is ImageLayer ? _imageDims[layer.assetPath] : null,
  );

  /// The layer's bounding size in canvas-logical units, including its own
  /// scale. Image layers shrink to their BoxFit.contain content rect (once the
  /// header dims are cached) so a letterboxed photo doesn't blanket the canvas
  /// and block taps on the layer underneath (#74).
  ///
  /// The formula lives in `layer_bounds.dart` because the Adjust panel's
  /// placement sliders measure the layer the same way - see [layerLogicalSize].
  Size _sizeOf(Layer layer) => layerLogicalSize(
    layer,
    imagePixels: layer is ImageLayer ? _imageDims[layer.assetPath] : null,
  );

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
