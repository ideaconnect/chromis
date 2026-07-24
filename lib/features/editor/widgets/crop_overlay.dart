import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/models/frame.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/checkerboard.dart';
import '../../export/project_renderer.dart';

/// Opens a full-screen freeform crop editor over the current composition and
/// returns the chosen crop rectangle in **canvas-logical** coordinates
/// (top-left origin, same space as layer transforms), or null if cancelled.
/// Pair with `EditorController.cropCanvasRect`.
Future<Rect?> showCropOverlay(
  BuildContext context, {
  required Frame frame,
  required int canvasWidth,
  required int canvasHeight,
}) {
  return Navigator.of(context).push<Rect>(
    MaterialPageRoute<Rect>(
      fullscreenDialog: true,
      builder: (_) => _CropOverlay(
        loadPreview: () => ProjectRenderer.renderImageSized(
          frame,
          canvasWidth: canvasWidth,
          canvasHeight: canvasHeight,
          outputWidth: canvasWidth.clamp(1, 1080),
        ),
        srcWidth: canvasWidth,
        srcHeight: canvasHeight,
      ),
    ),
  );
}

/// Opens the crop editor over a single decoded [image] and returns the chosen
/// crop as a **normalized** (0..1) rect, or null if cancelled. [initialCrop]
/// seeds the box from the layer's existing crop. The overlay takes ownership of
/// [image] and disposes it. Pair with `EditorController.setImageCrop`.
Future<Rect?> showLayerCropOverlay(
  BuildContext context, {
  required ui.Image image,
  Rect initialCrop = const Rect.fromLTRB(0, 0, 1, 1),
  int? srcWidth,
  int? srcHeight,
}) {
  return Navigator.of(context).push<Rect>(
    MaterialPageRoute<Rect>(
      fullscreenDialog: true,
      builder: (_) => _CropOverlay(
        loadPreview: () async => image,
        // [image] may be a downscaled preview; the true source dimensions drive
        // the px readout + minimum crop while the preview only displays.
        srcWidth: srcWidth ?? image.width,
        srcHeight: srcHeight ?? image.height,
        initialCrop: initialCrop,
        normalized: true,
      ),
    ),
  );
}

class _CropOverlay extends StatefulWidget {
  const _CropOverlay({
    required this.loadPreview,
    required this.srcWidth,
    required this.srcHeight,
    this.initialCrop = const Rect.fromLTRB(0, 0, 1, 1),
    this.normalized = false,
  });

  /// Produces the preview image (the composition, or a single layer's image).
  final Future<ui.Image> Function() loadPreview;

  /// Source dimensions - drive the container aspect and the minimum crop size.
  final int srcWidth;
  final int srcHeight;

  /// Initial crop, normalized (0..1).
  final Rect initialCrop;

  /// When true, [_CropOverlayState._apply] returns the normalized rect;
  /// otherwise source-pixel (canvas-logical) coordinates.
  final bool normalized;

  @override
  State<_CropOverlay> createState() => _CropOverlayState();
}

class _CropOverlayState extends State<_CropOverlay> {
  ui.Image? _preview;
  bool _failed = false;

  // Crop rect, normalized (0..1) in image space.
  late double _l = widget.initialCrop.left;
  late double _t = widget.initialCrop.top;
  late double _r = widget.initialCrop.right;
  late double _b = widget.initialCrop.bottom;

  double get _minW => 16 / widget.srcWidth; // ≥16 px wide
  double get _minH => 16 / widget.srcHeight;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final image = await widget.loadPreview();
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() => _preview = image);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _preview?.dispose();
    super.dispose();
  }

  Rect _containRect(Size box, double aspect) {
    var w = box.width;
    var h = w / aspect;
    if (h > box.height) {
      h = box.height;
      w = h * aspect;
    }
    return Rect.fromLTWH((box.width - w) / 2, (box.height - h) / 2, w, h);
  }

  void _moveBody(Offset delta, Rect display) {
    final dnx = delta.dx / display.width;
    final dny = delta.dy / display.height;
    final wN = _r - _l;
    final hN = _b - _t;
    final l = (_l + dnx).clamp(0.0, 1 - wN);
    final t = (_t + dny).clamp(0.0, 1 - hN);
    setState(() {
      _l = l;
      _t = t;
      _r = l + wN;
      _b = t + hN;
    });
  }

  void _resize(
    Offset delta,
    Rect display, {
    required bool left,
    required bool top,
  }) {
    final dnx = delta.dx / display.width;
    final dny = delta.dy / display.height;
    var l = _l, t = _t, r = _r, b = _b;
    if (left) {
      l = (l + dnx).clamp(0.0, r - _minW);
    } else {
      r = (r + dnx).clamp(l + _minW, 1.0);
    }
    if (top) {
      t = (t + dny).clamp(0.0, b - _minH);
    } else {
      b = (b + dny).clamp(t + _minH, 1.0);
    }
    setState(() {
      _l = l;
      _t = t;
      _r = r;
      _b = b;
    });
  }

  void _apply() {
    Navigator.of(context).pop(
      widget.normalized
          ? Rect.fromLTRB(_l, _t, _r, _b)
          : Rect.fromLTRB(
              _l * widget.srcWidth,
              _t * widget.srcHeight,
              _r * widget.srcWidth,
              _b * widget.srcHeight,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07101B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Crop'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: _preview == null ? null : _apply,
            style: TextButton.styleFrom(foregroundColor: AppColors.cyan),
            child: const Text(
              'Done',
              style: TextStyle(
                fontFamily: AppFonts.display,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _canvasArea(),
              ),
            ),
            _footer(),
          ],
        ),
      ),
    );
  }

  Widget _canvasArea() {
    if (_failed) {
      return const Center(
        child: Text(
          'Preview unavailable',
          style: TextStyle(fontFamily: AppFonts.ui, color: AppColors.textMuted),
        ),
      );
    }
    final preview = _preview;
    if (preview == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.cyan),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final box = Size(constraints.maxWidth, constraints.maxHeight);
        final display = _containRect(box, widget.srcWidth / widget.srcHeight);
        final crop = Rect.fromLTRB(
          display.left + _l * display.width,
          display.top + _t * display.height,
          display.left + _r * display.width,
          display.top + _b * display.height,
        );
        const h = 30.0; // corner handle hit size
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fromRect(
              rect: display,
              child: const Checkerboard(
                cell: 12,
                base: Color(0xFF0E1B2A),
                tile: Color(0xFF15263A),
              ),
            ),
            Positioned.fromRect(
              rect: display,
              child: RawImage(image: preview, fit: BoxFit.fill),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _CropPainter(display: display, crop: crop),
                ),
              ),
            ),
            Positioned.fromRect(
              rect: crop,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanUpdate: (d) => _moveBody(d.delta, display),
              ),
            ),
            _handle(
              crop.topLeft,
              h,
              (d) => _resize(d, display, left: true, top: true),
            ),
            _handle(
              crop.topRight,
              h,
              (d) => _resize(d, display, left: false, top: true),
            ),
            _handle(
              crop.bottomLeft,
              h,
              (d) => _resize(d, display, left: true, top: false),
            ),
            _handle(
              crop.bottomRight,
              h,
              (d) => _resize(d, display, left: false, top: false),
            ),
          ],
        );
      },
    );
  }

  Widget _handle(Offset center, double size, ValueChanged<Offset> onDrag) {
    return Positioned(
      left: center.dx - size / 2,
      top: center.dy - size / 2,
      width: size,
      height: size,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanUpdate: (d) => onDrag(d.delta),
        child: const SizedBox.expand(),
      ),
    );
  }

  Widget _footer() {
    final w = ((_r - _l) * widget.srcWidth).round();
    final ph = ((_b - _t) * widget.srcHeight).round();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 12, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$w × $ph px',
            style: const TextStyle(
              fontFamily: AppFonts.ui,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          TextButton.icon(
            onPressed: () => setState(() {
              _l = 0;
              _t = 0;
              _r = 1;
              _b = 1;
            }),
            style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
            icon: const Icon(Icons.crop_free, size: 18),
            label: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

class _CropPainter extends CustomPainter {
  _CropPainter({required this.display, required this.crop});

  final Rect display;
  final Rect crop;

  @override
  void paint(Canvas canvas, Size size) {
    // Dim the image area outside the crop rectangle (even-odd punch-out).
    canvas.drawPath(
      Path()
        ..addRect(display)
        ..addRect(crop)
        ..fillType = PathFillType.evenOdd,
      Paint()..color = const Color(0xAA07101B),
    );
    // Crop border.
    canvas.drawRect(
      crop,
      Paint()
        ..color = AppColors.cyan
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    // Rule-of-thirds grid.
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final x = crop.left + crop.width * i / 3;
      final y = crop.top + crop.height * i / 3;
      canvas.drawLine(Offset(x, crop.top), Offset(x, crop.bottom), grid);
      canvas.drawLine(Offset(crop.left, y), Offset(crop.right, y), grid);
    }
    // Corner ticks (draw inward from each corner).
    final tick = Paint()
      ..color = AppColors.cyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const len = 18.0;
    void corner(Offset c, double sx, double sy) {
      canvas.drawLine(c, c + Offset(len * sx, 0), tick);
      canvas.drawLine(c, c + Offset(0, len * sy), tick);
    }

    corner(crop.topLeft, 1, 1);
    corner(crop.topRight, -1, 1);
    corner(crop.bottomLeft, 1, -1);
    corner(crop.bottomRight, -1, -1);
  }

  @override
  bool shouldRepaint(_CropPainter old) =>
      old.crop != crop || old.display != display;
}
