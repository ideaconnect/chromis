import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/models/project.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/name_prompt.dart';
import '../../core/widgets/responsive_center.dart';
import '../../l10n/app_localizations.dart';
import '../editor/state/editor_controller.dart';
import 'project_delete.dart';
import 'project_repository.dart';
import 'widgets/project_tile.dart';

/// Browse and search every saved project, reached from the Home "See all".
/// Filters by name live as you type.
class AllProjectsScreen extends ConsumerStatefulWidget {
  const AllProjectsScreen({super.key});

  @override
  ConsumerState<AllProjectsScreen> createState() => _AllProjectsScreenState();
}

class _AllProjectsScreenState extends ConsumerState<AllProjectsScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Case-insensitive match on the project name.
  static bool _matches(Project p, String q) {
    if (q.isEmpty) return true;
    return p.name.toLowerCase().contains(q.toLowerCase());
  }

  void _openProject(Project p) {
    ref.read(editorControllerProvider.notifier).loadProject(p);
    context.pushNamed(Routes.editor);
  }

  /// Confirms and deletes the project.
  Future<void> _deleteProject(Project project) =>
      confirmAndDeleteProject(context, ref, project);

  /// Renames a saved project in place: dialog → load → copyWith(name) → save.
  /// A cancelled or blank dialog keeps the old name.
  Future<void> _renameProject(Project p) async {
    final l10n = AppLocalizations.of(context);
    final name = await promptName(
      context,
      title: l10n.renameProject,
      initial: p.name,
      hint: l10n.projectNameHint,
    );
    if (name == null) return;
    final repo = ref.read(projectRepositoryProvider);
    final current = await repo.load(p.id) ?? p;
    await repo.save(current.copyWith(name: name, updatedAt: DateTime.now()));
    ref.invalidate(savedProjectsProvider);
  }

  /// Saves a deep copy (`<name> copy`, fresh ids, shared asset files) and
  /// refreshes the list.
  Future<void> _duplicateProject(String id) async {
    await ref
        .read(projectRepositoryProvider)
        .duplicate(id, copyLabel: AppLocalizations.of(context).copySuffix);
    ref.invalidate(savedProjectsProvider);
  }

  /// The content column width. Deliberately the same number Home uses, so
  /// "See all" does not jump from a 3-column grid to a 2-column one.
  static double _columnWidth(BuildContext context) =>
      isTabletWidth(context) ? 840 : 560;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = AppLocalizations.of(context);
    final projectsAsync = ref.watch(savedProjectsProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _topBar(context),
            ResponsiveCenter(
              maxWidth: _columnWidth(context),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
                child: _searchField(),
              ),
            ),
            Expanded(
              child: ResponsiveCenter(
                maxWidth: _columnWidth(context),
                child: projectsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => _Empty(
                    icon: Icons.error_outline,
                    title: l10n.projectsLoadFailed,
                    body: l10n.tryAgainInAMoment,
                  ),
                  data: (all) {
                    if (all.isEmpty) {
                      return _Empty(
                        icon: Icons.auto_awesome,
                        title: l10n.noProjectsYet,
                        body: l10n.allProjectsEmptyHint,
                      );
                    }
                    final matches = all
                        .where((p) => _matches(p, _query))
                        .toList();
                    if (matches.isEmpty) {
                      return _Empty(
                        icon: Icons.search_off,
                        title: l10n.noMatches,
                        body: l10n.noMatchesFor(_query),
                      );
                    }
                    return GridView.count(
                      crossAxisCount: isTabletWidth(context) ? 3 : 2,
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.82,
                      children: [
                        for (final p in matches)
                          ProjectTile(
                            project: p,
                            radius: tokens.radiusCard,
                            onTap: () => _openProject(p),
                            onRename: () => _renameProject(p),
                            onDuplicate: () => _duplicateProject(p.id),
                            onDelete: () => _deleteProject(p),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 6),
      child: Row(
        children: [
          IconButton(
            tooltip: AppLocalizations.of(context).back,
            onPressed: () => context.pop(),
            icon: Icon(
              Icons.chevron_left,
              size: 26,
              color: context.colors.textSecondary,
            ),
          ),
          Expanded(
            child: Text(
              AppLocalizations.of(context).allProjects,
              style: TextStyle(
                fontFamily: AppFonts.display,
                fontWeight: FontWeight.w600,
                fontSize: 17,
                color: context.colors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _searchField() {
    return TextField(
      controller: _controller,
      onChanged: (v) => setState(() => _query = v.trim()),
      textInputAction: TextInputAction.search,
      style: TextStyle(color: context.colors.textPrimary, fontSize: 14.5),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: context.colors.inputField,
        hintText: AppLocalizations.of(context).searchProjects,
        hintStyle: TextStyle(color: context.colors.textFaint, fontSize: 14),
        prefixIcon: Icon(
          Icons.search,
          size: 20,
          color: context.colors.textMuted,
        ),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                icon: Icon(
                  Icons.close,
                  size: 18,
                  color: context.colors.textMuted,
                ),
                onPressed: () {
                  _controller.clear();
                  setState(() => _query = '');
                },
              ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: context.colors.violetLight),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.display,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 12.5,
                color: context.colors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
