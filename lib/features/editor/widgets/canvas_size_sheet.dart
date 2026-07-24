import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/models/project.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// A canvas dimension preset offered in the size sheet.
class CanvasPreset {
  const CanvasPreset(this.label, this.width, this.height);
  final String label;
  final int width;
  final int height;

  String get sub => width == height ? '$width²' : '$width × $height';
}

const _presets = <CanvasPreset>[
  CanvasPreset('Square', 1080, 1080),
  CanvasPreset('Portrait', 1080, 1350),
  CanvasPreset('Story', 1080, 1920),
  CanvasPreset('Landscape', 1920, 1080),
  CanvasPreset('Wide', 1620, 1080),
  CanvasPreset('Small', 512, 512),
];

/// The chosen size, plus whether existing layers should be resampled to fit.
typedef CanvasSizeResult = ({int width, int height, bool scaleContent});

/// Bottom sheet for choosing a canvas size - used both for a new project
/// (presets + custom) and for resizing an existing canvas ([allowScaleContent]
/// adds the "Scale layers to fit" resample toggle). Returns null if dismissed.
Future<CanvasSizeResult?> showCanvasSizeSheet(
  BuildContext context, {
  required String title,
  int? initialWidth,
  int? initialHeight,
  bool allowScaleContent = false,
  String confirmLabel = 'Create',
}) {
  return showModalBottomSheet<CanvasSizeResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.panel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _CanvasSizeSheet(
      title: title,
      initialWidth: initialWidth,
      initialHeight: initialHeight,
      allowScaleContent: allowScaleContent,
      confirmLabel: confirmLabel,
    ),
  );
}

class _CanvasSizeSheet extends StatefulWidget {
  const _CanvasSizeSheet({
    required this.title,
    required this.initialWidth,
    required this.initialHeight,
    required this.allowScaleContent,
    required this.confirmLabel,
  });

  final String title;
  final int? initialWidth;
  final int? initialHeight;
  final bool allowScaleContent;
  final String confirmLabel;

  @override
  State<_CanvasSizeSheet> createState() => _CanvasSizeSheetState();
}

class _CanvasSizeSheetState extends State<_CanvasSizeSheet> {
  late final TextEditingController _w;
  late final TextEditingController _h;
  bool _scale = false;

  @override
  void initState() {
    super.initState();
    _w = TextEditingController(
      text: (widget.initialWidth ?? _presets.first.width).toString(),
    );
    _h = TextEditingController(
      text: (widget.initialHeight ?? _presets.first.height).toString(),
    );
    _w.addListener(_onChanged);
    _h.addListener(_onChanged);
  }

  @override
  void dispose() {
    _w.dispose();
    _h.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  int get _wv => int.tryParse(_w.text) ?? 0;
  int get _hv => int.tryParse(_h.text) ?? 0;

  bool get _valid =>
      _wv >= Project.minCanvasDimension &&
      _wv <= Project.maxCanvasDimension &&
      _hv >= Project.minCanvasDimension &&
      _hv <= Project.maxCanvasDimension;

  void _pick(CanvasPreset p) {
    _w.text = p.width.toString();
    _h.text = p.height.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: 20 + MediaQuery.viewInsetsOf(context).bottom,
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
          Text(
            widget.title,
            style: const TextStyle(
              fontFamily: AppFonts.display,
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final p in _presets) _presetChip(p)],
          ),
          const SizedBox(height: 18),
          const Text(
            'CUSTOM (PIXELS)',
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _numField(_w, 'Width')),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('×', style: TextStyle(color: AppColors.textMuted)),
              ),
              Expanded(child: _numField(_h, 'Height')),
            ],
          ),
          if (widget.allowScaleContent) ...[
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _scale,
              activeThumbColor: AppColors.cyan,
              onChanged: (v) => setState(() => _scale = v),
              title: const Text(
                'Scale layers to fit',
                style: TextStyle(
                  fontFamily: AppFonts.ui,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: const Text(
                'Resample the whole composition to the new size',
                style: TextStyle(
                  fontFamily: AppFonts.ui,
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _valid
                ? () => Navigator.of(
                    context,
                  ).pop((width: _wv, height: _hv, scaleContent: _scale))
                : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.cyan,
              foregroundColor: AppColors.cutoutInk,
              disabledBackgroundColor: AppColors.elevated,
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
      ),
    );
  }

  Widget _presetChip(CanvasPreset p) {
    final active = p.width == _wv && p.height == _hv;
    return GestureDetector(
      onTap: () => _pick(p),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: active
              ? AppColors.cyan.withValues(alpha: 0.16)
              : AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? AppColors.cyan : AppColors.borderFaint,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              p.label,
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: active ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              p.sub,
              style: const TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 10,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _numField(TextEditingController c, String label) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(
        fontFamily: AppFonts.ui,
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        filled: true,
        fillColor: AppColors.inputField,
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
