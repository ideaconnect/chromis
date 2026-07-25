import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/router.dart';
import '../../config/ads_config.dart';
import '../../core/models/layer_transform.dart';
import '../../core/models/project.dart';
import '../../core/rendering/canvas_geometry.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/name_prompt.dart';
import '../../core/widgets/responsive_center.dart';
import '../about/about_data.dart';
import '../editor/services/image_import.dart';
import '../editor/state/editor_controller.dart';
import '../editor/widgets/canvas_size_sheet.dart';
import '../go_pro/iap.dart';
import '../grid/widgets/grid_setup_sheet.dart';
import 'project_delete.dart';
import 'project_repository.dart';
import 'widgets/app_drawer.dart';
import 'widgets/new_project_sheet.dart';
import 'widgets/project_tile.dart';

/// Home screen: brand header, the "New project" hero action, quickstart chips
/// and a grid of the user's saved projects (from [savedProjectsProvider]).
/// A side [AppDrawer] hosts navigation + Go Pro; a placeholder ad banner sits
/// at the bottom until the real AdMob banner lands in M7.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  /// How many recent projects the Home grid shows before "See all". The grid is
  /// shrink-wrapped (non-lazy), so it must stay small - otherwise every saved
  /// project's thumbnail decodes up front. The full list lives in All projects.
  static const _recentCount = 6;

  /// "New project" asks what kind of document first, then branches to the
  /// canvas-size sheet or the Photo Grid setup.
  Future<void> _newProject(BuildContext context, WidgetRef ref) async {
    final mode = await showNewProjectModeSheet(context);
    if (mode == null || !context.mounted) return;
    if (mode == NewProjectMode.grid) return _newGridProject(context, ref);

    final size = await showCanvasSizeSheet(context, title: 'New project');
    if (size == null || !context.mounted) return;
    final project = Project.empty(
      id: 'pe_${DateTime.now().microsecondsSinceEpoch}',
      width: size.width,
      height: size.height,
      createdAt: DateTime.now(),
    );
    ref.read(editorControllerProvider.notifier).loadProject(project);
    // Don't persist yet - the editor auto-saves on the first real edit, so an
    // abandoned blank project never litters Recent.
    unawaited(context.pushNamed(Routes.editor));
  }

  /// Creates a collage: pick the count/layout/size, then fill the whole grid
  /// from one trip to the gallery. Cancelling the picker still opens the
  /// editor on an empty collage - its cells are the invitation to add photos.
  Future<void> _newGridProject(BuildContext context, WidgetRef ref) async {
    final setup = await showGridSetupSheet(context);
    if (setup == null || !context.mounted) return;
    final project = Project.empty(
      id: 'pe_${DateTime.now().microsecondsSinceEpoch}',
      width: setup.width,
      height: setup.height,
      createdAt: DateTime.now(),
    ).copyWith(grid: setup.grid);
    final controller = ref.read(editorControllerProvider.notifier);
    controller.loadProject(project);

    final cellIds = setup.grid.cellIds;
    List<String> picked;
    try {
      picked = await ref
          .read(imageImportServiceProvider)
          .pickMultipleFromGallery(limit: cellIds.length);
    } catch (_) {
      picked = const []; // permission denied / no picker: open it empty
    }
    for (var i = 0; i < picked.length && i < cellIds.length; i++) {
      controller.addPhotoToCell(
        assetPath: picked[i],
        cellId: cellIds[i],
        pixels: await decodeImageSize(picked[i]),
      );
    }
    if (context.mounted) unawaited(context.pushNamed(Routes.editor));
  }

  /// Starts a project FROM a photo: the canvas takes the photo's pixel size and
  /// the photo fills it. (The other start, [_newProject], keeps its fixed size.)
  Future<void> _openPhoto(BuildContext context, WidgetRef ref) async {
    String? path;
    try {
      path = await ref.read(imageImportServiceProvider).pickFromGallery();
    } catch (_) {
      path = null;
    }
    if (path == null || !context.mounted) return;
    final pixels = await decodeImageSize(path);
    final w = pixels?.width.round() ?? 1080;
    final h = pixels?.height.round() ?? 1080;
    final project = Project.empty(
      id: 'pe_${DateTime.now().microsecondsSinceEpoch}',
      width: w,
      height: h,
      createdAt: DateTime.now(),
    );
    final controller = ref.read(editorControllerProvider.notifier);
    controller.loadProject(project);
    final layer = controller.addImageLayer(assetPath: path);
    if (pixels != null) {
      controller.updateTransform(
        layer.id,
        LayerTransform(
          position: project.canvasCenter,
          scale: photoFitScale(pixels, w, h),
        ),
      );
    }
    if (context.mounted) unawaited(context.pushNamed(Routes.editor));
  }

  void _openProject(BuildContext context, WidgetRef ref, Project p) {
    ref.read(editorControllerProvider.notifier).loadProject(p);
    context.pushNamed(Routes.editor);
  }

  Future<void> _deleteProject(
    BuildContext context,
    WidgetRef ref,
    Project project,
  ) => confirmAndDeleteProject(context, ref, project);

  /// Renames a saved project in place: dialog → load → copyWith(name) → save.
  Future<void> _renameProject(
    BuildContext context,
    WidgetRef ref,
    Project p,
  ) async {
    final name = await promptName(
      context,
      title: 'Rename project',
      initial: p.name,
      hint: 'Project name',
    );
    if (name == null) return;
    final repo = ref.read(projectRepositoryProvider);
    final current = await repo.load(p.id) ?? p;
    await repo.save(current.copyWith(name: name, updatedAt: DateTime.now()));
    ref.invalidate(savedProjectsProvider);
  }

  /// Saves a deep copy (`<name> copy`, fresh ids, shared asset files).
  Future<void> _duplicateProject(WidgetRef ref, Project p) async {
    await ref.read(projectRepositoryProvider).duplicate(p.id);
    ref.invalidate(savedProjectsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final projectsAsync = ref.watch(savedProjectsProvider);

    return Scaffold(
      drawer: const AppDrawer(),
      bottomNavigationBar: const _HomeAdBanner(),
      body: SafeArea(
        // A tablet gets a wider column and one more recent per row; a phone is
        // untouched (the gate is shortestSide, so a landscape phone is still a
        // phone). 840 rather than the full width because the two start cards
        // are single-row heroes - much wider and they read as stretched bands.
        child: ResponsiveCenter(
          maxWidth: isTabletWidth(context) ? 840 : 560,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            children: [
              const _Header(),
              const SizedBox(height: 18),
              // Side by side on a tablet: stacked, each is an 800-wide band
              // with a 48px icon stranded at the left end, and the pair costs
              // a third of the fold. A phone keeps them stacked - at 372 wide
              // there is no room for two.
              if (isTabletWidth(context))
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _StartCard(
                          icon: Icons.add,
                          title: 'New project',
                          subtitle: 'Blank canvas or a photo grid',
                          onTap: () => _newProject(context, ref),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StartCard(
                          icon: Icons.photo_library_outlined,
                          title: 'Open a photo',
                          subtitle: "Canvas takes the photo's size",
                          onTap: () => _openPhoto(context, ref),
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                _StartCard(
                  icon: Icons.add,
                  title: 'New project',
                  subtitle: 'Blank canvas or a photo grid',
                  onTap: () => _newProject(context, ref),
                ),
                const SizedBox(height: 12),
                _StartCard(
                  icon: Icons.photo_library_outlined,
                  title: 'Open a photo',
                  subtitle: "Canvas takes the photo's size",
                  onTap: () => _openPhoto(context, ref),
                ),
              ],
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'RECENT',
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.pushNamed(Routes.allProjects),
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      '${projectsAsync.asData?.value.length ?? 0} projects',
                      style: const TextStyle(
                        fontFamily: AppFonts.ui,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              projectsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) => const _EmptyRecent(),
                data: (projects) => projects.isEmpty
                    ? const _EmptyRecent()
                    : GridView.count(
                        crossAxisCount: isTabletWidth(context) ? 3 : 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.82,
                        children: [
                          for (final p in projects.take(_recentCount))
                            ProjectTile(
                              project: p,
                              radius: tokens.radiusCard,
                              onTap: () => _openProject(context, ref, p),
                              onRename: () => _renameProject(context, ref, p),
                              onDuplicate: () => _duplicateProject(ref, p),
                              onDelete: () => _deleteProject(context, ref, p),
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
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your projects',
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  height: 1,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Chromis · Photo editor with AI cutout',
                style: TextStyle(
                  fontFamily: AppFonts.ui,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        const _DiscordButton(),
        const SizedBox(width: 8),
        const _HamburgerButton(),
      ],
    );
  }
}

/// Community Discord button - a circular icon button matching the menu button,
/// sitting just left of it in the Home header. Opens the invite in the Discord
/// app or the browser.
class _DiscordButton extends StatelessWidget {
  const _DiscordButton();

  Future<void> _open() async {
    try {
      await launchUrl(
        Uri.parse(AboutInfo.discordUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      // Nothing else to do on Home if there is no handler for the link.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Join our Discord',
      child: InkWell(
        onTap: () => unawaited(_open()),
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.chipSurface,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1.5,
            ),
          ),
          child: SvgPicture.string(
            _discordSvg,
            width: 20,
            height: 20,
            colorFilter: const ColorFilter.mode(
              AppColors.textSecondary,
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }
}

/// Discord's brand logo, used solely to link to our community server per
/// Discord's brand guidelines (not part of a licensed icon set).
const String _discordSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 640 512">'
    '<path d="M524.531,69.836a1.5,1.5,0,0,0-.764-.7A485.065,485.065,0,0,0,'
    '404.081,32.03a1.816,1.816,0,0,0-1.923.91,337.461,337.461,0,0,0-14.9,'
    '30.6,447.848,447.848,0,0,0-134.426,0,309.541,309.541,0,0,0-15.135-30.6,'
    '1.89,1.89,0,0,0-1.924-.91A483.689,483.689,0,0,0,116.085,69.14a1.712,'
    '1.712,0,0,0-.788.676C39.068,183.651,18.186,294.69,28.43,404.354a2.016,'
    '2.016,0,0,0,.765,1.375A487.666,487.666,0,0,0,176.02,479.918a1.9,1.9,0,'
    '0,0,2.063-.676A348.2,348.2,0,0,0,208.12,430.4a1.86,1.86,0,0,0-1.019-'
    '2.588,321.173,321.173,0,0,1-45.868-21.853,1.885,1.885,0,0,1-.185-3.126'
    'c3.082-2.309,6.166-4.711,9.109-7.137a1.819,1.819,0,0,1,1.9-.256c96.229,'
    '43.917,200.41,43.917,295.5,0a1.812,1.812,0,0,1,1.924.233c2.944,2.426,'
    '6.027,4.851,9.132,7.16a1.884,1.884,0,0,1-.162,3.126,301.407,301.407,0,'
    '0,1-45.89,21.83,1.875,1.875,0,0,0-1,2.611,391.055,391.055,0,0,0,30.014,'
    '48.815,1.864,1.864,0,0,0,2.063.7A486.048,486.048,0,0,0,610.7,405.729a'
    '1.882,1.882,0,0,0,.765-1.352C623.729,277.594,590.933,167.465,524.531,'
    '69.836ZM222.491,337.58c-28.972,0-52.844-26.587-52.844-59.239S193.056,'
    '219.1,222.491,219.1c29.665,0,53.306,26.82,52.843,59.239C275.334,'
    '310.993,251.924,337.58,222.491,337.58Zm195.38,0c-28.971,0-52.843-'
    '26.587-52.843-59.239S388.437,219.1,417.871,219.1c29.667,0,53.307,26.82,'
    '52.844,59.239C470.715,310.993,447.538,337.58,417.871,337.58Z"/></svg>';

class _HamburgerButton extends StatelessWidget {
  const _HamburgerButton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Menu',
      child: InkWell(
        onTap: () => Scaffold.of(context).openDrawer(),
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.chipSurface,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1.5,
            ),
          ),
          child: const Icon(
            Icons.menu,
            size: 20,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// A start-a-project CTA - a dashed cyan border over a subtle cyan-tint
/// gradient, a filled cyan icon tile, a title and a subtitle. Used for both
/// "New blank project" and "Open a photo".
class _StartCard extends StatelessWidget {
  const _StartCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _DashedBorderPainter(
        color: AppColors.cyan.withValues(alpha: 0.42),
        radius: 18,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.cyan.withValues(alpha: 0.12),
              AppColors.cyan.withValues(alpha: 0.03),
            ],
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.cyan,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, size: 26, color: AppColors.cutoutInk),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontFamily: AppFonts.display,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontFamily: AppFonts.ui,
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Strokes a dashed rounded-rectangle border (Flutter has no built-in one).
class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    const dash = 6.0, gap = 5.0;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final len = math.min(dash, metric.length - d);
        canvas.drawPath(metric.extractPath(d, d + len), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}

class _EmptyRecent extends StatelessWidget {
  const _EmptyRecent();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderFaint),
      ),
      child: const Column(
        children: [
          Icon(Icons.auto_awesome, size: 34, color: AppColors.cyan),
          SizedBox(height: 12),
          Text(
            'No projects yet',
            style: TextStyle(
              fontFamily: AppFonts.display,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Tap New project to import a photo.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontSize: 12.5,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder 320×50 banner slot pinned to the bottom of Home. The real
/// AdMob banner (hidden when Pro) is wired in M7; the "Remove ads" chip already
/// routes to the Go Pro paywall.
/// Home's bottom ad slot: a real AdMob banner (Google test unit until real ids
/// are set) with a "Remove ads →" link to Go Pro. Renders nothing for Pro users.
class _HomeAdBanner extends ConsumerStatefulWidget {
  const _HomeAdBanner();

  @override
  ConsumerState<_HomeAdBanner> createState() => _HomeAdBannerState();
}

class _HomeAdBannerState extends ConsumerState<_HomeAdBanner> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (ref.read(isProProvider)) return; // Pro: never request an ad
    final ad = BannerAd(
      adUnitId: AdsConfig.banner,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          _ad = null; // avoid a second dispose() when the widget is disposed
        },
      ),
    );
    _ad = ad;
    ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    // Hide the slot for Pro users, and while there's no ad to show (still
    // loading or no-fill) - no stuck "Ad" placeholder pinned to the bottom.
    if (ref.watch(isProProvider) || !_loaded || ad == null) {
      return const SizedBox.shrink();
    }
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        // Capped to the same column the page body uses. As the Scaffold's
        // bottomNavigationBar this gets a TIGHT full-width constraint, so
        // uncapped the card became a screen-wide empty panel with a 320x50 ad
        // marooned in the middle and the "Remove ads" link stranded in the far
        // corner, hundreds of px from the content it belongs to.
        //
        // Align with heightFactor 1, NOT ResponsiveCenter: its Center expands
        // to the height it is offered, and a bottomNavigationBar is offered the
        // whole screen - which swallowed the page and left the ad floating in
        // the middle of it.
        child: Align(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => context.pushNamed(Routes.goPro),
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.only(bottom: 4, right: 2),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Remove ads →',
                        style: TextStyle(
                          fontFamily: AppFonts.ui,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderFaint),
                  ),
                  child: SizedBox(
                    width: ad.size.width.toDouble(),
                    height: ad.size.height.toDouble(),
                    child: AdWidget(ad: ad),
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
