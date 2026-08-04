import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/settings/settings_store.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/responsive_center.dart';
import '../../l10n/app_localizations.dart';

/// First-run intro: start → cut out → export. Three swipeable pages that
/// explain the flow. Completing or skipping records the flag and routes Home.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  bool _finishing = false;

  /// The three intro pages. Built per-locale and per-theme rather than held as
  /// a `static const`, so switching either re-reads them instead of freezing
  /// whatever the app happened to launch in.
  static List<_Page> _pagesFor(BuildContext context, AppLocalizations l10n) =>
      <_Page>[
        _Page(
          icon: Icons.add_photo_alternate_outlined,
          gradient: context.colors.logoGradient,
          glow: context.colors.violetBright,
          title: l10n.onboardStartTitle,
          body: l10n.onboardStartBody,
        ),
        _Page(
          // Matches EditorTool.cutout, now that the wand means Effects.
          icon: Icons.auto_awesome_outlined,
          gradient: context.colors.cutoutGradient,
          glow: context.colors.green,
          title: l10n.onboardCutoutTitle,
          body: l10n.onboardCutoutBody,
        ),
        _Page(
          icon: Icons.ios_share,
          gradient: context.colors.heroGradient,
          glow: context.colors.pink,
          title: l10n.onboardExportTitle,
          body: l10n.onboardExportBody,
        ),
      ];

  /// The page count is fixed by [_pagesFor] and read before the localizations
  /// are resolved (in [_next]), so it is a constant rather than a list length.
  static const _pageCount = 3;

  bool get _isLast => _page == _pageCount - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    await ref.read(settingsStoreProvider).setOnboardingSeen(true);
    ref.invalidate(onboardingSeenProvider);
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pages = _pagesFor(context, l10n);
    return Scaffold(
      backgroundColor: context.colors.pageBackground,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: AnimatedOpacity(
                opacity: _isLast ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                child: TextButton(
                  onPressed: _isLast || _finishing ? null : _finish,
                  child: Text(
                    l10n.skip,
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => _PageView(page: pages[i]),
              ),
            ),
            _Dots(count: pages.length, active: _page),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              // Capped: at full width on a tablet the CTA is a screen-wide
              // gradient bar around a 60px label, and its glow smears across
              // the whole bottom edge. Narrower than the text measure on
              // purpose - a primary button reads as a button, not a banner.
              child: ResponsiveCenter(
                maxWidth: 420,
                child: SizedBox(
                  width: double.infinity,
                  child: GradientButton(
                    label: _isLast ? l10n.getStarted : l10n.next,
                    icon: _isLast ? Icons.check_rounded : null,
                    busy: _finishing,
                    onPressed: _next,
                    glowColor: pages[_page].glow,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Page {
  const _Page({
    required this.icon,
    required this.gradient,
    required this.glow,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final List<Color> gradient;
  final Color glow;
  final String title;
  final String body;
}

class _PageView extends StatelessWidget {
  const _PageView({required this.page});

  final _Page page;

  @override
  Widget build(BuildContext context) {
    // Centred when there is room, scrollable when there is not. The artwork,
    // title and body add up to a fixed height, so a short viewport - a phone in
    // landscape, a large system font, or simply a device whose insets leave
    // less than we assumed - used to overflow the page instead of letting the
    // user reach the rest of it.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 128,
                height: 128,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: page.gradient,
                  ),
                  borderRadius: BorderRadius.circular(36),
                  boxShadow: [
                    BoxShadow(
                      color: page.glow.withValues(alpha: 0.4),
                      blurRadius: 40,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: Icon(
                  page.icon,
                  size: 58,
                  color: context.colors.onAccent,
                ),
              ),
              const SizedBox(height: 40),
              Text(
                page.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  fontWeight: FontWeight.w700,
                  fontSize: 26,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                page.body,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.ui,
                  fontSize: 14.5,
                  height: 1.5,
                  color: context.colors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == active ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == active
                  ? context.colors.violetLight
                  : context.colors.elevated,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}
