import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/project.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'project_repository.dart';

/// Confirms and deletes a saved project. Shared by the Home "Recent" grid and
/// the "All projects" screen.
Future<void> confirmAndDeleteProject(
  BuildContext context,
  WidgetRef ref,
  Project project,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.panel,
      title: Text(
        'Delete "${project.name}"?',
        style: const TextStyle(
          fontFamily: AppFonts.display,
          color: AppColors.textPrimary,
          fontSize: 17,
        ),
      ),
      content: const Text(
        "This can't be undone.",
        style: TextStyle(
          fontFamily: AppFonts.ui,
          fontSize: 13.5,
          color: AppColors.textMuted,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete', style: TextStyle(color: AppColors.rose)),
        ),
      ],
    ),
  );
  if (ok != true) return;

  await ref.read(projectRepositoryProvider).delete(project.id);
  ref.invalidate(savedProjectsProvider);
}
