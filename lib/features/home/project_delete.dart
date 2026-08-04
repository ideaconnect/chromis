import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/project.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../l10n/app_localizations.dart';
import 'project_repository.dart';

/// Confirms and deletes a saved project. Shared by the Home "Recent" grid and
/// the "All projects" screen.
Future<void> confirmAndDeleteProject(
  BuildContext context,
  WidgetRef ref,
  Project project,
) async {
  final l10n = AppLocalizations.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: context.colors.panel,
      title: Text(
        l10n.deleteProjectTitle(project.name),
        style: TextStyle(
          fontFamily: AppFonts.display,
          color: context.colors.textPrimary,
          fontSize: 17,
        ),
      ),
      content: Text(
        l10n.cannotBeUndone,
        style: TextStyle(
          fontFamily: AppFonts.ui,
          fontSize: 13.5,
          color: context.colors.textMuted,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            l10n.delete,
            style: TextStyle(color: context.colors.rose),
          ),
        ),
      ],
    ),
  );
  if (ok != true) return;

  await ref.read(projectRepositoryProvider).delete(project.id);
  ref.invalidate(savedProjectsProvider);
}
