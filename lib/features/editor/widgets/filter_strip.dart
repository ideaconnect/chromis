import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/models/photo_filter.dart';
import '../../../core/rendering/color_matrix.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/localized_labels.dart';

/// The horizontal filter picker: the layer's own photo, thumbnailed once and
/// re-tinted per tile, so what you tap is what you get.
///
/// Every tile shares one small decode (`cacheWidth: _decodePx`) - the filters
/// differ only by a [ColorFilter], which costs nothing - so scrolling fifteen
/// previews does not decode fifteen bitmaps.
class FilterStrip extends StatelessWidget {
  const FilterStrip({
    super.key,
    required this.assetPath,
    required this.selected,
    required this.onPick,
  });

  /// The photo to preview. A missing file falls back to a colour swatch, so the
  /// strip still communicates each look.
  final String assetPath;
  final PhotoFilter selected;
  final ValueChanged<PhotoFilter> onPick;

  static const double _tile = 56;
  static const int _decodePx = 140;

  @override
  Widget build(BuildContext context) {
    final exists = File(assetPath).existsSync();
    return SizedBox(
      height: _tile + 20,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: PhotoFilter.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final filter = PhotoFilter.values[i];
          return _FilterTile(
            key: ValueKey('filter-${filter.name}'),
            filter: filter,
            selected: filter == selected,
            assetPath: exists ? assetPath : null,
            onTap: () => onPick(filter),
          );
        },
      ),
    );
  }
}

class _FilterTile extends StatelessWidget {
  const _FilterTile({
    super.key,
    required this.filter,
    required this.selected,
    required this.assetPath,
    required this.onTap,
  });

  final PhotoFilter filter;
  final bool selected;
  final String? assetPath;
  final VoidCallback onTap;

  /// Stand-in when the photo cannot be read: a neutral ramp that still shows
  /// what each look does to colour.
  static const _swatch = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6FA8DC), Color(0xFFE8C07A), Color(0xFF2B2B33)],
  );

  @override
  Widget build(BuildContext context) {
    final path = assetPath;
    Widget preview = path == null
        ? const DecoratedBox(decoration: BoxDecoration(gradient: _swatch))
        : Image.file(
            File(path),
            width: FilterStrip._tile,
            height: FilterStrip._tile,
            fit: BoxFit.cover,
            cacheWidth: FilterStrip._decodePx,
            errorBuilder: (_, _, _) => const DecoratedBox(
              decoration: BoxDecoration(gradient: _swatch),
            ),
          );
    if (filter != PhotoFilter.none) {
      preview = ColorFiltered(
        colorFilter: ColorFilter.matrix(ColorMatrix.filter(filter)),
        child: preview,
      );
    }
    return Semantics(
      button: true,
      selected: selected,
      label: filter.labelOf(AppLocalizations.of(context)),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: FilterStrip._tile,
              height: FilterStrip._tile,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? context.colors.teal : context.colors.border,
                  width: selected ? 2 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: SizedBox.expand(child: preview),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              filter.labelOf(AppLocalizations.of(context)),
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: selected
                    ? context.colors.teal
                    : context.colors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
