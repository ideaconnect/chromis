import 'package:flutter/material.dart';

import '../../../core/models/project.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/checkerboard.dart';
import '../../../core/widgets/sheet_body.dart';
import '../../../l10n/app_localizations.dart';
import '../../editor/widgets/project_canvas.dart';

/// A saved-project card: live canvas preview, name + layer count. Tap to open;
/// long-press for a menu - Open / Rename / Duplicate / Delete. Shared by the
/// Home "Recent" grid and the "All projects" screen.
///
/// Delete confirmation is owner-handled via [onDelete] (see
/// `confirmAndDeleteProject`), so the dialog can warn about pack membership -
/// something this tile can't know.
class ProjectTile extends StatelessWidget {
  const ProjectTile({
    super.key,
    required this.project,
    required this.radius,
    required this.onTap,
    required this.onRename,
    required this.onDuplicate,
    required this.onDelete,
  });

  final Project project;
  final double radius;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDuplicate;

  /// Invoked when the user picks Delete; the owner confirms (with a pack-membership
  /// warning) and cascades via `confirmAndDeleteProject`.
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final layerCount = project.frames.isEmpty
        ? 0
        : project.frames.first.layers.length;
    final count = AppLocalizations.of(context).layerCount(layerCount);

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        onLongPress: () => _showMenu(context),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: context.colors.borderFaint),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(radius),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const Checkerboard(cell: 9),
                      if (project.frames.isNotEmpty)
                        ProjectCanvas(
                          frame: project.frames.first,
                          width: project.canvasWidth,
                          height: project.canvasHeight,
                          grid: project.grid,
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 9, 12, 11),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        project.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppFonts.ui,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      count,
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
      ),
    );
  }

  /// Long-press menu. Open mirrors a plain tap; Delete routes to the owner's
  /// confirm+cascade handler.
  Future<void> _showMenu(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
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
          _menuTile(ctx, Icons.open_in_full, l10n.open, 'open'),
          _menuTile(
            ctx,
            Icons.drive_file_rename_outline,
            l10n.rename,
            'rename',
          ),
          _menuTile(ctx, Icons.content_copy, l10n.duplicate, 'duplicate'),
          _menuTile(ctx, Icons.delete_outline, l10n.delete, 'delete'),
        ],
      ),
    );
    switch (choice) {
      case 'open':
        onTap();
      case 'rename':
        onRename();
      case 'duplicate':
        onDuplicate();
      case 'delete':
        // The owner's handler shows the confirm dialog (with a pack-membership
        // warning) and cascades - this tile must not confirm on its own.
        onDelete();
    }
  }

  Widget _menuTile(
    BuildContext ctx,
    IconData icon,
    String label,
    String value,
  ) {
    return ListTile(
      leading: Icon(icon, color: ctx.colors.textSecondary),
      title: Text(
        label,
        style: TextStyle(
          fontFamily: AppFonts.ui,
          color: ctx.colors.textPrimary,
        ),
      ),
      onTap: () => Navigator.pop(ctx, value),
    );
  }
}
