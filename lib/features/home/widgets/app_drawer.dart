import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/models/project.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../l10n/app_localizations.dart';
import '../../about/about_data.dart';
import '../../about/about_sheet.dart';
import '../../editor/state/editor_controller.dart';
import '../../editor/widgets/canvas_size_sheet.dart';
import '../../go_pro/iap.dart';

/// The app-wide side menu (net-new for Chromis). Matches the mockup:
/// brand header, primary destinations, a "Go Pro · remove ads" gradient CTA,
/// and the IDCT footer.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  Future<void> _newProject(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    navigator.pop(); // close the drawer
    // The drawer element is now gone - show the sheet on the stable nav context.
    final ctx = navigator.context;
    final size = await showCanvasSizeSheet(
      ctx,
      title: AppLocalizations.of(ctx).newProject,
    );
    if (size == null || !ctx.mounted) return;
    final project = Project.empty(
      id: 'pe_${DateTime.now().microsecondsSinceEpoch}',
      name: AppLocalizations.of(ctx).untitledProject,
      width: size.width,
      height: size.height,
      createdAt: DateTime.now(),
    );
    ref.read(editorControllerProvider.notifier).loadProject(project);
    // Don't persist yet - the editor auto-saves on the first real edit, so an
    // abandoned blank project never litters Recent.
    if (ctx.mounted) unawaited(ctx.pushNamed(Routes.editor));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Drawer(
      backgroundColor: context.colors.panel,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
              child: Row(
                children: [
                  // The real launcher artwork, like the About sheet's lockup -
                  // not a generic sparkle on the token gradient. This header is
                  // the app naming itself, so it has to be the same mark the
                  // user tapped to get here.
                  const AppLogo(size: 42, radius: 13),
                  const SizedBox(width: 11),
                  // Expanded, not intrinsic: the drawer is a fixed 304dp wide
                  // whatever the screen is, so a wide accessibility text scale
                  // (or a longer subtitle) has to ellipsize rather than
                  // overflow the header row.
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AboutInfo.appName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppFonts.display,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        // Read from AboutInfo, never a literal: this line was
                        // hardcoded 'v1.0.0' and stayed there for two releases
                        // while the About sheet had already been fixed.
                        Text(
                          l10n.drawerSubtitle(AboutInfo.appVersion),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppFonts.ui,
                            fontSize: 10.5,
                            color: context.colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: context.colors.border),
            // The item list scrolls rather than pushing the footer off the
            // bottom: a phone in landscape leaves barely 400px of drawer.
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 8),
                children: [
                  _DrawerItem(
                    icon: Icons.home_outlined,
                    label: l10n.drawerHome,
                    onTap: () {
                      Navigator.of(context).pop();
                      context.goNamed(Routes.home);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.add_photo_alternate_outlined,
                    label: l10n.newProject,
                    onTap: () => _newProject(context, ref),
                  ),
                  _DrawerItem(
                    icon: Icons.grid_view_rounded,
                    label: l10n.allProjects,
                    onTap: () {
                      Navigator.of(context).pop();
                      context.pushNamed(Routes.allProjects);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.settings_outlined,
                    label: l10n.settings,
                    onTap: () {
                      Navigator.of(context).pop();
                      context.pushNamed(Routes.settings);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.info_outline,
                    label: l10n.about,
                    onTap: () {
                      Navigator.of(context).pop();
                      showAboutSheet(context);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.privacy_tip_outlined,
                    label: l10n.privacyTitle,
                    onTap: () {
                      Navigator.of(context).pop();
                      context.pushNamed(Routes.privacy);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.description_outlined,
                    label: l10n.licenses,
                    onTap: () {
                      Navigator.of(context).pop();
                      context.pushNamed(Routes.licenses);
                    },
                  ),
                ],
              ),
            ),
            // Pro users have already removed ads - don't keep selling it.
            if (!ref.watch(isProProvider))
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                child: _GoProButton(
                  onTap: () {
                    Navigator.of(context).pop();
                    context.pushNamed(Routes.goPro);
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                AboutInfo.publisher,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.ui,
                  fontSize: 10.5,
                  color: context.colors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: context.colors.textSecondary, size: 22),
      title: Text(
        label,
        style: TextStyle(
          fontFamily: AppFonts.ui,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: context.colors.textPrimary,
        ),
      ),
      onTap: onTap,
      dense: true,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _GoProButton extends StatelessWidget {
  const _GoProButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: context.tokens.heroGradient,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.workspace_premium,
                  color: context.colors.onAccent,
                  size: 18,
                ),
                const SizedBox(width: 8),
                // Flexible so a large system font scale shrinks the label
                // instead of overflowing the button, which is fixed-width.
                Flexible(
                  child: Text(
                    AppLocalizations.of(context).goProRemoveAds,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.display,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: context.colors.onAccent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
