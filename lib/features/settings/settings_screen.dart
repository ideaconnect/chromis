import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/settings/locale_controller.dart';
import '../../core/settings/theme_controller.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/responsive_center.dart';
import '../../l10n/app_localizations.dart';

/// App preferences: the appearance and the UI language. The screen is the home
/// for anything that is a genuine app-wide preference rather than a per-project
/// one.
///
/// Both pickers are three-state in the same way - System, then the explicit
/// choices - because both answer to a device setting the user may already have
/// made. Neither writes anything for "System": see [ThemeModeController] and
/// [LocaleController], where "never chose" and "chose System" are one state.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // The override, not the resolved locale: "System" has to stay selected
    // while the app is (say) showing Polish because the phone is Polish.
    final chosen = ref.watch(localeControllerProvider).asData?.value;
    final mode = ref.watch(themeModeControllerProvider).asData?.value;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(title: l10n.settings),
            Expanded(
              child: ResponsiveCenter(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                  children: [
                    _SectionHeader(l10n.appearance),
                    const SizedBox(height: 10),
                    _AppearanceCard(mode: mode ?? ThemeMode.system),
                    const SizedBox(height: 10),
                    Text(
                      l10n.appearanceNote,
                      style: TextStyle(
                        fontFamily: AppFonts.ui,
                        fontSize: 12,
                        height: 1.45,
                        color: context.colors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 26),
                    _SectionHeader(l10n.language),
                    const SizedBox(height: 10),
                    _LanguageCard(chosen: chosen),
                    const SizedBox(height: 10),
                    Text(
                      l10n.languageNote,
                      style: TextStyle(
                        fontFamily: AppFonts.ui,
                        fontSize: 12,
                        height: 1.45,
                        color: context.colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The radio list for light / dark, with the device setting first.
class _AppearanceCard extends ConsumerWidget {
  const _AppearanceCard({required this.mode});

  final ThemeMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    Future<void> pick(ThemeMode m) =>
        ref.read(themeModeControllerProvider.notifier).setThemeMode(m);

    // Labelled here rather than in the controller: these are user-visible
    // strings, so they need a context to be read from.
    final labels = <ThemeMode, (String, String)>{
      ThemeMode.system: (l10n.appearanceSystem, l10n.appearanceSystemSub),
      ThemeMode.light: (l10n.appearanceLight, l10n.appearanceLightSub),
      ThemeMode.dark: (l10n.appearanceDark, l10n.appearanceDarkSub),
    };

    return _Card(
      children: [
        for (final option in kAppThemeModes)
          _ChoiceRow(
            key: ValueKey('appearance-${option.name}'),
            label: labels[option]!.$1,
            sub: labels[option]!.$2,
            selected: mode == option,
            onTap: () => pick(option),
          ),
      ],
    );
  }
}

/// The rounded surface both pickers sit on.
class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.borderFaint),
      ),
      child: Column(children: children),
    );
  }
}

/// The radio list: "System" plus one row per supported language, each labelled
/// in its own language.
class _LanguageCard extends ConsumerWidget {
  const _LanguageCard({required this.chosen});

  final Locale? chosen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    Future<void> pick(Locale? locale) =>
        ref.read(localeControllerProvider.notifier).setLocale(locale);

    return _Card(
      children: [
        _ChoiceRow(
          key: const ValueKey('language-system'),
          label: l10n.languageSystem,
          sub: l10n.languageSystemSub,
          selected: chosen == null,
          onTap: () => pick(null),
        ),
        for (final language in kAppLanguages)
          _ChoiceRow(
            key: ValueKey('language-${language.locale.languageCode}'),
            label: language.label,
            selected: chosen?.languageCode == language.locale.languageCode,
            onTap: () => pick(language.locale),
          ),
      ],
    );
  }
}

/// One row of a radio list: a label, an optional sub-label, and the tick.
class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    super.key,
    required this.label,
    this.sub,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String? sub;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sub = this.sub;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontFamily: AppFonts.ui,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      if (sub != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          sub,
                          style: TextStyle(
                            fontFamily: AppFonts.ui,
                            fontSize: 11.5,
                            color: context.colors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 20,
                  color: selected
                      ? context.colors.cyan
                      : context.colors.textFaint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontFamily: AppFonts.ui,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: context.colors.textMuted,
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
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
              title,
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
}
