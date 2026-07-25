import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/router.dart';
import '../../core/models/frame.dart';
import '../../core/models/grid.dart';
import '../../core/models/image_adjustments.dart';
import '../../core/models/layer.dart';
import '../../core/models/layer_effects.dart';
import '../../core/models/layer_transform.dart';
import '../../core/models/project.dart';
import '../../core/rendering/canvas_geometry.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/checkerboard.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/labeled_slider.dart';
import '../../core/widgets/name_prompt.dart';
import '../../core/widgets/pill_chip.dart';
import '../../core/widgets/sm_toast.dart';
import '../../core/widgets/text_caption.dart';
import '../ads/ads_service.dart';
import '../fonts/custom_fonts.dart';
import '../go_pro/iap.dart';
import '../grid/grid_templates.dart';
import '../grid/widgets/grid_template_strip.dart';
import '../home/project_repository.dart';
import '../home/widgets/app_drawer.dart';
import '../segmentation/ai_capability.dart';
import '../segmentation/alpha_mask.dart';
import '../segmentation/engines/inpaint/inpaint_engine.dart';
import '../segmentation/engines/object/mobile_sam_engine.dart';
import '../segmentation/mask_brush.dart';
import '../segmentation/mask_processing.dart';
import '../segmentation/mask_store.dart';
import '../segmentation/seg_model.dart';
import '../segmentation/segmentation_engine.dart';
import '../segmentation/segmentation_registry.dart';
import 'mask_mapper.dart';
import 'services/image_import.dart';
import 'services/layer_flattener.dart';
import 'state/editor_controller.dart';
import 'state/editor_state.dart';
import 'state/editor_tool.dart';
import 'widgets/canvas_size_sheet.dart';
import 'widgets/crop_overlay.dart';
import 'widgets/editor_canvas.dart';
import 'widgets/filter_strip.dart';
import 'widgets/project_canvas.dart';

/// Editor: top bar, model-driven project canvas, a contextual panel that swaps
/// per tool, and the six-tab tool bar. State lives in [editorControllerProvider];
/// this widget renders it and dispatches edits. Image-dependent tools (Adjust,
/// Cut out, Erase) wait on image import (#21) / AI segmentation (#2).
class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  final TextEditingController _textController = TextEditingController();
  String? _editingTextId;
  final TextEditingController _bubbleTextController = TextEditingController();
  String? _editingBubbleId;

  // Transient tool UI state not yet backed by the model.
  bool _isPlaying = false; // frame playback (M4)
  Timer? _playTimer;
  bool _onionSkin = false; // ghost the previous frame (M4 #37)
  bool _eraseMode = true; // erase vs restore (M2)
  bool _softEdges = true;
  double _brushSize = 40;
  bool _removingBg = false; // AI cut-out in progress
  bool _removeObjectMode = false; // tap-to-remove mode in the cutout tool (#83)
  bool _fillMode =
      false; // Fill (MI-GAN inpaint) vs Erase in remove-object mode
  bool _inpainting = false; // MI-GAN generative fill in progress
  bool _samBusy = false; // MobileSAM object segmentation in progress (#86)
  bool _merging = false; // flatten / merge-down render in progress
  // Landscape only: whether the tool column beside the rail is showing.
  bool _sidePanelOpen = true;
  // Set when the SAM engine hard-fails (precompute/segmentAt threw): a broken
  // ORT runtime never heals mid-session, so later taps short-circuit to the
  // capability toast instead of re-paying the full decode + encoder attempt.
  bool _samEngineFailed = false;

  /// The honest capability toast - deliberately DISTINCT from the
  /// tapped-the-subject message, which used to double for this case and sent
  /// users tapping other objects expecting different results (2026-07-19
  /// review, low/ai-usage).
  static const String samUnavailableMessage =
      "Object removal AI isn't available on this device - "
      'use the Erase brush instead';

  // Working mask cached across strokes of the Erase tool, so we don't reload
  // and decode the mask file on every dab. Keyed by (layerId, maskPath) so an
  // undo/redo or a layer switch transparently reloads.
  AlphaMask? _workingMask;
  String? _workingMaskLayerId;
  String? _workingMaskPath;
  Size? _workingImageSize;
  // Serializes erase strokes so overlapping async applies can't race and lose
  // dabs (each stroke starts only after the previous one has fully applied).
  Future<void> _strokeLock = Future<void>.value();

  // Reclaims superseded mask PNGs (previous cut-out / erase files a newer mask
  // replaced) once they fall out of undo/redo reach, so intermediate masks
  // don't pile up as orphans (#review perf 2026-07-19). Never deletes a path a
  // live undo entry could still restore - see [EditorController.isMaskReferenced].
  late final SupersededMaskCollector _maskGc = SupersededMaskCollector(
    ref.read(maskStoreProvider),
  );

  Timer? _saveTimer;
  Project? _pendingSave;
  // Captured during build so dispose() can save without touching `ref`
  // (which is unsafe once the widget is unmounting).
  ProjectRepository? _repo;
  // Captured during build so dispose()'s final save can also refresh Home's
  // Recent list - invalidating via `ref` while unmounting is unsafe.
  ProviderContainer? _homeContainer;

  EditorController get _controller =>
      ref.read(editorControllerProvider.notifier);

  void _toast(String m) => showSmToast(context, m);

  /// Closes the current undo step when a slider drag ends.
  void _endSliderEdit(double _) => _controller.endEdit();

  /// Whether two projects are the same *document* - everything that gets
  /// persisted except the transient current-frame index (frame navigation and
  /// playback must not count as edits).
  bool _sameDocument(Project a, Project b) =>
      a.id == b.id &&
      a.name == b.name &&
      a.fps == b.fps &&
      a.canvasWidth == b.canvasWidth &&
      a.canvasHeight == b.canvasHeight &&
      listEquals(a.frames, b.frames);

  /// Debounced auto-save of the document to disk.
  void _scheduleSave(Project project) {
    _pendingSave = project;
    _saveTimer?.cancel();
    _saveTimer = Timer(
      const Duration(milliseconds: 800),
      () => _flushSave(refreshHome: true),
    );
  }

  void _flushSave({bool refreshHome = false}) {
    final project = _pendingSave;
    if (project == null) return;
    _pendingSave = null;
    _repo?.save(project.copyWith(updatedAt: DateTime.now()));
    // Refresh Home's Recent list - via the captured container so it works even
    // from dispose() (a brand-new project's first save may only flush on exit).
    if (refreshHome) _homeContainer?.invalidate(savedProjectsProvider);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _playTimer?.cancel();
    _flushSave(refreshHome: true); // persist + refresh Home on the way out
    _textController.dispose();
    _bubbleTextController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------- playback
  void _togglePlayback(EditorState editor) {
    if (_isPlaying) {
      _stopPlayback();
    } else if (editor.project.frameCount > 1) {
      setState(() => _isPlaying = true);
      _restartPlayTimer();
    }
  }

  void _restartPlayTimer() {
    _playTimer?.cancel();
    // Preview at the project's fps - the same rate every export path uses.
    // Upper bound 8000 ms lets the 0.25 fps slow-motion preset play back too.
    final fps = ref.read(editorControllerProvider).project.fps;
    final ms = (1000 / fps).round().clamp(20, 8000);
    _playTimer = Timer.periodic(Duration(milliseconds: ms), (_) {
      final project = ref.read(editorControllerProvider).project;
      if (project.frameCount <= 1) {
        _stopPlayback();
        return;
      }
      final next = (project.currentFrameIndex + 1) % project.frameCount;
      _controller.selectFrame(next);
    });
  }

  void _stopPlayback() {
    _playTimer?.cancel();
    _playTimer = null;
    if (_isPlaying && mounted) setState(() => _isPlaying = false);
  }

  /// Discrete playback / export speeds, including the sub-1 fps slow-motion
  /// presets. The selected value drives both the preview timer and every
  /// export path (WYSIWYG).
  static const List<double> _fpsPresets = [0.25, 0.5, 1, 2, 4, 8, 12, 16, 24];

  /// "0.25", "0.5", "1", "12" - drops the trailing ".0" on whole rates.
  static String _fpsLabel(double fps) => fps < 1 ? '$fps' : '${fps.round()}';

  Widget _fpsControl(EditorState editor) {
    final fps = editor.project.fps;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Speed',
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              '${_fpsLabel(fps)} fps',
              style: const TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in _fpsPresets)
              PillChip(
                label: _fpsLabel(preset),
                accent: AppColors.orange,
                selected: (preset - fps).abs() < 0.001,
                onTap: () {
                  _controller.setFps(preset);
                  if (_isPlaying) _restartPlayTimer();
                },
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final editor = ref.watch(editorControllerProvider);
    _repo = ref.read(projectRepositoryProvider);
    _homeContainer = ProviderScope.containerOf(context, listen: false);
    ref.listen(editorControllerProvider, (prev, next) {
      // A different project loaded into the shared editor state re-locks AI -
      // the rewarded unlock is per project, not per editor-screen instance.
      if (prev != null && prev.project.id != next.project.id) {
        _aiUnlockedThisSession = false;
      }
      // Persist only real document edits - not frame navigation / playback,
      // which change currentFrameIndex only. Otherwise scrubbing the timeline
      // (or a playback tick) would rewrite the file and bump it to the top of
      // Home's "recent" list with no actual edit.
      if (prev == null || !_sameDocument(prev.project, next.project)) {
        _scheduleSave(next.project);
      }
      // Stop looping playback when the user leaves the Frames tool.
      if (next.tool != EditorTool.frames && _isPlaying) {
        _stopPlayback();
      }
      // A commit / undo / redo may have dropped the last history reference to a
      // superseded mask - reclaim any now-unreachable files (no-op when none are
      // pending). Runs off the frame; the file delete never blocks the gesture.
      unawaited(_maskGc.collect(_controller.isMaskReferenced));
    });
    return Scaffold(
      drawer: const AppDrawer(),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final topBar = _TopBar(
              title: editor.project.name,
              layerCount: editor.layers.length,
              canUndo: _controller.canUndo,
              canRedo: _controller.canRedo,
              onExport: () => context.pushNamed(Routes.export),
              onUndo: _controller.undo,
              onRedo: _controller.redo,
              onRename: _renameProject,
              onCanvasSize: _showCanvasSize,
            );
            // Landscape turns the layout on its side: the dock becomes a rail
            // down the left edge, the tool panel a column beside it that folds
            // away on demand, and everything left over goes to the canvas -
            // which is the whole point of turning the phone.
            if (constraints.maxWidth > constraints.maxHeight) {
              return Column(
                children: [
                  topBar,
                  Expanded(child: _landscapeBody(editor, constraints)),
                ],
              );
            }
            final panelMax = math.min(300.0, constraints.maxHeight * 0.5);
            return Column(
              children: [
                topBar,
                Expanded(child: _canvas(editor)),
                _panel(editor, panelMax),
                _toolBar(editor),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Rail | folding panel | canvas.
  Widget _landscapeBody(EditorState editor, BoxConstraints constraints) {
    final panelWidth = math.min(320.0, constraints.maxWidth * 0.36);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _toolRail(editor),
        if (_sidePanelOpen)
          SizedBox(width: panelWidth, child: _sidePanel(editor)),
        Expanded(child: _canvas(editor, wide: true)),
      ],
    );
  }

  // ---------------------------------------------------------------- canvas
  Widget _canvas(EditorState editor, {bool wide = false}) {
    final tokens = context.tokens;
    return Padding(
      padding: wide
          ? const EdgeInsets.fromLTRB(14, 10, 16, 12)
          : const EdgeInsets.fromLTRB(20, 8, 20, 14),
      child: Center(
        child: ConstrainedBox(
          // Portrait caps the canvas so it never dominates a tall phone;
          // landscape gives it everything the rail and panel left over.
          constraints: BoxConstraints(maxWidth: wide ? double.infinity : 460),
          child: AspectRatio(
            aspectRatio: editor.project.canvasAspect,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(tokens.radiusCanvas),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x80000000),
                    blurRadius: 50,
                    offset: Offset(0, 20),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(tokens.radiusCanvas),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    EditorCanvas(
                      onEmptyTap: () => _pickPhoto(ImageSource.gallery),
                      onEmptyCellTap: _pickPhotoIntoCell,
                      dropPlaceholder: const DropPlaceholder(),
                      onEraseStroke: _applyEraseStroke,
                      // Non-null only while the cutout tool's Remove-object
                      // mode is armed (#83).
                      onObjectTap: _removeObjectMode
                          ? _applyObjectRemoval
                          : null,
                      onionFrame: _onionFrame(editor),
                    ),
                    if (_hasCutout(editor)) const _CutBadge(),
                    if (_removingBg) const _RemovingOverlay(),
                    if (_samBusy || _inpainting)
                      _RemovingOverlay(
                        label: _inpainting
                            ? 'Filling in the background…'
                            : 'Finding the object…',
                      ),
                    if (_merging)
                      const _RemovingOverlay(label: 'Merging layers…'),
                    // Which frame you're editing - shown in every tool while the
                    // project is animated (per-frame editing indicator, #36).
                    if (editor.project.frameCount > 1)
                      _FrameCounter(
                        current: editor.project.safeFrameIndex + 1,
                        total: editor.project.frameCount,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Badge for the SELECTED layer only - with several photos a global "any
  /// layer has a mask" reading was misleading (#73); per-layer state lives on
  /// the Layers-panel thumbnails.
  bool _hasCutout(EditorState editor) {
    final selected = editor.selectedLayer;
    return selected is ImageLayer && selected.maskPath != null;
  }

  /// The previous frame to ghost behind the current one (onion skin), or null
  /// when disabled / not applicable. Suppressed during playback.
  Frame? _onionFrame(EditorState editor) {
    if (!_onionSkin ||
        _isPlaying ||
        editor.tool != EditorTool.frames ||
        editor.project.frameCount < 2) {
      return null;
    }
    final frames = editor.project.frames;
    final prev =
        (editor.project.safeFrameIndex - 1 + frames.length) % frames.length;
    return frames[prev];
  }

  // ---------------------------------------------------------------- panel
  Widget _panel(EditorState editor, double maxHeight) {
    final tokens = context.tokens;
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border(top: BorderSide(color: tokens.border)),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(tokens.radiusPanel),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      child: SingleChildScrollView(child: _panelBody(editor)),
    );
  }

  /// The landscape twin of [_panel]: a full-height column between the rail and
  /// the canvas, with its own collapse control so the canvas can take the whole
  /// width when you just want to look at the photo.
  Widget _sidePanel(EditorState editor) {
    final tokens = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border(right: BorderSide(color: tokens.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              key: const ValueKey('collapse-panel'),
              tooltip: 'Hide tool panel',
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => _sidePanelOpen = false),
              icon: const Icon(
                Icons.keyboard_double_arrow_left,
                color: AppColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _panelBody(editor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _panelBody(EditorState editor) {
    return switch (editor.tool) {
      EditorTool.adjust => _adjustPanel(editor),
      EditorTool.effects => _effectsPanel(editor),
      EditorTool.text =>
        editor.selectedLayer is BubbleLayer
            ? _bubblePanel(editor)
            : _textPanel(editor),
      EditorTool.cutout => _cutoutPanel(editor),
      EditorTool.erase => _erasePanel(),
      EditorTool.frames => _framesPanel(editor),
      EditorTool.layers => _layersPanel(editor),
      EditorTool.grid => _gridPanel(editor),
    };
  }

  Widget _panelHeader(EditorTool tool, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            tool.panelTitle,
            style: TextStyle(
              fontFamily: AppFonts.display,
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: context.tokens.accent(tool.accent),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  Widget _emptyHint(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: AppFonts.ui,
          fontSize: 12.5,
          color: AppColors.textMuted,
          height: 1.5,
        ),
      ),
    );
  }

  // ------------------------------------------------------------ Adjust
  /// Opens the per-layer crop editor over [layer]'s source photo (decoded at a
  /// preview resolution - the crop itself is normalized) and applies the result.
  Future<void> _cropSelectedImage(ImageLayer layer) async {
    final ui.Image image;
    final int srcW;
    final int srcH;
    try {
      final bytes = await File(layer.assetPath).readAsBytes();
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      srcW = descriptor.width;
      srcH = descriptor.height;
      final target = descriptor.width > 1080 ? 1080 : null;
      final codec = target != null
          ? await descriptor.instantiateCodec(targetWidth: target)
          : await descriptor.instantiateCodec();
      descriptor.dispose();
      buffer.dispose();
      try {
        image = (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
    } catch (_) {
      if (mounted) _toast("Couldn't open the photo to crop");
      return;
    }
    if (!mounted) {
      image.dispose();
      return;
    }
    // The overlay takes ownership of `image` and disposes it.
    final rect = await showLayerCropOverlay(
      context,
      image: image,
      initialCrop: layer.cropRect,
      srcWidth: srcW,
      srcHeight: srcH,
    );
    if (rect == null || !mounted) return;
    _controller.setImageCrop(layer.id, rect);
    _toast('Photo cropped');
  }

  Widget _adjustPanel(EditorState editor) {
    final selected = editor.selectedLayer;
    // Adding a photo/text/bubble is reachable right from the default tool -
    // not only via the Layers tab (#77).
    final addChip = PillChip(
      label: 'Add',
      icon: Icons.add,
      onTap: _showAddMenu,
    );
    if (selected is! ImageLayer) {
      return Column(
        children: [
          _panelHeader(EditorTool.adjust, trailing: addChip),
          _emptyHint(
            'Adjustments apply to a photo layer.\nSelect a photo, or tap Add '
            'to import one.',
          ),
        ],
      );
    }
    final id = selected.id;
    final adj = selected.adjustments;
    void update(ImageAdjustments next) =>
        _controller.updateImageAdjustments(id, next);
    return Column(
      children: [
        _panelHeader(
          EditorTool.adjust,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              addChip,
              const SizedBox(width: 8),
              PillChip(
                label: 'Reset',
                onTap: () {
                  // Only this panel's own sliders - the chosen filter / HDR
                  // survive, and Effects has its own Reset for those.
                  _controller.updateImageAdjustments(id, adj.resetSliders());
                  _controller.setOpacity(id, 1);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _cropSelectedImage(selected),
                icon: const Icon(Icons.crop, size: 17),
                label: Text(selected.isCropped ? 'Edit crop' : 'Crop photo'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.border),
                  minimumSize: const Size.fromHeight(38),
                ),
              ),
            ),
            if (selected.isCropped) ...[
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _controller.setImageCrop(
                  id,
                  const Rect.fromLTRB(0, 0, 1, 1),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textMuted,
                  side: const BorderSide(color: AppColors.border),
                  // NOT Expanded, so a fixed 38 min-HEIGHT only - Size.fromHeight
                  // sets min-WIDTH to infinity, which crashes layout here (#crop).
                  minimumSize: const Size(0, 38),
                ),
                child: const Text('Reset crop'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        LabeledSlider(
          label: 'Brightness',
          value: adj.brightness * 100,
          min: 0,
          max: 200,
          accent: AppColors.amber,
          valueLabel: '${(adj.brightness * 100).round()}%',
          onChanged: (v) => update(adj.copyWith(brightness: v / 100)),
          onChangeEnd: _endSliderEdit,
        ),
        LabeledSlider(
          label: 'Contrast',
          value: adj.contrast * 100,
          min: 0,
          max: 200,
          accent: AppColors.cyan,
          valueLabel: '${(adj.contrast * 100).round()}%',
          onChanged: (v) => update(adj.copyWith(contrast: v / 100)),
          onChangeEnd: _endSliderEdit,
        ),
        LabeledSlider(
          label: 'Saturation',
          value: adj.saturation * 100,
          min: 0,
          max: 200,
          accent: AppColors.pink,
          valueLabel: '${(adj.saturation * 100).round()}%',
          onChanged: (v) => update(adj.copyWith(saturation: v / 100)),
          onChangeEnd: _endSliderEdit,
        ),
        LabeledSlider(
          label: 'Hue',
          value: adj.hue,
          min: -180,
          max: 180,
          accent: AppColors.violet,
          valueLabel: '${adj.hue.round()}°',
          onChanged: (v) => update(adj.copyWith(hue: v)),
          onChangeEnd: _endSliderEdit,
        ),
        LabeledSlider(
          label: 'Opacity',
          value: selected.opacity * 100,
          min: 0,
          max: 100,
          accent: AppColors.green,
          valueLabel: '${(selected.opacity * 100).round()}%',
          onChanged: (v) => _controller.setOpacity(id, v / 100),
          onChangeEnd: _endSliderEdit,
        ),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: () => _controller.setTool(EditorTool.effects),
          icon: const Icon(Icons.auto_awesome_mosaic, size: 17),
          label: const Text('Filters, HDR, vignette, shadow…'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.teal,
            side: const BorderSide(color: AppColors.border),
            minimumSize: const Size.fromHeight(38),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------ Text
  Widget _textPanel(EditorState editor) {
    const colors = [
      Colors.white,
      Color(0xFF111111),
      AppColors.pink,
      AppColors.amber,
      AppColors.green,
      AppColors.cyan,
      AppColors.violet,
      AppColors.rose,
      AppColors.orange,
    ];

    final selected = editor.selectedLayer;
    if (selected is! TextLayer) {
      return Column(
        children: [
          _panelHeader(EditorTool.text),
          _emptyHint('Select a text layer, or add one.'),
          GradientButton(
            label: 'Add text',
            icon: Icons.add,
            gradient: LinearGradient(
              colors: [AppColors.pink, AppColors.pink.withValues(alpha: 0.7)],
            ),
            glowColor: AppColors.pink,
            onPressed: () => _controller.addTextLayer(),
          ),
        ],
      );
    }

    // Resync the field when the selection changes OR when the model text
    // diverges from the field (e.g. after an undo, which clears the selection
    // and reverts the text but leaves the field id/content stale).
    if (_editingTextId != selected.id ||
        _textController.text != selected.text) {
      _editingTextId = selected.id;
      _textController.value = TextEditingValue(
        text: selected.text,
        selection: TextSelection.collapsed(offset: selected.text.length),
      );
    }
    final id = selected.id;
    final fonts = ref.watch(availableFontsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _panelHeader(
          EditorTool.text,
          trailing: const _PanelHint('Tap a font to preview'),
        ),
        TextField(
          controller: _textController,
          onChanged: (v) => _controller.updateTextLayer(id, text: v),
          style: const TextStyle(
            fontFamily: AppFonts.ui,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'Type your caption…',
            hintStyle: const TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.inputField,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 11,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 42,
          child: ListView.separated(
            // Keyed so a test can hold on to the row while it scrolls: an
            // anchor chip scrolls out of the tree and takes the finder with it.
            key: const ValueKey('font-row'),
            scrollDirection: Axis.horizontal,
            itemCount: fonts.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 9),
            itemBuilder: (_, i) {
              if (i == fonts.length) {
                return _importFontChip(() => _importFontFor(id, bubble: false));
              }
              final f = fonts[i];
              final active = selected.fontFamily == f;
              return PillChip(
                label: f,
                accent: AppColors.pink,
                selected: active,
                radius: 12,
                onTap: () => _controller.updateTextLayer(id, fontFamily: f),
                labelStyle: TextStyle(
                  fontFamily: f,
                  fontSize: 16,
                  color: active ? Colors.white : AppColors.textSecondary,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        LabeledSlider(
          label: 'Size',
          value: selected.fontSize,
          min: 16,
          max: 72,
          accent: AppColors.pink,
          valueColor: AppColors.textMuted,
          valueLabel: '${selected.fontSize.round()}px',
          onChanged: (v) => _controller.updateTextLayer(id, fontSize: v),
          onChangeEnd: _endSliderEdit,
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            for (final c in colors)
              GestureDetector(
                onTap: () => _controller.updateTextLayer(id, color: c),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected.color == c
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.15),
                      width: selected.color == c ? 3 : 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _PanelHint('OUTLINE'),
            if (selected.strokeColor != null)
              PillChip(
                key: const ValueKey('text-stroke-auto'),
                label: 'Auto color',
                onTap: () => _controller.updateTextStroke(id, autoColor: true),
              ),
          ],
        ),
        LabeledSlider(
          label: 'Thickness',
          value: selected.strokeWidth,
          min: 0,
          max: 16,
          accent: AppColors.pink,
          valueColor: AppColors.textMuted,
          valueLabel: selected.strokeWidth < 0.05
              ? 'Off'
              : selected.strokeWidth.toStringAsFixed(1),
          onChanged: (v) => _controller.updateTextStroke(id, width: v),
          onChangeEnd: _endSliderEdit,
        ),
        if (selected.hasStroke) ...[
          LabeledSlider(
            label: 'Outline opacity',
            value: selected.strokeOpacity * 100,
            min: 0,
            max: 100,
            accent: AppColors.pink,
            valueColor: AppColors.textMuted,
            valueLabel: '${(selected.strokeOpacity * 100).round()}%',
            onChanged: (v) =>
                _controller.updateTextStroke(id, opacity: v / 100),
            onChangeEnd: _endSliderEdit,
          ),
          const SizedBox(height: 4),
          _swatchRow(
            'Color',
            // Show the automatic pick as the current swatch until the user
            // chooses one, so the row never looks unrelated to the canvas.
            TextCaption.resolveStrokeColor(
              selected.color,
              selected.strokeColor,
              1,
            ),
            (c) => _controller.updateTextStroke(id, color: c),
          ),
        ],
      ],
    );
  }

  // ------------------------------------------------------------ Bubble
  /// Imports a user font file and applies it to the layer being edited.
  Future<void> _importFontFor(String layerId, {required bool bubble}) async {
    final family = await ref.read(customFontsProvider.notifier).importFont();
    if (family == null || !mounted) return;
    if (bubble) {
      _controller.updateBubbleLayer(layerId, fontFamily: family);
    } else {
      _controller.updateTextLayer(layerId, fontFamily: family);
    }
    _toast('Added font · $family');
  }

  /// The "+ Font" chip at the end of a font row - opens the .ttf/.otf picker.
  Widget _importFontChip(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 15, color: AppColors.textSecondary),
            SizedBox(width: 5),
            Text(
              'Font',
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubblePanel(EditorState editor) {
    final bubble = editor.selectedLayer! as BubbleLayer;
    if (_editingBubbleId != bubble.id ||
        _bubbleTextController.text != bubble.text) {
      _editingBubbleId = bubble.id;
      _bubbleTextController.value = TextEditingValue(
        text: bubble.text,
        selection: TextSelection.collapsed(offset: bubble.text.length),
      );
    }
    final id = bubble.id;
    final fonts = ref.watch(availableFontsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _panelHeader(
          EditorTool.text,
          trailing: const _PanelHint('Comic bubble'),
        ),
        // Five shapes don't fit as equal tabs - horizontal pill scroll (#80).
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final s in BubbleShape.values) ...[
                SizedBox(
                  width: 90,
                  child: _segTab(
                    _bubbleShapeLabel(s),
                    bubble.shape == s,
                    AppColors.pink,
                    () => _controller.updateBubbleLayer(id, shape: s),
                  ),
                ),
                if (s != BubbleShape.values.last) const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _bubbleTextController,
          onChanged: (v) => _controller.updateBubbleLayer(id, text: v),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: AppFonts.ui,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'Bubble text…',
            hintStyle: const TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.inputField,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 11,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Font & size were model-supported but UI-locked to Bangers 26 (#81).
        // The chosen size acts as a maximum - the auto-fit (#79) may shrink
        // long captions to keep them inside the bubble.
        SizedBox(
          height: 42,
          child: ListView.separated(
            // Keyed so a test can hold on to the row while it scrolls: an
            // anchor chip scrolls out of the tree and takes the finder with it.
            key: const ValueKey('bubble-font-row'),
            scrollDirection: Axis.horizontal,
            itemCount: fonts.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 9),
            itemBuilder: (_, i) {
              if (i == fonts.length) {
                return _importFontChip(() => _importFontFor(id, bubble: true));
              }
              final f = fonts[i];
              final active = bubble.fontFamily == f;
              return PillChip(
                label: f,
                accent: AppColors.pink,
                selected: active,
                radius: 12,
                onTap: () => _controller.updateBubbleLayer(id, fontFamily: f),
                labelStyle: TextStyle(
                  fontFamily: f,
                  fontSize: 16,
                  color: active ? Colors.white : AppColors.textSecondary,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        LabeledSlider(
          label: 'Size',
          value: bubble.fontSize,
          min: 14,
          max: 44,
          accent: AppColors.pink,
          valueColor: AppColors.textMuted,
          valueLabel: '${bubble.fontSize.round()}px',
          onChanged: (v) => _controller.updateBubbleLayer(id, fontSize: v),
          onChangeEnd: _endSliderEdit,
        ),
        const SizedBox(height: 4),
        _swatchRow(
          'Fill',
          bubble.fillColor,
          (c) => _controller.updateBubbleLayer(
            id,
            fillColor: c,
            textColor: _inkFor(c),
          ),
        ),
        const SizedBox(height: 10),
        _swatchRow(
          'Outline',
          bubble.strokeColor,
          (c) => _controller.updateBubbleLayer(id, strokeColor: c),
        ),
        const SizedBox(height: 8),
        // The tail is direct-manipulation now: drag the round knob at its tip
        // on the canvas - any direction, any shape (#78).
        const Text(
          'Drag the dot at the tail tip to aim it - any direction.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 11.5,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  String _bubbleShapeLabel(BubbleShape s) => switch (s) {
    BubbleShape.speech => 'Speech',
    BubbleShape.thought => 'Thought',
    BubbleShape.shout => 'Shout',
    BubbleShape.caption => 'Caption',
    BubbleShape.whisper => 'Whisper',
  };

  /// A labelled row of 9 color swatches for the bubble fill / outline.
  Widget _swatchRow(String label, Color selected, ValueChanged<Color> onPick) {
    const colors = [
      Colors.white,
      Color(0xFF111111),
      AppColors.pink,
      AppColors.amber,
      AppColors.green,
      AppColors.cyan,
      AppColors.violet,
      AppColors.rose,
      AppColors.orange,
    ];
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: AppFonts.ui,
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in colors)
                GestureDetector(
                  onTap: () => onPick(c),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected == c
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.15),
                        width: selected == c ? 3 : 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------ Photo grid
  /// The always-available collage controls: how many photos, which layout, and
  /// the frame (color, thickness, corner rounding).
  Widget _gridPanel(EditorState editor) {
    final grid = editor.project.grid;
    if (grid == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _panelHeader(EditorTool.grid),
          _emptyHint('This project is not a photo grid.'),
        ],
      );
    }
    final templates = gridTemplatesFor(grid.cellCount);
    final current = matchGridTemplate(grid.root);
    final accent = context.tokens.accent(ToolAccent.grid);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _panelHeader(
          EditorTool.grid,
          trailing: PillChip(
            label: 'Shuffle',
            icon: Icons.shuffle,
            accent: accent,
            selected: true,
            onTap: _controller.shuffleGridPhotos,
          ),
        ),
        const _PanelHint('PHOTOS'),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var n = kMinGridPhotos; n <= kMaxGridPhotos; n++) ...[
              Expanded(
                child: PillChip(
                  key: ValueKey('grid-count-$n'),
                  label: '$n',
                  accent: accent,
                  selected: n == grid.cellCount,
                  onTap: () => _controller.setGridPhotoCount(n),
                ),
              ),
              if (n < kMaxGridPhotos) const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 14),
        const _PanelHint('LAYOUT'),
        const SizedBox(height: 8),
        GridTemplateStrip(
          templates: templates,
          selectedIndex: current == null
              ? -1
              : templates.indexWhere((t) => t.label == current.label),
          aspect: editor.project.canvasAspect,
          onSelected: (i) => _controller.setGridTemplate(templates[i].root),
        ),
        const SizedBox(height: 10),
        LabeledSlider(
          label: 'Border',
          value: grid.borderWidth,
          min: 0,
          max: GridSpec.maxBorderWidth,
          accent: accent,
          valueLabel: '${grid.borderWidth.round()} px',
          onChanged: (v) => _controller.setGridBorder(width: v),
          onChangeEnd: (_) => _controller.endEdit(),
        ),
        LabeledSlider(
          label: 'Corners',
          value: grid.cornerRadius,
          min: 0,
          max: GridSpec.maxCornerRadius,
          accent: accent,
          valueLabel: '${grid.cornerRadius.round()} px',
          onChanged: (v) => _controller.setGridBorder(radius: v),
          onChangeEnd: (_) => _controller.endEdit(),
        ),
        const SizedBox(height: 4),
        _swatchRow(
          'Color',
          grid.borderColor,
          (c) => _controller.setGridBorder(color: c),
        ),
      ],
    );
  }

  // ------------------------------------------------------------ Effects
  /// Everything that changes how a layer *looks*: one-tap filters, HDR,
  /// vignette, drop shadow, contour and blend mode.
  ///
  /// Photo-only sections (filter / HDR / vignette describe pixels) are hidden
  /// for text and bubble layers rather than shown disabled - a greyed-out
  /// filter strip under a caption teaches nothing.
  Widget _effectsPanel(EditorState editor) {
    final selected = editor.selectedLayer;
    final accent = context.tokens.accent(ToolAccent.effects);
    if (selected == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _panelHeader(
            EditorTool.effects,
            trailing: PillChip(
              label: 'Add',
              icon: Icons.add,
              onTap: _showAddMenu,
            ),
          ),
          _emptyHint(
            'Select a layer to give it a look.\nFilters, HDR and vignette for '
            'photos; shadow, outline and blending for anything.',
          ),
        ],
      );
    }
    final id = selected.id;
    final image = selected is ImageLayer ? selected : null;
    final effects = selected.effects;
    final shadow = effects.shadow;
    final stroke = effects.stroke;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _panelHeader(
          EditorTool.effects,
          trailing: PillChip(
            key: const ValueKey('effects-reset'),
            label: 'Reset',
            onTap: () => _controller.resetLayerEffects(id),
          ),
        ),
        if (image != null) ...[
          const _PanelHint('FILTER'),
          const SizedBox(height: 8),
          FilterStrip(
            assetPath: image.assetPath,
            selected: image.adjustments.filter,
            onPick: (f) => _controller.setPhotoFilter(id, f),
          ),
          if (image.adjustments.hasFilter)
            LabeledSlider(
              label: 'Strength',
              value: image.adjustments.filterStrength * 100,
              min: 0,
              max: 100,
              accent: accent,
              valueLabel:
                  '${(image.adjustments.filterStrength * 100).round()}%',
              onChanged: (v) => _controller.setFilterStrength(id, v / 100),
              onChangeEnd: _endSliderEdit,
            ),
          const SizedBox(height: 10),
          const _PanelHint('HDR'),
          LabeledSlider(
            label: 'Tone + detail',
            value: image.adjustments.hdr * 100,
            min: 0,
            max: 100,
            accent: AppColors.greenLight,
            valueLabel: image.adjustments.hdr < 0.005
                ? 'Off'
                : '${(image.adjustments.hdr * 100).round()}%',
            onChanged: (v) => _controller.setHdr(id, v / 100),
            onChangeEnd: _endSliderEdit,
          ),
          const SizedBox(height: 6),
          const _PanelHint('VIGNETTE'),
          LabeledSlider(
            label: 'Amount',
            value: image.vignette.amount * 100,
            min: 0,
            max: 100,
            accent: AppColors.violet,
            valueLabel: image.vignette.amount < 0.005
                ? 'Off'
                : '${(image.vignette.amount * 100).round()}%',
            onChanged: (v) => _controller.updateVignette(id, amount: v / 100),
            onChangeEnd: _endSliderEdit,
          ),
          if (image.vignette.isVisible) ...[
            LabeledSlider(
              label: 'Size',
              value: image.vignette.size * 100,
              min: 5,
              max: 95,
              accent: AppColors.violet,
              valueLabel: '${(image.vignette.size * 100).round()}%',
              onChanged: (v) => _controller.updateVignette(id, size: v / 100),
              onChangeEnd: _endSliderEdit,
            ),
            LabeledSlider(
              label: 'Softness',
              value: image.vignette.softness * 100,
              min: 0,
              max: 100,
              accent: AppColors.violet,
              valueLabel: '${(image.vignette.softness * 100).round()}%',
              onChanged: (v) =>
                  _controller.updateVignette(id, softness: v / 100),
              onChangeEnd: _endSliderEdit,
            ),
            const SizedBox(height: 4),
            _swatchRow(
              'Color',
              image.vignette.color,
              (c) => _controller.updateVignette(id, color: c),
            ),
          ],
          const SizedBox(height: 12),
        ],
        const _PanelHint('SHADOW'),
        LabeledSlider(
          label: 'Opacity',
          value: shadow.enabled ? shadow.opacity * 100 : 0,
          min: 0,
          max: 100,
          accent: AppColors.cyan,
          valueLabel: shadow.isVisible
              ? '${(shadow.opacity * 100).round()}%'
              : 'Off',
          onChanged: (v) => _controller.updateLayerShadow(
            id,
            enabled: v > 0,
            opacity: v / 100,
          ),
          onChangeEnd: _endSliderEdit,
        ),
        if (shadow.isVisible) ...[
          LabeledSlider(
            label: 'Direction',
            value: shadow.angle,
            min: 0,
            max: 360,
            accent: AppColors.cyan,
            valueLabel: '${shadow.angle.round()}°',
            onChanged: (v) => _controller.updateLayerShadow(id, angle: v),
            onChangeEnd: _endSliderEdit,
          ),
          LabeledSlider(
            label: 'Distance',
            value: shadow.distance,
            min: 0,
            max: 120,
            accent: AppColors.cyan,
            valueLabel: '${shadow.distance.round()} px',
            onChanged: (v) => _controller.updateLayerShadow(id, distance: v),
            onChangeEnd: _endSliderEdit,
          ),
          LabeledSlider(
            label: 'Blur',
            value: shadow.blur,
            min: 0,
            max: 80,
            accent: AppColors.cyan,
            valueLabel: '${shadow.blur.round()} px',
            onChanged: (v) => _controller.updateLayerShadow(id, blur: v),
            onChangeEnd: _endSliderEdit,
          ),
          LabeledSlider(
            label: 'Density',
            value: shadow.density,
            min: 0,
            max: 30,
            accent: AppColors.cyan,
            valueLabel: '${shadow.density.round()} px',
            onChanged: (v) => _controller.updateLayerShadow(id, density: v),
            onChangeEnd: _endSliderEdit,
          ),
          const SizedBox(height: 4),
          _swatchRow(
            'Color',
            shadow.color,
            (c) => _controller.updateLayerShadow(id, color: c),
          ),
        ],
        const SizedBox(height: 12),
        _PanelHint(image?.maskPath != null ? 'CUTOUT OUTLINE' : 'OUTLINE'),
        LabeledSlider(
          label: 'Thickness',
          value: stroke.width,
          min: 0,
          max: 40,
          accent: AppColors.violetLight,
          valueLabel: stroke.width < 0.5 ? 'Off' : '${stroke.width.round()} px',
          onChanged: (v) => _controller.updateLayerStroke(id, width: v),
          onChangeEnd: _endSliderEdit,
        ),
        if (stroke.isVisible) ...[
          LabeledSlider(
            label: 'Opacity',
            value: stroke.opacity * 100,
            min: 0,
            max: 100,
            accent: AppColors.violetLight,
            valueLabel: '${(stroke.opacity * 100).round()}%',
            onChanged: (v) =>
                _controller.updateLayerStroke(id, opacity: v / 100),
            onChangeEnd: _endSliderEdit,
          ),
          const SizedBox(height: 4),
          _swatchRow(
            'Color',
            stroke.color,
            (c) => _controller.updateLayerStroke(id, color: c),
          ),
        ],
        const SizedBox(height: 14),
        const _PanelHint('BLEND'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final blend in LayerBlend.values)
              PillChip(
                key: ValueKey('blend-${blend.name}'),
                label: blend.label,
                accent: accent,
                selected: effects.blend == blend,
                onTap: () => _controller.setLayerBlend(id, blend),
              ),
          ],
        ),
      ],
    );
  }

  /// Contrasting ink for text on a given fill.
  Color _inkFor(Color fill) => (fill == Colors.white || fill == AppColors.amber)
      ? const Color(0xFF14101A)
      : Colors.white;

  // ------------------------------------------------------------ Cut out
  Widget _cutoutPanel(EditorState editor) {
    final selected = editor.selectedLayer;
    final image = selected is ImageLayer ? selected : null;
    final removed = image?.maskPath != null;
    final label = _removingBg
        ? 'Working…'
        : (removed ? 'Undo removal' : 'Remove background');
    final model = ref.watch(segModelProvider).asData?.value ?? SegModel.builtin;
    final removeMode = _removeObjectMode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 4),
          child: Text(
            'AI Background Removal',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.display,
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: AppColors.green,
            ),
          ),
        ),
        // A second mode removes objects by tapping them on the canvas (#83) -
        // works on the raw photo (MobileSAM), no prior background cut needed.
        if (image != null) ...[
          Row(
            children: [
              Expanded(
                child: _segTab(
                  'Background',
                  !removeMode,
                  AppColors.green,
                  () => setState(() => _removeObjectMode = false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _segTab('Remove object', removeMode, AppColors.rose, () {
                  setState(() => _removeObjectMode = true);
                  // Warm the SAM image embedding while the user aims, so
                  // the first escalated tap only pays the decoder (#85) -
                  // skipped entirely on capability-denied devices and after
                  // a hard engine failure.
                  unawaited(_precomputeSamIfAllowed(image.assetPath));
                }),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
        if (removeMode) ...[
          _emptyHint(
            'Tap an unwanted object on the photo to remove it - a stray '
            'item, a second subject, clutter. Tapping the main subject is '
            'safely ignored; undo brings anything back.',
          ),
          if (ref.watch(inpaintAvailableProvider).asData?.value ?? false) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _segTab(
                    'Erase',
                    !_fillMode,
                    AppColors.rose,
                    () => setState(() => _fillMode = false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _segTab(
                    'Fill (AI)',
                    _fillMode,
                    AppColors.cyan,
                    () => setState(() => _fillMode = true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              _fillMode
                  ? 'Fill replaces the object with matching background.'
                  : 'Erase cuts the object out to transparency.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 10.5,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ] else ...[
          _emptyHint(
            image == null
                ? 'Select a photo layer to cut out.'
                : "One tap to isolate your subject. We'll auto-detect the "
                      'edges - refine anything by hand in the Erase tool.',
          ),
          _modelPicker(model),
          const SizedBox(height: 16),
          GradientButton(
            label: label,
            icon: Icons.auto_awesome,
            busy: _removingBg,
            gradient: removed ? null : context.tokens.cutoutGradient,
            solidColor: removed ? AppColors.neutralButton : null,
            foreground: removed ? AppColors.textSecondary : AppColors.cutoutInk,
            glowColor: AppColors.green,
            onPressed: image == null
                ? null
                : () {
                    if (removed) {
                      _controller.setImageMask(image.id, null);
                      _toast('Background restored');
                    } else {
                      _removeBackground(image);
                    }
                  },
          ),
        ],
      ],
    );
  }

  /// The "AI Model" picker: a labelled radio list of [SegModel]s plus a "?"
  /// that opens the info sheet. Tapping a row persists the preference (which
  /// engine `_removeBackground` runs first).
  Widget _modelPicker(SegModel selected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              const Text(
                'AI MODEL',
                style: TextStyle(
                  fontFamily: AppFonts.ui,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 7),
              _modelInfoButton(),
            ],
          ),
        ),
        for (final m in SegModel.values) ...[
          _modelRow(m, selected: m == selected),
          if (m != SegModel.values.last) const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _modelInfoButton() {
    return GestureDetector(
      onTap: _showModelInfo,
      child: Container(
        width: 20,
        height: 20,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.green.withValues(alpha: 0.12),
          border: Border.all(
            color: AppColors.green.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        child: const Text(
          '?',
          style: TextStyle(
            fontFamily: AppFonts.display,
            fontWeight: FontWeight.w700,
            fontSize: 12,
            height: 1,
            color: AppColors.greenLight,
          ),
        ),
      ),
    );
  }

  Widget _modelRow(SegModel model, {required bool selected}) {
    return GestureDetector(
      onTap: _removingBg
          ? null
          : () => ref.read(segModelProvider.notifier).select(model),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.green.withValues(alpha: 0.10)
              : AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? AppColors.green.withValues(alpha: 0.6)
                : AppColors.border,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            _modelRadio(selected),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    model.label,
                    style: const TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    model.tagline,
                    style: const TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modelRadio(bool selected) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.green : Colors.transparent,
        border: selected
            ? null
            : Border.all(color: Colors.white.withValues(alpha: 0.22), width: 2),
      ),
      child: selected
          ? const DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: SizedBox(width: 8, height: 8),
            )
          : null,
    );
  }

  /// Bottom sheet explaining the two models (design's "Which AI model?").
  Future<void> _showModelInfo() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 14),
                child: Text(
                  'Which AI model?',
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    color: AppColors.green,
                  ),
                ),
              ),
              for (final m in SegModel.values) ...[
                _modelInfoCard(m),
                if (m != SegModel.values.last) const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _modelInfoCard(SegModel model) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.inputField,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            model.label,
            style: const TextStyle(
              fontFamily: AppFonts.ui,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.greenLight,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            model.blurb,
            style: const TextStyle(
              fontFamily: AppFonts.ui,
              fontSize: 12.5,
              height: 1.55,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// True once the user has unlocked AI actions this editor session (Pro, or by
  /// watching one rewarded ad). Gates every AI invocation uniformly so the ad
  /// can't be routed around, and isn't re-charged per action.
  bool _aiUnlockedThisSession = false;

  /// Ensures AI actions are unlocked: Pro or already-unlocked → true; otherwise
  /// asks the user to opt in, then shows a rewarded ad and unlocks on reward.
  /// The opt-in prompt keeps the full-screen rewarded ad user-initiated with a
  /// clear choice (AdMob policy) instead of launching it unannounced.
  Future<bool> _ensureAiAllowed() async {
    if (_aiUnlockedThisSession || ref.read(isProProvider)) return true;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text(
          'Unlock AI tools',
          style: TextStyle(
            fontFamily: AppFonts.display,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
        content: const Text(
          'Watch a short ad to use AI tools for this editing session - or go '
          'Pro to remove ads entirely.',
          style: TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 13.5,
            height: 1.4,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'pro'),
            child: const Text('Go Pro'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'ad'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.cyan,
              foregroundColor: AppColors.cutoutInk,
            ),
            child: const Text('Watch ad'),
          ),
        ],
      ),
    );
    if (!mounted || choice == 'cancel' || choice == null) return false;
    if (choice == 'pro') {
      unawaited(context.pushNamed(Routes.goPro));
      return false;
    }
    final rewarded = await ref.read(adsServiceProvider).showRewarded();
    if (rewarded) {
      _aiUnlockedThisSession = true;
    } else if (mounted) {
      _toast('Watch the full ad to use AI, or Go Pro to remove ads');
    }
    return rewarded;
  }

  /// Runs the AI cut-out for [image]: pick the best available segmentation
  /// engine, clean up the mask, persist it and apply it to the layer (undoable
  /// via the controller's history). Gracefully reports when no engine can run.
  Future<void> _removeBackground(ImageLayer image, {bool refine = true}) async {
    if (!await _ensureAiAllowed()) return;
    setState(() => _removingBg = true);
    try {
      final registry = ref.read(segmentationRegistryProvider);
      final preferred =
          ref.read(segModelProvider).asData?.value ?? SegModel.builtin;
      final result = await registry.segment(
        SegmentationRequest(imagePath: image.assetPath),
        preferredId: preferred.engineId,
      );
      if (result == null) {
        if (mounted) {
          _toast("Background removal isn't available on this device yet");
        }
        return;
      }
      // The clean-up chain crunches every pixel of a photo-sized mask - run it
      // off the UI isolate so the "Working…" spinner actually animates
      // (docs/reviews/2026-07-19-review.md).
      final mask = await _processCutoutMask(result.mask, refine: refine);
      final path = await ref.read(maskStoreProvider).save(mask, id: image.id);
      _maskGc.supersede(image.maskPath, path);
      _controller.setImageMask(image.id, path);
      if (mounted) {
        // Report which engine actually ran - it may differ from the preference
        // if that one was unavailable and the registry fell through.
        final used = SegModel.fromEngineId(result.engineId);
        _toast(
          used == null
              ? 'Background removed'
              : 'Background removed · ${used.label}',
        );
      }
    } catch (_) {
      if (mounted) _toast("Couldn't remove the background - try again");
    } finally {
      if (mounted) setState(() => _removingBg = false);
    }
  }

  /// The design's AI-Cut bottom sheet: pick the on-device engine (ML Kit vs
  /// U²-Net) then remove the selected photo's background. Reuses the persisted
  /// [SegModel] preference and [_removeBackground]; processing shows on the
  /// canvas overlay. (Object-removal mode + edge-feather land next.)
  /// Runs the preferred engine over [image] and returns the raw mask (no
  /// commit), so the sheet can feather it before applying.
  Future<SegmentationResult?> _segment(ImageLayer image) {
    final registry = ref.read(segmentationRegistryProvider);
    final preferred =
        ref.read(segModelProvider).asData?.value ?? SegModel.builtin;
    return registry.segment(
      SegmentationRequest(imagePath: image.assetPath),
      preferredId: preferred.engineId,
    );
  }

  /// Processes [mask] (keep-largest + [feather]) and applies it to [image] as
  /// its cut-out alpha. Re-callable from the done stage's feather slider.
  Future<void> _applyCutout(
    ImageLayer image,
    AlphaMask mask, {
    required bool keepLargest,
    required int feather,
  }) async {
    final processed = await _processMask(
      mask,
      keepLargest: keepLargest,
      feather: feather,
    );
    final path = await ref
        .read(maskStoreProvider)
        .save(processed, id: image.id);
    _maskGc.supersede(image.maskPath, path);
    if (mounted) _controller.setImageMask(image.id, path);
  }

  void _showBgSheet() {
    final selected = ref.read(editorControllerProvider).selectedLayer;
    final image = selected is ImageLayer ? selected : null;
    if (image == null) {
      _toast('Select a photo layer to cut out');
      return;
    }
    var objectMode = false;
    var autoRefine = true;
    var stage = 'choose'; // choose | processing | done
    var feather = 2.0;
    var engineLabel = '';
    AlphaMask? raw;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheet) => Consumer(
          builder: (ctx, sheetRef, _) {
            final model =
                sheetRef.watch(segModelProvider).asData?.value ??
                SegModel.builtin;

            Future<void> run() async {
              // Watch one rewarded ad per session to unlock AI (Pro skips it).
              if (!await _ensureAiAllowed() || !sheetCtx.mounted) return;
              if (objectMode) {
                Navigator.of(sheetCtx).pop();
                _startObjectRemoval(image);
                return;
              }
              engineLabel = model.label;
              setSheet(() => stage = 'processing');
              final result = await _segment(image);
              if (!sheetCtx.mounted) return;
              if (result == null) {
                setSheet(() => stage = 'choose');
                _toast("Background removal isn't available on this device yet");
                return;
              }
              raw = result.mask;
              await _applyCutout(
                image,
                raw!,
                keepLargest: autoRefine,
                feather: feather.round(),
              );
              if (!sheetCtx.mounted) return;
              setSheet(() => stage = 'done');
            }

            final List<Widget> children;
            if (stage == 'processing') {
              children = [
                const SizedBox(height: 12),
                const SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(
                    strokeWidth: 5,
                    color: AppColors.cyan,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '$engineLabel is working…',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: AppFonts.display,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Detecting the subject & refining edges · on device',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
              ];
            } else if (stage == 'done') {
              children = [
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        color: AppColors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 18,
                        color: AppColors.cutoutInk,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Background removed',
                      style: TextStyle(
                        fontFamily: AppFonts.display,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Text(
                      'Edge feather',
                      style: TextStyle(
                        fontFamily: AppFonts.ui,
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        value: feather,
                        max: 8,
                        divisions: 8,
                        activeColor: AppColors.cyan,
                        label: feather.round().toString(),
                        onChanged: (v) => setSheet(() => feather = v),
                        onChangeEnd: (v) => _applyCutout(
                          image,
                          raw!,
                          keepLargest: autoRefine,
                          feather: v.round(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () => setSheet(() => stage = 'choose'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.border),
                        minimumSize: const Size(52, 50),
                      ),
                      child: const Icon(Icons.refresh, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(sheetCtx).pop(),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.cyan,
                          foregroundColor: AppColors.cutoutInk,
                          minimumSize: const Size.fromHeight(50),
                        ),
                        child: const Text(
                          'Apply to layer',
                          style: TextStyle(
                            fontFamily: AppFonts.display,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ];
            } else {
              children = [
                _bgModeToggle(
                  objectMode,
                  (v) => setSheet(() => objectMode = v),
                ),
                const SizedBox(height: 16),
                Text(
                  objectMode ? 'Remove an object' : 'Remove background',
                  style: const TextStyle(
                    fontFamily: AppFonts.display,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  objectMode
                      ? 'Tap objects on the photo to erase them'
                      : 'Choose an AI engine · runs on your device',
                  style: const TextStyle(
                    fontFamily: AppFonts.ui,
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                // The engine picker only affects background removal; object
                // removal uses MobileSAM, so hide it in Object mode.
                if (!objectMode)
                  for (final m in SegModel.values)
                    _bgEngineCard(
                      model,
                      m,
                      () => sheetRef.read(segModelProvider.notifier).select(m),
                    ),
                if (!objectMode)
                  _bgRefineToggle(
                    autoRefine,
                    (v) => setSheet(() => autoRefine = v),
                  ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: run,
                  style: FilledButton.styleFrom(
                    backgroundColor: objectMode
                        ? AppColors.pink
                        : AppColors.cyan,
                    foregroundColor: AppColors.cutoutInk,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: Text(
                    objectMode ? 'Tap objects to remove' : 'Remove background',
                    style: const TextStyle(
                      fontFamily: AppFonts.display,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ];
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                14,
                20,
                20 + MediaQuery.viewInsetsOf(ctx).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.elevated,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...children,
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// "Auto-refine edges" toggle - gates the keep-largest-component + feather
  /// clean-up on the raw engine mask (off = keep the raw soft mask).
  Widget _bgRefineToggle(bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Auto-refine edges',
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: AppColors.cutoutInk,
            activeTrackColor: AppColors.cyan,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  /// Background | Object segmented toggle for the AI-Cut sheet.
  Widget _bgModeToggle(bool object, ValueChanged<bool> onChanged) {
    Widget tab(String label, bool active, VoidCallback onTap) => Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.cyan : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
              color: active ? AppColors.cutoutInk : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.cardAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderFaint),
      ),
      child: Row(
        children: [
          tab('Background', !object, () => onChanged(false)),
          tab('Object', object, () => onChanged(true)),
        ],
      ),
    );
  }

  /// Enters tap-to-remove-object mode on the photo - MobileSAM segments the
  /// tapped object and cuts it out (no prior background removal required); the
  /// cutout tool's panel provides the mode's exit.
  void _startObjectRemoval(ImageLayer image) {
    _controller.setTool(EditorTool.cutout);
    setState(() => _removeObjectMode = true);
    _toast('Tap an object on the photo to remove it');
    unawaited(_precomputeSamIfAllowed(image.assetPath));
  }

  Widget _bgEngineCard(SegModel current, SegModel model, VoidCallback onTap) {
    final active = current == model;
    final accent = model == SegModel.builtin ? AppColors.cyan : AppColors.pink;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: active ? accent.withValues(alpha: 0.1) : AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active ? accent : AppColors.borderFaint,
              width: 1.6,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  model == SegModel.builtin
                      ? Icons.auto_awesome
                      : Icons.blur_on,
                  color: AppColors.cutoutInk,
                  size: 22,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.label,
                      style: const TextStyle(
                        fontFamily: AppFonts.ui,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      model.tagline,
                      style: const TextStyle(
                        fontFamily: AppFonts.ui,
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: active ? accent : AppColors.textFaint,
                    width: 2,
                  ),
                ),
                child: active
                    ? Center(
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accent,
                          ),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Enqueues an erase stroke onto [_strokeLock] so strokes apply strictly in
  /// order - overlapping async applies (esp. the cold-cache rebuild-after-await)
  /// can't interleave and drop each other's dabs.
  void _applyEraseStroke(List<Offset> pointsLogical) {
    _strokeLock = _strokeLock
        .then((_) => _runEraseStroke(pointsLogical))
        .catchError((Object _) {});
  }

  /// Applies an Erase/Restore brush stroke (points in 512-logical canvas units)
  /// to the selected photo's alpha mask: map into mask pixels, paint, persist
  /// and apply - undoable per stroke. A working mask is cached across dabs so we
  /// don't decode the mask file every time; it reloads on a layer/mask change.
  /// Loads (or reuses) the working mask + image size for [layer]. Shared by
  /// the Erase brush and tap-to-remove (#83); false when the widget unmounted
  /// mid-load.
  Future<bool> _ensureWorkingMask(ImageLayer layer) async {
    if (_workingMask != null &&
        _workingImageSize != null &&
        _workingMaskLayerId == layer.id &&
        _workingMaskPath == layer.maskPath) {
      return true;
    }
    final size = await MaskStore.decodeImageSize(layer.assetPath);
    final mask = layer.maskPath != null
        ? await ref.read(maskStoreProvider).load(layer.maskPath!)
        : AlphaMask.filled(size.width.round(), size.height.round(), 255);
    if (!mounted) return false;
    _workingImageSize = size;
    _workingMask = mask;
    _workingMaskLayerId = layer.id;
    _workingMaskPath = layer.maskPath;
    return true;
  }

  Future<void> _runEraseStroke(List<Offset> pointsLogical) async {
    final layer = ref.read(editorControllerProvider).selectedLayer;
    if (layer is! ImageLayer) return;
    try {
      if (!await _ensureWorkingMask(layer)) return;
      final mapper = MaskMapper(
        imageSize: _workingImageSize!,
        position: layer.transform.position,
        layerScale: layer.transform.scale,
        rotation: layer.transform.rotation,
        cropRect: layer.cropRect,
      );
      final maskPoints = <Offset>[
        for (final p in pointsLogical) ?mapper.canvasToMask(p),
      ];
      if (maskPoints.isEmpty) return;
      final painted = await _paintStroke(
        _workingMask!,
        BrushStroke(
          points: maskPoints,
          radius: mapper.radiusToMask(_brushSize / 2),
          erase: _eraseMode,
          soft: _softEdges,
        ),
      );
      if (!mounted) return;
      _workingMask = painted;
      final path = await ref
          .read(maskStoreProvider)
          .save(painted, id: layer.id);
      if (!mounted) return;
      // The mask this stroke replaces becomes an undo-only reference; queue it
      // for reclamation once it drops out of history.
      _maskGc.supersede(layer.maskPath, path);
      _workingMaskPath = path;
      _controller.setImageMask(layer.id, path);
    } catch (_) {
      if (mounted) _toast("Couldn't apply the brush");
    }
  }

  /// Enqueues a remove-object tap on the same lock as erase strokes, so a tap
  /// can't interleave with an in-flight brush apply on the same mask (#83).
  void _applyObjectRemoval(Offset pointLogical) {
    _strokeLock = _strokeLock
        .then((_) => _removeObjectAt(pointLogical))
        .catchError((Object _) {});
  }

  /// Tier-1 object removal (#83): the tapped 4-connected blob of the cutout's
  /// alpha is subtracted (with a feathered seam) - no ML involved. Tapping the
  /// largest blob (the subject) or transparency is a safe no-op.
  Future<void> _removeObjectAt(Offset pointLogical) async {
    final layer = ref.read(editorControllerProvider).selectedLayer;
    if (layer is! ImageLayer) return;
    try {
      if (!await _ensureWorkingMask(layer)) return;
      final mapper = MaskMapper(
        imageSize: _workingImageSize!,
        position: layer.transform.position,
        layerScale: layer.transform.scale,
        rotation: layer.transform.rotation,
        cropRect: layer.cropRect,
      );
      final maskPoint = mapper.canvasToMask(pointLogical);
      if (maskPoint == null) return; // missed the photo entirely
      // AI object removal is gated like the other AI actions (once per session;
      // Pro skips). Placed after the "hit the photo" checks so an empty-space
      // tap never spends the unlock, and it can't be routed around via the
      // erase-seeded cutout panel.
      if (!await _ensureAiAllowed()) return;
      // Component labelling + feathered subtract walk the whole mask several
      // times - off the UI isolate (docs/reviews/2026-07-19-review.md). Still
      // serialized behind [_strokeLock], so the working mask can't change
      // underneath the hop.
      final result = await _removeTappedObject(
        _workingMask!,
        maskPoint.dx.round(),
        maskPoint.dy.round(),
      );
      if (!mounted) return;
      switch (result.outcome) {
        case RemoveTapOutcome.miss:
          if (mounted) _toast('Nothing to remove there');
        case RemoveTapOutcome.subject:
          // The tapped blob IS (or touches) the biggest one - the free CC
          // tier can't carve an attached object out. Escalate to the
          // point-prompt model (#86): tap coords are already source px.
          await _samRemoveAt(layer, maskPoint);
        case RemoveTapOutcome.removed:
          if (_fillMode &&
              (ref.read(inpaintAvailableProvider).asData?.value ?? false)) {
            // Fill the removed blob with synthesized background rather than
            // cutting it out to transparency.
            final blob = await _removedRegion(_workingMask!, result.mask!);
            if (!mounted) return;
            await _inpaintObject(layer, blob, _workingMask!);
          } else {
            await _applyRemovedMask(layer, result.mask!);
            if (mounted) _toast('Object removed - undo brings it back');
          }
      }
    } catch (_) {
      if (mounted) _toast("Couldn't remove that - try again");
    }
  }

  /// Persists [next] as the layer's mask - shared by both removal tiers.
  Future<void> _applyRemovedMask(ImageLayer layer, AlphaMask next) async {
    _workingMask = next;
    final path = await ref.read(maskStoreProvider).save(next, id: layer.id);
    if (!mounted) return;
    _maskGc.supersede(layer.maskPath, path);
    _workingMaskPath = path;
    _controller.setImageMask(layer.id, path);
  }

  /// Warms the SAM embedding for [assetPath] so the first escalated tap only
  /// pays the decoder (#85). Skipped when the capability gate denies the SAM
  /// tier (the ~100 MB-transient encoder must never run on low-RAM devices)
  /// or after a hard engine failure this session; a warm-up throw is itself
  /// remembered as a hard failure so taps stop retrying a dead runtime.
  Future<void> _precomputeSamIfAllowed(String assetPath) async {
    if (_samEngineFailed) return;
    final capability = await ref.read(aiCapabilityProvider.future);
    if (!capability.samAllowed) return;
    try {
      await ref.read(objectSegmentationEngineProvider).precompute(assetPath);
    } catch (_) {
      _samEngineFailed = true;
    }
  }

  /// Tier 2 (#84/#85/#86): MobileSAM point-prompt segmentation of the tapped
  /// object, subtracted from the cutout. Guarded so a tap on the subject
  /// itself (SAM returning essentially the whole remaining foreground) never
  /// removes the layer.
  Future<void> _samRemoveAt(ImageLayer layer, Offset maskPoint) async {
    // Capability gate first: on denied devices (and after a hard engine
    // failure) short-circuit before paying any decode/encoder cost, and be
    // honest that the CAPABILITY is missing - this is not the user's tap.
    final capability = await ref.read(aiCapabilityProvider.future);
    if (!capability.samAllowed || _samEngineFailed) {
      if (mounted) _toast(samUnavailableMessage);
      return;
    }
    final engine = ref.read(objectSegmentationEngineProvider);
    if (!await engine.isAvailable()) {
      if (mounted) _toast(samUnavailableMessage);
      return;
    }
    if (mounted) setState(() => _samBusy = true);
    try {
      final AlphaMask? object;
      try {
        object = await engine.segmentAt(layer.assetPath, [
          PromptPoint(maskPoint),
        ]);
      } catch (_) {
        // A throwing engine (broken ORT runtime, unloadable model) won't heal
        // this session - remember it so the next tap short-circuits to the
        // capability toast instead of re-paying the whole attempt. Only the
        // engine call trips the flag: failures past this point (a transient
        // mask-save IO error, say) are retryable and must not disable the
        // tier.
        _samEngineFailed = true;
        if (mounted) _toast("Couldn't remove that - try again");
        return;
      }
      if (!mounted) return;
      final current = _workingMask;
      if (object == null || current == null) {
        _toast("Couldn't find an object there");
        return;
      }
      // Overlap with what the cutout currently keeps - a per-pixel pass over
      // the full mask, so off the UI isolate (docs/reviews/2026-07-19-review.md).
      final stats = await _maskOverlap(current, object);
      if (!mounted) return;
      if (stats.overlap == 0) {
        _toast("Couldn't find an object there");
        return;
      }
      if (stats.overlap > stats.kept * 0.8) {
        _toast('That looks like your subject - use Erase for fine edits');
        return;
      }
      // Fill mode: replace the object with synthesized background instead of
      // erasing it to transparency (falls back to erase if the model can't run).
      if (_fillMode) {
        await _inpaintObject(layer, object, current);
        return;
      }
      // Feather + subtract are two more full-mask passes - same treatment.
      final next = await _subtractObject(current, object);
      if (!mounted) return;
      await _applyRemovedMask(layer, next);
      if (mounted) _toast('Object removed - undo brings it back');
    } catch (_) {
      if (mounted) _toast("Couldn't remove that - try again");
    } finally {
      if (mounted) setState(() => _samBusy = false);
    }
  }

  /// Generative fill (MI-GAN): replaces the tapped [object] region in [layer]'s
  /// photo with synthesized background, swapping in the new image. Falls back to
  /// erasing (subtract from [current]) when the model is absent or fails.
  Future<void> _inpaintObject(
    ImageLayer layer,
    AlphaMask object,
    AlphaMask current,
  ) async {
    if (mounted) setState(() => _inpainting = true);
    try {
      final filled = await _tryInpaint(layer, object);
      if (!mounted) return;
      if (filled == null) {
        final next = await _subtractObject(current, object);
        if (!mounted) return;
        await _applyRemovedMask(layer, next);
        if (mounted) _toast('Fill unavailable - erased instead');
        return;
      }
      final newPath = await ref
          .read(imageImportServiceProvider)
          .storeBytes(filled);
      if (!mounted) return;
      _controller.replaceImageAsset(layer.id, newPath);
      if (mounted) _toast('Object filled in - undo reverts');
    } finally {
      if (mounted) setState(() => _inpainting = false);
    }
  }

  Future<Uint8List?> _tryInpaint(ImageLayer layer, AlphaMask object) async {
    try {
      final bytes = await File(layer.assetPath).readAsBytes();
      return await ref.read(inpaintEngineProvider).inpaint(bytes, object);
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------ Erase
  Widget _erasePanel() {
    // Erasing needs a photo layer - strokes no-op without one, so guide instead
    // of showing live brush controls that do nothing.
    final selected = ref.read(editorControllerProvider).selectedLayer;
    if (selected is! ImageLayer) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _panelHeader(EditorTool.erase),
          _emptyHint('Select a photo layer to erase, or add a photo.'),
        ],
      );
    }
    final brushPreview = (_brushSize * 0.4).clamp(8.0, 40.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _panelHeader(
          EditorTool.erase,
          trailing: const _PanelHint('Brush over the canvas'),
        ),
        Row(
          children: [
            Expanded(
              child: _segTab(
                'Erase',
                _eraseMode,
                AppColors.amber,
                () => setState(() => _eraseMode = true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _segTab(
                'Restore',
                !_eraseMode,
                AppColors.green,
                () => setState(() => _eraseMode = false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: LabeledSlider(
                label: 'Brush size',
                value: _brushSize,
                min: 8,
                max: 120,
                accent: AppColors.amber,
                valueColor: AppColors.textMuted,
                valueLabel: '${_brushSize.round()}px',
                onChanged: (v) => setState(() => _brushSize = v),
              ),
            ),
            const SizedBox(width: 14),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                width: brushPreview,
                height: brushPreview,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.amber.withValues(alpha: 0.25),
                  border: Border.all(color: AppColors.amber, width: 2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Soft edges',
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            Switch(
              value: _softEdges,
              activeThumbColor: Colors.white,
              activeTrackColor: AppColors.amber,
              onChanged: (v) => setState(() => _softEdges = v),
            ),
          ],
        ),
      ],
    );
  }

  // ------------------------------------------------------------ Frames
  Widget _framesPanel(EditorState editor) {
    final frames = editor.project.frames;
    final current = editor.project.currentFrameIndex;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _panelHeader(
          EditorTool.frames,
          trailing: PillChip(
            label: _isPlaying ? 'Pause' : 'Play',
            icon: _isPlaying ? Icons.pause : Icons.play_arrow,
            accent: AppColors.orange,
            selected: true,
            onTap: () => _togglePlayback(editor),
          ),
        ),
        SizedBox(
          height: 64,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: frames.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              if (i == frames.length) return _addFrameButton();
              return _FrameThumb(
                key: ValueKey('frame-thumb-${frames[i].id}'),
                index: i,
                frame: frames[i],
                project: editor.project,
                active: i == current,
                onTap: () => _controller.selectFrame(i),
                onMenu: () => _showFrameMenu(i, frames.length),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        _fpsControl(editor),
        if (frames.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'New layers to all frames',
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Switch(
                  value: _controller.addToAllFrames,
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppColors.orange,
                  onChanged: (v) =>
                      setState(() => _controller.addToAllFrames = v),
                ),
              ],
            ),
          ),
        if (frames.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Onion skin (ghost previous)',
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Switch(
                value: _onionSkin,
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.orange,
                onChanged: (v) => setState(() => _onionSkin = v),
              ),
            ],
          ),
      ],
    );
  }

  Widget _addFrameButton() {
    return GestureDetector(
      onTap: _controller.addFrame,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.orange.withValues(alpha: 0.4),
            width: 2,
          ),
        ),
        child: const Icon(Icons.add, color: AppColors.orange),
      ),
    );
  }

  /// Long-press menu for a frame: duplicate, reorder (when not at an edge), or
  /// delete (when >1 frame).
  Future<void> _showFrameMenu(int index, int frameCount) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetTile(
              ctx,
              Icons.copy_all_outlined,
              'Duplicate frame',
              'duplicate',
            ),
            if (index > 0)
              _sheetTile(ctx, Icons.arrow_back, 'Move left', 'move_left'),
            if (index < frameCount - 1)
              _sheetTile(ctx, Icons.arrow_forward, 'Move right', 'move_right'),
            if (frameCount > 1)
              _sheetTile(ctx, Icons.delete_outline, 'Delete frame', 'delete'),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    switch (choice) {
      case 'duplicate':
        _controller.duplicateFrame(index);
      case 'move_left':
        _controller.reorderFrame(index, index - 1);
      case 'move_right':
        _controller.reorderFrame(index, index + 1);
      case 'delete':
        _controller.deleteFrame(index);
    }
  }

  // ------------------------------------------------------------ Layers
  Widget _layersPanel(EditorState editor) {
    final layers = editor.layers;
    final selectedId = editor.selectedLayerId;
    final canMergeDown =
        selectedId != null &&
        LayerFlattener.mergeDownTarget(editor.currentFrame, selectedId) != null;
    final canFlatten = LayerFlattener.canFlatten(editor.project);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _panelHeader(
          EditorTool.layers,
          trailing: PillChip(
            label: 'Add',
            icon: Icons.add,
            onTap: _showAddMenu,
          ),
        ),
        if (canMergeDown || canFlatten) ...[
          Row(
            children: [
              if (canMergeDown)
                Expanded(
                  child: PillChip(
                    key: const ValueKey('merge-down'),
                    label: 'Merge down',
                    icon: Icons.vertical_align_bottom,
                    onTap: () => _mergeDown(selectedId),
                  ),
                ),
              if (canMergeDown && canFlatten) const SizedBox(width: 8),
              if (canFlatten)
                Expanded(
                  child: PillChip(
                    key: const ValueKey('flatten-layers'),
                    label: 'Flatten',
                    icon: Icons.layers_clear,
                    onTap: _flattenLayers,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        if (layers.isEmpty)
          _emptyHint('No layers yet. Tap Add to import a photo or add text.')
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: layers.length,
            onReorderItem: (oldIndex, newIndex) =>
                _controller.reorderLayer(oldIndex, newIndex),
            itemBuilder: (context, i) {
              final layer = layers[i];
              return _LayerRow(
                key: ValueKey(layer.id),
                layer: layer,
                selected: editor.selectedLayerId == layer.id,
                onSelect: () => _controller.selectLayer(layer.id),
                onRename: () => _showRenameDialog(layer),
                onToggleVisibility: () =>
                    _controller.toggleVisibility(layer.id),
                onDuplicate: () => _controller.duplicateLayer(layer.id),
                onDelete: () => _controller.removeLayer(layer.id),
              );
            },
          ),
      ],
    );
  }

  /// Folds the selected layer into the one below it (within the same Photo
  /// Grid cell), baking both into a single photo layer.
  Future<void> _mergeDown(String id) async {
    final frame = ref.read(editorControllerProvider).currentFrame;
    final below = LayerFlattener.mergeDownTarget(frame, id);
    if (below == null) return;
    final top = frame.layers.firstWhere((l) => l.id == id);
    await _merge([
      [below, top],
    ], 'Merged 2 layers');
  }

  /// Bakes each group of stacked layers into one photo. A collage flattens per
  /// cell, so the grid itself survives (see [LayerFlattener.flattenGroups]).
  Future<void> _flattenLayers() async {
    final groups = LayerFlattener.flattenGroups(
      ref.read(editorControllerProvider).currentFrame,
    );
    if (groups.isEmpty) return;
    final count = groups.fold<int>(0, (n, g) => n + g.length);
    await _merge(groups, 'Flattened $count layers');
  }

  /// Renders each group to a PNG and swaps the originals for it - one undo
  /// step for the whole operation, whatever it merged.
  Future<void> _merge(List<List<Layer>> groups, String doneMessage) async {
    if (_merging) return;
    setState(() => _merging = true);
    final project = ref.read(editorControllerProvider).project;
    final imports = ref.read(imageImportServiceProvider);
    try {
      final specs = <MergedLayerSpec>[];
      for (final group in groups) {
        final bytes = await LayerFlattener.renderPng(
          group,
          canvasWidth: project.canvasWidth,
          canvasHeight: project.canvasHeight,
        );
        specs.add(
          MergedLayerSpec(
            ids: [for (final l in group) l.id],
            assetPath: await imports.storeBytes(bytes),
            name: LayerFlattener.mergedName(group),
          ),
        );
      }
      if (!mounted) return;
      _controller.applyMerges(specs);
      _toast(doneMessage);
    } catch (_) {
      if (mounted) _toast("Couldn't merge those layers");
    } finally {
      if (mounted) setState(() => _merging = false);
    }
  }

  /// Imports a photo from the given [source] and adds it as an image layer.
  /// The Photo Grid cell a newly imported photo should land in: the selected
  /// layer's cell, else the first empty one. Null on an ordinary project, or
  /// when the collage has no empty cell and nothing is selected - the photo
  /// then becomes a free layer above the grid.
  String? _targetCell() {
    final editor = ref.read(editorControllerProvider);
    final grid = editor.project.grid;
    if (grid == null) return null;
    final selected = editor.selectedLayer?.cellId;
    if (selected != null) return selected;
    final taken = editor.layers.map((l) => l.cellId).toSet();
    for (final id in grid.cellIds) {
      if (!taken.contains(id)) return id;
    }
    return null;
  }

  /// Imports a photo straight into Photo Grid cell [cellId] - the empty-cell
  /// tap on the canvas.
  Future<void> _pickPhotoIntoCell(String cellId) async {
    try {
      final path = await ref.read(imageImportServiceProvider).pickFromGallery();
      if (path == null) return; // cancelled
      _controller.addPhotoToCell(
        assetPath: path,
        cellId: cellId,
        pixels: await _decodeImageSize(path),
      );
    } catch (_) {
      if (mounted) _toast('Could not import photo');
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final service = ref.read(imageImportServiceProvider);
    try {
      final path = source == ImageSource.camera
          ? await service.pickFromCamera()
          : await service.pickFromGallery();
      if (path == null) return; // cancelled
      // In a collage a photo belongs to a cell, cover-scaled to fill it.
      final cell = _targetCell();
      if (cell != null) {
        _controller.addPhotoToCell(
          assetPath: path,
          cellId: cell,
          pixels: await _decodeImageSize(path),
        );
        return;
      }
      // Importing a photo NEVER resizes the canvas - a blank project keeps the
      // size the user chose. (To start with the canvas sized to a photo, use
      // "Open a photo" on Home.) The first photo is placed scaled to FIT.
      final wasEmpty = ref.read(editorControllerProvider).layers.isEmpty;
      final pixels = wasEmpty ? await _decodeImageSize(path) : null;
      final layer = _controller.addImageLayer(assetPath: path);
      if (pixels != null) {
        final canvas = ref.read(editorControllerProvider).project;
        _controller.updateTransform(
          layer.id,
          LayerTransform(
            position: canvas.canvasCenter,
            scale: photoFitScale(
              pixels,
              canvas.canvasWidth,
              canvas.canvasHeight,
            ),
          ),
        );
      }
      _controller.setTool(EditorTool.adjust);
    } catch (_) {
      if (mounted) _toast('Could not import photo');
    }
  }

  /// Decodes just the header of [path] to read the source image's pixel size.
  Future<Size?> _decodeImageSize(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final size = Size(image.width.toDouble(), image.height.toDouble());
      image.dispose();
      codec.dispose();
      return size;
    } catch (_) {
      return null;
    }
  }

  /// Pastes an image from the clipboard as a new image layer.
  Future<void> _pastePhoto() async {
    final service = ref.read(imageImportServiceProvider);
    try {
      final path = await service.pasteFromClipboard();
      if (path == null) {
        if (mounted) _toast('No image in clipboard');
        return;
      }
      _controller.addImageLayer(assetPath: path);
      _controller.setTool(EditorTool.adjust);
    } catch (_) {
      if (mounted) _toast('Could not paste image');
    }
  }

  /// Bottom sheet to add a layer: a photo (camera / gallery) or text.
  Future<void> _showAddMenu() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetTile(
              ctx,
              Icons.photo_camera_outlined,
              'Take photo',
              'camera',
            ),
            _sheetTile(
              ctx,
              Icons.photo_library_outlined,
              'Choose photo',
              'gallery',
            ),
            _sheetTile(ctx, Icons.content_paste, 'Paste image', 'paste'),
            _sheetTile(ctx, Icons.title, 'Add text', 'text'),
            _sheetTile(ctx, Icons.chat_bubble_outline, 'Add bubble', 'bubble'),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    switch (choice) {
      case 'camera':
        await _pickPhoto(ImageSource.camera);
      case 'gallery':
        await _pickPhoto(ImageSource.gallery);
      case 'paste':
        await _pastePhoto();
      case 'text':
        _controller.addTextLayer();
      case 'bubble':
        _controller.addBubbleLayer();
        _controller.setTool(EditorTool.text);
    }
  }

  Widget _sheetTile(
    BuildContext ctx,
    IconData icon,
    String label,
    String value,
  ) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(
        label,
        style: const TextStyle(
          fontFamily: AppFonts.ui,
          color: AppColors.textPrimary,
        ),
      ),
      onTap: () => Navigator.pop(ctx, value),
    );
  }

  Future<void> _showRenameDialog(Layer layer) async {
    var value = layer.name;
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text(
          'Rename layer',
          style: TextStyle(
            fontFamily: AppFonts.display,
            color: AppColors.textPrimary,
          ),
        ),
        // TextFormField owns and disposes its own controller.
        content: TextFormField(
          initialValue: layer.name,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          onChanged: (v) => value = v,
          onFieldSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, value.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      _controller.renameLayer(layer.id, name);
    }
  }

  /// Tap-the-title project rename. A blank or cancelled dialog keeps the old
  /// name; the controller guards empty too.
  Future<void> _renameProject() async {
    final name = await promptName(
      context,
      title: 'Rename project',
      initial: ref.read(editorControllerProvider).project.name,
      hint: 'Project name',
    );
    if (name == null) return;
    _controller.rename(name);
  }

  /// Opens the canvas-size sheet (presets / custom + optional resample) and
  /// applies the chosen dimensions.
  Future<void> _showCanvasSize() async {
    final project = ref.read(editorControllerProvider).project;
    final result = await showCanvasSizeSheet(
      context,
      title: 'Canvas size',
      initialWidth: project.canvasWidth,
      initialHeight: project.canvasHeight,
      allowScaleContent: true,
      confirmLabel: 'Apply',
    );
    if (result == null) return;
    _controller.setCanvasSize(
      result.width,
      result.height,
      scaleContent: result.scaleContent,
    );
  }

  /// Crop tool sheet - center-crops the canvas to a common aspect ratio.
  /// Opens the full-screen freeform crop editor, then applies the returned
  /// rectangle (in canvas coords) as an arbitrary crop.
  Future<void> _openFreeformCrop() async {
    final p = ref.read(editorControllerProvider).project;
    final rect = await showCropOverlay(
      context,
      frame: p.currentFrame,
      canvasWidth: p.canvasWidth,
      canvasHeight: p.canvasHeight,
      grid: p.grid,
    );
    if (rect == null) return;
    _controller.cropCanvasRect(rect);
    _toast('Cropped to ${rect.width.round()}×${rect.height.round()}');
  }

  void _showCropSheet() {
    const ratios = <(String, double)>[
      ('1:1', 1.0),
      ('4:5', 4 / 5),
      ('9:16', 9 / 16),
      ('16:9', 16 / 9),
      ('3:2', 3 / 2),
      ('2:3', 2 / 3),
    ];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          14,
          20,
          20 + MediaQuery.viewInsetsOf(sheetCtx).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.elevated,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Crop to ratio',
              style: TextStyle(
                fontFamily: AppFonts.display,
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 3),
            const Text(
              'Drag a freeform box, or center-crop to a ratio',
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 11.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _openFreeformCrop();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.cyan.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.cyan),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.crop, size: 18, color: AppColors.cyan),
                    SizedBox(width: 8),
                    Text(
                      'Freeform crop',
                      style: TextStyle(
                        fontFamily: AppFonts.ui,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: AppColors.cyan,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'RATIOS',
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in ratios)
                  GestureDetector(
                    onTap: () {
                      Navigator.of(sheetCtx).pop();
                      _applyCropAspect(r.$2);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderFaint),
                      ),
                      child: Text(
                        r.$1,
                        style: const TextStyle(
                          fontFamily: AppFonts.ui,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Center-crops the canvas so its aspect becomes [aspect], reducing whichever
  /// dimension is currently too large.
  void _applyCropAspect(double aspect) {
    final p = ref.read(editorControllerProvider).project;
    final current = p.canvasWidth / p.canvasHeight;
    final int nw;
    final int nh;
    if (aspect > current) {
      nw = p.canvasWidth;
      nh = (p.canvasWidth / aspect).round();
    } else {
      nh = p.canvasHeight;
      nw = (p.canvasHeight * aspect).round();
    }
    _controller.cropCanvas(nw, nh);
    _toast('Cropped to $nw×$nh');
  }

  Widget _segTab(String label, bool active, Color accent, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? accent.withValues(alpha: 0.18) : AppColors.inputField,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: active ? accent : AppColors.textMuted,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- tool bar
  /// The design's bottom tool dock: Add layer / Text / Bubble / AI Cut / Erase /
  /// Crop / Adjust / Layers. Tool buttons switch the contextual panel; action
  /// buttons (Add layer, Bubble) dispatch straight to the controller.
  /// The dock's contents, shared by the portrait bar and the landscape rail so
  /// the two can never drift out of sync.
  List<_DockItem> _dockItems(EditorState editor) {
    void tool(EditorTool t) {
      // In landscape a tap on the tool you are already in folds the panel away
      // (and brings it back), which is how the canvas gets the full width.
      if (_sidePanelOpen && editor.tool == t) {
        setState(() => _sidePanelOpen = false);
      } else {
        if (!_sidePanelOpen) setState(() => _sidePanelOpen = true);
        _controller.setTool(t);
      }
    }

    return [
      // Collage-only, and first: layout / count / border are what a photo grid
      // is edited through.
      if (editor.project.isGrid)
        _DockItem(
          icon: Icons.grid_view,
          label: 'Grid',
          active: editor.tool == EditorTool.grid,
          onTap: () => tool(EditorTool.grid),
        ),
      _DockItem(
        icon: Icons.add_photo_alternate_outlined,
        label: 'Add layer',
        onTap: () => _pickPhoto(ImageSource.gallery),
      ),
      _DockItem(
        icon: Icons.text_fields,
        label: 'Text',
        active: editor.tool == EditorTool.text,
        onTap: () => tool(EditorTool.text),
      ),
      _DockItem(
        icon: Icons.chat_bubble_outline,
        label: 'Bubble',
        onTap: () {
          _controller.addBubbleLayer();
          _controller.setTool(EditorTool.text);
          if (!_sidePanelOpen) setState(() => _sidePanelOpen = true);
        },
      ),
      _DockItem(icon: Icons.auto_awesome, label: 'AI Cut', onTap: _showBgSheet),
      _DockItem(
        icon: Icons.brush_outlined,
        label: 'Erase',
        active: editor.tool == EditorTool.erase,
        onTap: () => tool(EditorTool.erase),
      ),
      _DockItem(icon: Icons.crop, label: 'Crop', onTap: _showCropSheet),
      _DockItem(
        icon: Icons.tune,
        label: 'Adjust',
        active: editor.tool == EditorTool.adjust,
        onTap: () => tool(EditorTool.adjust),
      ),
      _DockItem(
        icon: Icons.auto_awesome_mosaic,
        label: 'Effects',
        active: editor.tool == EditorTool.effects,
        onTap: () => tool(EditorTool.effects),
      ),
      _DockItem(
        icon: Icons.layers_outlined,
        label: 'Layers',
        active: editor.tool == EditorTool.layers,
        onTap: () => tool(EditorTool.layers),
      ),
    ];
  }

  Widget _toolBar(EditorState editor) {
    return Container(
      color: AppColors.background,
      padding: EdgeInsets.fromLTRB(
        8,
        12,
        8,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final item in _dockItems(editor)) _DockButton(item: item),
          ],
        ),
      ),
    );
  }

  /// The landscape dock: the same buttons stacked down the left edge, with the
  /// panel-reveal control on top when the panel is folded away.
  Widget _toolRail(EditorState editor) {
    return Container(
      width: 68,
      color: AppColors.background,
      child: Column(
        children: [
          if (!_sidePanelOpen)
            IconButton(
              key: const ValueKey('expand-panel'),
              tooltip: 'Show tool panel',
              iconSize: 18,
              onPressed: () => setState(() => _sidePanelOpen = true),
              icon: const Icon(
                Icons.keyboard_double_arrow_right,
                color: AppColors.textMuted,
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  for (final item in _dockItems(editor))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _DockButton(item: item),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One dock entry - icon, label, and what tapping it does.
@immutable
class _DockItem {
  const _DockItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
}

class _DockButton extends StatelessWidget {
  _DockButton({required this.item})
    // Keyed by label because the dock's wording repeats the panel titles
    // ("Adjust", "Layers"), so a plain text finder is ambiguous in a test.
    : super(key: ValueKey('dock-${item.label}'));

  final _DockItem item;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: item.onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: item.active
                    ? AppColors.cyan
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                item.icon,
                size: 20,
                color: item.active
                    ? AppColors.cutoutInk
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: item.active
                    ? AppColors.textPrimary
                    : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LayerRow extends StatelessWidget {
  const _LayerRow({
    super.key,
    required this.layer,
    required this.selected,
    required this.onSelect,
    required this.onRename,
    required this.onToggleVisibility,
    required this.onDuplicate,
    required this.onDelete,
  });

  final Layer layer;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onRename;
  final VoidCallback onToggleVisibility;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  /// A 38px preview of the photo (decoded small via [cacheWidth], never at
  /// full resolution), falling back to the generic icon when the file is
  /// missing. [cut] overlays a green tick for a cut-out layer.
  Widget _photoThumb(String assetPath, {required bool cut}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            File(assetPath),
            fit: BoxFit.cover,
            cacheWidth: 114, // 38 logical px × 3 for high-dpi rows
            errorBuilder: (_, _, _) =>
                const Icon(Icons.image_outlined, size: 18, color: Colors.white),
          ),
          if (cut)
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                width: 13,
                height: 13,
                decoration: const BoxDecoration(
                  color: AppColors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 9, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final (Widget badge, String typeLabel) = switch (layer) {
      TextLayer() => (
        const Text(
          'T',
          style: TextStyle(
            fontFamily: AppFonts.bangers,
            fontSize: 16,
            color: Colors.white,
          ),
        ),
        'Text layer',
      ),
      BubbleLayer() => (
        const Icon(Icons.chat_bubble_outline, size: 18, color: Colors.white),
        'Bubble layer',
      ),
      // A real thumbnail so multiple photos are tellable apart (#73), with a
      // small green tick when this layer has been cut out.
      ImageLayer(:final assetPath, :final maskPath) => (
        _photoThumb(assetPath, cut: maskPath != null),
        maskPath == null ? 'Image layer' : 'Image layer · cut out',
      ),
    };
    final flatBadge = layer is! ImageLayer;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onSelect,
          onLongPress: onRename,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.violet.withValues(alpha: 0.14)
                  : AppColors.cardAlt,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AppColors.violet : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: flatBadge ? AppColors.elevated : null,
                    gradient: flatBadge ? null : context.tokens.logoGradient,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: badge,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        layer.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppFonts.ui,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        typeLabel,
                        style: const TextStyle(
                          fontFamily: AppFonts.ui,
                          fontSize: 10.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onToggleVisibility,
                  icon: Icon(
                    layer.visible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18,
                    color: layer.visible
                        ? AppColors.textSecondary
                        : AppColors.textFaint,
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Duplicate layer',
                  onPressed: onDuplicate,
                  icon: const Icon(
                    Icons.content_copy,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
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

class _CutBadge extends StatelessWidget {
  const _CutBadge();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 12,
      left: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.green.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.green.withValues(alpha: 0.5)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check, size: 13, color: AppColors.greenLight),
            SizedBox(width: 5),
            Text(
              'Cut out',
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.greenLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-canvas overlay shown while the AI cut-out runs.
class _RemovingOverlay extends StatelessWidget {
  const _RemovingOverlay({this.label = 'Removing background…'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xB2131019),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(AppColors.greenLight),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              label,
              style: const TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Frame N / M" badge shown on the canvas while the Frames tool is active.
class _FrameCounter extends StatelessWidget {
  const _FrameCounter({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xB8131019),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.orange.withValues(alpha: 0.4)),
        ),
        child: Text(
          'Frame $current / $total',
          style: const TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.orange,
          ),
        ),
      ),
    );
  }
}

/// A 64px frame thumbnail in the Frames strip: a live [ProjectCanvas] preview
/// over a checkerboard, an active highlight, and a numbered badge.
class _FrameThumb extends StatelessWidget {
  const _FrameThumb({
    super.key,
    required this.index,
    required this.frame,
    required this.project,
    required this.active,
    required this.onTap,
    required this.onMenu,
  });

  final int index;
  final Frame frame;

  /// The owning document - the thumb needs its canvas size (so a non-square
  /// project previews at its real aspect instead of the 512² default) and its
  /// Photo Grid.
  final Project project;

  final bool active;
  final VoidCallback onTap;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onMenu,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active
                ? AppColors.orange
                : Colors.white.withValues(alpha: 0.08),
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const Checkerboard(cell: 6),
              ProjectCanvas(
                frame: frame,
                width: project.canvasWidth,
                height: project.canvasHeight,
                grid: project.grid,
              ),
              Positioned(
                top: 3,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xB8131019),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: active ? AppColors.orange : AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.layerCount,
    required this.canUndo,
    required this.canRedo,
    required this.onExport,
    required this.onUndo,
    required this.onRedo,
    required this.onRename,
    required this.onCanvasSize,
  });

  final String title;
  final int layerCount;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onExport;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onRename;
  final VoidCallback onCanvasSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 10, 12, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Scaffold.of(context).openDrawer(),
            icon: const Icon(
              Icons.menu,
              size: 22,
              color: AppColors.textSecondary,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tap the title to rename the project (mirrors the pack
                // detail screen's tap-title-to-rename affordance).
                GestureDetector(
                  onTap: onRename,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppFonts.display,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Icon(
                        Icons.edit_outlined,
                        size: 13,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
                Text(
                  '$layerCount ${layerCount == 1 ? 'layer' : 'layers'} · auto-saved',
                  style: const TextStyle(
                    fontFamily: AppFonts.ui,
                    fontSize: 10.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onCanvasSize,
            tooltip: 'Canvas size',
            icon: const Icon(
              Icons.aspect_ratio,
              size: 20,
              color: AppColors.textMuted,
            ),
          ),
          IconButton(
            onPressed: canUndo ? onUndo : null,
            color: AppColors.textMuted,
            disabledColor: AppColors.textFaint,
            icon: const Icon(Icons.undo, size: 20),
          ),
          IconButton(
            onPressed: canRedo ? onRedo : null,
            color: AppColors.textMuted,
            disabledColor: AppColors.textFaint,
            icon: const Icon(Icons.redo, size: 20),
          ),
          const SizedBox(width: 4),
          GradientButton(
            label: 'Export',
            icon: Icons.ios_share,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            fontSize: 13,
            onPressed: onExport,
          ),
        ],
      ),
    );
  }
}

/// Small right-aligned helper text shown next to a panel title.
class _PanelHint extends StatelessWidget {
  const _PanelHint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: AppFonts.ui,
        fontSize: 11,
        color: AppColors.textMuted,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Off-UI-isolate mask helpers (docs/reviews/2026-07-19-review.md): each runs
// O(width × height) pixel loops over source-resolution masks, which froze the
// raster thread when run on the UI isolate. An [AlphaMask] is just ints + a
// Uint8List, so it crosses isolates cheaply.
//
// Each helper owns its [Isolate.run] call ON PURPOSE: the sent closure must be
// created here, in a scope whose context holds only the helper's parameters.
// Created inline in a `_EditorScreenState` method it would share that method's
// closure context with the `setState(() => …)` closures, dragging `this` (the
// whole State) into the isolate message and failing to send at runtime.

/// Full clean-up chain for a fresh AI cut-out result.
Future<AlphaMask> _processCutoutMask(AlphaMask raw, {bool refine = true}) =>
    Isolate.run(
      () => MaskProcessing.process(
        raw,
        refine
            ? const MaskProcessingOptions()
            : const MaskProcessingOptions(
                keepLargestComponent: false,
                featherRadius: 0,
              ),
      ),
    );

/// Cleans up a raw engine mask with an explicit [feather] radius - used by the
/// AI-Cut sheet's done stage so the edge-feather slider is live.
Future<AlphaMask> _processMask(
  AlphaMask raw, {
  required bool keepLargest,
  required int feather,
}) => Isolate.run(
  () => MaskProcessing.process(
    raw,
    MaskProcessingOptions(
      keepLargestComponent: keepLargest,
      featherRadius: feather,
    ),
  ),
);

/// Tier-1 tap-to-remove: component labelling + feathered subtract (#83).
Future<({RemoveTapOutcome outcome, AlphaMask? mask})> _removeTappedObject(
  AlphaMask mask,
  int x,
  int y,
) => Isolate.run(() => MaskProcessing.removeObjectAt(mask, x, y));

/// How much of what the cutout currently keeps ([current] > 16) the SAM
/// [object] (> 128) covers - drives the "that's your subject" guard (#86).
Future<({int kept, int overlap})> _maskOverlap(
  AlphaMask current,
  AlphaMask object,
) => Isolate.run(() {
  var kept = 0;
  var overlap = 0;
  for (var i = 0; i < current.length; i++) {
    if (current.alpha[i] > 16) {
      kept++;
      if (object.alpha[i] > 128) overlap++;
    }
  }
  return (kept: kept, overlap: overlap);
});

/// Subtracts the SAM [object] (with a 1-px feathered seam) from [current].
Future<AlphaMask> _subtractObject(AlphaMask current, AlphaMask object) =>
    Isolate.run(
      () => MaskProcessing.subtract(current, MaskProcessing.feather(object, 1)),
    );

/// Paints an Erase/Restore brush [stroke] over [mask] off the UI isolate - the
/// full mask copy + dab loop are pure CPU work, like the cut-out helpers above.
Future<AlphaMask> _paintStroke(AlphaMask mask, BrushStroke stroke) =>
    Isolate.run(() => MaskBrush.paint(mask, stroke));

/// The region removed between [before] and [after] masks (opaque → transparent),
/// as an opaque-where-removed mask - the blob to fill in Fill mode.
Future<AlphaMask> _removedRegion(AlphaMask before, AlphaMask after) =>
    Isolate.run(() {
      final n = before.alpha.length;
      final out = Uint8List(n);
      for (var i = 0; i < n; i++) {
        out[i] = (before.alpha[i] > 128 && after.alpha[i] <= 128) ? 255 : 0;
      }
      return AlphaMask(width: before.width, height: before.height, alpha: out);
    });
