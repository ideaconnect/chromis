import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sheet_body.dart';
import '../../../l10n/app_localizations.dart';
import '../../segmentation/fill_quality.dart';

/// Asked the first time a Fill is about to run (#68): which of the two ways to
/// rebuild the background, with the one this phone's memory suggests already
/// selected and marked.
///
/// Asked rather than decided because the two are a real trade - detail on a
/// large object against 460 MB of memory and several seconds - and the right
/// answer depends on the phone and on what the user is removing. Asked once:
/// the answer is persisted, and the Remove-object panel shows it and changes
/// it from then on.
class FillQualitySheet extends StatefulWidget {
  const FillQualitySheet({super.key, required this.recommended});

  /// Preselected, and the one carrying the "recommended" badge.
  final FillQuality recommended;

  /// Shows the sheet. Resolves to the chosen quality, or null when it was
  /// dismissed - which the caller treats as "not now", not as a choice.
  static Future<FillQuality?> show(
    BuildContext context, {
    required FillQuality recommended,
  }) => showModalBottomSheet<FillQuality>(
    context: context,
    // So the sheet may use the height it needs; SheetBody caps and scrolls it.
    isScrollControlled: true,
    backgroundColor: context.colors.panel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => FillQualitySheet(recommended: recommended),
  );

  @override
  State<FillQualitySheet> createState() => _FillQualitySheetState();
}

class _FillQualitySheetState extends State<FillQualitySheet> {
  late FillQuality _selected = widget.recommended;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SheetBody(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
      children: [
        const SizedBox(height: 4),
        Icon(Icons.auto_fix_high, color: context.colors.cyan, size: 34),
        const SizedBox(height: 12),
        Text(
          l10n.fillQualityTitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.display,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: context.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.fillQualityMessage,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 13,
            height: 1.4,
            color: context.colors.textMuted,
          ),
        ),
        const SizedBox(height: 18),
        for (final q in FillQuality.values) ...[
          _option(
            q,
            title: q == FillQuality.best
                ? l10n.fillQualityBest
                : l10n.fillQualityLowMemory,
            detail: q == FillQuality.best
                ? l10n.fillQualityBestDetail
                : l10n.fillQualityLowMemoryDetail,
            recommended: q == widget.recommended
                ? l10n.fillQualityRecommended
                : null,
          ),
          if (q != FillQuality.values.last) const SizedBox(height: 10),
        ],
        const SizedBox(height: 22),
        FilledButton(
          key: const ValueKey('fill-quality-continue'),
          onPressed: () => Navigator.pop(context, _selected),
          style: FilledButton.styleFrom(
            backgroundColor: context.colors.cyan,
            foregroundColor: context.colors.onAccent,
            minimumSize: const Size.fromHeight(50),
            textStyle: const TextStyle(
              fontFamily: AppFonts.display,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          child: Text(l10n.fillQualityContinue),
        ),
      ],
    );
  }

  Widget _option(
    FillQuality quality, {
    required String title,
    required String detail,
    String? recommended,
  }) {
    final selected = quality == _selected;
    return Semantics(
      key: ValueKey('fill-quality-${quality.id}'),
      button: true,
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _selected = quality),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
          decoration: BoxDecoration(
            color: selected
                ? context.colors.cyan.withValues(alpha: 0.10)
                : context.colors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? context.colors.cyan.withValues(alpha: 0.6)
                  : context.colors.border,
              width: 1.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: _radio(selected),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: AppFonts.ui,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      detail,
                      style: TextStyle(
                        fontFamily: AppFonts.ui,
                        fontSize: 12,
                        height: 1.35,
                        color: context.colors.textMuted,
                      ),
                    ),
                    if (recommended != null) ...[
                      const SizedBox(height: 7),
                      _badge(recommended),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: context.colors.green.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(context.tokens.radiusChip),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontFamily: AppFonts.ui,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: context.colors.greenLight,
      ),
    ),
  );

  Widget _radio(bool selected) => Container(
    width: 20,
    height: 20,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: selected ? context.colors.cyan : Colors.transparent,
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
