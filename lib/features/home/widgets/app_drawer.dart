import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/models/project.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
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
    final size = await showCanvasSizeSheet(ctx, title: 'New project');
    if (size == null || !ctx.mounted) return;
    final project = Project.empty(
      id: 'pe_${DateTime.now().microsecondsSinceEpoch}',
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
    final tokens = context.tokens;
    return Drawer(
      backgroundColor: AppColors.panel,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: tokens.logoGradient,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 11),
                  // Expanded, not intrinsic: the drawer is a fixed 304dp wide
                  // whatever the screen is, so a wide accessibility text scale
                  // (or a longer subtitle) has to ellipsize rather than
                  // overflow the header row.
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chromis',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppFonts.display,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        // Read from AboutInfo, never a literal: this line was
                        // hardcoded 'v1.0.0' and stayed there for two releases
                        // while the About sheet had already been fixed. The
                        // interpolation is still const - appVersion is.
                        Text(
                          'Photo editor · v${AboutInfo.appVersion}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppFonts.ui,
                            fontSize: 10.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            // The item list scrolls rather than pushing the footer off the
            // bottom: a phone in landscape leaves barely 400px of drawer.
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 8),
                children: [
                  _DrawerItem(
                    icon: Icons.home_outlined,
                    label: 'Home & projects',
                    onTap: () {
                      Navigator.of(context).pop();
                      context.goNamed(Routes.home);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.add_photo_alternate_outlined,
                    label: 'New project',
                    onTap: () => _newProject(context, ref),
                  ),
                  _DrawerItem(
                    icon: Icons.grid_view_rounded,
                    label: 'All projects',
                    onTap: () {
                      Navigator.of(context).pop();
                      context.pushNamed(Routes.allProjects);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.info_outline,
                    label: 'About',
                    onTap: () {
                      Navigator.of(context).pop();
                      showAboutSheet(context);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.privacy_tip_outlined,
                    label: 'Privacy & Cookies',
                    onTap: () {
                      Navigator.of(context).pop();
                      context.pushNamed(Routes.privacy);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.description_outlined,
                    label: 'Licenses',
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
            const Padding(
              padding: EdgeInsets.only(bottom: 14),
              child: Text(
                'IDCT · Bartosz Pachołek',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.ui,
                  fontSize: 10.5,
                  color: AppColors.textMuted,
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
      leading: Icon(icon, color: AppColors.textSecondary, size: 22),
      title: Text(
        label,
        style: const TextStyle(
          fontFamily: AppFonts.ui,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
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
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.workspace_premium,
                  color: AppColors.cutoutInk,
                  size: 18,
                ),
                SizedBox(width: 8),
                // Flexible so a large system font scale shrinks the label
                // instead of overflowing the button, which is fixed-width.
                Flexible(
                  child: Text(
                    'Go Pro · remove ads',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.display,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: AppColors.cutoutInk,
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
