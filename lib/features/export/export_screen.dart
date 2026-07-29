import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/project.dart';
import '../../core/platform/platform_services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/checkerboard.dart';
import '../../core/widgets/responsive_center.dart';
import '../ads/ad_gate.dart';
import '../ads/ads_service.dart';
import '../editor/state/editor_controller.dart';
import 'project_renderer.dart';

/// Export & share the current project (PNG/JPG/WebP) at a chosen resolution.
/// Free users watch a short rewarded ad before exporting; Pro users export
/// instantly (see [_adGate]).
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  double _scale = 1.0; // 100 / 75 / 50 / 25 %
  _Fmt _fmt = _Fmt.png;
  bool _busy = false;

  /// Rendered composition for the preview tile - computed once (the project
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
      grid: project.grid,
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
    final grid = project.grid;
    return switch (_fmt) {
      _Fmt.png => ProjectRenderer.renderPngSized(
        frame,
        canvasWidth: w,
        canvasHeight: h,
        outputWidth: outW,
        grid: grid,
      ),
      _Fmt.jpg => ProjectRenderer.renderJpgSized(
        frame,
        canvasWidth: w,
        canvasHeight: h,
        outputWidth: outW,
        grid: grid,
      ),
      _Fmt.webp => ProjectRenderer.renderWebpSized(
        frame,
        canvasWidth: w,
        canvasHeight: h,
        outputWidth: outW,
        grid: grid,
      ),
    };
  }

  Future<void> _save() async {
    // Render BEFORE the ad gate. The ad is the price of delivering the export,
    // so a render that fails must not cost one - the gate used to be the first
    // statement here, and on a device where saving could not work every retry
    // burned another rewarded ad. The ad still runs before the file is
    // written, which is the part the gate is actually protecting.
    setState(() => _busy = true);
    final Uint8List bytes;
    final ({String ext, String mime, bool alpha}) f;
    try {
      bytes = await _render();
      f = _fmtInfo;
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        _snack('Export failed - try again');
      }
      return;
    }
    if (mounted) setState(() => _busy = false);
    if (!await _adGate()) return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final name = 'Chromis_${DateTime.now().millisecondsSinceEpoch}.${f.ext}';
      final result = await ref
          .read(platformServicesProvider)
          .saveToGallery(name, f.mime, bytes);
      if (!mounted) return;
      _snack(switch (result) {
        GallerySaveSuccess(:final location) => 'Saved · $location',
        GallerySaveFailure(permissionDenied: true) =>
          'Allow storage access to save to your gallery',
        GallerySaveFailure() => "Couldn't save the image",
      });
    } catch (_) {
      if (mounted) _snack('Export failed - try again');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    // Same ordering as _save: a failed render must not cost an ad.
    setState(() => _busy = true);
    final Uint8List bytes;
    final ({String ext, String mime, bool alpha}) f;
    try {
      bytes = await _render();
      f = _fmtInfo;
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        _snack('Share failed - try again');
      }
      return;
    }
    if (mounted) setState(() => _busy = false);
    if (!await _adGate()) return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/Chromis_${DateTime.now().millisecondsSinceEpoch}'
        '.${f.ext}',
      );
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: f.mime)],
          subject: 'Chromis',
        ),
      );
    } catch (_) {
      if (mounted) _snack('Share failed - try again');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  /// Gates an export behind a short rewarded ad for free users; Pro users pass
  /// straight through. Returns true when the export may proceed. Fail-open: if
  /// no ad is available [AdsService.showRewarded] returns true, so a missing ad
  /// never traps the user.
  Future<bool> _adGate() async => (await AdGate.run(
    context,
    ref,
    title: 'Watch a short ad to export',
    message:
        'Free exports are supported by a short ad. Go Pro to export '
        'without ads, forever.',
    watchLabel: 'Watch & export',
  )).allows;

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(editorControllerProvider).project;
    final outW = (project.canvasWidth * _scale).round();
    final outH = (project.canvasHeight * _scale).round();
    return Scaffold(
      appBar: AppBar(title: const Text('Export & share')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Side by side when the screen is wider than it is tall. Stacked,
          // the preview is an AspectRatio given the full width, so a square
          // project became a 1240-px-tall tile in a 700-px viewport and every
          // control - format, resolution, Save - started below the fold. Keyed
          // exactly like the editor's landscape branch.
          if (constraints.maxWidth > constraints.maxHeight) {
            return Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 10, 20),
                    child: Center(child: _preview(project)),
                  ),
                ),
                SizedBox(
                  width: math.min(420, constraints.maxWidth * 0.42),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(10, 12, 20, 28),
                    children: _controls(project, outW, outH),
                  ),
                ),
              ],
            );
          }
          return ResponsiveCenter(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                _preview(project),
                const SizedBox(height: 20),
                ..._controls(project, outW, outH),
              ],
            ),
          );
        },
      ),
    );
  }

  /// The composition over a transparency checker.
  Widget _preview(Project project) {
    return AspectRatio(
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
    );
  }

  /// Format, resolution, the output summary and the two actions.
  List<Widget> _controls(Project project, int outW, int outH) {
    return [
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
    ];
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
