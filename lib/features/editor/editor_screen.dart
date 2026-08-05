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
import '../../core/rendering/image_decode.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/checkerboard.dart';
import '../../core/widgets/crown_icon.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/labeled_slider.dart';
import '../../core/widgets/name_prompt.dart';
import '../../core/widgets/pill_chip.dart';
import '../../core/widgets/responsive_center.dart';
import '../../core/widgets/sheet_body.dart';
import '../../core/widgets/sm_toast.dart';
import '../../core/widgets/text_caption.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/localized_labels.dart';
import '../ads/ad_gate.dart';
import '../fonts/custom_fonts.dart';
import '../go_pro/iap.dart';
import '../grid/grid_templates.dart';
import '../grid/widgets/grid_template_strip.dart';
import '../home/project_repository.dart';
import '../home/widgets/app_drawer.dart';
import '../segmentation/ai_capability.dart';
import '../segmentation/alpha_mask.dart';
import '../segmentation/engines/inpaint/content_fill_engine.dart';
import '../segmentation/engines/inpaint/inpaint_engine.dart';
import '../segmentation/engines/object/mobile_sam_engine.dart';
import '../segmentation/mask_brush.dart';
import '../segmentation/mask_processing.dart';
import '../segmentation/mask_store.dart';
import '../segmentation/seg_model.dart';
import '../segmentation/segmentation_engine.dart';
import '../segmentation/segmentation_registry.dart';
import 'layer_scale_curve.dart';
import 'mask_mapper.dart';
import 'services/image_import.dart';
import 'services/layer_flattener.dart';
import 'state/editor_controller.dart';
import 'state/editor_state.dart';
import 'state/editor_tool.dart';
import 'widgets/bubble_shape_sheet.dart';
import 'widgets/canvas_size_sheet.dart';
import 'widgets/crop_overlay.dart';
import 'widgets/editor_canvas.dart';
import 'widgets/filter_strip.dart';
import 'widgets/project_canvas.dart';

/// Layout of the Bubble panel's format row. Fixed widths on purpose: they are
/// what lets [_EditorScreenState._revealBubbleFormat] compute a scroll offset
/// arithmetically instead of measuring a lazily-built list.
///
/// The tile width is set by the longest TRANSLATED format name, not by English.
/// At 92 the label box was 92 - 16 of tile padding - 2 of border (a Container
/// folds `decoration.padding` in) = 74dp, which fits every English name with
/// 22dp to spare - "Thought" is 51.9 - and cut four others: German rendered
/// "Sprechbla…" for the very format that was selected, and fr "Chuchotement"
/// wants 92.5. 116 leaves 98dp, clear of that worst case by more than the ~2dp
/// of rounding the grid strip taught us to keep. `tool/measure_labels.py`
/// guards it.
const double _kBubbleRowTile = 116;
const double _kBubbleRowGap = 8;
const double _kBubbleRowThumb = 68;

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

  /// The Bubble panel's format row, so selecting a bubble can bring its own
  /// format into view - the fifth of five sits past the fold on a phone.
  final ScrollController _bubbleFormatScroll = ScrollController();

  // Transient tool UI state not yet backed by the model.
  bool _isPlaying = false; // frame playback (M4)
  Timer? _playTimer;
  bool _onionSkin = false; // ghost the previous frame (M4 #37)
  bool _eraseMode = true; // erase vs restore (M2)
  bool _softEdges = true;
  double _brushSize = 40;
  bool _removingBg = false; // AI cut-out in progress
  bool _removeObjectMode = false; // tap-to-remove mode in the cutout tool (#83)
  // Fill (rebuild the background) vs Erase (cut to transparency) in
  // remove-object mode. Fill is the DEFAULT because it is what "remove object"
  // means to nearly everyone who taps it - erasing to a transparent hole was
  // read as a broken fill often enough to be the bug report that added this.
  bool _fillMode = true;
  bool _inpainting = false; // fill in progress (either tier)
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
  String get samUnavailableMessage => _l10n.objectAiUnavailable;

  /// The screen's localizations. Every panel, sheet and toast in this file
  /// reads its text from here.
  AppLocalizations get _l10n => AppLocalizations.of(context);

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

  /// A write is in flight - a second one would race it onto the same temp file.
  bool _saving = false;

  /// Something reached disk, so Home's Recent list needs one refresh on exit.
  bool _homeDirty = false;

  /// Whether the "couldn't save" toast has already been shown this session.
  bool _saveErrorToasted = false;
  // Captured during build so dispose() can save without touching `ref`
  // (which is unsafe once the widget is unmounting).
  ProjectRepository? _repo;
  // Captured during build so dispose()'s final save can also refresh Home's
  // Recent list - invalidating via `ref` while unmounting is unsafe.
  ProviderContainer? _homeContainer;

  EditorController get _controller =>
      ref.read(editorControllerProvider.notifier);

  /// [ok] false paints the toast's status dot red - the pill used to report a
  /// failure with a success badge.
  void _toast(String m, {bool ok = true}) => showSmToast(context, m, ok: ok);

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
    _saveTimer = Timer(const Duration(milliseconds: 800), () {
      unawaited(_flushSave());
    });
  }

  /// Writes the pending snapshot, keeping it until the write actually lands.
  ///
  /// This used to be a sync `void` that cleared `_pendingSave` and then dropped
  /// the `save()` future on the floor. `ProjectRepository.save` rethrows, and
  /// there is no zone guard or crash reporter in the app, so a full disk lost
  /// the snapshot AND said nothing - no toast, no retry, no diagnostics.
  ///
  /// [_saving] matters as much as the error handling: two overlapping writers
  /// share one `<id>.json.tmp`, and a second writer renaming a half-written
  /// temp over the target is exactly the corruption the atomic write exists to
  /// prevent.
  Future<void> _flushSave() async {
    final project = _pendingSave;
    final repo = _repo;
    if (project == null || repo == null || _saving) return;
    _saving = true;
    try {
      await repo.save(project.copyWith(updatedAt: DateTime.now()));
      // Only now is it safe to forget - and only if no newer edit arrived
      // while the write was in flight.
      if (identical(_pendingSave, project)) _pendingSave = null;
      _homeDirty = true;
    } catch (error, stack) {
      // The snapshot stays pending, so the next tick retries it; a newer edit
      // supersedes it, which is also correct.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'chromis',
          context: ErrorDescription('autosaving the project'),
        ),
      );
      _saveTimer?.cancel();
      _saveTimer = Timer(const Duration(seconds: 5), () {
        unawaited(_flushSave());
      });
      // Once per session: repeating it every 5s would bury the canvas.
      if (mounted && !_saveErrorToasted) {
        _saveErrorToasted = true;
        _toast(_l10n.saveRetrying, ok: false);
      }
    } finally {
      _saving = false;
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _playTimer?.cancel();
    // Last chance to persist. dispose() cannot await, so this is deliberately
    // fire-and-forget - but its failure is reported rather than swallowed, and
    // Home is refreshed only after it settles so a brand-new project (whose
    // first save may only happen here) appears in Recent.
    unawaited(
      _flushSave().whenComplete(() {
        // Once per editor session rather than once per debounce tick: every
        // autosave used to invalidate this, which re-listed and re-parsed every
        // manifest and rebuilt the offstage Home for nothing on screen.
        if (_homeDirty) _homeContainer?.invalidate(savedProjectsProvider);
      }),
    );
    _textController.dispose();
    _bubbleTextController.dispose();
    _bubbleFormatScroll.dispose();
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
            Text(
              _l10n.speed,
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.colors.textSecondary,
              ),
            ),
            Text(
              '${_fpsLabel(fps)} fps',
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 12,
                color: context.colors.textMuted,
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
                accent: context.colors.orange,
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
            return Column(
              children: [
                topBar,
                // The panel's cap is half of what is LEFT, not half of the
                // screen. Taken from the whole viewport it ignored the top bar
                // and the dock, so when those grew - a large text scale, a
                // longer language - the three of them together no longer fit
                // and the body overflowed. Measuring here instead means the
                // column cannot overflow whatever the chrome does, without
                // anything having to assume how tall the chrome is.
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, body) {
                      final panelMax = math.min(300.0, body.maxHeight * 0.5);
                      return Column(
                        children: [
                          Expanded(child: _canvas(editor)),
                          _panel(editor, panelMax),
                        ],
                      );
                    },
                  ),
                ),
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
    return Padding(
      padding: wide
          ? const EdgeInsets.fromLTRB(14, 10, 16, 12)
          : const EdgeInsets.fromLTRB(20, 8, 20, 14),
      child: Center(
        child: ConstrainedBox(
          // Portrait caps the canvas so it never dominates a tall phone;
          // landscape gives it everything the rail and panel left over.
          //
          // The 460 is a PHONE number. On a tablet in portrait it left the
          // photo floating in a small box with ~150px of dead margin on each
          // side of an 800-wide screen, so a tablet gets the room instead.
          constraints: BoxConstraints(
            maxWidth: wide || isTabletWidth(context) ? double.infinity : 460,
          ),
          child: AspectRatio(
            aspectRatio: editor.project.canvasAspect,
            // SQUARE corners, and a ClipRect rather than a ClipRRect. The
            // viewport is a preview of the exported image, so anything it adds
            // to the shape is a lie: rounding it here rounded the photo's own
            // corners on screen while the export - which knows nothing about
            // this widget - produced square ones. Only a Photo Grid rounds
            // anything, and it does that per cell, from `grid.cornerRadius`.
            //
            // The clip itself stays: layers are positioned in canvas space and
            // may extend past it, and they must not spill into the editor chrome.
            child: DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: context.colors.shadow,
                    blurRadius: 50,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: ClipRect(
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
                            ? _l10n.fillingBackground
                            : _l10n.findingObject,
                      ),
                    if (_merging) _RemovingOverlay(label: _l10n.mergingLayers),
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
      // Keyed so a test can measure the panel SURFACE. Measuring its scroll
      // view instead proves nothing: that shrink-wraps either way, which is
      // how the panel-height regression slipped through once already.
      key: const ValueKey('tool-panel'),
      width: double.infinity,
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        // `chrome`, not `panel`: this is the largest persistent surface in the
        // app, so it takes the page's own colour - pure black on AMOLED, pure
        // white on IPS - and gets its edge from the hairline below.
        color: context.colors.chrome,
        border: Border(top: BorderSide(color: context.colors.border)),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(tokens.radiusPanel),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      // The bar itself spans the screen (it is the panel's surface), but its
      // controls stay a readable column - a slider stretched across a tablet is
      // harder to aim, not easier.
      //
      // Align with heightFactor 1, NOT ResponsiveCenter: this Container caps
      // the height rather than setting it, so a Center here would expand to
      // that cap and the panel would stop hugging its content - a two-line
      // empty state would reserve 300px and float in the middle of it.
      child: Align(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(child: _panelBody(editor)),
        ),
      ),
    );
  }

  /// The landscape twin of [_panel]: a full-height column between the rail and
  /// the canvas, with its own collapse control so the canvas can take the whole
  /// width when you just want to look at the photo.
  Widget _sidePanel(EditorState editor) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.chrome,
        border: Border(right: BorderSide(color: context.colors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              key: const ValueKey('collapse-panel'),
              tooltip: _l10n.hideToolPanel,
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => _sidePanelOpen = false),
              icon: Icon(
                Icons.keyboard_double_arrow_left,
                color: context.colors.textMuted,
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

  /// [title] overrides the tool's own name for a panel that is only one of the
  /// tool's modes - the bubble editor lives under Text but must not claim to be
  /// it, or adding a bubble looks like the Text tool merely opened.
  Widget _panelHeader(EditorTool tool, {Widget? trailing, String? title}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      // A Wrap, not a Row of two Flexibles. Two flex children split the row
      // 50/50 whatever they need, so the Adjust header gave its chips half -
      // ~77dp each - while "Anpassen" used a fifth of its own half and the
      // space between them went to waste. Every non-English locale paid for
      // it: German rendered "+ Hinzu…" and "Zurücks…" side by side.
      //
      // A fixed ratio cannot fix that either, because the panels disagree
      // about who needs the room: Adjust is a short title with two chips,
      // Erase is "Manuelles Radieren" with a hint. Wrap asks each for its
      // intrinsic width and moves the trailing to a second line only when the
      // two genuinely do not fit - so nothing loses words, and a header that
      // already fitted does not move.
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          Text(
            title ?? tool.panelTitleOf(_l10n),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
        style: TextStyle(
          fontFamily: AppFonts.ui,
          fontSize: 12.5,
          color: context.colors.textMuted,
          height: 1.5,
        ),
      ),
    );
  }

  // ------------------------------------------------------------ Adjust
  /// Opens the per-layer crop editor over [layer]'s source photo (decoded at a
  /// preview resolution - the crop itself is normalized) and applies the result.
  Future<void> _cropSelectedImage(ImageLayer layer) async {
    // Both sides are capped: the overlay only ever displays this, and a tall
    // stitched screenshot at full height is tens of MB of bitmap. The crop it
    // returns is normalized, so the preview resolution does not reach the
    // document - `sourceWidth/Height` drive the px readout instead.
    final decoded = await decodeImageFile(
      layer.assetPath,
      maxWidth: 1080,
      maxHeight: 1080,
    );
    if (decoded == null) {
      if (mounted) _toast(_l10n.cropOpenFailed, ok: false);
      return;
    }
    if (!mounted) {
      decoded.image.dispose();
      return;
    }
    // The overlay takes ownership of the image and disposes it.
    final rect = await showLayerCropOverlay(
      context,
      image: decoded.image,
      initialCrop: layer.cropRect,
      srcWidth: decoded.sourceWidth,
      srcHeight: decoded.sourceHeight,
    );
    if (rect == null || !mounted) return;
    _controller.setImageCrop(layer.id, rect);
    _toast(_l10n.photoCropped);
  }

  /// [radians] as degrees in (-180, 180].
  ///
  /// The canvas ACCUMULATES rotation - a second pinch adds to whatever the
  /// first left - so a layer can legitimately sit at 400°, which the slider has
  /// no room for. 400° and 40° are the same picture, so the slider shows the
  /// wrapped angle and writes it back plainly; nothing on screen moves.
  static double _degreesOf(double radians) {
    final deg = (radians * 180 / math.pi) % 360;
    return deg > 180 ? deg - 360 : deg;
  }

  // The scale range and the slider's curve live in layer_scale_curve.dart, so
  // the pinch gesture and this slider read the same numbers instead of each
  // keeping their own copy.

  /// Scale + rotation for the selected layer, whatever its type.
  ///
  /// The canvas can already pinch-zoom and twist a layer, but a caption or a
  /// bubble created small - or scaled down by accident - is the one thing a
  /// finger cannot get back: the hit box IS the layer, so past a certain size
  /// there is nothing left to grab and the layer is stranded on the canvas. A
  /// slider does not depend on the layer's size, so it is always a way in.
  List<Widget> _placementSliders(Layer layer) {
    final id = layer.id;
    final t = layer.transform;
    final degrees = _degreesOf(t.rotation);
    return [
      LabeledSlider(
        label: _l10n.scale,
        // Driven in bar-position space rather than in percent, because the
        // mapping is a curve - see [_scaleUnityAt]. The readout stays the real
        // percentage, which is the number anyone actually wants.
        value: sliderFromLayerScale(t.scale),
        min: 0,
        max: 1,
        accent: context.colors.teal,
        valueLabel: '${(t.scale * 100).round()}%',
        onChanged: (v) => _controller.updateTransform(
          id,
          t.copyWith(scale: layerScaleFromSlider(v)),
        ),
        onChangeEnd: _endSliderEdit,
      ),
      LabeledSlider(
        label: _l10n.rotation,
        value: degrees,
        min: -180,
        max: 180,
        accent: context.colors.teal,
        valueLabel: '${degrees.round()}°',
        onChanged: (v) => _controller.updateTransform(
          id,
          // Snapped to straight over the last couple of degrees: a caption a
          // hair off level reads as a mistake rather than a choice, and a
          // slider cannot be nudged to an exact value the way a field can.
          t.copyWith(rotation: (v.abs() < 2 ? 0.0 : v) * math.pi / 180),
        ),
        onChangeEnd: _endSliderEdit,
      ),
    ];
  }

  Widget _adjustPanel(EditorState editor) {
    final selected = editor.selectedLayer;
    // Adding a photo/text/bubble is reachable right from the default tool -
    // not only via the Layers tab (#77).
    final addChip = PillChip(
      label: _l10n.add,
      icon: Icons.add,
      onTap: _showAddMenu,
    );
    if (selected == null) {
      return Column(
        children: [
          _panelHeader(EditorTool.adjust, trailing: addChip),
          _emptyHint(_l10n.adjustEmptyHint),
        ],
      );
    }
    // Crop and the colour sliders reach the photo's PIXELS, so they are a photo
    // layer's alone; scale, rotation and opacity are the layer itself and work
    // on a caption or a bubble just as well. Adjust used to answer anything but
    // an ImageLayer with the empty hint, which left a caption pinched too small
    // to touch with no way back - the hit box is the layer, so there was
    // nothing left to grab.
    final photo = selected is ImageLayer ? selected : null;
    // A photo that FILLS a grid cell is placed by the cell, not by the user:
    // `EditorCanvas._clampToCell` keeps it covering, because a cell photo
    // shrunk aside leaves a hole in the collage that reads as a bug. A slider
    // here would be a second path to that state with none of the clamp, so a
    // cell photo keeps pinch-to-zoom (which is clamped) and no sliders. The
    // problem the sliders solve does not arise there anyway - a cell photo
    // fills its cell, and captions and bubbles in a cell are free layers.
    final placeable = selected.cellId == null || photo == null;
    final id = selected.id;
    return Column(
      children: [
        _panelHeader(
          EditorTool.adjust,
          // Flexible children, not bare chips: the header bounds this Row, and
          // a Row lays a non-flex child out at its intrinsic width however
          // little room it was given - so the overflow would simply move in
          // here. PillChip ellipsizes once it is actually bounded.
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: addChip),
              if (photo != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: PillChip(
                    label: _l10n.reset,
                    onTap: () {
                      // Only this panel's own colour sliders - the chosen
                      // filter / HDR survive, and Effects has its own Reset for
                      // those. Scale and rotation are placement, not an
                      // adjustment: dropping a photo back to 100% and straight
                      // would undo how it was framed, which is not what a user
                      // reaching for "reset the sliders" is asking for.
                      _controller.updateImageAdjustments(
                        id,
                        photo.adjustments.resetSliders(),
                      );
                      _controller.setOpacity(id, 1);
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 2),
        // Geometry first - crop, then scale and rotation - and colour after,
        // so the one button in the panel stays at the top of it rather than
        // splitting the slider stack in two.
        if (photo != null) ..._cropControls(photo),
        if (placeable) ..._placementSliders(selected),
        if (photo != null) ..._colorSliders(photo),
        LabeledSlider(
          label: _l10n.opacity,
          value: selected.opacity * 100,
          min: 0,
          max: 100,
          accent: context.colors.green,
          valueLabel: '${(selected.opacity * 100).round()}%',
          onChanged: (v) => _controller.setOpacity(id, v / 100),
          onChangeEnd: _endSliderEdit,
        ),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: () => _controller.setTool(EditorTool.effects),
          icon: const Icon(Icons.auto_fix_high, size: 17),
          label: Text(
            photo == null ? _l10n.effectsLinkLayer : _l10n.effectsLink,
            overflow: TextOverflow.ellipsis,
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: context.colors.teal,
            side: BorderSide(color: context.colors.border),
            minimumSize: const Size.fromHeight(38),
          ),
        ),
      ],
    );
  }

  /// The crop entry point - a photo layer's alone, like everything else in
  /// Adjust that reaches pixels rather than the layer's transform.
  List<Widget> _cropControls(ImageLayer selected) {
    final id = selected.id;
    return [
      // STACKED, not a 2:1 Row. Sharing a row gave Reset crop a third of the
      // panel minus an M3 OutlinedButton's 24dp of padding a side, which is
      // about 72dp of text on a 360dp phone - enough for English "Reset crop"
      // (68dp) and for nothing else. German rendered "Zuschnitt …" next to a
      // full "Zuschnitt bearbeiten", i.e. two buttons whose visible labels
      // were the same word and one of them cut; fr, es and cs were as bad.
      // No wording fixes it - "Zuschnitt zurücksetzen" is simply the term -
      // and no flex ratio does either, since the two labels want 200dp each
      // in German against 324dp of panel. Full width gives every language
      // room, and the panel scrolls, so the second line costs nothing.
      //
      // Size.fromHeight is safe HERE because the parent is a Column, which
      // hands down a bounded width. It is NOT safe inside a Row - that sets
      // the minimum width to infinity, which is the layout error (#crop)
      // this row previously worked around by sharing the space instead.
      OutlinedButton.icon(
        onPressed: () => _cropSelectedImage(selected),
        icon: const Icon(Icons.crop, size: 17),
        label: Text(
          selected.isCropped ? _l10n.editCrop : _l10n.cropPhoto,
          overflow: TextOverflow.ellipsis,
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: context.colors.textSecondary,
          side: BorderSide(color: context.colors.border),
          minimumSize: const Size.fromHeight(38),
        ),
      ),
      if (selected.isCropped) ...[
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () =>
              _controller.setImageCrop(id, const Rect.fromLTRB(0, 0, 1, 1)),
          style: OutlinedButton.styleFrom(
            foregroundColor: context.colors.textMuted,
            side: BorderSide(color: context.colors.border),
            minimumSize: const Size.fromHeight(38),
          ),
          child: Text(_l10n.resetCrop, overflow: TextOverflow.ellipsis),
        ),
      ],
      const SizedBox(height: 6),
    ];
  }

  /// The colour half of Adjust, which reaches the photo's pixels and so exists
  /// only for a photo layer.
  List<Widget> _colorSliders(ImageLayer selected) {
    final id = selected.id;
    final adj = selected.adjustments;
    void update(ImageAdjustments next) =>
        _controller.updateImageAdjustments(id, next);
    return [
      LabeledSlider(
        label: _l10n.brightness,
        value: adj.brightness * 100,
        min: 0,
        max: 200,
        accent: context.colors.amber,
        valueLabel: '${(adj.brightness * 100).round()}%',
        onChanged: (v) => update(adj.copyWith(brightness: v / 100)),
        onChangeEnd: _endSliderEdit,
      ),
      LabeledSlider(
        label: _l10n.contrast,
        value: adj.contrast * 100,
        min: 0,
        max: 200,
        accent: context.colors.cyan,
        valueLabel: '${(adj.contrast * 100).round()}%',
        onChanged: (v) => update(adj.copyWith(contrast: v / 100)),
        onChangeEnd: _endSliderEdit,
      ),
      LabeledSlider(
        label: _l10n.saturation,
        value: adj.saturation * 100,
        min: 0,
        max: 200,
        accent: context.colors.pink,
        valueLabel: '${(adj.saturation * 100).round()}%',
        onChanged: (v) => update(adj.copyWith(saturation: v / 100)),
        onChangeEnd: _endSliderEdit,
      ),
      LabeledSlider(
        label: _l10n.hue,
        value: adj.hue,
        min: -180,
        max: 180,
        accent: context.colors.violet,
        valueLabel: '${adj.hue.round()}°',
        onChanged: (v) => update(adj.copyWith(hue: v)),
        onChangeEnd: _endSliderEdit,
      ),
    ];
  }

  // ------------------------------------------------------------ Text
  Widget _textPanel(EditorState editor) {
    // Fixed brand hues, NOT theme colours: this list is written into the
    // layer and saved, so it has to mean the same thing in both themes.
    const colors = AppColors.swatches;

    final selected = editor.selectedLayer;
    if (selected is! TextLayer) {
      return Column(
        children: [
          _panelHeader(EditorTool.text),
          _emptyHint(_l10n.textEmptyHint),
          GradientButton(
            label: _l10n.addText,
            icon: Icons.add,
            gradient: LinearGradient(
              colors: [
                context.colors.pink,
                context.colors.pink.withValues(alpha: 0.7),
              ],
            ),
            glowColor: context.colors.pink,
            onPressed: () =>
                _controller.addTextLayer(text: _l10n.textLayerDefault),
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
          trailing: _PanelHint(_l10n.tapFontToPreview),
        ),
        TextField(
          controller: _textController,
          onChanged: (v) => _controller.updateTextLayer(id, text: v),
          style: TextStyle(
            fontFamily: AppFonts.ui,
            color: context.colors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: _l10n.typeYourCaption,
            hintStyle: TextStyle(color: context.colors.textMuted),
            filled: true,
            fillColor: context.colors.inputField,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 11,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.colors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.colors.border),
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
                accent: context.colors.pink,
                selected: active,
                radius: 12,
                onTap: () => _controller.updateTextLayer(id, fontFamily: f),
                labelStyle: TextStyle(
                  fontFamily: f,
                  fontSize: 16,
                  color: active
                      ? context.colors.textPrimary
                      : context.colors.textSecondary,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        LabeledSlider(
          label: _l10n.size,
          value: selected.fontSize,
          min: 16,
          max: 72,
          accent: context.colors.pink,
          valueColor: context.colors.textMuted,
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
                          ? context.colors.textPrimary
                          : context.colors.borderStrong,
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
            _PanelHint(_l10n.outlineSection),
            if (selected.strokeColor != null)
              PillChip(
                key: const ValueKey('text-stroke-auto'),
                label: _l10n.autoColor,
                onTap: () => _controller.updateTextStroke(id, autoColor: true),
              ),
          ],
        ),
        LabeledSlider(
          label: _l10n.thickness,
          value: selected.strokeWidth,
          min: 0,
          max: 16,
          accent: context.colors.pink,
          valueColor: context.colors.textMuted,
          valueLabel: selected.strokeWidth < 0.05
              ? _l10n.off
              : selected.strokeWidth.toStringAsFixed(1),
          onChanged: (v) => _controller.updateTextStroke(id, width: v),
          onChangeEnd: _endSliderEdit,
        ),
        if (selected.hasStroke) ...[
          LabeledSlider(
            label: _l10n.outlineOpacity,
            value: selected.strokeOpacity * 100,
            min: 0,
            max: 100,
            accent: context.colors.pink,
            valueColor: context.colors.textMuted,
            valueLabel: '${(selected.strokeOpacity * 100).round()}%',
            onChanged: (v) =>
                _controller.updateTextStroke(id, opacity: v / 100),
            onChangeEnd: _endSliderEdit,
          ),
          const SizedBox(height: 4),
          _swatchRow(
            _l10n.color,
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
    _toast(_l10n.fontAdded(family));
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
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 15, color: context.colors.textSecondary),
            const SizedBox(width: 5),
            Text(
              _l10n.font,
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: context.colors.textSecondary,
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
      final entered = _editingBubbleId != bubble.id;
      _editingBubbleId = bubble.id;
      _bubbleTextController.value = TextEditingValue(
        text: bubble.text,
        selection: TextSelection.collapsed(offset: bubble.text.length),
      );
      // Arriving at a bubble whose format sits past the fold - Whisper is the
      // fifth of five - would otherwise open the panel on a row with nothing
      // highlighted, right after the user picked that very format. Only on
      // arrival: while editing, the scroll position is the user's.
      if (entered) _revealBubbleFormat(bubble.shape);
    }
    final id = bubble.id;
    final fonts = ref.watch(availableFontsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // No trailing hint naming the format: the row below already shows which
        // one is on, drawn and highlighted, and a second copy is what pushed
        // this header past a narrow landscape column.
        _panelHeader(EditorTool.text, title: _l10n.comicBubble),
        // Formats are drawn, not just named: as five text pills, four of the
        // five read as jargon and only the default ever got picked. Same tile
        // as the creation sheet, so the row doubles as "you can still change
        // your mind".
        //
        // The height is measured, not a constant: the tile ends in a label, so
        // a hard 106 would overflow the moment the system font scale went up.
        SizedBox(
          height: bubbleShapeTileHeight(context, thumbWidth: _kBubbleRowThumb),
          child: ListView.separated(
            // Keyed so a test can hold on to the row while it scrolls - an
            // off-screen tile does not exist yet in a lazy list.
            key: const ValueKey('bubble-shape-row'),
            controller: _bubbleFormatScroll,
            scrollDirection: Axis.horizontal,
            itemCount: BubbleShape.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: _kBubbleRowGap),
            itemBuilder: (_, i) {
              final s = BubbleShape.values[i];
              return SizedBox(
                width: _kBubbleRowTile,
                child: BubbleShapeTile(
                  shape: s,
                  selected: bubble.shape == s,
                  thumbWidth: _kBubbleRowThumb,
                  onTap: () => _controller.updateBubbleLayer(id, shape: s),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _bubbleTextController,
          onChanged: (v) => _controller.updateBubbleLayer(id, text: v),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.ui,
            color: context.colors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: _l10n.bubbleTextHint,
            hintStyle: TextStyle(color: context.colors.textMuted),
            filled: true,
            fillColor: context.colors.inputField,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 11,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.colors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.colors.border),
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
                accent: context.colors.pink,
                selected: active,
                radius: 12,
                onTap: () => _controller.updateBubbleLayer(id, fontFamily: f),
                labelStyle: TextStyle(
                  fontFamily: f,
                  fontSize: 16,
                  color: active
                      ? context.colors.textPrimary
                      : context.colors.textSecondary,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        LabeledSlider(
          label: _l10n.size,
          value: bubble.fontSize,
          min: 14,
          max: 44,
          accent: context.colors.pink,
          valueColor: context.colors.textMuted,
          valueLabel: '${bubble.fontSize.round()}px',
          onChanged: (v) => _controller.updateBubbleLayer(id, fontSize: v),
          onChangeEnd: _endSliderEdit,
        ),
        const SizedBox(height: 4),
        _swatchRow(
          _l10n.fill,
          bubble.fillColor,
          (c) => _controller.updateBubbleLayer(
            id,
            fillColor: c,
            textColor: _inkFor(c),
          ),
        ),
        const SizedBox(height: 10),
        _swatchRow(
          _l10n.outline,
          bubble.strokeColor,
          (c) => _controller.updateBubbleLayer(id, strokeColor: c),
        ),
        const SizedBox(height: 8),
        // The tail is direct-manipulation now: drag the round knob at its tip
        // on the canvas - any direction, any shape (#78).
        Text(
          _l10n.bubbleTailHint,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 11.5,
            color: context.colors.textMuted,
          ),
        ),
      ],
    );
  }

  /// Adds a comic bubble, after asking which format - the four non-default
  /// formats were unreachable at creation, and a bubble that arrived silently
  /// under a panel headed "Text" was routinely missed.
  ///
  /// Dismissing the picker adds nothing, so the sheet is also the way out.
  Future<void> _addBubble() async {
    final shape = await showBubbleShapeSheet(context);
    if (shape == null || !mounted) return;
    _controller.addBubbleLayer(shape: shape, bubbleLabel: _l10n.bubble);
    _controller.setTool(EditorTool.text);
    if (!_sidePanelOpen) setState(() => _sidePanelOpen = true);
    // "in the panel", not "below": in landscape the panel is a rail to the
    // left of the canvas, so a direction would be wrong half the time.
    _toast(_l10n.bubbleAdded(bubbleShapeLabel(_l10n, shape)));
  }

  /// Scrolls the Bubble panel's format row so [shape]'s tile is on screen.
  ///
  /// Post-frame because the row may not exist yet: this is called from the
  /// build that first shows the panel, and a [ScrollController] with no clients
  /// cannot be moved.
  void _revealBubbleFormat(BubbleShape shape) {
    final index = BubbleShape.values.indexOf(shape);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_bubbleFormatScroll.hasClients) return;
      final position = _bubbleFormatScroll.position;
      // Tiles are a fixed width, so the offset is arithmetic - no need to
      // measure, and nothing to go stale if the row rebuilds.
      const stride = _kBubbleRowTile + _kBubbleRowGap;
      final target = (index * stride).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      _bubbleFormatScroll.jumpTo(target);
    });
  }

  /// Names for the swatch row, positionally matched to its colours - a screen
  /// reader has nothing else to go on.
  ///
  /// Localized, and easy to miss that it has to be: these never appear as a
  /// `Text`, only inside a `Semantics` label, so nothing on screen shows them
  /// and an ARB-to-ARB parity test cannot see a string that was never keyed.
  /// As English literals they made a Polish user's screen reader say
  /// "Wypełnienie white".
  List<String> get _colorNames => [
    _l10n.swatchWhite,
    _l10n.swatchBlack,
    _l10n.swatchPink,
    _l10n.swatchAmber,
    _l10n.swatchGreen,
    _l10n.swatchCyan,
    _l10n.swatchViolet,
    _l10n.swatchRose,
    _l10n.swatchOrange,
  ];

  /// A labelled row of 9 color swatches for the bubble fill / outline.
  Widget _swatchRow(String label, Color selected, ValueChanged<Color> onPick) {
    // Fixed brand hues, NOT theme colours: this list is written into the
    // layer and saved, so it has to mean the same thing in both themes.
    const colors = AppColors.swatches;
    return Row(
      children: [
        SizedBox(
          // 84, not the 52 this was built at for English "Fill" / "Outline".
          // These labels are single words, so a box narrower than the word has
          // nowhere to break and Flutter splits it mid-word: Polish rendered
          // "Wypełni / enie", French would do the same with "Remplissage".
          // Widening is the right fix rather than shortening the words,
          // because this slot HAS give - the swatches beside it are a
          // horizontally scrolling list, so the extra dp comes out of a row
          // that was already scrolling. 84 was measured, not guessed: at 72
          // the Polish still ellipsized to "Wypełnien…".
          width: 84,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontSize: 12,
              color: context.colors.textSecondary,
            ),
          ),
        ),
        Expanded(
          // Horizontally scrollable rather than wrapped: nine 40dp targets do
          // not fit one row on a 360dp phone, and letting them wrap moved the
          // controls below the fold on a short viewport. The dots stay 26px -
          // only the area that accepts a tap grew around them.
          child: SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: colors.length,
              separatorBuilder: (_, _) => const SizedBox(width: 2),
              itemBuilder: (_, i) {
                final c = colors[i];
                return Semantics(
                  button: true,
                  selected: selected == c,
                  // Unlabeled, these were nine identical "button" nodes to a
                  // screen reader, in a row whose whole purpose is which one
                  // is which.
                  // Comma-separated: the row label and the colour name are two
                  // facts, not a phrase, so nothing has to agree with
                  // anything. "Wypelnienie, bialy" is right where
                  // "Wypelnienie bialy" would not be.
                  label: '$label, ${_colorNames[i]}',
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: () => onPick(c),
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected == c
                                  ? context.colors.textPrimary
                                  : context.colors.borderStrong,
                              width: selected == c ? 3 : 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
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
          _emptyHint(_l10n.notAPhotoGrid),
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
            label: _l10n.shuffle,
            icon: Icons.shuffle,
            accent: accent,
            selected: true,
            onTap: _controller.shuffleGridPhotos,
          ),
        ),
        _PanelHint(_l10n.photosSection),
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
        _PanelHint(_l10n.layoutSection),
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
          label: _l10n.border,
          value: grid.borderWidth,
          min: 0,
          max: GridSpec.maxBorderWidth,
          accent: accent,
          valueLabel: '${grid.borderWidth.round()} px',
          onChanged: (v) => _controller.setGridBorder(width: v),
          onChangeEnd: (_) => _controller.endEdit(),
        ),
        LabeledSlider(
          label: _l10n.corners,
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
          _l10n.color,
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
              label: _l10n.add,
              icon: Icons.add,
              onTap: _showAddMenu,
            ),
          ),
          _emptyHint(_l10n.effectsEmptyHint),
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
            label: _l10n.reset,
            onTap: () => _controller.resetLayerEffects(id),
          ),
        ),
        if (image != null) ...[
          _PanelHint(_l10n.filterSection),
          const SizedBox(height: 8),
          FilterStrip(
            assetPath: image.assetPath,
            selected: image.adjustments.filter,
            onPick: (f) => _controller.setPhotoFilter(id, f),
          ),
          if (image.adjustments.hasFilter)
            LabeledSlider(
              label: _l10n.strength,
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
          _PanelHint(_l10n.hdrSection),
          LabeledSlider(
            label: _l10n.toneAndDetail,
            value: image.adjustments.hdr * 100,
            min: 0,
            max: 100,
            accent: context.colors.greenLight,
            valueLabel: image.adjustments.hdr < 0.005
                ? _l10n.off
                : '${(image.adjustments.hdr * 100).round()}%',
            onChanged: (v) => _controller.setHdr(id, v / 100),
            onChangeEnd: _endSliderEdit,
          ),
          const SizedBox(height: 6),
          _PanelHint(_l10n.vignetteSection),
          LabeledSlider(
            label: _l10n.amount,
            value: image.vignette.amount * 100,
            min: 0,
            max: 100,
            accent: context.colors.violet,
            valueLabel: image.vignette.amount < 0.005
                ? _l10n.off
                : '${(image.vignette.amount * 100).round()}%',
            onChanged: (v) => _controller.updateVignette(id, amount: v / 100),
            onChangeEnd: _endSliderEdit,
          ),
          if (image.vignette.isVisible) ...[
            LabeledSlider(
              label: _l10n.size,
              value: image.vignette.size * 100,
              min: 5,
              max: 95,
              accent: context.colors.violet,
              valueLabel: '${(image.vignette.size * 100).round()}%',
              onChanged: (v) => _controller.updateVignette(id, size: v / 100),
              onChangeEnd: _endSliderEdit,
            ),
            LabeledSlider(
              label: _l10n.softness,
              value: image.vignette.softness * 100,
              min: 0,
              max: 100,
              accent: context.colors.violet,
              valueLabel: '${(image.vignette.softness * 100).round()}%',
              onChanged: (v) =>
                  _controller.updateVignette(id, softness: v / 100),
              onChangeEnd: _endSliderEdit,
            ),
            const SizedBox(height: 4),
            _swatchRow(
              _l10n.color,
              image.vignette.color,
              (c) => _controller.updateVignette(id, color: c),
            ),
          ],
          const SizedBox(height: 12),
        ],
        _PanelHint(_l10n.shadowSection),
        LabeledSlider(
          label: _l10n.opacity,
          value: shadow.enabled ? shadow.opacity * 100 : 0,
          min: 0,
          max: 100,
          accent: context.colors.cyan,
          valueLabel: shadow.isVisible
              ? '${(shadow.opacity * 100).round()}%'
              : _l10n.off,
          onChanged: (v) => _controller.updateLayerShadow(
            id,
            enabled: v > 0,
            opacity: v / 100,
          ),
          onChangeEnd: _endSliderEdit,
        ),
        if (shadow.isVisible) ...[
          LabeledSlider(
            label: _l10n.direction,
            value: shadow.angle,
            min: 0,
            max: 360,
            accent: context.colors.cyan,
            valueLabel: '${shadow.angle.round()}°',
            onChanged: (v) => _controller.updateLayerShadow(id, angle: v),
            onChangeEnd: _endSliderEdit,
          ),
          LabeledSlider(
            label: _l10n.distance,
            value: shadow.distance,
            min: 0,
            max: 120,
            accent: context.colors.cyan,
            valueLabel: '${shadow.distance.round()} px',
            onChanged: (v) => _controller.updateLayerShadow(id, distance: v),
            onChangeEnd: _endSliderEdit,
          ),
          LabeledSlider(
            label: _l10n.blur,
            value: shadow.blur,
            min: 0,
            max: 80,
            accent: context.colors.cyan,
            valueLabel: '${shadow.blur.round()} px',
            onChanged: (v) => _controller.updateLayerShadow(id, blur: v),
            onChangeEnd: _endSliderEdit,
          ),
          LabeledSlider(
            label: _l10n.density,
            value: shadow.density,
            min: 0,
            max: 30,
            accent: context.colors.cyan,
            valueLabel: '${shadow.density.round()} px',
            onChanged: (v) => _controller.updateLayerShadow(id, density: v),
            onChangeEnd: _endSliderEdit,
          ),
          const SizedBox(height: 4),
          _swatchRow(
            _l10n.color,
            shadow.color,
            (c) => _controller.updateLayerShadow(id, color: c),
          ),
        ],
        const SizedBox(height: 12),
        _PanelHint(
          image?.maskPath != null
              ? _l10n.cutoutOutlineSection
              : _l10n.outlineSection,
        ),
        LabeledSlider(
          label: _l10n.thickness,
          value: stroke.width,
          min: 0,
          max: 40,
          accent: context.colors.violetLight,
          valueLabel: stroke.width < 0.5
              ? _l10n.off
              : _l10n.pixels(stroke.width.round()),
          onChanged: (v) => _controller.updateLayerStroke(id, width: v),
          onChangeEnd: _endSliderEdit,
        ),
        if (stroke.isVisible) ...[
          LabeledSlider(
            label: _l10n.opacity,
            value: stroke.opacity * 100,
            min: 0,
            max: 100,
            accent: context.colors.violetLight,
            valueLabel: '${(stroke.opacity * 100).round()}%',
            onChanged: (v) =>
                _controller.updateLayerStroke(id, opacity: v / 100),
            onChangeEnd: _endSliderEdit,
          ),
          const SizedBox(height: 4),
          _swatchRow(
            _l10n.color,
            stroke.color,
            (c) => _controller.updateLayerStroke(id, color: c),
          ),
        ],
        const SizedBox(height: 14),
        _PanelHint(_l10n.blendSection),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final blend in LayerBlend.values)
              PillChip(
                key: ValueKey('blend-${blend.name}'),
                label: blend.labelOf(_l10n),
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
        ? _l10n.working
        : (removed ? _l10n.undoRemoval : _l10n.removeBackground);
    final model = ref.watch(segModelProvider).asData?.value ?? SegModel.builtin;
    final removeMode = _removeObjectMode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            _l10n.toolCutoutPanel,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.display,
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: context.colors.green,
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
                  _l10n.background,
                  !removeMode,
                  context.colors.green,
                  () => setState(() => _removeObjectMode = false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _segTab(
                  _l10n.removeObject,
                  removeMode,
                  context.colors.rose,
                  () {
                    setState(() => _removeObjectMode = true);
                    // Warm the SAM image embedding while the user aims, so
                    // the first escalated tap only pays the decoder (#85) -
                    // skipped entirely on capability-denied devices and after
                    // a hard engine failure.
                    unawaited(_precomputeSamIfAllowed(image.assetPath));
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
        if (removeMode) ...[
          _emptyHint(_l10n.objectRemoveHint),
          const SizedBox(height: 8),
          // What "remove" is going to MEAN - two genuinely different results.
          // This chooser used to be built only when the optional MI-GAN asset
          // was bundled, which no shipped build has ever had: every tap erased
          // the object to a transparent hole, with nothing on screen saying so
          // and no way to ask for anything else. Most people tap "remove
          // object" expecting the background to close over it, so Fill leads
          // and Erase stays one tap away.
          Row(
            children: [
              Expanded(
                child: _segTab(
                  _l10n.fillIn,
                  _fillMode,
                  context.colors.cyan,
                  () => setState(() => _fillMode = true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _segTab(
                  _l10n.erase,
                  !_fillMode,
                  context.colors.rose,
                  () => setState(() => _fillMode = false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            _fillMode ? _l10n.fillExplainer : _l10n.eraseExplainer,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontSize: 10.5,
              color: context.colors.textMuted,
            ),
          ),
        ] else ...[
          _emptyHint(
            image == null ? _l10n.cutoutSelectPhoto : _l10n.cutoutHint,
          ),
          _modelPicker(model),
          const SizedBox(height: 16),
          GradientButton(
            label: label,
            icon: Icons.auto_awesome,
            busy: _removingBg,
            gradient: removed ? null : context.tokens.cutoutGradient,
            solidColor: removed ? context.colors.neutralButton : null,
            foreground: removed
                ? context.colors.textSecondary
                : context.colors.onAccent,
            glowColor: context.colors.green,
            onPressed: image == null
                ? null
                : () {
                    if (removed) {
                      _controller.setImageMask(image.id, null);
                      _toast(_l10n.backgroundRestored);
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
              Text(
                _l10n.aiModelSection,
                style: TextStyle(
                  fontFamily: AppFonts.ui,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: context.colors.textSecondary,
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
          color: context.colors.green.withValues(alpha: 0.12),
          border: Border.all(
            color: context.colors.green.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        child: Text(
          '?',
          style: TextStyle(
            fontFamily: AppFonts.display,
            fontWeight: FontWeight.w700,
            fontSize: 12,
            height: 1,
            color: context.colors.greenLight,
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
              ? context.colors.green.withValues(alpha: 0.10)
              : context.colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? context.colors.green.withValues(alpha: 0.6)
                : context.colors.border,
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
                    model.labelOf(_l10n),
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    model.taglineOf(_l10n),
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: 11,
                      color: context.colors.textMuted,
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
        color: selected ? context.colors.green : Colors.transparent,
        border: selected
            ? null
            : Border.all(color: context.colors.borderStrong, width: 2),
      ),
      child: selected
          ? DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.colors.onAccent,
              ),
              child: const SizedBox(width: 8, height: 8),
            )
          : null,
    );
  }

  /// Bottom sheet explaining the two models (design's "Which AI model?").
  Future<void> _showModelInfo() async {
    await showModalBottomSheet<void>(
      context: context,
      // So the sheet may use the height it needs; SheetBody caps and scrolls it.
      isScrollControlled: true,
      backgroundColor: context.colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SheetBody(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(
              _l10n.whichAiModel,
              style: TextStyle(
                fontFamily: AppFonts.display,
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: context.colors.green,
              ),
            ),
          ),
          for (final m in SegModel.values) ...[
            _modelInfoCard(m),
            if (m != SegModel.values.last) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _modelInfoCard(SegModel model) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      decoration: BoxDecoration(
        color: context.colors.inputField,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            model.labelOf(_l10n),
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: context.colors.greenLight,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            model.blurbOf(_l10n),
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontSize: 12.5,
              height: 1.55,
              color: context.colors.textSecondary,
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
    // The SAME prompt the export gate uses. This used to be a bare AlertDialog
    // whose "Go Pro" was a text button beside "Cancel" - the one route out of
    // ads, styled like the way to back out.
    final outcome = await AdGate.run(
      context,
      ref,
      title: _l10n.aiGateTitle,
      message: _l10n.aiGateMessage,
      watchLabel: _l10n.aiGateWatch,
    );
    if (outcome.allows) {
      _aiUnlockedThisSession = true;
      return true;
    }
    // Only when they started an ad and it did not count. Dismissing the sheet is
    // an answer, not a mistake, and someone who just tapped Go Pro is already
    // looking at the purchase screen - telling them there to consider Go Pro is
    // exactly the nag this gate exists to avoid.
    if (outcome == AdGateOutcome.notRewarded && mounted) {
      _toast(_l10n.aiGateNotRewarded, ok: false);
    }
    return false;
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
          _toast(_l10n.bgRemovalUnavailable, ok: false);
        }
        return;
      }
      // The clean-up chain crunches every pixel of a photo-sized mask - run it
      // off the UI isolate so the "Working…" spinner actually animates
      // (docs/reviews/2026-07-19-review.md).
      final mask = await _processCutoutMask(result.mask, refine: refine);
      // `ref` after an await is unsafe once unmounted - in riverpod 3.x that is
      // a real StateError, which the catch below would have swallowed as
      // "couldn't remove the background".
      if (!mounted) return;
      final path = await ref.read(maskStoreProvider).save(mask, id: image.id);
      if (!mounted) return;
      // The overlay does not block the dock or the Layers panel, so the layer
      // may have been deleted - or the frame switched - while this ran.
      // Applying to a document that no longer has it is a no-op that used to
      // still toast "Background removed" over an unchanged picture.
      if (!_controller.hasLayer(image.id)) {
        _toast(_l10n.layerGoneCutoutDiscarded, ok: false);
        return;
      }
      _maskGc.supersede(image.maskPath, path);
      _controller.setImageMask(image.id, path);
      if (mounted) {
        // Report which engine actually ran - it may differ from the preference
        // if that one was unavailable and the registry fell through.
        final used = SegModel.fromEngineId(result.engineId);
        _toast(
          used == null
              ? _l10n.backgroundRemoved
              : _l10n.backgroundRemovedWith(used.labelOf(_l10n)),
        );
      }
    } catch (_) {
      if (mounted) {
        _toast(_l10n.bgRemovalFailed, ok: false);
      }
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
    if (!mounted) return; // `ref` after an await needs the screen alive
    final path = await ref
        .read(maskStoreProvider)
        .save(processed, id: image.id);
    if (!mounted) return;
    // The layer can be deleted while this runs - nothing blocks the dock or
    // the Layers panel during a cut-out.
    if (!_controller.hasLayer(image.id)) {
      _toast(_l10n.layerGoneCutoutDiscarded, ok: false);
      return;
    }
    _maskGc.supersede(image.maskPath, path);
    _controller.setImageMask(image.id, path);
  }

  void _showBgSheet() {
    final selected = ref.read(editorControllerProvider).selectedLayer;
    final image = selected is ImageLayer ? selected : null;
    if (image == null) {
      _toast(_l10n.selectPhotoToCutOut, ok: false);
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
      backgroundColor: context.colors.panel,
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
              engineLabel = model.labelOf(_l10n);
              setSheet(() => stage = 'processing');
              final result = await _segment(image);
              // Deliberately the SCREEN's `mounted`, not the sheet's. The sheet
              // is dismissible and the engine keeps running regardless, so
              // keying the apply on `sheetCtx.mounted` meant a reflexive
              // back-press threw a finished cut-out away with no toast, no
              // spinner and nothing on the canvas to show for the wait.
              if (!mounted) return;
              if (result == null) {
                if (sheetCtx.mounted) setSheet(() => stage = 'choose');
                _toast(_l10n.bgRemovalUnavailable, ok: false);
                return;
              }
              raw = result.mask;
              await _applyCutout(
                image,
                raw!,
                keepLargest: autoRefine,
                feather: feather.round(),
              );
              if (!mounted) return;
              if (!sheetCtx.mounted) {
                // Dismissed mid-run: the work landed anyway, so say so - the
                // sheet's own "done" stage is not there to report it.
                _toast(_l10n.backgroundRemovedWith(engineLabel));
                return;
              }
              setSheet(() => stage = 'done');
            }

            final List<Widget> children;
            if (stage == 'processing') {
              children = [
                const SizedBox(height: 12),
                SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(
                    strokeWidth: 5,
                    color: context.colors.cyan,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _l10n.engineWorking(engineLabel),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _l10n.detectingSubject,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontSize: 11.5,
                    color: context.colors.textSecondary,
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
                      decoration: BoxDecoration(
                        color: context.colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check,
                        size: 18,
                        color: context.colors.onAccent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _l10n.backgroundRemoved,
                      style: TextStyle(
                        fontFamily: AppFonts.display,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: context.colors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(
                      _l10n.edgeFeather,
                      style: TextStyle(
                        fontFamily: AppFonts.ui,
                        fontSize: 12,
                        color: context.colors.textSecondary,
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        value: feather,
                        max: 8,
                        divisions: 8,
                        activeColor: context.colors.cyan,
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
                        foregroundColor: context.colors.textSecondary,
                        side: BorderSide(color: context.colors.border),
                        minimumSize: const Size(52, 50),
                      ),
                      child: const Icon(Icons.refresh, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(sheetCtx).pop(),
                        style: FilledButton.styleFrom(
                          backgroundColor: context.colors.cyan,
                          foregroundColor: context.colors.onAccent,
                          minimumSize: const Size.fromHeight(50),
                        ),
                        child: Text(
                          _l10n.applyToLayer,
                          style: const TextStyle(
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
                  objectMode ? _l10n.removeAnObject : _l10n.removeBackground,
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  objectMode ? _l10n.tapObjectsToErase : _l10n.chooseAiEngine,
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontSize: 11.5,
                    color: context.colors.textSecondary,
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
                        ? context.colors.pink
                        : context.colors.cyan,
                    foregroundColor: context.colors.onAccent,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: Text(
                    objectMode
                        ? _l10n.tapObjectsToRemove
                        : _l10n.removeBackground,
                    style: const TextStyle(
                      fontFamily: AppFonts.display,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ];
            }

            return SheetBody(children: children);
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
          Expanded(
            child: Text(
              _l10n.autoRefineEdges,
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: context.colors.textSecondary,
              ),
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: context.colors.onAccent,
            activeTrackColor: context.colors.cyan,
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
            color: active ? context.colors.cyan : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
              color: active
                  ? context.colors.onAccent
                  : context.colors.textSecondary,
            ),
          ),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.colors.cardAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.borderFaint),
      ),
      child: Row(
        children: [
          tab(_l10n.background, !object, () => onChanged(false)),
          tab(_l10n.object, object, () => onChanged(true)),
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
    _toast(_l10n.tapAnObjectToRemove);
    unawaited(_precomputeSamIfAllowed(image.assetPath));
  }

  Widget _bgEngineCard(SegModel current, SegModel model, VoidCallback onTap) {
    final active = current == model;
    final accent = model == SegModel.builtin
        ? context.colors.cyan
        : context.colors.pink;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: active ? accent.withValues(alpha: 0.1) : context.colors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active ? accent : context.colors.borderFaint,
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
                  color: context.colors.onAccent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.labelOf(_l10n),
                      style: TextStyle(
                        fontFamily: AppFonts.ui,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      model.taglineOf(_l10n),
                      style: TextStyle(
                        fontFamily: AppFonts.ui,
                        fontSize: 11,
                        color: context.colors.textSecondary,
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
                    color: active ? accent : context.colors.textFaint,
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
      if (mounted) _toast(_l10n.brushFailed, ok: false);
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
          if (mounted) _toast(_l10n.nothingToRemoveThere, ok: false);
        case RemoveTapOutcome.subject:
          // The tapped blob IS (or touches) the biggest one - the free CC
          // tier can't carve an attached object out. Escalate to the
          // point-prompt model (#86): tap coords are already source px.
          await _samRemoveAt(layer, maskPoint);
        case RemoveTapOutcome.removed:
          if (_fillMode) {
            // Fill the removed blob with rebuilt background rather than
            // cutting it out to transparency.
            final blob = await _removedRegion(_workingMask!, result.mask!);
            if (!mounted) return;
            await _inpaintObject(layer, blob, _workingMask!);
          } else {
            await _applyRemovedMask(layer, result.mask!);
            if (mounted) _toast(_l10n.objectRemoved);
          }
      }
    } catch (_) {
      if (mounted) _toast(_l10n.objectRemoveFailed, ok: false);
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
      if (mounted) _toast(samUnavailableMessage, ok: false);
      return;
    }
    final engine = ref.read(objectSegmentationEngineProvider);
    if (!await engine.isAvailable()) {
      if (mounted) _toast(samUnavailableMessage, ok: false);
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
        if (mounted) _toast(_l10n.objectRemoveFailed, ok: false);
        return;
      }
      if (!mounted) return;
      final current = _workingMask;
      if (object == null || current == null) {
        _toast(_l10n.noObjectThere, ok: false);
        return;
      }
      // Overlap with what the cutout currently keeps - a per-pixel pass over
      // the full mask, so off the UI isolate (docs/reviews/2026-07-19-review.md).
      final stats = await _maskOverlap(current, object);
      if (!mounted) return;
      if (stats.overlap == 0) {
        _toast(_l10n.noObjectThere, ok: false);
        return;
      }
      if (stats.overlap > stats.kept * 0.8) {
        _toast(_l10n.thatLooksLikeSubject, ok: false);
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
      if (mounted) _toast(_l10n.objectRemoved);
    } catch (_) {
      if (mounted) _toast(_l10n.objectRemoveFailed, ok: false);
    } finally {
      if (mounted) setState(() => _samBusy = false);
    }
  }

  /// Fill: replaces the tapped [object] region in [layer]'s photo with rebuilt
  /// background, swapping in the new image. Falls back to erasing (subtract
  /// from [current]) when neither fill tier can produce a result.
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
        if (mounted) _toast(_l10n.fillUnavailable, ok: false);
        return;
      }
      final newPath = await ref
          .read(imageImportServiceProvider)
          .storeBytes(filled);
      if (!mounted) return;
      _controller.replaceImageAsset(layer.id, newPath);
      if (mounted) _toast(_l10n.objectFilled);
    } finally {
      if (mounted) setState(() => _inpainting = false);
    }
  }

  /// The two fill tiers, best first. MI-GAN invents plausible content and wins
  /// on structured scenes, but it is an OPTIONAL bundled model (see
  /// docs/inpaint-setup.md) and absent from the shipped app; content-aware fill
  /// only rebuilds from texture the photo already has, and always runs. Trying
  /// them in order is what lets Fill be offered unconditionally - the feature
  /// no longer disappears with the asset.
  Future<Uint8List?> _tryInpaint(ImageLayer layer, AlphaMask object) async {
    try {
      final bytes = await File(layer.assetPath).readAsBytes();
      if (ref.read(inpaintAvailableProvider).asData?.value ?? false) {
        final generated = await ref
            .read(inpaintEngineProvider)
            .inpaint(bytes, object);
        if (generated != null) return generated;
      }
      return await ref.read(contentFillEngineProvider).fill(bytes, object);
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
          _emptyHint(_l10n.eraseEmptyHint),
        ],
      );
    }
    final brushPreview = (_brushSize * 0.4).clamp(8.0, 40.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _panelHeader(
          EditorTool.erase,
          trailing: _PanelHint(_l10n.brushOverCanvas),
        ),
        Row(
          children: [
            Expanded(
              child: _segTab(
                _l10n.erase,
                _eraseMode,
                context.colors.amber,
                () => setState(() => _eraseMode = true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _segTab(
                _l10n.restore,
                !_eraseMode,
                context.colors.green,
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
                label: _l10n.brushSize,
                value: _brushSize,
                min: 8,
                max: 120,
                accent: context.colors.amber,
                valueColor: context.colors.textMuted,
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
                  color: context.colors.amber.withValues(alpha: 0.25),
                  border: Border.all(color: context.colors.amber, width: 2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _l10n.softEdges,
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: context.colors.textSecondary,
              ),
            ),
            Switch(
              value: _softEdges,
              activeThumbColor: context.colors.onAccent,
              activeTrackColor: context.colors.amber,
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
            label: _isPlaying ? _l10n.pause : _l10n.play,
            icon: _isPlaying ? Icons.pause : Icons.play_arrow,
            accent: context.colors.orange,
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
                Expanded(
                  child: Text(
                    _l10n.newLayersToAllFrames,
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ),
                Switch(
                  value: _controller.addToAllFrames,
                  activeThumbColor: context.colors.onAccent,
                  activeTrackColor: context.colors.orange,
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
              Expanded(
                child: Text(
                  _l10n.onionSkin,
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
              Switch(
                value: _onionSkin,
                activeThumbColor: context.colors.onAccent,
                activeTrackColor: context.colors.orange,
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
            color: context.colors.orange.withValues(alpha: 0.4),
            width: 2,
          ),
        ),
        child: Icon(Icons.add, color: context.colors.orange),
      ),
    );
  }

  /// Long-press menu for a frame: duplicate, reorder (when not at an edge), or
  /// delete (when >1 frame).
  Future<void> _showFrameMenu(int index, int frameCount) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      // So the sheet may use the height it needs; SheetBody caps and scrolls it.
      isScrollControlled: true,
      backgroundColor: context.colors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SheetBody(
        // No side padding: these tiles are meant to run edge to edge.
        padding: const EdgeInsets.fromLTRB(0, 14, 0, 8),
        children: [
          _sheetTile(
            ctx,
            Icons.copy_all_outlined,
            _l10n.duplicateFrame,
            'duplicate',
          ),
          if (index > 0)
            _sheetTile(ctx, Icons.arrow_back, _l10n.moveLeft, 'move_left'),
          if (index < frameCount - 1)
            _sheetTile(ctx, Icons.arrow_forward, _l10n.moveRight, 'move_right'),
          if (frameCount > 1)
            _sheetTile(ctx, Icons.delete_outline, _l10n.deleteFrame, 'delete'),
        ],
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
  /// Converts between the Layers panel's top-most-first rows and
  /// `Project.layers`' paint order (index 0 = bottom). Its own inverse, and
  /// correct for an insertion index too: dropping a row at panel slot `i` of
  /// `count` rows means inserting at `count - 1 - i` in the model, which is what
  /// [EditorController.reorderLayer] takes after the drag's removal.
  static int _modelIndex(int panelIndex, int count) => count - 1 - panelIndex;

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
            label: _l10n.add,
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
                    label: _l10n.mergeDown,
                    icon: Icons.vertical_align_bottom,
                    onTap: () => _mergeDown(selectedId),
                  ),
                ),
              if (canMergeDown && canFlatten) const SizedBox(width: 8),
              if (canFlatten)
                Expanded(
                  child: PillChip(
                    key: const ValueKey('flatten-layers'),
                    label: _l10n.flatten,
                    icon: Icons.layers_clear,
                    onTap: _flattenLayers,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        if (layers.isEmpty)
          _emptyHint(_l10n.layersEmptyHint)
        else
          // TOP-MOST FIRST. `Project.layers` is in paint order - index 0 is
          // painted first, so the LAST entry is the one on top of the canvas -
          // and listing it that way put the bottom layer at the top of the panel
          // and made dragging a row upwards send it *behind* everything. Every
          // layers UI reads top-down, so the panel is the reverse of the model
          // and `_modelIndex` is the single place that conversion lives.
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: layers.length,
            // An explicit grip instead of the default whole-row drag listener.
            // On a touch platform the default wraps each row in a DELAYED drag
            // listener, and the row already spends its long press on rename - so
            // the two raced in the same gesture arena, rename won, and dragging a
            // layer was simply impossible on a device. A grip also says the rows
            // are draggable, which a long-press cannot.
            buildDefaultDragHandles: false,
            // `onReorderItem` (not the deprecated `onReorder`) already accounts
            // for the dragged item having been removed, which is exactly what
            // `reorderLayer`'s remove-then-insert expects - so both indices need
            // only the display->model flip.
            onReorderItem: (oldIndex, newIndex) => _controller.reorderLayer(
              _modelIndex(oldIndex, layers.length),
              _modelIndex(newIndex, layers.length),
            ),
            itemBuilder: (context, i) {
              final layer = layers[_modelIndex(i, layers.length)];
              return _LayerRow(
                dragIndex: i,
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
    ], _l10n.mergedTwoLayers);
  }

  /// Bakes each group of stacked layers into one photo. A collage flattens per
  /// cell, so the grid itself survives (see [LayerFlattener.flattenGroups]).
  Future<void> _flattenLayers() async {
    final groups = LayerFlattener.flattenGroups(
      ref.read(editorControllerProvider).currentFrame,
    );
    if (groups.isEmpty) return;
    final count = groups.fold<int>(0, (n, g) => n + g.length);
    await _merge(groups, _l10n.flattenedLayers(count));
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
            name: LayerFlattener.mergedName(
              group,
              mergedLabel: _l10n.mergedLayerName,
              mergedSuffix: _l10n.mergedLayerSuffix,
            ),
          ),
        );
      }
      if (!mounted) return;
      _controller.applyMerges(specs);
      _toast(doneMessage);
    } catch (_) {
      if (mounted) _toast(_l10n.mergeFailed, ok: false);
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
        photoLabel: _l10n.photoLayerDefault,
      );
    } catch (_) {
      if (mounted) _toast(_l10n.importPhotoFailed, ok: false);
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
          photoLabel: _l10n.photoLayerDefault,
        );
        return;
      }
      // Importing a photo NEVER resizes the canvas - a blank project keeps the
      // size the user chose. (To start with the canvas sized to a photo, use
      // "Open a photo" on Home.) The first photo is placed scaled to FIT.
      final wasEmpty = ref.read(editorControllerProvider).layers.isEmpty;
      final pixels = wasEmpty ? await _decodeImageSize(path) : null;
      final layer = _controller.addImageLayer(
        assetPath: path,
        photoLabel: _l10n.photoLayerDefault,
      );
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
      if (mounted) _toast(_l10n.importPhotoFailed, ok: false);
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
        if (mounted) _toast(_l10n.noImageInClipboard, ok: false);
        return;
      }
      _controller.addImageLayer(
        assetPath: path,
        photoLabel: _l10n.photoLayerDefault,
      );
      _controller.setTool(EditorTool.adjust);
    } catch (_) {
      if (mounted) _toast(_l10n.pasteFailed, ok: false);
    }
  }

  /// Bottom sheet to add a layer: a photo (camera / gallery) or text.
  Future<void> _showAddMenu() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      // So the sheet may use the height it needs; SheetBody caps and scrolls it.
      isScrollControlled: true,
      backgroundColor: context.colors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SheetBody(
        // No side padding: these tiles are meant to run edge to edge.
        padding: const EdgeInsets.fromLTRB(0, 14, 0, 8),
        children: [
          _sheetTile(
            ctx,
            Icons.photo_camera_outlined,
            _l10n.takePhoto,
            'camera',
          ),
          _sheetTile(
            ctx,
            Icons.photo_library_outlined,
            _l10n.choosePhoto,
            'gallery',
          ),
          _sheetTile(ctx, Icons.content_paste, _l10n.pasteImage, 'paste'),
          _sheetTile(ctx, Icons.title, _l10n.addText, 'text'),
          _sheetTile(ctx, Icons.chat_bubble_outline, _l10n.addBubble, 'bubble'),
        ],
      ),
    );
    // "Add bubble" answers with a second sheet, so the editor has to still be
    // on screen before another route is pushed onto it.
    if (!mounted) return;
    switch (choice) {
      case 'camera':
        await _pickPhoto(ImageSource.camera);
      case 'gallery':
        await _pickPhoto(ImageSource.gallery);
      case 'paste':
        await _pastePhoto();
      case 'text':
        _controller.addTextLayer(text: _l10n.textLayerDefault);
      case 'bubble':
        await _addBubble();
    }
  }

  Widget _sheetTile(
    BuildContext ctx,
    IconData icon,
    String label,
    String value,
  ) {
    return ListTile(
      leading: Icon(icon, color: context.colors.textSecondary),
      title: Text(
        label,
        style: TextStyle(
          fontFamily: AppFonts.ui,
          color: context.colors.textPrimary,
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
        backgroundColor: context.colors.panel,
        title: Text(
          _l10n.renameLayer,
          style: TextStyle(
            fontFamily: AppFonts.display,
            color: context.colors.textPrimary,
          ),
        ),
        // TextFormField owns and disposes its own controller.
        content: TextFormField(
          initialValue: layer.name,
          autofocus: true,
          style: TextStyle(color: context.colors.textPrimary),
          onChanged: (v) => value = v,
          onFieldSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, value.trim()),
            child: Text(_l10n.rename),
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
      title: _l10n.renameProject,
      initial: ref.read(editorControllerProvider).project.name,
      hint: _l10n.projectNameHint,
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
      title: _l10n.canvasSize,
      initialWidth: project.canvasWidth,
      initialHeight: project.canvasHeight,
      allowScaleContent: true,
      confirmLabel: _l10n.apply,
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
    _toast(_l10n.croppedTo(rect.width.round(), rect.height.round()));
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
      // So the sheet may use the height it needs; SheetBody caps and scrolls it.
      isScrollControlled: true,
      backgroundColor: context.colors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SheetBody(
        children: [
          Text(
            _l10n.cropToRatio,
            style: TextStyle(
              fontFamily: AppFonts.display,
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            _l10n.cropSheetHint,
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontSize: 11.5,
              color: context.colors.textSecondary,
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
                color: context.colors.cyan.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.colors.cyan),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.crop, size: 18, color: context.colors.cyan),
                  const SizedBox(width: 8),
                  Text(
                    _l10n.freeformCrop,
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: context.colors.cyan,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _l10n.ratiosSection,
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: context.colors.textMuted,
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
                      color: context.colors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.colors.borderFaint),
                    ),
                    child: Text(
                      r.$1,
                      style: TextStyle(
                        fontFamily: AppFonts.ui,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
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
    _toast(_l10n.croppedTo(nw, nh));
  }

  Widget _segTab(String label, bool active, Color accent, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? accent.withValues(alpha: 0.18)
              : context.colors.inputField,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(
          label,
          // Bounded by Expanded - two tabs split one row - so it has to
          // ellipsize. "Supprimer l'objet" and "Wiederherstellen" fit at
          // normal size, but nothing here caps growth: at a 2x text scale
          // an uncapped Text paints an overflow stripe instead.
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: active ? accent : context.colors.textMuted,
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

    // The bubble editor is a mode of the Text tool, so the dock says so with a
    // pink badge on Bubble rather than by stealing Text's highlight: Bubble is
    // an action (it adds one), and painting it cyan would promise a mode whose
    // next tap adds a second bubble. Text keeps its own highlight, so the
    // landscape fold-on-retap still matches what is lit.
    final onBubble =
        editor.tool == EditorTool.text && editor.selectedLayer is BubbleLayer;

    return [
      // Go Pro sits first, and only for people who haven't bought it. It is the
      // one dock entry that opens a sheet instead of selecting a tool, so it
      // carries the gold accent to say so before it is tapped.
      if (!ref.watch(isProProvider))
        _DockItem(
          icon: Icons.workspace_premium,
          glyph: CrownIcon(color: context.colors.gold, size: 21),
          label: _l10n.goPro,
          accent: context.colors.gold,
          onTap: _showGoProSheet,
        ),
      // Collage-only, and first: layout / count / border are what a photo grid
      // is edited through.
      if (editor.project.isGrid)
        _DockItem(
          icon: Icons.grid_view,
          label: _l10n.toolGrid,
          active: editor.tool == EditorTool.grid,
          onTap: () => tool(EditorTool.grid),
        ),
      _DockItem(
        icon: Icons.add_photo_alternate_outlined,
        label: _l10n.addLayer,
        onTap: () => _pickPhoto(ImageSource.gallery),
      ),
      _DockItem(
        icon: Icons.text_fields,
        label: _l10n.toolText,
        active: editor.tool == EditorTool.text,
        onTap: () => tool(EditorTool.text),
      ),
      _DockItem(
        icon: Icons.chat_bubble_outline,
        label: _l10n.bubble,
        accent: onBubble ? context.colors.pink : null,
        onTap: _addBubble,
      ),
      _DockItem(
        icon: Icons.auto_awesome,
        label: _l10n.aiCut,
        onTap: _showBgSheet,
      ),
      _DockItem(
        icon: Icons.brush_outlined,
        label: _l10n.erase,
        active: editor.tool == EditorTool.erase,
        onTap: () => tool(EditorTool.erase),
      ),
      _DockItem(icon: Icons.crop, label: _l10n.crop, onTap: _showCropSheet),
      _DockItem(
        icon: Icons.tune,
        label: _l10n.toolAdjust,
        active: editor.tool == EditorTool.adjust,
        onTap: () => tool(EditorTool.adjust),
      ),
      _DockItem(
        icon: Icons.auto_fix_high,
        label: _l10n.toolEffects,
        active: editor.tool == EditorTool.effects,
        onTap: () => tool(EditorTool.effects),
      ),
      _DockItem(
        icon: Icons.layers_outlined,
        label: _l10n.toolLayers,
        active: editor.tool == EditorTool.layers,
        onTap: () => tool(EditorTool.layers),
      ),
    ];
  }

  /// What Go Pro gets you, from the dock's crown. Deliberately a sheet rather
  /// than a jump straight to the purchase screen: this button sits in the middle
  /// of the tool row, so tapping it must never feel like it took you somewhere.
  Future<void> _showGoProSheet() async {
    final benefits = <(IconData, String, String)>[
      (Icons.block, _l10n.proBenefitNoAdsTitle, _l10n.proBenefitNoAdsBody),
      (Icons.auto_fix_high, _l10n.proBenefitAiTitle, _l10n.proBenefitAiBody),
      (
        Icons.ios_share,
        _l10n.proBenefitExportTitle,
        _l10n.proBenefitExportBody,
      ),
      (
        Icons.lock_outline,
        _l10n.proBenefitLocalTitle,
        _l10n.proBenefitLocalBody,
      ),
    ];

    final go = await showModalBottomSheet<bool>(
      context: context,
      // So the sheet may use the height it needs; SheetBody caps and scrolls it.
      isScrollControlled: true,
      backgroundColor: context.colors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SheetBody(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: context.colors.gold.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: context.colors.gold.withValues(alpha: 0.55),
                  ),
                ),
                child: Center(
                  child: CrownIcon(color: context.colors.gold, size: 25),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _l10n.goPro,
                      style: TextStyle(
                        fontFamily: AppFonts.display,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    Text(
                      _l10n.oneTimeNoSubscriptionShort,
                      style: TextStyle(
                        fontFamily: AppFonts.ui,
                        fontSize: 12.5,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          for (final (icon, title, body) in benefits)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 18, color: context.colors.gold),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontFamily: AppFonts.ui,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        Text(
                          body,
                          style: TextStyle(
                            fontFamily: AppFonts.ui,
                            fontSize: 12.5,
                            height: 1.45,
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          FilledButton.icon(
            key: const ValueKey('go-pro-sheet-cta'),
            onPressed: () => Navigator.of(sheetCtx).pop(true),
            icon: CrownIcon(color: context.colors.onAccent, size: 19),
            label: Text(_l10n.seeThePrice),
            style: FilledButton.styleFrom(
              backgroundColor: context.colors.gold,
              foregroundColor: context.colors.onAccent,
              minimumSize: const Size.fromHeight(50),
              textStyle: const TextStyle(
                fontFamily: AppFonts.display,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => Navigator.of(sheetCtx).pop(false),
            child: Text(
              _l10n.notNow,
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontWeight: FontWeight.w700,
                color: context.colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
    if (go == true && mounted) unawaited(context.pushNamed(Routes.goPro));
  }

  Widget _toolBar(EditorState editor) {
    return Container(
      color: context.colors.background,
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
      color: context.colors.background,
      child: Column(
        children: [
          if (!_sidePanelOpen)
            IconButton(
              key: const ValueKey('expand-panel'),
              tooltip: _l10n.showToolPanel,
              iconSize: 18,
              onPressed: () => setState(() => _sidePanelOpen = true),
              icon: Icon(
                Icons.keyboard_double_arrow_right,
                color: context.colors.textMuted,
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
    this.accent,
    this.glyph,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  /// Tints the button when it isn't a tool. Only Go Pro uses this: it sits in
  /// the same row but doesn't select anything, so it needs to look unlike the
  /// tools rather than like an eleventh one.
  final Color? accent;

  /// Drawn instead of [icon] when set. Go Pro wants a crown and Material has
  /// none, so it supplies one (see [CrownIcon]); [icon] stays as the semantic
  /// fallback everything else uses.
  final Widget? glyph;
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
                    ? context.colors.cyan
                    : item.accent?.withValues(alpha: 0.16) ??
                          context.colors.borderFaint,
                borderRadius: BorderRadius.circular(14),
                border: item.accent == null
                    ? null
                    : Border.all(color: item.accent!.withValues(alpha: 0.55)),
              ),
              child:
                  item.glyph ??
                  Icon(
                    item.icon,
                    size: 20,
                    color: item.active
                        ? context.colors.onAccent
                        : item.accent ?? context.colors.textSecondary,
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
                    ? context.colors.textPrimary
                    : item.accent ?? context.colors.textMuted,
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
    required this.dragIndex,
    required this.onSelect,
    required this.onRename,
    required this.onToggleVisibility,
    required this.onDuplicate,
    required this.onDelete,
  });

  final Layer layer;
  final bool selected;

  /// This row's position in the PANEL (top-most first), which is what
  /// [ReorderableDragStartListener] expects - not the layer's paint index.
  final int dragIndex;

  final VoidCallback onSelect;
  final VoidCallback onRename;
  final VoidCallback onToggleVisibility;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  /// A 38px preview of the photo (decoded small via [cacheWidth], never at
  /// full resolution), falling back to the generic icon when the file is
  /// missing. [cut] overlays a green tick for a cut-out layer.
  Widget _photoThumb(
    BuildContext context,
    String assetPath, {
    required bool cut,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            File(assetPath),
            fit: BoxFit.cover,
            cacheWidth: 114, // 38 logical px × 3 for high-dpi rows
            errorBuilder: (_, _, _) => Icon(
              Icons.image_outlined,
              size: 18,
              color: context.colors.textFaint,
            ),
          ),
          if (cut)
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: context.colors.green,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check,
                  size: 9,
                  color: context.colors.onAccent,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (Widget badge, String typeLabel) = switch (layer) {
      TextLayer() => (
        Text(
          'T',
          style: TextStyle(
            fontFamily: AppFonts.bangers,
            fontSize: 16,
            color: context.colors.onAccent,
          ),
        ),
        l10n.textLayer,
      ),
      BubbleLayer() => (
        Icon(
          Icons.chat_bubble_outline,
          size: 18,
          color: context.colors.onAccent,
        ),
        l10n.bubbleLayer,
      ),
      // A real thumbnail so multiple photos are tellable apart (#73), with a
      // small green tick when this layer has been cut out.
      ImageLayer(:final assetPath, :final maskPath) => (
        _photoThumb(context, assetPath, cut: maskPath != null),
        maskPath == null ? l10n.imageLayer : l10n.imageLayerCutOut,
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
                  ? context.colors.violet.withValues(alpha: 0.14)
                  : context.colors.cardAlt,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? context.colors.violet : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                // Reordering starts here and nowhere else. An IMMEDIATE listener,
                // not the delayed one the list would wrap the whole row in: the
                // row's long press is already rename, and the two cannot share an
                // arena.
                //
                // Semantics, NOT a Tooltip: a Tooltip brings its own long-press
                // recognizer, and putting one inside the drag listener meant a
                // press on the grip raced the drag and popped "Drag to reorder"
                // instead of picking the row up. A control whose entire job is to
                // be dragged must not spend its gestures on a label.
                Semantics(
                  label: l10n.dragToReorder(layer.name),
                  child: ReorderableDragStartListener(
                    index: dragIndex,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 9,
                      ),
                      child: Icon(
                        Icons.drag_indicator,
                        size: 20,
                        color: context.colors.textMuted.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: flatBadge ? context.colors.elevated : null,
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
                        style: TextStyle(
                          fontFamily: AppFonts.ui,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      Text(
                        typeLabel,
                        style: TextStyle(
                          fontFamily: AppFonts.ui,
                          fontSize: 10.5,
                          color: context.colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: layer.visible ? l10n.hideLayer : l10n.showLayer,
                  visualDensity: VisualDensity.compact,
                  onPressed: onToggleVisibility,
                  icon: Icon(
                    layer.visible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18,
                    color: layer.visible
                        ? context.colors.textSecondary
                        : context.colors.textFaint,
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: l10n.duplicateLayer,
                  onPressed: onDuplicate,
                  icon: Icon(
                    Icons.content_copy,
                    size: 16,
                    color: context.colors.textMuted,
                  ),
                ),
                IconButton(
                  tooltip: l10n.deleteLayer,
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: context.colors.textMuted,
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
          color: context.colors.green.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: context.colors.green.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check, size: 13, color: context.colors.greenLight),
            const SizedBox(width: 5),
            Text(
              AppLocalizations.of(context).cutOut,
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: context.colors.greenLight,
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
  const _RemovingOverlay({this.label});

  /// Null means the default "Removing background…", which cannot be a default
  /// argument here: it is localized, so it needs a context to resolve.
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: AppScrim.fill,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(context.colors.greenLight),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              label ?? AppLocalizations.of(context).removingBackground,
              style: const TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppScrim.ink,
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
          color: AppScrim.fillStrong,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppScrim.accent.withValues(alpha: 0.4)),
        ),
        child: Text(
          AppLocalizations.of(context).frameOf(current, total),
          style: const TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppScrim.accent,
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
            color: active ? context.colors.orange : context.colors.border,
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
                    color: AppScrim.fillStrong,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: active ? AppScrim.accent : AppScrim.inkMuted,
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

  /// Width the project title is guaranteed, so the bar degrades by shortening
  /// the Export label rather than by crushing the title.
  ///
  /// It also has to stay above the title row's own non-shrinkable content (a
  /// 5px gap plus the 13px rename pencil): at 360dp the fixed chrome used to
  /// leave the title 6.5dp, and those 18dp then overflowed by 12. Reserving
  /// here fixes that at the source, so the title row cannot be squeezed into
  /// overflowing whatever the width, language or text scale.
  static const double _minTitleWidth = 56;

  /// Below this the Export button is not worth drawing - it keeps its icon and
  /// as much of the label as fits.
  static const double _minExportWidth = 96;

  /// Narrower than this and the rename pencil is dropped: below roughly three
  /// characters of title it is decorating nothing.
  static const double _renameHintFrom = 40;

  /// Undo / redo / canvas-size keep a 48dp-tall target but give up width at
  /// 360dp, where four 48dp buttons are over half the screen. Same trade the
  /// colour swatches already make (see `a11y_test.dart`), and for the same
  /// reason: the alternative is a row that cannot hold its own content.
  ///
  /// `constraints:` alone does NOT do this - IconButton defaults to
  /// [MaterialTapTargetSize.padded], which pads the button back out to 48x48
  /// and silently swallows a narrower constraint. Hence shrinkWrap, and hence
  /// `top_bar_fit_test` asserting the RENDERED width instead of trusting that
  /// asking for 40 produced 40.
  static final ButtonStyle _secondaryIconStyle = IconButton.styleFrom(
    minimumSize: const Size(40, 48),
    padding: EdgeInsets.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 10, 12, 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Everything except the title is fixed width, so what the Export
          // button may take is simply what is left once the title has its
          // reserve. GradientButton ellipsizes into whatever it is given.
          const chrome = 48 + 3 * 40.0; // menu + the three secondary buttons
          final exportMax = math.max(
            _minExportWidth,
            constraints.maxWidth - chrome - _minTitleWidth,
          );
          return _row(context, exportMax);
        },
      ),
    );
  }

  Widget _row(BuildContext context, double exportMax) {
    return Row(
      children: [
        IconButton(
          tooltip: AppLocalizations.of(context).menu,
          onPressed: () => Scaffold.of(context).openDrawer(),
          icon: Icon(Icons.menu, size: 22, color: context.colors.textSecondary),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tap the title to rename the project (mirrors the pack
              // detail screen's tap-title-to-rename affordance).
              //
              // The pencil is the only thing in this row that cannot shrink,
              // so it is also the only thing that can make the row overflow.
              // It is dropped rather than clipped when the title area gets too
              // narrow to be worth decorating: the row then consists of one
              // ellipsizing Text and cannot overflow at any width, language or
              // text scale. Tap-to-rename still works - the GestureDetector is
              // on the row, not on the icon.
              LayoutBuilder(
                builder: (context, titleConstraints) => GestureDetector(
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
                          style: TextStyle(
                            fontFamily: AppFonts.display,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: context.colors.textPrimary,
                          ),
                        ),
                      ),
                      if (titleConstraints.maxWidth >= _renameHintFrom) ...[
                        const SizedBox(width: 5),
                        Icon(
                          Icons.edit_outlined,
                          size: 13,
                          color: context.colors.textMuted,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Text(
                // The count keeps its own plural message, so the two places
                // that say "N layers" cannot disagree; this one only adds
                // the suffix, and the translator owns the separator.
                AppLocalizations.of(context).layersAutoSaved(
                  AppLocalizations.of(context).layerCount(layerCount),
                ),
                // Two lines, not one and not unbounded. Uncapped, at a 2x
                // text scale this wrapped into eight lines and made the top
                // bar taller than the screen. Capped at ONE it fitted the
                // English but truncated every translation at normal size -
                // "0 Ebenen · auto-gespeic…" - because this column is only as
                // wide as the title reserve. Two lines holds the longest
                // translation at 1x and still bounds the growth at 2x.
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppFonts.ui,
                  fontSize: 10.5,
                  color: context.colors.textMuted,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onCanvasSize,
          tooltip: AppLocalizations.of(context).canvasSize,
          style: _secondaryIconStyle,
          icon: Icon(
            Icons.aspect_ratio,
            size: 20,
            color: context.colors.textMuted,
          ),
        ),
        IconButton(
          tooltip: AppLocalizations.of(context).undo,
          onPressed: canUndo ? onUndo : null,
          style: _secondaryIconStyle,
          color: context.colors.textMuted,
          disabledColor: context.colors.textFaint,
          icon: const Icon(Icons.undo, size: 20),
        ),
        IconButton(
          tooltip: AppLocalizations.of(context).redo,
          onPressed: canRedo ? onRedo : null,
          style: _secondaryIconStyle,
          color: context.colors.textMuted,
          disabledColor: context.colors.textFaint,
          icon: const Icon(Icons.redo, size: 20),
        ),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: exportMax),
          child: GradientButton(
            label: AppLocalizations.of(context).export,
            icon: Icons.ios_share,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            fontSize: 13,
            onPressed: onExport,
          ),
        ),
      ],
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
      // Sits in a bounded slot beside the panel title, so it shortens rather
      // than pushing the header wider than the panel.
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: AppFonts.ui,
        fontSize: 11,
        color: context.colors.textMuted,
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
