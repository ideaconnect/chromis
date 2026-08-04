import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/localized_labels.dart';
import '../grid_templates.dart';
import 'grid_template_preview.dart';

/// The horizontal scroller of Photo Grid layouts.
///
/// One widget for both entry points - the create sheet and the editor's Grid
/// panel - so the two can never drift apart. It is deliberately state-free:
/// callers pass the templates, which one is selected, and a callback.
class GridTemplateStrip extends StatelessWidget {
  const GridTemplateStrip({
    super.key,
    required this.templates,
    required this.selectedIndex,
    required this.onSelected,
    this.aspect = 1,
    this.tileHeight = 62,
  });

  final List<GridTemplate> templates;

  /// Index into [templates], or -1 when the current layout matches none.
  final int selectedIndex;

  final ValueChanged<int> onSelected;

  /// Canvas aspect (width / height), so a Story-format collage previews tall.
  final double aspect;

  final double tileHeight;

  /// Tile width for the canvas aspect, kept in a range that stays tappable and
  /// does not blow out the strip on extreme canvases.
  double get _tileWidth => (tileHeight * aspect).clamp(40.0, 104.0);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: tileHeight + 22,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: templates.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) => _TemplateTile(
          template: templates[i],
          selected: i == selectedIndex,
          width: _tileWidth,
          height: tileHeight,
          onTap: () => onSelected(i),
        ),
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({
    required this.template,
    required this.selected,
    required this.width,
    required this.height,
    required this.onTap,
  });

  final GridTemplate template;
  final bool selected;
  final double width;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: AppLocalizations.of(
        context,
      ).gridLayoutNamed(template.labelOf(AppLocalizations.of(context))),
      child: GestureDetector(
        key: ValueKey('grid-template-${template.label}'),
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: width,
              height: height,
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: selected
                    ? context.colors.cyan.withValues(alpha: 0.14)
                    : context.colors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? context.colors.cyan
                      : context.colors.borderFaint,
                ),
              ),
              child: GridTemplatePreview(
                root: template.root,
                color: selected
                    ? context.colors.cyan
                    : context.colors.textFaint,
              ),
            ),
            const SizedBox(height: 5),
            SizedBox(
              width: width + 12,
              child: Text(
                template.labelOf(AppLocalizations.of(context)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.ui,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? context.colors.textPrimary
                      : context.colors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
