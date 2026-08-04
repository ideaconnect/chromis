import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sheet_body.dart';
import '../../../l10n/app_localizations.dart';

/// What the user is starting: a plain canvas, or a Photo Grid (collage).
enum NewProjectMode { blank, grid }

/// Step 1 of "New project": which kind of document. Returns null if dismissed.
Future<NewProjectMode?> showNewProjectModeSheet(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showModalBottomSheet<NewProjectMode>(
    context: context,
    // So the sheet may use the height it needs; SheetBody caps and scrolls it.
    isScrollControlled: true,
    backgroundColor: context.colors.panel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SheetBody(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      children: [
        Text(
          l10n.newProjectQuestion,
          style: TextStyle(
            fontFamily: AppFonts.display,
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: context.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        _ModeCard(
          mode: NewProjectMode.blank,
          icon: Icons.crop_original,
          title: l10n.blankCanvas,
          subtitle: l10n.blankCanvasSubtitle,
          onTap: () => Navigator.of(ctx).pop(NewProjectMode.blank),
        ),
        const SizedBox(height: 10),
        _ModeCard(
          mode: NewProjectMode.grid,
          icon: Icons.grid_view,
          title: l10n.photoGrid,
          subtitle: l10n.photoGridSubtitle,
          onTap: () => Navigator.of(ctx).pop(NewProjectMode.grid),
        ),
      ],
    ),
  );
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.mode,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final NewProjectMode mode;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: GestureDetector(
        key: ValueKey('new-project-${mode.name}'),
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.colors.borderFaint),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: context.colors.cyan.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: context.colors.cyan),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: AppFonts.display,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: AppFonts.ui,
                        fontSize: 11.5,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: context.colors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
