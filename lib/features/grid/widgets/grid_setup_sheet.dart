import 'package:flutter/material.dart';

import '../../../core/models/grid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sheet_body.dart';
import '../../editor/widgets/canvas_size_sheet.dart';
import '../grid_templates.dart';
import 'grid_template_strip.dart';

/// Canvas size plus the grid the new collage starts on.
typedef GridSetupResult = ({int width, int height, GridSpec grid});

/// Aspect presets a collage is usually shot for. Reuses [CanvasPreset] so the
/// blank-canvas and Photo Grid flows offer the same sizes.
const _aspects = <CanvasPreset>[
  CanvasPreset('Square', 1080, 1080),
  CanvasPreset('Portrait', 1080, 1350),
  CanvasPreset('Story', 1080, 1920),
  CanvasPreset('Landscape', 1920, 1080),
];

/// Step 2 of the Photo Grid flow: how many photos, which layout, what size.
/// Returns null if dismissed.
Future<GridSetupResult?> showGridSetupSheet(BuildContext context) {
  return showModalBottomSheet<GridSetupResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.panel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _GridSetupSheet(),
  );
}

class _GridSetupSheet extends StatefulWidget {
  const _GridSetupSheet();

  @override
  State<_GridSetupSheet> createState() => _GridSetupSheetState();
}

class _GridSetupSheetState extends State<_GridSetupSheet> {
  int _count = 2;
  int _template = 0;
  CanvasPreset _aspect = _aspects.first;

  List<GridTemplate> get _templates => gridTemplatesFor(_count);

  void _setCount(int count) {
    setState(() {
      _count = count;
      // Layouts are per count, so the old index means nothing at the new one.
      _template = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SheetBody(
      children: [
        const Text(
          'Photo grid',
          style: TextStyle(
            fontFamily: AppFonts.display,
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        const _SectionLabel('HOW MANY PHOTOS?'),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var n = kMinGridPhotos; n <= kMaxGridPhotos; n++) ...[
              Expanded(
                child: _CountChip(
                  count: n,
                  selected: n == _count,
                  onTap: () => _setCount(n),
                ),
              ),
              if (n < kMaxGridPhotos) const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 18),
        const _SectionLabel('LAYOUT'),
        const SizedBox(height: 8),
        GridTemplateStrip(
          templates: _templates,
          selectedIndex: _template,
          aspect: _aspect.width / _aspect.height,
          onSelected: (i) => setState(() => _template = i),
        ),
        const SizedBox(height: 16),
        const _SectionLabel('SIZE'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in _aspects)
              _AspectChip(
                preset: preset,
                selected: preset.label == _aspect.label,
                onTap: () => setState(() => _aspect = preset),
              ),
          ],
        ),
        const SizedBox(height: 18),
        FilledButton(
          key: const ValueKey('grid-setup-create'),
          onPressed: () => Navigator.of(context).pop((
            width: _aspect.width,
            height: _aspect.height,
            grid: GridSpec(root: _templates[_template].root),
          )),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.cyan,
            foregroundColor: AppColors.cutoutInk,
            minimumSize: const Size.fromHeight(50),
          ),
          child: const Text(
            'Create',
            style: TextStyle(
              fontFamily: AppFonts.display,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Pick your photos next - you can change the layout, count and '
          'border any time.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 11,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

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

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$count photos',
      child: GestureDetector(
        key: ValueKey('grid-count-$count'),
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.cyan.withValues(alpha: 0.16)
                : AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.cyan : AppColors.borderFaint,
            ),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontFamily: AppFonts.display,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _AspectChip extends StatelessWidget {
  const _AspectChip({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final CanvasPreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('grid-aspect-${preset.label}'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.cyan.withValues(alpha: 0.16)
              : AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.cyan : AppColors.borderFaint,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              preset.label,
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              preset.sub,
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
}
