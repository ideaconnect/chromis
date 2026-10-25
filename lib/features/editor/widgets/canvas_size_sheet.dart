import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/models/project.dart';
import '../../../core/rendering/resample.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/pill_chip.dart';
import '../../../core/widgets/sheet_body.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/localized_labels.dart';

/// A canvas dimension preset offered in the size sheet.
class CanvasPreset {
  const CanvasPreset(this.label, this.width, this.height);
  final String label;
  final int width;
  final int height;

  String get sub => _dimensions(width, height);
}

String _dimensions(int width, int height) =>
    width == height ? '$width²' : '$width × $height';

const _presets = <CanvasPreset>[
  CanvasPreset('Square', 1080, 1080),
  CanvasPreset('Portrait', 1080, 1350),
  CanvasPreset('Story', 1080, 1920),
  CanvasPreset('Landscape', 1920, 1080),
  CanvasPreset('Wide', 1620, 1080),
  CanvasPreset('Small', 512, 512),
];

/// The Image tab's shortcuts, as percentages of the current size.
const _scalePercents = <int>[25, 50, 75, 150, 200];

/// The chosen size, plus how to get there.
///
/// [resample] is set only by the Image tab: scale the whole picture to this
/// size, resampling its photos with that method. Null is a canvas resize, and
/// then [scaleContent] says whether the layers follow the canvas.
typedef CanvasSizeResult = ({
  int width,
  int height,
  bool scaleContent,
  ResampleMethod? resample,
});

/// Bottom sheet for choosing a canvas size - used both for a new project
/// (presets + custom) and for resizing an existing canvas ([allowScaleContent]
/// adds the "Scale layers to fit" resample toggle). Returns null if dismissed.
///
/// [allowImageResize] adds a second tab, Image, for scaling the whole picture
/// instead - the editor's case. It is a tab of THIS sheet rather than a sheet
/// of its own because both answer "how big is it", and people look for either
/// behind the same button.
Future<CanvasSizeResult?> showCanvasSizeSheet(
  BuildContext context, {
  required String title,
  int? initialWidth,
  int? initialHeight,
  bool allowScaleContent = false,
  bool allowImageResize = false,
  String? confirmLabel,
}) {
  return showModalBottomSheet<CanvasSizeResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.panel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _CanvasSizeSheet(
      title: title,
      initialWidth: initialWidth,
      initialHeight: initialHeight,
      allowScaleContent: allowScaleContent,
      allowImageResize: allowImageResize,
      confirmLabel: confirmLabel ?? AppLocalizations.of(context).create,
    ),
  );
}

enum _Mode { canvas, image }

class _CanvasSizeSheet extends StatefulWidget {
  const _CanvasSizeSheet({
    required this.title,
    required this.initialWidth,
    required this.initialHeight,
    required this.allowScaleContent,
    required this.allowImageResize,
    required this.confirmLabel,
  });

  final String title;
  final int? initialWidth;
  final int? initialHeight;
  final bool allowScaleContent;
  final bool allowImageResize;
  final String confirmLabel;

  @override
  State<_CanvasSizeSheet> createState() => _CanvasSizeSheetState();
}

class _CanvasSizeSheetState extends State<_CanvasSizeSheet> {
  late final TextEditingController _w;
  late final TextEditingController _h;
  bool _scale = false;

  _Mode _mode = _Mode.canvas;

  /// The Image tab's own fields. Separate from the canvas tab's, because the
  /// two mean different things - a canvas can take any shape, an image keeps
  /// its own - and switching tabs must not carry a half-typed size across.
  late final TextEditingController _iw;
  late final TextEditingController _ih;

  /// The size being resized FROM; the aspect the two fields are locked to.
  late final int _baseW;
  late final int _baseH;

  /// Set while one field is being written from the other, so that write does
  /// not bounce back. And the last text each field held, because a listener
  /// also fires on a cursor move - recomputing then could re-round a number
  /// the user typed in the other field.
  bool _linking = false;
  String _lastIw = '';
  String _lastIh = '';

  /// Remembered for the rest of the session: someone resizing pixel art wants
  /// nearest neighbour every time, not just the first.
  static ResampleMethod _lastMethod = ResampleMethod.bicubic;
  ResampleMethod _method = _lastMethod;

  @override
  void initState() {
    super.initState();
    _baseW = widget.initialWidth ?? _presets.first.width;
    _baseH = widget.initialHeight ?? _presets.first.height;
    _w = TextEditingController(text: '$_baseW');
    _h = TextEditingController(text: '$_baseH');
    _w.addListener(_onChanged);
    _h.addListener(_onChanged);
    _iw = TextEditingController(text: '$_baseW');
    _ih = TextEditingController(text: '$_baseH');
    _lastIw = _iw.text;
    _lastIh = _ih.text;
    _iw.addListener(_onImageWidth);
    _ih.addListener(_onImageHeight);
  }

  @override
  void dispose() {
    _w.dispose();
    _h.dispose();
    _iw.dispose();
    _ih.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  void _onImageWidth() {
    if (_linking || _iw.text == _lastIw) return;
    _lastIw = _iw.text;
    final w = int.tryParse(_iw.text);
    if (w != null && w > 0) _link(_ih, (w * _baseH / _baseW).round());
    setState(() {});
  }

  void _onImageHeight() {
    if (_linking || _ih.text == _lastIh) return;
    _lastIh = _ih.text;
    final h = int.tryParse(_ih.text);
    if (h != null && h > 0) _link(_iw, (h * _baseW / _baseH).round());
    setState(() {});
  }

  /// Writes [value] into the OTHER field of the pair.
  void _link(TextEditingController field, int value) {
    _linking = true;
    field.text = '$value';
    if (identical(field, _iw)) {
      _lastIw = field.text;
    } else {
      _lastIh = field.text;
    }
    _linking = false;
  }

  int get _wv => int.tryParse(_w.text) ?? 0;
  int get _hv => int.tryParse(_h.text) ?? 0;
  int get _iwv => int.tryParse(_iw.text) ?? 0;
  int get _ihv => int.tryParse(_ih.text) ?? 0;

  static bool _inBounds(int w, int h) =>
      w >= Project.minCanvasDimension &&
      w <= Project.maxCanvasDimension &&
      h >= Project.minCanvasDimension &&
      h <= Project.maxCanvasDimension;

  bool get _valid => switch (_mode) {
    _Mode.canvas => _inBounds(_wv, _hv),
    // The size it already is would change nothing but the photos' pixels,
    // which is not what anyone pressing Apply on an unchanged size asked for.
    _Mode.image => _inBounds(_iwv, _ihv) && (_iwv != _baseW || _ihv != _baseH),
  };

  void _pick(CanvasPreset p) {
    _w.text = p.width.toString();
    _h.text = p.height.toString();
  }

  /// [percent] of the size being resized from, or null when that falls
  /// outside the canvas bounds.
  ({int width, int height})? _scaled(int percent) {
    final w = (_baseW * percent / 100).round();
    final h = (_baseH * percent / 100).round();
    return _inBounds(w, h) ? (width: w, height: h) : null;
  }

  void _pickScaled(({int width, int height}) size) {
    _link(_iw, size.width);
    _link(_ih, size.height);
    setState(() {});
  }

  void _confirm() {
    final CanvasSizeResult result = switch (_mode) {
      _Mode.canvas => (
        width: _wv,
        height: _hv,
        scaleContent: _scale,
        resample: null,
      ),
      _Mode.image => (
        width: _iwv,
        height: _ihv,
        scaleContent: true,
        resample: _method,
      ),
    };
    if (_mode == _Mode.image) _lastMethod = _method;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SheetBody(
      children: [
        Text(
          _mode == _Mode.image ? l10n.imageSize : widget.title,
          style: TextStyle(
            fontFamily: AppFonts.display,
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: context.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        if (widget.allowImageResize) ...[
          Row(
            children: [
              Expanded(
                child: _modeTab(
                  _Mode.canvas,
                  l10n.sizeModeCanvas,
                  Icons.aspect_ratio,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _modeTab(
                  _Mode.image,
                  l10n.sizeModeImage,
                  Icons.photo_size_select_large,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
        ],
        ...switch (_mode) {
          _Mode.canvas => _canvasBody(l10n),
          _Mode.image => _imageBody(l10n),
        },
        const SizedBox(height: 14),
        FilledButton(
          key: const ValueKey('size-sheet-confirm'),
          onPressed: _valid ? _confirm : null,
          style: FilledButton.styleFrom(
            backgroundColor: context.colors.cyan,
            foregroundColor: context.colors.onAccent,
            disabledBackgroundColor: context.colors.elevated,
            minimumSize: const Size.fromHeight(50),
          ),
          child: Text(
            widget.confirmLabel,
            style: const TextStyle(
              fontFamily: AppFonts.display,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _canvasBody(AppLocalizations l10n) => [
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final p in _presets)
          _sizeChip(
            p.labelOf(l10n),
            p.sub,
            p.width == _wv && p.height == _hv,
            () => _pick(p),
          ),
      ],
    ),
    const SizedBox(height: 18),
    _sectionLabel(l10n.customPixels),
    const SizedBox(height: 8),
    Row(
      children: [
        Expanded(child: _numField(_w, l10n.width)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text('×', style: TextStyle(color: context.colors.textMuted)),
        ),
        Expanded(child: _numField(_h, l10n.height)),
      ],
    ),
    if (widget.allowScaleContent) ...[
      const SizedBox(height: 6),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: _scale,
        activeThumbColor: context.colors.cyan,
        onChanged: (v) => setState(() => _scale = v),
        title: Text(
          l10n.scaleLayersToFit,
          style: TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.colors.textPrimary,
          ),
        ),
        subtitle: Text(
          l10n.scaleLayersToFitSub,
          style: TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 11,
            color: context.colors.textMuted,
          ),
        ),
      ),
    ],
  ];

  List<Widget> _imageBody(AppLocalizations l10n) => [
    Text(
      l10n.imageSizeExplainer,
      style: TextStyle(
        fontFamily: AppFonts.ui,
        fontSize: 11.5,
        color: context.colors.textSecondary,
      ),
    ),
    const SizedBox(height: 14),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final percent in _scalePercents)
          if (_scaled(percent) case final size?)
            _sizeChip(
              '$percent%',
              _dimensions(size.width, size.height),
              size.width == _iwv && size.height == _ihv,
              () => _pickScaled(size),
            ),
      ],
    ),
    const SizedBox(height: 18),
    _sectionLabel(l10n.customPixels),
    const SizedBox(height: 8),
    Row(
      children: [
        Expanded(
          child: _numField(_iw, l10n.width, key: const ValueKey('image-width')),
        ),
        // A link, not a times sign: the two fields move together, and that
        // is the one thing about them that differs from the canvas tab's.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.link, size: 18, color: context.colors.textMuted),
        ),
        Expanded(
          child: _numField(
            _ih,
            l10n.height,
            key: const ValueKey('image-height'),
          ),
        ),
      ],
    ),
    const SizedBox(height: 18),
    _sectionLabel(l10n.resamplingSection),
    const SizedBox(height: 8),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final m in ResampleMethod.values)
          Semantics(
            selected: m == _method,
            child: PillChip(
              key: ValueKey('resample-${m.name}'),
              label: m.labelOf(l10n),
              selected: m == _method,
              accent: context.colors.cyan,
              onTap: () => setState(() => _method = m),
            ),
          ),
      ],
    ),
    const SizedBox(height: 8),
    Text(
      _method.descriptionOf(l10n),
      style: TextStyle(
        fontFamily: AppFonts.ui,
        fontSize: 11,
        color: context.colors.textMuted,
      ),
    ),
  ];

  Widget _modeTab(_Mode mode, String label, IconData icon) {
    final active = _mode == mode;
    final accent = context.colors.cyan;
    final fg = active ? accent : context.colors.textMuted;
    return Semantics(
      button: true,
      selected: active,
      child: GestureDetector(
        key: ValueKey('size-mode-${mode.name}'),
        onTap: () => setState(() => _mode = mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
          decoration: BoxDecoration(
            color: active
                ? accent.withValues(alpha: 0.18)
                : context.colors.inputField,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              // Half a row each, so the label has to be able to give.
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
    text,
    style: TextStyle(
      fontFamily: AppFonts.ui,
      fontSize: 10.5,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.4,
      color: context.colors.textMuted,
    ),
  );

  Widget _sizeChip(String title, String sub, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: active
              ? context.colors.cyan.withValues(alpha: 0.16)
              : context.colors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? context.colors.cyan : context.colors.borderFaint,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: active
                    ? context.colors.textPrimary
                    : context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              sub,
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 10,
                color: context.colors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _numField(TextEditingController c, String label, {Key? key}) {
    return TextField(
      key: key,
      controller: c,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: TextStyle(
        fontFamily: AppFonts.ui,
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: context.colors.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: context.colors.textMuted, fontSize: 12),
        filled: true,
        fillColor: context.colors.inputField,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
