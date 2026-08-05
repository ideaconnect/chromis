import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../../../core/theme/app_palette.dart';

/// The blue mark under the finger while an erase stroke is being drawn, and for
/// as long afterwards as it takes the real pixels to arrive.
///
/// **There was never a debounce to shorten.** `EditorCanvas` collected the
/// stroke into a plain list and handed it over only on `onScaleEnd` - the
/// finger LIFT - and `_onScaleUpdate` called neither `setState` nor a callback,
/// so during the drag the widget tree did not even rebuild. Nothing could
/// appear, by construction. Then the lift starts a pipeline that is genuinely
/// slow and entirely off the UI thread: decode the source header, decode the
/// mask PNG, run the dab loop in an isolate, encode a full source-resolution
/// PNG, write it, commit an undo step - and only then does `_MaskedImage`
/// re-read and re-decode both the photo and the new mask before a painter runs.
///
/// So this object has to cover BOTH halves, and the second is the one that is
/// easy to get wrong. Retiring the trail when the apply future completes looks
/// right and is not: the future resolves at `setImageMask`, which is where the
/// re-decode *starts*. Clear it there and the user sees the trail vanish onto
/// an un-erased photo and the erase appear a beat later - a flash of the
/// original, which is a worse artefact than the one being fixed. The trail is
/// therefore retired by the renderer, when a decode carrying that mask has
/// actually been painted ([paintedFor]).
///
/// Two failure modes that a ledger, rather than a single flag, is here to
/// handle: strokes can overlap (the brush size slider is live, so two pending
/// strokes can want different radii), and `_runEraseStroke` has several silent
/// exits that commit nothing - so every stroke also needs a floor
/// ([retireIfUncommitted]) or a stroke that quietly failed leaves a blue ghost
/// on the photo for the rest of the session.
class EraseTrail extends ChangeNotifier {
  // ------------------------------------------------------------------ live
  ui.Path? _live;
  String? _liveLayerId;
  double _liveRadius = 0;

  /// The stroke currently under the finger, in 512-logical canvas units.
  ui.Path? get live => _live;
  String? get liveLayerId => _liveLayerId;
  double get liveRadius => _liveRadius;

  /// Begins a stroke at [pointLogical] with the brush's half-width.
  ///
  /// Emits `moveTo` AND `lineTo` at the same point on purpose: a zero-length
  /// segment with `StrokeCap.round` rasterises as a full-diameter disc, so a
  /// tap-dab draws its footprint with no special case in the painter, and the
  /// brush's size is visible before the finger has moved at all.
  void begin(String layerId, Offset pointLogical, double radiusLogical) {
    _live = ui.Path()
      ..moveTo(pointLogical.dx, pointLogical.dy)
      ..lineTo(pointLogical.dx, pointLogical.dy);
    _liveLayerId = layerId;
    _liveRadius = radiusLogical;
    notifyListeners();
  }

  /// Extends the live stroke. O(1) - the path grows, it is not rebuilt from a
  /// point list, which matters because this runs on every pointer move.
  void extend(Offset pointLogical) {
    final path = _live;
    if (path == null) return;
    path.lineTo(pointLogical.dx, pointLogical.dy);
    notifyListeners();
  }

  // --------------------------------------------------------------- pending
  int _nextTicket = 1;
  final List<PendingErase> _pending = [];

  List<PendingErase> get pending => List.unmodifiable(_pending);

  /// Hands the live stroke to the pending ledger and returns its ticket, which
  /// the caller passes back to [markCommitted] / [retireIfUncommitted].
  ///
  /// Returns null when there is no live stroke, so the caller can tell a real
  /// gesture from a stray end.
  int? settle() {
    final path = _live;
    final layerId = _liveLayerId;
    if (path == null || layerId == null) return null;
    final ticket = _nextTicket++;
    _pending.add(
      PendingErase(
        ticket: ticket,
        path: path,
        layerId: layerId,
        radius: _liveRadius,
      ),
    );
    _live = null;
    _liveLayerId = null;
    notifyListeners();
    return ticket;
  }

  /// The stroke's pixels have been written to [maskPath]; keep drawing it until
  /// a decode of that mask has actually been painted.
  void markCommitted(int ticket, String maskPath) {
    for (final p in _pending) {
      if (p.ticket == ticket) {
        p.committedMaskPath = maskPath;
        return;
      }
    }
  }

  /// The floor under every silent exit in the apply path. A stroke that never
  /// committed has no pixels coming, so it must not wait for a repaint that
  /// will never mention it.
  void retireIfUncommitted(int ticket) {
    final before = _pending.length;
    _pending.removeWhere(
      (p) => p.ticket == ticket && p.committedMaskPath == null,
    );
    if (_pending.length != before) notifyListeners();
  }

  /// Called by the renderer once it has painted [layerId] with [maskPath].
  ///
  /// Retires every committed stroke for that layer up to and including the one
  /// whose mask this is. Strokes are serialised by the screen's `_strokeLock`,
  /// so an earlier stroke's mask is always superseded by a later one - and
  /// keying on the path rather than merely on the layer means an unrelated
  /// re-decode (a pinch raising the decode target, say) cannot retire a stroke
  /// whose pixels have not landed.
  void paintedFor(String layerId, String? maskPath) {
    if (maskPath == null) return;
    final index = _pending.indexWhere(
      (p) => p.layerId == layerId && p.committedMaskPath == maskPath,
    );
    if (index < 0) return;
    _pending.removeRange(0, index + 1);
    notifyListeners();
  }

  /// Drops everything. For leaving the tool or the screen - a trail must not
  /// outlive the editor that explains it.
  void clear() {
    if (_live == null && _pending.isEmpty) return;
    _live = null;
    _liveLayerId = null;
    _pending.clear();
    notifyListeners();
  }

  bool get isEmpty => _live == null && _pending.isEmpty;
}

/// A stroke that has left the finger but whose pixels have not arrived.
class PendingErase {
  PendingErase({
    required this.ticket,
    required this.path,
    required this.layerId,
    required this.radius,
  });

  final int ticket;
  final ui.Path path;
  final String layerId;

  /// Captured per stroke, not read from the screen at paint time: the Brush
  /// size slider is live while an apply is in flight, so a stroke drawn at 40
  /// must keep being drawn at 40 even after the slider has moved to 120.
  final double radius;

  /// Set once the mask file carrying this stroke has been written. Null means
  /// nothing is coming.
  String? committedMaskPath;
}

/// Paints [trail] in canvas-logical units scaled to the widget.
///
/// Repaints are driven by `super(repaint: trail)` rather than by `setState`, so
/// a pointer move dirties one render object instead of rebuilding the canvas
/// subtree - the difference between a trail that keeps up with a fast drag and
/// one that stutters behind it.
class BrushTrailPainter extends CustomPainter {
  BrushTrailPainter({
    required this.trail,
    required this.scale,
    required this.clip,
  }) : super(repaint: trail);

  final EraseTrail trail;

  /// Logical-to-pixel factor; the canvas is scaled by it so the stroke's width
  /// is expressed once, in the same units as the brush.
  final double scale;

  /// The rect the stroke may show inside - the layer's content box, further
  /// intersected with its collage cell by the caller. A stroke only erases
  /// pixels of its own layer, so a trail that ran past the photo would promise
  /// an erase that cannot happen.
  final Rect? clip;

  @override
  void paint(Canvas canvas, Size size) {
    if (trail.isEmpty) return;
    canvas.save();
    canvas.scale(scale);
    if (clip != null) canvas.clipRect(clip!);

    for (final p in trail.pending) {
      // Dimmed once the finger is off it: the stroke is no longer where the
      // user is, it is what the app is still working on. One shape, two
      // opacities, and the alpha rides the group so the rim and the fill fade
      // together rather than separately.
      _stroke(canvas, p.path, p.radius, 0.55);
    }
    final live = trail.live;
    if (live != null) _stroke(canvas, live, trail.liveRadius, 1.0);

    canvas.restore();
  }

  void _stroke(Canvas canvas, ui.Path path, double radius, double opacity) {
    final width = radius * 2;
    // A layer, not two direct draws: a stroke that doubles back over itself
    // would otherwise show its overlaps as darker blue, which reads as "more
    // erased there" - and the brush does not work that way, it moves each
    // pixel monotonically toward the target. One group, one alpha, flat.
    final bounds = path.getBounds().inflate(radius + 2 / scale);
    canvas.saveLayer(
      bounds,
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: opacity),
    );
    // A dark rim under the fill, so the trail stays visible over a blue sky as
    // well as a dark one - the same trick the drag handles use.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width + 2 / scale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = AppScrim.outline.withValues(alpha: 0.5),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = AppScrim.brush,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(BrushTrailPainter old) =>
      old.scale != scale || old.clip != clip;
}
