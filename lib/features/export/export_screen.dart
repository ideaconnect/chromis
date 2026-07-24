import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/platform/platform_services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/checkerboard.dart';
import '../ads/ads_service.dart';
import '../editor/state/editor_controller.dart';
import '../go_pro/iap.dart';
import 'project_renderer.dart';

/// Export & share the current project (PNG/JPG/WebP) at a chosen resolution.
/// A successful save shows an interstitial ad for non-Pro users (M7).
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  double _scale = 1.0; // 100 / 75 / 50 / 25 %
  _Fmt _fmt = _Fmt.png;
  bool _busy = false;

  /// Rendered composition for the preview tile — computed once (the project
  /// doesn't change while this screen is open), disposed on close.
  late final Future<ui.Image> _previewFuture;

  @override
  void initState() {
    super.initState();
    final project = ref.read(editorControllerProvider).project;
    _previewFuture = ProjectRenderer.renderImageSized(
      project.currentFrame,
      canvasWidth: project.canvasWidth,
      canvasHeight: project.canvasHeight,
      outputWidth: project.canvasWidth.clamp(1, 600),
    );
  }

  @override
  void dispose() {
    _previewFuture.then((img) => img.dispose()).ignore();
    super.dispose();
  }

  ({String ext, String mime, bool alpha}) get _fmtInfo => switch (_fmt) {
    _Fmt.png => (ext: 'png', mime: 'image/png', alpha: true),
    _Fmt.jpg => (ext: 'jpg', mime: 'image/jpeg', alpha: false),
    _Fmt.webp => (ext: 'webp', mime: 'image/webp', alpha: true),
  };

  Future<Uint8List> _render() {
    final project = ref.read(editorControllerProvider).project;
    final w = project.canvasWidth;
    final h = project.canvasHeight;
    final outW = (w * _scale).round().clamp(16, w);
    final frame = project.currentFrame;
    return switch (_fmt) {
      _Fmt.png => ProjectRenderer.renderPngSized(
        frame,
        canvasWidth: w,
        canvasHeight: h,
        outputWidth: outW,
      ),
      _Fmt.jpg => ProjectRenderer.renderJpgSized(
        frame,
        canvasWidth: w,
        canvasHeight: h,
        outputWidth: outW,
      ),
      _Fmt.webp => ProjectRenderer.renderWebpSized(
        frame,
        canvasWidth: w,
        canvasHeight: h,
        outputWidth: outW,
      ),
    };
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final bytes = await _render();
      final f = _fmtInfo;
      final name =
          'PhotoEditor_${DateTime.now().millisecondsSinceEpoch}.${f.ext}';
      final loc = await ref
          .read(platformServicesProvider)
          .saveToGallery(name, f.mime, bytes);
      if (!mounted) return;
      _snack(loc == null ? "Couldn't save the image" : 'Saved · $loc');
      if (loc != null) _maybeInterstitial();
    } catch (_) {
      if (mounted) _snack('Export failed — try again');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final bytes = await _render();
      final f = _fmtInfo;
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/PhotoEditor_${DateTime.now().millisecondsSinceEpoch}'
        '.${f.ext}',
      );
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: f.mime)],
          subject: 'Photo Editor AI',
        ),
      );
    } catch (_) {
      if (mounted) _snack('Share failed — try again');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  /// After a successful export, show a full-screen interstitial — skipped for
  /// Pro users, and a no-op when none is preloaded (never blocks the user).
  void _maybeInterstitial() {
    if (ref.read(isProProvider)) return;
    unawaited(ref.read(adsServiceProvider).showInterstitial());
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(editorControllerProvider).project;
    final outW = (project.canvasWidth * _scale).round();
    final outH = (project.canvasHeight * _scale).round();
    return Scaffold(
      appBar: AppBar(title: const Text('Export & share')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          // Preview tile: the actual composition over a transparency checker.
          AspectRatio(
            aspectRatio: project.canvasAspect,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const Checkerboard(
                    cell: 14,
                    base: Color(0xFF0E1B2A),
                    tile: Color(0xFF15263A),
                  ),
                  FutureBuilder<ui.Image>(
                    future: _previewFuture,
                    builder: (context, snap) {
                      final image = snap.data;
                      if (image == null) return const SizedBox.shrink();
                      return RawImage(image: image, fit: BoxFit.contain);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const _Label('FORMAT'),
          const SizedBox(height: 8),
          Row(
            children: [
              _chip(
                'PNG',
                'transparent',
                _fmt == _Fmt.png,
                () => setState(() => _fmt = _Fmt.png),
              ),
              const SizedBox(width: 8),
              _chip(
                'JPG',
                'flattened',
                _fmt == _Fmt.jpg,
                () => setState(() => _fmt = _Fmt.jpg),
              ),
              const SizedBox(width: 8),
              _chip(
                'WebP',
                'smaller',
                _fmt == _Fmt.webp,
                () => setState(() => _fmt = _Fmt.webp),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _Label('RESOLUTION'),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final p in const [1.0, 0.75, 0.5, 0.25]) ...[
                _chip(
                  '${(p * 100).round()}%',
                  '${(project.canvasWidth * p).round()}px',
                  _scale == p,
                  () => setState(() => _scale = p),
                ),
                if (p != 0.25) const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Output · $outW × $outH px · ${_fmtInfo.ext.toUpperCase()}'
            '${_fmtInfo.alpha ? ' (transparent)' : ''}',
            style: const TextStyle(
              fontFamily: AppFonts.ui,
              fontSize: 11.5,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
            label: const Text('Save to device'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.cyan,
              foregroundColor: AppColors.cutoutInk,
              minimumSize: const Size.fromHeight(50),
              textStyle: const TextStyle(
                fontFamily: AppFonts.display,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy ? null : _share,
            icon: const Icon(Icons.ios_share, size: 18),
            label: const Text('Share'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              minimumSize: const Size.fromHeight(50),
              side: const BorderSide(color: AppColors.border),
              textStyle: const TextStyle(
                fontFamily: AppFonts.ui,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String title, String sub, bool active, VoidCallback? onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null && !active ? 0.5 : 1,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.cyan.withValues(alpha: 0.14)
                  : AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active ? AppColors.cyan : AppColors.borderFaint,
              ),
            ),
            child: Column(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: active
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: const TextStyle(
                    fontFamily: AppFonts.ui,
                    fontSize: 9.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: AppFonts.ui,
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
        color: AppColors.textMuted,
      ),
    );
  }
}

enum _Fmt { png, jpg, webp }
